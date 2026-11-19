-- =====================================================================
-- Row Level Security. Tenant isolation first, then permission and
-- data-scope checks. No policy means no access.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Extra helpers used by policies
-- ---------------------------------------------------------------------
create or replace function public.auth_branch_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select e.branch_id from public.employees e
  where e.user_id = auth.uid() and e.archived_at is null
  limit 1
$$;

create or replace function public.auth_department_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select e.department_id from public.employees e
  where e.user_id = auth.uid() and e.archived_at is null
  limit 1
$$;

create or replace function public.employee_in_scope(p_employee uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((
    select public.in_scope(e.branch_id, e.department_id, e.id)
    from public.employees e
    where e.id = p_employee and e.organization_id = public.auth_org_id()
  ), false)
$$;

grant execute on function public.auth_branch_id() to authenticated;
grant execute on function public.auth_department_id() to authenticated;
grant execute on function public.employee_in_scope(uuid) to authenticated;

create or replace function public.notices_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.created_by := auth.uid();
  new.created_by_employee_id := public.auth_employee_id();
  select e.full_name into new.created_by_name
  from public.employees e
  where e.id = new.created_by_employee_id;
  return new;
end;
$$;

create trigger trg_notices_1_before_insert
  before insert on public.notices
  for each row execute function public.notices_before_insert();

-- ---------------------------------------------------------------------
-- Table privileges: anonymous users get nothing.
-- ---------------------------------------------------------------------
revoke all on all tables in schema public from anon;
grant select, insert, update, delete on all tables in schema public to authenticated;

revoke insert, update, delete on public.permissions from authenticated;
revoke insert, update, delete on public.role_permissions from authenticated;
revoke insert, update, delete on public.audit_logs from authenticated;
revoke insert, delete on public.organizations from authenticated;
revoke insert on public.notifications from authenticated;
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- ---------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------
alter table public.organizations enable row level security;
alter table public.branches enable row level security;
alter table public.departments enable row level security;
alter table public.designations enable row level security;
alter table public.permissions enable row level security;
alter table public.roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.employees enable row level security;
alter table public.employee_private enable row level security;
alter table public.employee_documents enable row level security;
alter table public.onboarding_template_items enable row level security;
alter table public.onboarding_items enable row level security;
alter table public.notices enable row level security;
alter table public.notice_receipts enable row level security;
alter table public.notifications enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.audit_logs enable row level security;

-- ---------------------------------------------------------------------
-- Organizations
-- ---------------------------------------------------------------------
create policy organizations_select on public.organizations
  for select to authenticated
  using (id = public.auth_org_id());

create policy organizations_update on public.organizations
  for update to authenticated
  using (id = public.auth_org_id() and public.has_permission('org.manage'))
  with check (id = public.auth_org_id());

-- ---------------------------------------------------------------------
-- Branches, departments, designations: readable by every member
-- ---------------------------------------------------------------------
create policy branches_select on public.branches
  for select to authenticated using (organization_id = public.auth_org_id());
create policy branches_insert on public.branches
  for insert to authenticated
  with check (organization_id = public.auth_org_id() and public.has_permission('branches.manage'));
create policy branches_update on public.branches
  for update to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('branches.manage'))
  with check (organization_id = public.auth_org_id());
create policy branches_delete on public.branches
  for delete to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('branches.manage'));

create policy departments_select on public.departments
  for select to authenticated using (organization_id = public.auth_org_id());
create policy departments_insert on public.departments
  for insert to authenticated
  with check (organization_id = public.auth_org_id() and public.has_permission('departments.manage'));
create policy departments_update on public.departments
  for update to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('departments.manage'))
  with check (organization_id = public.auth_org_id());
create policy departments_delete on public.departments
  for delete to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('departments.manage'));

create policy designations_select on public.designations
  for select to authenticated using (organization_id = public.auth_org_id());
create policy designations_insert on public.designations
  for insert to authenticated
  with check (organization_id = public.auth_org_id() and public.has_permission('designations.manage'));
create policy designations_update on public.designations
  for update to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('designations.manage'))
  with check (organization_id = public.auth_org_id());
