-- =====================================================================
-- Application RPCs: dashboards, celebrations, roles, archive, photo
-- =====================================================================

-- Next occurrence (today or later) of an annual date such as a birthday.
create or replace function public.next_annual_date(p_date date)
returns date
language sql
stable
as $$
  select case
    when t.cand >= current_date then t.cand
    else (p_date + make_interval(years => t.y + 1))::date
  end
  from (
    select s.y, (p_date + make_interval(years => s.y))::date as cand
    from (
      select (extract(year from current_date)::int - extract(year from p_date)::int) as y
    ) s
  ) t
$$;

-- Birthdays and work anniversaries for every member of the organization.
create or replace function public.upcoming_celebrations(p_days int default 30)
returns table (
  employee_id uuid,
  full_name text,
  photo_path text,
  kind text,
  event_date date,
  years int
)
language sql
stable
security definer
set search_path = public
as $$
  with e as (
    select id, full_name, photo_path, date_of_birth, joining_date
    from public.employees
    where organization_id = public.auth_org_id()
      and archived_at is null
      and status not in ('resigned', 'terminated')
  ),
  b as (
    select id, full_name, photo_path, 'birthday'::text as kind,
           public.next_annual_date(date_of_birth) as event_date,
           (extract(year from public.next_annual_date(date_of_birth))::int
              - extract(year from date_of_birth)::int) as years
    from e
    where date_of_birth is not null
  ),
  a as (
    select id, full_name, photo_path, 'anniversary'::text as kind,
           public.next_annual_date(joining_date) as event_date,
           (extract(year from public.next_annual_date(joining_date))::int
              - extract(year from joining_date)::int) as years
    from e
  )
  select x.id, x.full_name, x.photo_path, x.kind, x.event_date, x.years
  from (
    select * from b
    union all
    select * from a where years > 0
  ) x
  where x.event_date <= current_date + greatest(p_days, 0)
  order by x.event_date, x.full_name
$$;

-- ---------------------------------------------------------------------
-- Organization dashboard
-- ---------------------------------------------------------------------
create or replace function public.dashboard_admin_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_org uuid := public.auth_org_id();
  v_summary jsonb;
  v_branches jsonb;
  v_departments jsonb;
  v_designations jsonb;
  v_types jsonb;
  v_genders jsonb;
  v_trend jsonb;
  v_activity jsonb;
begin
  if v_org is null or not public.has_permission('dashboard.admin') then
    raise exception 'You do not have access to the organization dashboard.' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total', count(*),
    'active', count(*) filter (where status = 'active'),
    'probation', count(*) filter (where status = 'probation'),
    'on_leave', count(*) filter (where status = 'on_leave'),
    'suspended', count(*) filter (where status = 'suspended'),
    'inactive', count(*) filter (where status in ('resigned', 'terminated')),
    'joined_this_month', count(*) filter (where joining_date >= date_trunc('month', current_date)::date),
    'onboarding_pending', count(*) filter (where onboarding_status <> 'completed'),
    'invites_pending', count(*) filter (where user_id is null),
    'probation_ending_soon', count(*) filter (where probation_end_date between current_date and current_date + 30),
    'contracts_expiring_soon', count(*) filter (where contract_end_date between current_date and current_date + 30)
  ) into v_summary
  from public.employees
  where organization_id = v_org and archived_at is null;

  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'count', x.cnt)
                            order by x.cnt desc, x.name), '[]'::jsonb)
    into v_branches
  from (
    select b.id, b.name, count(e.id) as cnt
    from public.branches b
    left join public.employees e on e.branch_id = b.id and e.archived_at is null
    where b.organization_id = v_org
    group by b.id, b.name
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', x.name, 'count', x.cnt)
                            order by x.cnt desc, x.name), '[]'::jsonb)
    into v_departments
  from (
    select d.id, d.name, count(e.id) as cnt
    from public.departments d
    left join public.employees e on e.department_id = d.id and e.archived_at is null
    where d.organization_id = v_org
    group by d.id, d.name
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', x.title, 'count', x.cnt)
                            order by x.cnt desc, x.title), '[]'::jsonb)
    into v_designations
  from (
    select g.id, g.title, count(e.id) as cnt
    from public.designations g
    join public.employees e on e.designation_id = g.id and e.archived_at is null
    where g.organization_id = v_org
    group by g.id, g.title
    order by count(e.id) desc, g.title
    limit 8
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('name', x.employee_type, 'count', x.cnt)
                            order by x.cnt desc), '[]'::jsonb)
    into v_types
  from (
    select employee_type, count(*) as cnt
    from public.employees
    where organization_id = v_org and archived_at is null
    group by employee_type
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object('name', x.gender, 'count', x.cnt)
                            order by x.cnt desc), '[]'::jsonb)
    into v_genders
  from (
    select coalesce(gender, 'unspecified') as gender, count(*) as cnt
    from public.employees
    where organization_id = v_org and archived_at is null
    group by coalesce(gender, 'unspecified')
  ) x;

  select coalesce(jsonb_agg(jsonb_build_object(
           'month', to_char(m.month_start, 'YYYY-MM'),
           'label', to_char(m.month_start, 'Mon'),
           'joined', coalesce(c.cnt, 0)) order by m.month_start), '[]'::jsonb)
    into v_trend
  from (
    select (date_trunc('month', current_date) - make_interval(months => n))::date as month_start
    from generate_series(0, 5) as n
  ) m
  left join (
    select date_trunc('month', joining_date)::date as month_start, count(*) as cnt
    from public.employees
    where organization_id = v_org and archived_at is null
    group by 1
  ) c on c.month_start = m.month_start;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', a.id,
           'action', a.action,
           'entity_type', a.entity_type,
           'summary', a.summary,
           'actor_name', a.actor_name,
           'created_at', a.created_at) order by a.created_at desc), '[]'::jsonb)
    into v_activity
  from (
    select id, action, entity_type, summary, actor_name, created_at
    from public.audit_logs
    where organization_id = v_org
    order by created_at desc, id desc
    limit 8
  ) a;

  return jsonb_build_object(
    'summary', v_summary,
    'by_branch', v_branches,
    'by_department', v_departments,
    'by_designation', v_designations,
    'by_type', v_types,
    'by_gender', v_genders,
    'joining_trend', v_trend,
    'recent_activity', v_activity
  );
