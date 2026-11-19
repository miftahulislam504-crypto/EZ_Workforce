-- =====================================================================
-- Integrity triggers: tenant isolation of references, privilege guards,
-- plan limits, employee code and invite code generation.
-- =====================================================================

-- Server-side code (SECURITY DEFINER functions) sets this flag for the
-- current transaction when it needs to bypass the client-facing guards.
create or replace function public.guard_bypassed()
returns boolean
language sql
stable
as $$
  select coalesce(current_setting('app.bypass_guard', true), '') = 'on'
$$;

-- ---------------------------------------------------------------------
-- Every foreign reference must point to a row of the same organization.
-- Trigger arguments are "table:column" pairs.
-- ---------------------------------------------------------------------
create or replace function public.enforce_same_org()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pair text;
  v_table text;
  v_col text;
  v_val uuid;
  v_ok boolean;
  v_org uuid := (to_jsonb(new) ->> 'organization_id')::uuid;
begin
  foreach v_pair in array tg_argv loop
    v_table := split_part(v_pair, ':', 1);
    v_col := split_part(v_pair, ':', 2);
    v_val := (to_jsonb(new) ->> v_col)::uuid;
    if v_val is not null then
      execute format(
        'select exists (select 1 from public.%I where id = $1 and organization_id = $2)', v_table)
        into v_ok using v_val, v_org;
      if not v_ok then
        raise exception 'Invalid reference "%": the record does not belong to this organization.', v_col
          using errcode = '23503';
      end if;
    end if;
  end loop;
  return new;
end;
$$;

create trigger trg_employees_0_same_org
  before insert or update on public.employees
  for each row execute function public.enforce_same_org(
    'branches:branch_id', 'departments:department_id', 'designations:designation_id',
    'employees:manager_id', 'roles:role_id');
create trigger trg_branches_0_same_org
  before insert or update on public.branches
  for each row execute function public.enforce_same_org('employees:manager_employee_id');
create trigger trg_departments_0_same_org
  before insert or update on public.departments
  for each row execute function public.enforce_same_org(
    'departments:parent_department_id', 'employees:head_employee_id');
create trigger trg_designations_0_same_org
  before insert or update on public.designations
  for each row execute function public.enforce_same_org('departments:department_id');
create trigger trg_notices_0_same_org
  before insert or update on public.notices
  for each row execute function public.enforce_same_org(
    'branches:branch_id', 'departments:department_id', 'employees:created_by_employee_id');
create trigger trg_employee_private_0_same_org
  before insert or update on public.employee_private
  for each row execute function public.enforce_same_org('employees:employee_id');
create trigger trg_employee_documents_0_same_org
  before insert or update on public.employee_documents
  for each row execute function public.enforce_same_org('employees:employee_id');
create trigger trg_onboarding_items_0_same_org
  before insert or update on public.onboarding_items
  for each row execute function public.enforce_same_org('employees:employee_id');
create trigger trg_notice_receipts_0_same_org
  before insert or update on public.notice_receipts
  for each row execute function public.enforce_same_org('notices:notice_id', 'employees:employee_id');
create trigger trg_role_permissions_0_same_org
  before insert or update on public.role_permissions
  for each row execute function public.enforce_same_org('roles:role_id');

-- ---------------------------------------------------------------------
-- Employees: defaults, plan limit, employee code, invite code
-- ---------------------------------------------------------------------
create or replace function public.employees_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org public.organizations%rowtype;
  v_count int;
  v_prev text := coalesce(current_setting('app.bypass_guard', true), '');
begin
  select * into v_org from public.organizations where id = new.organization_id;
  if not found then
    raise exception 'Organization not found.';
  end if;

  select count(*) into v_count
  from public.employees e
  where e.organization_id = new.organization_id and e.archived_at is null;
  if v_count >= v_org.max_employees then
    raise exception 'Employee limit of % reached for the current plan. Upgrade the plan to add more employees.',
      v_org.max_employees using errcode = 'P0001';
  end if;

  if new.role_id is null then
    select r.id into new.role_id
    from public.roles r
    where r.organization_id = new.organization_id and r.is_default;
  end if;

  if new.employee_code is null or btrim(new.employee_code) = '' then
    perform set_config('app.bypass_guard', 'on', true);
    update public.organizations
       set employee_seq = employee_seq + 1
     where id = new.organization_id
    returning employee_id_prefix, employee_seq into v_org.employee_id_prefix, v_org.employee_seq;
    perform set_config('app.bypass_guard', v_prev, true);
    new.employee_code := v_org.employee_id_prefix || lpad(v_org.employee_seq::text, 4, '0');
  end if;

  if new.user_id is null and new.invite_code is null then
    new.invite_code := upper(substr(md5(random()::text || clock_timestamp()::text || new.id::text), 1, 10));
  end if;

  if new.created_by is null then
    new.created_by := auth.uid();
  end if;

  -- Nothing to do when the organization has no active onboarding template.
  if not exists (
    select 1 from public.onboarding_template_items t
    where t.organization_id = new.organization_id and t.is_active
  ) then
    new.onboarding_status := 'completed';
  end if;

  return new;
end;
$$;

create trigger trg_employees_1_before_insert
  before insert on public.employees
  for each row execute function public.employees_before_insert();