create policy designations_delete on public.designations
  for delete to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('designations.manage'));

-- ---------------------------------------------------------------------
-- Roles and permissions
-- ---------------------------------------------------------------------
create policy permissions_select on public.permissions
  for select to authenticated using (true);

create policy roles_select on public.roles
  for select to authenticated using (organization_id = public.auth_org_id());
create policy roles_insert on public.roles
  for insert to authenticated
  with check (organization_id = public.auth_org_id() and public.has_permission('roles.manage'));
create policy roles_update on public.roles
  for update to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('roles.manage'))
  with check (organization_id = public.auth_org_id());
create policy roles_delete on public.roles
  for delete to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('roles.manage'));

create policy role_permissions_select on public.role_permissions
  for select to authenticated
  using (
    organization_id = public.auth_org_id()
    and (
      public.has_permission('roles.view')
      or public.has_permission('roles.manage')
      or exists (
        select 1 from public.employees me
        where me.id = public.auth_employee_id() and me.role_id = role_permissions.role_id
      )
    )
  );

-- ---------------------------------------------------------------------
-- Employees
-- ---------------------------------------------------------------------
create policy employees_select on public.employees
  for select to authenticated
  using (
    organization_id = public.auth_org_id()
    and (
      id = public.auth_employee_id()
      or (public.has_permission('employees.view') and public.in_scope(branch_id, department_id, id))
    )
  );

create policy employees_insert on public.employees
  for insert to authenticated
  with check (organization_id = public.auth_org_id() and public.has_permission('employees.create'));

create policy employees_update on public.employees
  for update to authenticated
  using (
    organization_id = public.auth_org_id()
    and public.has_permission('employees.edit')
    and public.in_scope(branch_id, department_id, id)
  )
  with check (organization_id = public.auth_org_id());

create policy employee_private_select on public.employee_private
  for select to authenticated
  using (
    organization_id = public.auth_org_id()
    and (
      employee_id = public.auth_employee_id()
      or (public.has_permission('employees.view_private') and public.employee_in_scope(employee_id))
    )
  );
create policy employee_private_insert on public.employee_private
  for insert to authenticated
  with check (
    organization_id = public.auth_org_id()
    and public.has_permission('employees.edit_private')
    and public.employee_in_scope(employee_id)
  );
create policy employee_private_update on public.employee_private
  for update to authenticated
  using (
    organization_id = public.auth_org_id()
    and public.has_permission('employees.edit_private')
    and public.employee_in_scope(employee_id)
  )
  with check (organization_id = public.auth_org_id());

create policy employee_documents_select on public.employee_documents
  for select to authenticated
  using (
    organization_id = public.auth_org_id()
    and (
      employee_id = public.auth_employee_id()
      or (public.has_permission('employees.documents') and public.employee_in_scope(employee_id))
    )
  );
create policy employee_documents_insert on public.employee_documents
  for insert to authenticated
  with check (
    organization_id = public.auth_org_id()
    and public.has_permission('employees.documents')
    and public.employee_in_scope(employee_id)
  );
create policy employee_documents_update on public.employee_documents
  for update to authenticated
  using (
    organization_id = public.auth_org_id()
    and public.has_permission('employees.documents')
    and public.employee_in_scope(employee_id)
  )
  with check (organization_id = public.auth_org_id());
create policy employee_documents_delete on public.employee_documents
  for delete to authenticated
  using (
    organization_id = public.auth_org_id()
    and public.has_permission('employees.documents')
    and public.employee_in_scope(employee_id)
  );

-- ---------------------------------------------------------------------
-- Onboarding
-- ---------------------------------------------------------------------
create policy onboarding_template_all on public.onboarding_template_items
  for all to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('onboarding.manage'))
  with check (organization_id = public.auth_org_id() and public.has_permission('onboarding.manage'));

create policy onboarding_items_select on public.onboarding_items
  for select to authenticated
  using (
    organization_id = public.auth_org_id()
    and (
      employee_id = public.auth_employee_id()
      or ((public.has_permission('onboarding.manage') or public.has_permission('employees.view'))
          and public.employee_in_scope(employee_id))
    )
  );