end;
$$;

-- ---------------------------------------------------------------------
-- Team dashboard for managers (respects the role data scope)
-- ---------------------------------------------------------------------
create or replace function public.dashboard_team_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_org uuid := public.auth_org_id();
  v_me uuid := public.auth_employee_id();
  v_summary jsonb;
  v_members jsonb;
begin
  if v_org is null or not (public.has_permission('dashboard.team') or public.has_permission('dashboard.admin')) then
    raise exception 'You do not have access to the team dashboard.' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'total', count(*),
    'active', count(*) filter (where e.status = 'active'),
    'probation', count(*) filter (where e.status = 'probation'),
    'on_leave', count(*) filter (where e.status = 'on_leave'),
    'joined_this_month', count(*) filter (where e.joining_date >= date_trunc('month', current_date)::date),
    'onboarding_pending', count(*) filter (where e.onboarding_status <> 'completed')
  ) into v_summary
  from public.employees e
  where e.organization_id = v_org
    and e.archived_at is null
    and e.id <> v_me
    and public.in_scope(e.branch_id, e.department_id, e.id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', m.id,
           'full_name', m.full_name,
           'photo_path', m.photo_path,
           'status', m.status,
           'designation_title', m.designation_title) order by m.full_name), '[]'::jsonb)
    into v_members
  from (
    select e.id, e.full_name, e.photo_path, e.status, g.title as designation_title
    from public.employees e
    left join public.designations g on g.id = e.designation_id
    where e.organization_id = v_org
      and e.archived_at is null
      and e.id <> v_me
      and public.in_scope(e.branch_id, e.department_id, e.id)
    order by e.full_name
    limit 12
  ) m;

  return jsonb_build_object('summary', v_summary, 'members', v_members);
end;
$$;

-- ---------------------------------------------------------------------
-- Replace the permission set of a role in one atomic call
-- ---------------------------------------------------------------------
create or replace function public.set_role_permissions(p_role uuid, p_codes text[])
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role public.roles%rowtype;
  v_old text[];
  v_new text[];
  v_unknown text[];
  v_actor_emp uuid;
  v_actor_name text;
begin
  if not public.has_permission('roles.manage') then
    raise exception 'You do not have permission to manage roles.' using errcode = '42501';
  end if;

  select * into v_role from public.roles where id = p_role and organization_id = public.auth_org_id();
  if not found then
    raise exception 'Role not found.';
  end if;
  if v_role.is_owner then
    raise exception 'The Owner role always has every permission.';
  end if;

  v_new := coalesce((select array_agg(distinct c) from unnest(coalesce(p_codes, '{}'::text[])) c), '{}'::text[]);

  select coalesce(array_agg(c), '{}'::text[]) into v_unknown
  from unnest(v_new) c
  where not exists (select 1 from public.permissions p where p.code = c);
  if array_length(v_unknown, 1) > 0 then
    raise exception 'Unknown permission: %', v_unknown[1];
  end if;

  select coalesce(array_agg(permission_code order by permission_code), '{}'::text[]) into v_old
  from public.role_permissions where role_id = p_role;

  delete from public.role_permissions where role_id = p_role;
  insert into public.role_permissions (role_id, permission_code, organization_id)
  select p_role, c, v_role.organization_id from unnest(v_new) c;

  select e.id, e.full_name into v_actor_emp, v_actor_name
  from public.employees e where e.user_id = auth.uid() limit 1;

  insert into public.audit_logs
    (organization_id, actor_user_id, actor_employee_id, actor_name, action, entity_type, entity_id, summary, changes)
  values (
    v_role.organization_id, auth.uid(), v_actor_emp, v_actor_name, 'update', 'role_permissions', p_role, v_role.name,
    jsonb_build_object(
      'added', to_jsonb(array(select c from unnest(v_new) c where c <> all (v_old))),
      'removed', to_jsonb(array(select c from unnest(v_old) c where c <> all (v_new)))
    )
  );
