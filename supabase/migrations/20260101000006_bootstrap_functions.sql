-- =====================================================================
-- Bootstrap: organization registration, invitation claim, app context
-- =====================================================================

-- ---------------------------------------------------------------------
-- Default roles, structure and onboarding template for a new tenant
-- ---------------------------------------------------------------------
create or replace function public.seed_organization_defaults(p_org uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_hr uuid;
  v_branch_mgr uuid;
  v_dept_mgr uuid;
  v_employee uuid;
begin
  insert into public.roles (organization_id, name, description, data_scope, is_owner, is_system, is_default)
  values (p_org, 'Owner', 'Full control of the organization, including roles and settings.', 'organization', true, true, false)
  returning id into v_owner;

  insert into public.roles (organization_id, name, description, data_scope, is_owner, is_system, is_default)
  values (p_org, 'HR Admin', 'Manages employees, onboarding, notices and organization structure.', 'organization', false, true, false)
  returning id into v_hr;

  insert into public.roles (organization_id, name, description, data_scope, is_owner, is_system, is_default)
  values (p_org, 'Branch Manager', 'Oversees the employees of their own branch.', 'branch', false, true, false)
  returning id into v_branch_mgr;

  insert into public.roles (organization_id, name, description, data_scope, is_owner, is_system, is_default)
  values (p_org, 'Department Manager', 'Oversees the employees of their own department or team.', 'department', false, true, false)
  returning id into v_dept_mgr;

  insert into public.roles (organization_id, name, description, data_scope, is_owner, is_system, is_default)
  values (p_org, 'Employee', 'Standard access to personal information and company notices.', 'self', false, true, true)
  returning id into v_employee;

  insert into public.role_permissions (role_id, permission_code, organization_id)
  select v_owner, p.code, p_org from public.permissions p;

  insert into public.role_permissions (role_id, permission_code, organization_id)
  select v_hr, c, p_org
  from unnest(array[
    'dashboard.admin', 'branches.manage', 'departments.manage', 'designations.manage',
    'roles.view', 'roles.assign',
    'employees.view', 'employees.create', 'employees.edit', 'employees.archive',
    'employees.view_private', 'employees.edit_private', 'employees.documents', 'employees.export',
    'onboarding.manage', 'notices.manage', 'audit.view'
  ]) as c;

  insert into public.role_permissions (role_id, permission_code, organization_id)
  select v_branch_mgr, c, p_org from unnest(array['dashboard.team', 'employees.view']) as c;

  insert into public.role_permissions (role_id, permission_code, organization_id)
  select v_dept_mgr, c, p_org from unnest(array['dashboard.team', 'employees.view']) as c;

  insert into public.departments (organization_id, name, code, description) values
    (p_org, 'Management', 'MGT', 'Company leadership and administration.'),
    (p_org, 'Human Resources', 'HR', 'People operations, hiring and employee relations.');

  insert into public.designations (organization_id, title, level, description) values
    (p_org, 'Owner', 10, 'Company owner or chief executive.'),
    (p_org, 'HR Manager', 7, 'Leads human resources.'),
    (p_org, 'Manager', 6, 'Leads a team or branch.'),
    (p_org, 'Executive', 3, 'Experienced individual contributor.'),
    (p_org, 'Officer', 2, 'Operational role.'),
    (p_org, 'Intern', 1, 'Short term learning role.');
end;
$$;

create or replace function public.seed_onboarding_template(p_org uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.onboarding_template_items (organization_id, title, description, sort_order) values
    (p_org, 'Collect signed appointment letter', 'Appointment or offer letter signed by the employee.', 1),
    (p_org, 'Collect identity documents', 'National ID or passport copy as required by company policy.', 2),
    (p_org, 'Collect certificates', 'Educational and experience certificates.', 3),
    (p_org, 'Collect photographs', 'Passport size photographs for records and ID card.', 4),
    (p_org, 'Capture payment details', 'Bank or mobile financial service details for salary payment.', 5),
    (p_org, 'Issue employee ID card', 'Prepare and hand over the employee identity card.', 6),
    (p_org, 'Assign equipment and workspace', 'Laptop, phone, desk, access cards and tools.', 7),
    (p_org, 'Share company policies', 'Employee handbook, code of conduct and HR policies.', 8),
    (p_org, 'Introduce to team', 'Introduce the employee to the reporting manager and team.', 9);
end;
$$;

-- ---------------------------------------------------------------------
-- Create a complete organization with its owner
-- ---------------------------------------------------------------------
create or replace function public.create_organization_for_user(p_user uuid, p_email text, p_meta jsonb)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
  v_name text := btrim(coalesce(p_meta ->> 'org_name', ''));
  v_full text := btrim(coalesce(p_meta ->> 'full_name', ''));
  v_first text;
  v_last text;
  v_branch uuid;
  v_dept uuid;
  v_desig uuid;
  v_role uuid;
  v_prev text := coalesce(current_setting('app.bypass_guard', true), '');
begin
  if v_name = '' then
    raise exception 'Organization name is required.';
  end if;
  if v_full = '' then
    v_full := split_part(coalesce(p_email, 'Owner'), '@', 1);
  end if;
  v_first := split_part(v_full, ' ', 1);
  v_last := nullif(btrim(substr(v_full, length(v_first) + 1)), '');

  perform set_config('app.bypass_guard', 'on', true);

  insert into public.organizations (name, business_type, country, timezone, currency, phone, email, created_by)
  values (
    v_name,
    nullif(btrim(coalesce(p_meta ->> 'business_type', '')), ''),
    nullif(btrim(coalesce(p_meta ->> 'country', '')), ''),
    coalesce(nullif(btrim(coalesce(p_meta ->> 'timezone', '')), ''), 'Asia/Dhaka'),
    coalesce(nullif(btrim(coalesce(p_meta ->> 'currency', '')), ''), 'BDT'),
    nullif(btrim(coalesce(p_meta ->> 'phone', '')), ''),
    p_email,
    p_user
  )
  returning id into v_org;

  perform public.seed_organization_defaults(v_org);

  insert into public.branches (organization_id, name, code, is_head_office)
  values (v_org, 'Head Office', 'HO', true)
  returning id into v_branch;

  select id into v_dept from public.departments where organization_id = v_org and code = 'MGT';
  select id into v_desig from public.designations where organization_id = v_org and title = 'Owner';
  select id into v_role from public.roles where organization_id = v_org and is_owner;

  insert into public.employees (
    organization_id, user_id, first_name, last_name, work_email, personal_phone,
    branch_id, department_id, designation_id, role_id, status, activated_at
  )
  values (
    v_org, p_user, v_first, v_last, p_email, nullif(btrim(coalesce(p_meta ->> 'phone', '')), ''),
    v_branch, v_dept, v_desig, v_role, 'active', now()
  );

  -- The template is seeded after the owner so the owner has no checklist.
  perform public.seed_onboarding_template(v_org);

  perform set_config('app.bypass_guard', v_prev, true);
  return v_org;
end;
$$;

-- Sign-up with registration metadata creates the tenant immediately, even
-- when e-mail confirmation is enabled and no session exists yet.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(new.raw_user_meta_data ->> 'registration_type', '') = 'organization' then
    perform public.create_organization_for_user(new.id, new.email, new.raw_user_meta_data);
  end if;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

-- ---------------------------------------------------------------------
-- Invitation flow for employee mobile login
-- ---------------------------------------------------------------------
create or replace function public.claim_invite(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emp public.employees%rowtype;
  v_prev text := coalesce(current_setting('app.bypass_guard', true), '');
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to activate an invitation.' using errcode = '28000';
  end if;
  if exists (select 1 from public.employees where user_id = auth.uid()) then
    raise exception 'This account is already linked to an organization.';
  end if;

  select * into v_emp
  from public.employees
  where invite_code = upper(btrim(coalesce(p_code, '')))
    and user_id is null
    and archived_at is null
  for update;
  if not found then
    raise exception 'The invitation code is invalid or has already been used.';
  end if;

  perform set_config('app.bypass_guard', 'on', true);
  update public.employees
     set user_id = auth.uid(), activated_at = now(), invite_code = null
   where id = v_emp.id;
  perform set_config('app.bypass_guard', v_prev, true);

  perform public.notify_employee(
    v_emp.id, 'system', 'Welcome aboard',
    'Your account is active. Review your profile and read the latest company notices.', '/profile');
  return v_emp.id;
end;
$$;

create or replace function public.regenerate_invite(p_employee uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_prev text := coalesce(current_setting('app.bypass_guard', true), '');
begin
  if not public.has_permission('employees.edit') or not public.employee_in_scope(p_employee) then
    raise exception 'You do not have permission to manage this invitation.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.employees
    where id = p_employee and user_id is null and archived_at is null
  ) then
    raise exception 'This employee already has an active login.';
  end if;

  v_code := upper(substr(md5(random()::text || clock_timestamp()::text || p_employee::text), 1, 10));
  perform set_config('app.bypass_guard', 'on', true);
  update public.employees set invite_code = v_code where id = p_employee;
  perform set_config('app.bypass_guard', v_prev, true);
  return v_code;
end;
$$;

-- ---------------------------------------------------------------------
-- One call that bootstraps the signed-in app session
-- ---------------------------------------------------------------------
create or replace function public.current_context()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_emp public.employees%rowtype;
  v_role public.roles%rowtype;
  v_org public.organizations%rowtype;
  v_perms text[];
begin
  select * into v_emp
  from public.employees
  where user_id = auth.uid() and archived_at is null;
  if not found then
    return null;
  end if;

  select * into v_role from public.roles where id = v_emp.role_id;
  select * into v_org from public.organizations where id = v_emp.organization_id;

  if v_role.is_owner then
    select coalesce(array_agg(code order by code), '{}') into v_perms from public.permissions;
  else
    select coalesce(array_agg(permission_code order by permission_code), '{}') into v_perms
    from public.role_permissions where role_id = v_role.id;
  end if;

  return jsonb_build_object(
    'employee', jsonb_build_object(
      'id', v_emp.id,
      'employee_code', v_emp.employee_code,
      'first_name', v_emp.first_name,
      'last_name', v_emp.last_name,
      'full_name', v_emp.full_name,
      'photo_path', v_emp.photo_path,
      'work_email', v_emp.work_email,
      'status', v_emp.status,
      'branch_id', v_emp.branch_id,
      'department_id', v_emp.department_id,
      'designation_id', v_emp.designation_id,
      'branch_name', (select name from public.branches where id = v_emp.branch_id),
      'department_name', (select name from public.departments where id = v_emp.department_id),
      'designation_title', (select title from public.designations where id = v_emp.designation_id),
      'onboarding_status', v_emp.onboarding_status
    ),
    'role', jsonb_build_object(
      'id', v_role.id,
      'name', v_role.name,
      'is_owner', v_role.is_owner,
      'data_scope', case when v_role.is_owner then 'organization' else v_role.data_scope end
    ),
    'organization', jsonb_build_object(
      'id', v_org.id,
      'name', v_org.name,
      'logo_path', v_org.logo_path,
      'timezone', v_org.timezone,
      'currency', v_org.currency,
      'date_format', v_org.date_format,
      'time_format', v_org.time_format,
      'plan', v_org.plan,
      'subscription_status', v_org.subscription_status,
      'trial_ends_at', v_org.trial_ends_at
    ),
    'permissions', to_jsonb(v_perms),
    'unread_notifications', (
      select count(*) from public.notifications n where n.employee_id = v_emp.id and n.read_at is null
    )
  );
end;
$$;

revoke execute on function public.claim_invite(text) from public, anon;
revoke execute on function public.regenerate_invite(uuid) from public, anon;
revoke execute on function public.current_context() from public, anon;
grant execute on function public.claim_invite(text) to authenticated;
grant execute on function public.regenerate_invite(uuid) to authenticated;
grant execute on function public.current_context() to authenticated;