create policy onboarding_items_write on public.onboarding_items
  for all to authenticated
  using (
    organization_id = public.auth_org_id()
    and public.has_permission('onboarding.manage')
    and public.employee_in_scope(employee_id)
  )
  with check (
    organization_id = public.auth_org_id()
    and public.has_permission('onboarding.manage')
    and public.employee_in_scope(employee_id)
  );

-- ---------------------------------------------------------------------
-- Notices
-- ---------------------------------------------------------------------
create policy notices_select on public.notices
  for select to authenticated
  using (
    organization_id = public.auth_org_id()
    and (
      public.has_permission('notices.manage')
      or (
        status = 'published'
        and publish_at <= now()
        and (expires_at is null or expires_at > now())
        and (
          audience = 'all'
          or (audience = 'branch' and branch_id = public.auth_branch_id())
          or (audience = 'department' and department_id = public.auth_department_id())
        )
      )
    )
  );
create policy notices_insert on public.notices
  for insert to authenticated
  with check (organization_id = public.auth_org_id() and public.has_permission('notices.manage'));
create policy notices_update on public.notices
  for update to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('notices.manage'))
  with check (organization_id = public.auth_org_id());
create policy notices_delete on public.notices
  for delete to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('notices.manage'));

create policy notice_receipts_select on public.notice_receipts
  for select to authenticated
  using (
    organization_id = public.auth_org_id()
    and (employee_id = public.auth_employee_id() or public.has_permission('notices.manage'))
  );
create policy notice_receipts_insert on public.notice_receipts
  for insert to authenticated
  with check (
    organization_id = public.auth_org_id()
    and employee_id = public.auth_employee_id()
    and exists (select 1 from public.notices n where n.id = notice_receipts.notice_id)
  );
create policy notice_receipts_update on public.notice_receipts
  for update to authenticated
  using (organization_id = public.auth_org_id() and employee_id = public.auth_employee_id())
  with check (organization_id = public.auth_org_id() and employee_id = public.auth_employee_id());

-- ---------------------------------------------------------------------
-- Notifications and preferences
-- ---------------------------------------------------------------------
create policy notifications_select on public.notifications
  for select to authenticated
  using (employee_id = public.auth_employee_id());
create policy notifications_update on public.notifications
  for update to authenticated
  using (employee_id = public.auth_employee_id())
  with check (employee_id = public.auth_employee_id());
create policy notifications_delete on public.notifications
  for delete to authenticated
  using (employee_id = public.auth_employee_id());

create policy notification_preferences_all on public.notification_preferences
  for all to authenticated
  using (employee_id = public.auth_employee_id())
  with check (employee_id = public.auth_employee_id() and organization_id = public.auth_org_id());

-- ---------------------------------------------------------------------
-- Audit trail
-- ---------------------------------------------------------------------
create policy audit_logs_select on public.audit_logs
  for select to authenticated
  using (organization_id = public.auth_org_id() and public.has_permission('audit.view'));

-- ---------------------------------------------------------------------
-- Directory view: limited, non-sensitive columns for every colleague.
-- It runs with the view owner's rights and filters by the caller's org.
-- ---------------------------------------------------------------------
create view public.employee_directory as
select
  e.id,
  e.organization_id,
  e.employee_code,
  e.full_name,
  e.first_name,
  e.last_name,
  e.photo_path,
  e.work_email,
  e.work_phone,
  e.status,
  e.employee_type,
  e.joining_date,
  e.branch_id,
  b.name as branch_name,
  e.department_id,
  d.name as department_name,
  e.designation_id,
  g.title as designation_title,
  e.manager_id,
  m.full_name as manager_name,
  (e.user_id is not null) as has_login
from public.employees e
left join public.branches b on b.id = e.branch_id
left join public.departments d on d.id = e.department_id
left join public.designations g on g.id = e.designation_id
left join public.employees m on m.id = e.manager_id
where e.organization_id = public.auth_org_id()
  and e.archived_at is null;

revoke all on public.employee_directory from anon;
grant select on public.employee_directory to authenticated;