end;
$$;

-- ---------------------------------------------------------------------
-- Archive or restore an employee
-- ---------------------------------------------------------------------
create or replace function public.archive_employee(p_employee uuid, p_archive boolean default true)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emp public.employees%rowtype;
  v_is_owner boolean;
  v_prev text := coalesce(current_setting('app.bypass_guard', true), '');
begin
  if not public.has_permission('employees.archive') or not public.employee_in_scope(p_employee) then
    raise exception 'You do not have permission to archive this employee.' using errcode = '42501';
  end if;
  if p_employee = public.auth_employee_id() then
    raise exception 'You cannot archive your own record.';
  end if;

  select * into v_emp from public.employees where id = p_employee and organization_id = public.auth_org_id();
  if not found then
    raise exception 'Employee not found.';
  end if;

  select r.is_owner into v_is_owner from public.roles r where r.id = v_emp.role_id;
  if v_is_owner and not public.auth_is_owner() then
    raise exception 'Only an owner can archive another owner.';
  end if;
  if v_is_owner and p_archive and not exists (
    select 1 from public.employees o
    join public.roles ro on ro.id = o.role_id
    where o.organization_id = v_emp.organization_id and ro.is_owner and o.id <> v_emp.id and o.archived_at is null
  ) then
    raise exception 'The organization must keep at least one owner.';
  end if;

  perform set_config('app.bypass_guard', 'on', true);
  update public.employees
     set archived_at = case when p_archive then now() else null end
   where id = p_employee;
  perform set_config('app.bypass_guard', v_prev, true);
end;
$$;

-- ---------------------------------------------------------------------
-- Profile photo of the signed-in employee
-- ---------------------------------------------------------------------
create or replace function public.set_my_photo(p_path text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_emp uuid := public.auth_employee_id();
  v_org uuid := public.auth_org_id();
begin
  if v_emp is null then
    raise exception 'Not signed in.' using errcode = '28000';
  end if;
  if p_path is not null and p_path not like v_org::text || '/' || v_emp::text || '/%' then
    raise exception 'Invalid photo location.';
  end if;
  update public.employees set photo_path = p_path where id = v_emp;
end;
$$;

-- ---------------------------------------------------------------------
-- How many active employees use each role
-- ---------------------------------------------------------------------
create or replace function public.role_usage()
returns table (role_id uuid, employee_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select r.id, count(e.id)
  from public.roles r
  left join public.employees e on e.role_id = r.id and e.archived_at is null
  where r.organization_id = public.auth_org_id()
    and (public.has_permission('roles.view') or public.has_permission('roles.manage'))
  group by r.id
$$;

-- ---------------------------------------------------------------------
-- Read and acknowledgement statistics of a notice (notice managers only)
-- ---------------------------------------------------------------------
create or replace function public.notice_stats(p_notice uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  n public.notices%rowtype;
  v_audience int;
  v_read int;
  v_ack int;
begin
  if not public.has_permission('notices.manage') then
    raise exception 'You do not have permission to view notice statistics.' using errcode = '42501';
  end if;

  select * into n from public.notices where id = p_notice and organization_id = public.auth_org_id();
  if not found then
    raise exception 'Notice not found.';
  end if;

  select count(*) into v_audience
  from public.employees e
  where e.organization_id = n.organization_id
    and e.user_id is not null
    and e.archived_at is null
    and (n.audience = 'all'
         or (n.audience = 'branch' and e.branch_id = n.branch_id)
         or (n.audience = 'department' and e.department_id = n.department_id));

  select count(*) filter (where read_at is not null),
         count(*) filter (where acknowledged_at is not null)
    into v_read, v_ack
  from public.notice_receipts
  where notice_id = p_notice;

  return jsonb_build_object('audience', v_audience, 'read', v_read, 'acknowledged', v_ack);
end;
$$;

revoke execute on function public.role_usage() from public, anon;
revoke execute on function public.notice_stats(uuid) from public, anon;
grant execute on function public.role_usage() to authenticated;
grant execute on function public.notice_stats(uuid) to authenticated;

revoke execute on function public.upcoming_celebrations(int) from public, anon;
revoke execute on function public.dashboard_admin_stats() from public, anon;
revoke execute on function public.dashboard_team_stats() from public, anon;
revoke execute on function public.set_role_permissions(uuid, text[]) from public, anon;
revoke execute on function public.archive_employee(uuid, boolean) from public, anon;
revoke execute on function public.set_my_photo(text) from public, anon;
revoke execute on function public.dispatch_due_notice_notifications(uuid) from public, anon;
grant execute on function public.upcoming_celebrations(int) to authenticated;
grant execute on function public.dashboard_admin_stats() to authenticated;
grant execute on function public.dashboard_team_stats() to authenticated;
grant execute on function public.set_role_permissions(uuid, text[]) to authenticated;
grant execute on function public.archive_employee(uuid, boolean) to authenticated;
grant execute on function public.set_my_photo(text) to authenticated;
