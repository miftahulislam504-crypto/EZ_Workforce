-- =====================================================================
-- Permission catalog and security helper functions
-- =====================================================================

insert into public.permissions (code, module, action, label, description, sort_order) values
  ('dashboard.admin',      'Dashboard',    'view',    'View organization dashboard',      'See company-wide workforce statistics.', 10),
  ('dashboard.team',       'Dashboard',    'view',    'View team dashboard',              'See statistics for the employees inside the role data scope.', 11),
  ('org.manage',           'Organization', 'manage',  'Manage company profile',           'Edit company profile, regional settings and ID format.', 20),
  ('branches.manage',      'Organization', 'manage',  'Manage branches',                  'Create, edit and deactivate branches.', 21),
  ('departments.manage',   'Organization', 'manage',  'Manage departments',               'Create, edit and deactivate departments.', 22),
  ('designations.manage',  'Organization', 'manage',  'Manage designations',              'Create, edit and deactivate designations.', 23),
  ('roles.view',           'Access',       'view',    'View roles and permissions',       'See the role list and permission matrix.', 30),
  ('roles.manage',         'Access',       'manage',  'Manage roles and permissions',     'Create roles and change their permissions.', 31),
  ('roles.assign',         'Access',       'assign',  'Assign roles to employees',        'Change the role of an employee.', 32),
  ('employees.view',       'Employees',    'view',    'View employee profiles',           'Open full employee profiles inside the role data scope.', 40),
  ('employees.create',     'Employees',    'create',  'Register employees',               'Add new employees and send login invitations.', 41),
  ('employees.edit',       'Employees',    'edit',    'Edit employees',                   'Update employment and personal information.', 42),
  ('employees.archive',    'Employees',    'archive', 'Archive employees',                'Archive or restore employee records.', 43),
  ('employees.view_private','Employees',   'view',    'View sensitive employee data',     'See national ID, passport and payment details.', 44),
  ('employees.edit_private','Employees',   'edit',    'Edit sensitive employee data',     'Change national ID, passport and payment details.', 45),
  ('employees.documents',  'Employees',    'manage',  'Manage employee documents',        'Upload, view and delete employee documents.', 46),
  ('employees.export',     'Employees',    'export',  'Export employee data',             'Download the employee list as a file.', 47),
  ('onboarding.manage',    'Onboarding',   'manage',  'Manage onboarding',                'Edit the onboarding template and complete checklist items.', 50),
  ('notices.manage',       'Notice Board', 'manage',  'Manage notices',                   'Create, edit, pin and remove notices.', 60),
  ('audit.view',           'Security',     'view',    'View audit trail',                 'See who changed what and when.', 70)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------
-- Session helpers. SECURITY DEFINER avoids RLS recursion because these
-- are evaluated inside policies of the same tables they read.
-- ---------------------------------------------------------------------
create or replace function public.auth_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select e.id
  from public.employees e
  where e.user_id = auth.uid() and e.archived_at is null
  limit 1
$$;

create or replace function public.auth_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select e.organization_id
  from public.employees e
  where e.user_id = auth.uid() and e.archived_at is null
  limit 1
$$;

create or replace function public.auth_is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select r.is_owner
    from public.employees e
    join public.roles r on r.id = e.role_id
    where e.user_id = auth.uid() and e.archived_at is null
    limit 1
  ), false)
$$;

create or replace function public.has_permission(p_code text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select r.is_owner or exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_code = p_code
    )
    from public.employees e
    join public.roles r on r.id = e.role_id
    where e.user_id = auth.uid() and e.archived_at is null
    limit 1
  ), false)
$$;

create or replace function public.auth_data_scope()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case when r.is_owner then 'organization' else r.data_scope end
  from public.employees e
  join public.roles r on r.id = e.role_id
  where e.user_id = auth.uid() and e.archived_at is null
  limit 1
$$;

-- True when the target employee falls inside the caller's role data scope.
create or replace function public.in_scope(p_branch uuid, p_department uuid, p_employee uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select case
      when r.is_owner or r.data_scope = 'organization' then true
      when r.data_scope = 'branch' then me.branch_id is not null and me.branch_id = p_branch
      when r.data_scope = 'department' then me.department_id is not null and me.department_id = p_department
      else me.id = p_employee
    end or me.id = p_employee
    from public.employees me
    join public.roles r on r.id = me.role_id
    where me.user_id = auth.uid() and me.archived_at is null
    limit 1
  ), false)
$$;

grant execute on function public.auth_employee_id() to authenticated;
grant execute on function public.auth_org_id() to authenticated;
grant execute on function public.auth_is_owner() to authenticated;
grant execute on function public.has_permission(text) to authenticated;
grant execute on function public.auth_data_scope() to authenticated;
grant execute on function public.in_scope(uuid, uuid, uuid) to authenticated;