-- Privilege guard for client writes on employees.
create or replace function public.employees_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_new_owner boolean;
  v_new_default boolean;
  v_old_owner boolean;
begin
  if public.guard_bypassed() or auth.uid() is null then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if new.organization_id is distinct from old.organization_id then
      raise exception 'The organization of an employee cannot be changed.';
    end if;
    if new.user_id is distinct from old.user_id
       or new.invite_code is distinct from old.invite_code
       or new.activated_at is distinct from old.activated_at then
      raise exception 'Login linkage can only be changed through the invitation flow.';
    end if;
    if new.employee_code is distinct from old.employee_code then
      raise exception 'Employee ID cannot be changed.';
    end if;
    if new.archived_at is distinct from old.archived_at then
      raise exception 'Use the archive action to archive or restore an employee.';
    end if;
    if new.onboarding_status is distinct from old.onboarding_status then
      raise exception 'Onboarding status is maintained automatically.';
    end if;
  end if;

  if tg_op = 'INSERT' or new.role_id is distinct from old.role_id then
    select r.is_owner, r.is_default into v_new_owner, v_new_default
    from public.roles r
    where r.id = new.role_id and r.organization_id = new.organization_id;
    if not found then
      raise exception 'Invalid role.';
    end if;
    if tg_op = 'UPDATE' and new.id = public.auth_employee_id() then
      raise exception 'You cannot change your own role.';
    end if;
    if v_new_owner and not public.auth_is_owner() then
      raise exception 'Only an owner can assign the Owner role.';
    end if;
    if not v_new_default and not public.has_permission('roles.assign') then
      raise exception 'You do not have permission to assign this role.';
    end if;
    if tg_op = 'UPDATE' then
      select r.is_owner into v_old_owner from public.roles r where r.id = old.role_id;
      if v_old_owner and not public.auth_is_owner() then
        raise exception 'Only an owner can change the role of an owner.';
      end if;
      if v_old_owner and not v_new_owner and not exists (
        select 1 from public.employees o
        join public.roles ro on ro.id = o.role_id
        where o.organization_id = new.organization_id and ro.is_owner
          and o.id <> new.id and o.archived_at is null
      ) then
        raise exception 'The organization must keep at least one owner.';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger trg_employees_2_guard
  before insert or update on public.employees
  for each row execute function public.employees_guard();

-- ---------------------------------------------------------------------
-- Organizations: SaaS fields are not client-editable
-- ---------------------------------------------------------------------
create or replace function public.organizations_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.guard_bypassed() or auth.uid() is null then
    return new;
  end if;
  if new.plan is distinct from old.plan
     or new.subscription_status is distinct from old.subscription_status
     or new.trial_ends_at is distinct from old.trial_ends_at
     or new.max_employees is distinct from old.max_employees
     or new.max_branches is distinct from old.max_branches
     or new.employee_seq is distinct from old.employee_seq
     or new.created_by is distinct from old.created_by then
    raise exception 'Subscription fields can only be changed by the platform.';
  end if;
  return new;
end;
$$;

create trigger trg_organizations_1_guard
  before update on public.organizations
  for each row execute function public.organizations_guard();

-- ---------------------------------------------------------------------
-- Branches: plan limit and head office protection
-- ---------------------------------------------------------------------
create or replace function public.branches_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_max int;
  v_count int;
begin
  select max_branches into v_max from public.organizations where id = new.organization_id;
  select count(*) into v_count from public.branches where organization_id = new.organization_id;
  if v_max is not null and v_count >= v_max then
    raise exception 'Branch limit of % reached for the current plan.', v_max using errcode = 'P0001';
  end if;
  return new;
end;
$$;

create trigger trg_branches_1_before_insert
  before insert on public.branches
  for each row execute function public.branches_before_insert();

create or replace function public.branches_before_delete()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.is_head_office
     and exists (select 1 from public.organizations o where o.id = old.organization_id) then
    raise exception 'The head office branch cannot be deleted.';
  end if;
  return old;
end;
$$;

create trigger trg_branches_2_before_delete
  before delete on public.branches
  for each row execute function public.branches_before_delete();

-- ---------------------------------------------------------------------
-- Roles: system roles are protected
-- ---------------------------------------------------------------------
create or replace function public.roles_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.guard_bypassed() or auth.uid() is null then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  if tg_op = 'DELETE' then
    if old.is_system and exists (select 1 from public.organizations o where o.id = old.organization_id) then
      raise exception 'System roles cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'INSERT' then
    if new.is_owner or new.is_system or new.is_default then
      raise exception 'System roles are created by the platform.';
    end if;
    return new;
  end if;

  if new.organization_id is distinct from old.organization_id
     or new.is_owner is distinct from old.is_owner
     or new.is_system is distinct from old.is_system
     or new.is_default is distinct from old.is_default then
    raise exception 'System role flags cannot be changed.';
  end if;
  if old.is_owner and (new.name is distinct from old.name or new.data_scope is distinct from old.data_scope) then
    raise exception 'The Owner role cannot be renamed or restricted.';
  end if;
  return new;
end;
$$;

create trigger trg_roles_1_guard
  before insert or update or delete on public.roles
  for each row execute function public.roles_guard();
