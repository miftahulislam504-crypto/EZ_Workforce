-- =====================================================================
-- EZ Workforce - Phase 1 - Core schema
-- Multi-tenant: every business table carries organization_id.
-- =====================================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------
-- Organizations (tenant root). Includes SaaS plan and limits.
-- ---------------------------------------------------------------------
create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  business_type text,
  logo_path text,
  email text,
  phone text,
  website text,
  address_line text,
  city text,
  state_region text,
  postal_code text,
  country text,
  timezone text not null default 'Asia/Dhaka',
  currency text not null default 'BDT',
  date_format text not null default 'dd MMM yyyy',
  time_format text not null default '12h' check (time_format in ('12h', '24h')),
  fiscal_year_start_month int not null default 1 check (fiscal_year_start_month between 1 and 12),
  employee_id_prefix text not null default 'EMP',
  employee_seq bigint not null default 0,
  plan text not null default 'trial' check (plan in ('trial', 'starter', 'business', 'enterprise')),
  subscription_status text not null default 'trialing'
    check (subscription_status in ('trialing', 'active', 'past_due', 'suspended', 'cancelled')),
  trial_ends_at timestamptz not null default (now() + interval '14 days'),
  max_employees int not null default 50,
  max_branches int not null default 5,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger trg_organizations_updated
  before update on public.organizations
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Branches, departments, designations
-- ---------------------------------------------------------------------
create table public.branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  code text,
  address_line text,
  city text,
  phone text,
  email text,
  manager_employee_id uuid,
  is_head_office boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index uq_branches_org_name on public.branches (organization_id, lower(name));
create unique index uq_branches_org_code on public.branches (organization_id, lower(code)) where code is not null;
create index ix_branches_org on public.branches (organization_id);
create trigger trg_branches_updated
  before update on public.branches
  for each row execute function public.set_updated_at();

create table public.departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  code text,
  description text,
  head_employee_id uuid,
  parent_department_id uuid references public.departments (id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index uq_departments_org_name on public.departments (organization_id, lower(name));
create unique index uq_departments_org_code on public.departments (organization_id, lower(code)) where code is not null;
create index ix_departments_org on public.departments (organization_id);
create trigger trg_departments_updated
  before update on public.departments
  for each row execute function public.set_updated_at();

create table public.designations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  title text not null,
  level int not null default 1 check (level between 1 and 20),
  department_id uuid references public.departments (id) on delete set null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index uq_designations_org_title on public.designations (organization_id, lower(title));
create index ix_designations_org on public.designations (organization_id);
create trigger trg_designations_updated
  before update on public.designations
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- Roles and permissions
-- ---------------------------------------------------------------------
create table public.permissions (
  code text primary key,
  module text not null,
  action text not null,
  label text not null,
  description text,
  sort_order int not null default 0
);

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  name text not null,
  description text,
  data_scope text not null default 'self'
    check (data_scope in ('organization', 'branch', 'department', 'self')),
  is_owner boolean not null default false,
  is_system boolean not null default false,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index uq_roles_org_name on public.roles (organization_id, lower(name));
create unique index uq_roles_one_owner on public.roles (organization_id) where is_owner;
create unique index uq_roles_one_default on public.roles (organization_id) where is_default;
create index ix_roles_org on public.roles (organization_id);
create trigger trg_roles_updated
  before update on public.roles
  for each row execute function public.set_updated_at();

create table public.role_permissions (
  role_id uuid not null references public.roles (id) on delete cascade,
  permission_code text not null references public.permissions (code) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  primary key (role_id, permission_code)
);
create index ix_role_permissions_org on public.role_permissions (organization_id);

-- ---------------------------------------------------------------------
-- Employees
-- ---------------------------------------------------------------------
create table public.employees (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid unique references auth.users (id) on delete set null,
  employee_code text not null default '',

  first_name text not null,
  last_name text,
  full_name text generated always as (trim(first_name || ' ' || coalesce(last_name, ''))) stored,
  photo_path text,
  date_of_birth date,
  gender text check (gender in ('male', 'female', 'other', 'prefer_not_to_say')),
  blood_group text check (blood_group in ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
  marital_status text check (marital_status in ('single', 'married', 'divorced', 'widowed')),

  personal_phone text,
  work_phone text,
  work_email text,
  personal_email text,
  present_address text,
  permanent_address text,
  emergency_contact_name text,
  emergency_contact_relation text,
  emergency_contact_phone text,

  joining_date date not null default current_date,
  employee_type text not null default 'full_time'
    check (employee_type in ('full_time', 'part_time', 'contractual', 'intern', 'temporary')),
  status text not null default 'active'
    check (status in ('active', 'probation', 'on_leave', 'suspended', 'resigned', 'terminated')),
  branch_id uuid references public.branches (id) on delete set null,
  department_id uuid references public.departments (id) on delete set null,
  designation_id uuid references public.designations (id) on delete set null,
  manager_id uuid references public.employees (id) on delete set null,
  role_id uuid not null references public.roles (id) on delete restrict,
  work_location text,
  probation_end_date date,
  confirmation_date date,
  contract_start_date date,
  contract_end_date date,

  invite_code text unique,
  activated_at timestamptz,
  onboarding_status text not null default 'pending'
    check (onboarding_status in ('pending', 'in_progress', 'completed')),
  archived_at timestamptz,

  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index uq_employees_org_code on public.employees (organization_id, lower(employee_code));
create unique index uq_employees_org_email on public.employees (organization_id, lower(work_email))
  where work_email is not null and work_email <> '';
create index ix_employees_org on public.employees (organization_id);
create index ix_employees_org_branch on public.employees (organization_id, branch_id);
create index ix_employees_org_department on public.employees (organization_id, department_id);
create index ix_employees_manager on public.employees (manager_id);
create index ix_employees_user on public.employees (user_id);
create trigger trg_employees_updated
  before update on public.employees
  for each row execute function public.set_updated_at();

alter table public.branches
  add constraint fk_branches_manager foreign key (manager_employee_id)
  references public.employees (id) on delete set null;
alter table public.departments
  add constraint fk_departments_head foreign key (head_employee_id)
  references public.employees (id) on delete set null;

-- Sensitive data lives in its own table so access can be restricted separately.
create table public.employee_private (
  employee_id uuid primary key references public.employees (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  national_id text,
  passport_no text,
  bank_name text,
  bank_account_name text,
  bank_account_number text,
  mfs_provider text,
  mfs_number text,
  updated_at timestamptz not null default now()
);
create index ix_employee_private_org on public.employee_private (organization_id);
create trigger trg_employee_private_updated
  before update on public.employee_private
  for each row execute function public.set_updated_at();

create table public.employee_documents (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  doc_type text not null default 'other'
    check (doc_type in ('cv', 'national_id', 'photograph', 'education_certificate',
                        'experience_certificate', 'appointment_letter', 'employment_contract', 'other')),
  title text not null,
  storage_path text not null,
  file_name text,
  file_size bigint,
  mime_type text,
  uploaded_by uuid,
  created_at timestamptz not null default now()
);
create index ix_employee_documents_employee on public.employee_documents (employee_id);
create index ix_employee_documents_org on public.employee_documents (organization_id);

-- ---------------------------------------------------------------------
-- Onboarding
-- ---------------------------------------------------------------------
create table public.onboarding_template_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  title text not null,
  description text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index ix_onboarding_template_org on public.onboarding_template_items (organization_id);

create table public.onboarding_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  title text not null,
  description text,
  is_done boolean not null default false,
  done_at timestamptz,
  done_by uuid,
  due_date date,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index ix_onboarding_items_employee on public.onboarding_items (employee_id);
create index ix_onboarding_items_org on public.onboarding_items (organization_id);

-- ---------------------------------------------------------------------
-- Notice board
-- ---------------------------------------------------------------------
create table public.notices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  title text not null,
  body text not null default '',
  category text not null default 'general'
    check (category in ('general', 'hr', 'policy', 'event', 'urgent')),
  is_pinned boolean not null default false,
  audience text not null default 'all' check (audience in ('all', 'branch', 'department')),
  branch_id uuid references public.branches (id) on delete cascade,
  department_id uuid references public.departments (id) on delete cascade,
  status text not null default 'published' check (status in ('draft', 'published', 'archived')),
  publish_at timestamptz not null default now(),
  expires_at timestamptz,
  requires_ack boolean not null default false,
  attachments jsonb not null default '[]'::jsonb,
  notified_at timestamptz,
  created_by uuid,
  created_by_employee_id uuid references public.employees (id) on delete set null,
  created_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint ck_notices_audience_target check (
    (audience = 'all' and branch_id is null and department_id is null)
    or (audience = 'branch' and branch_id is not null and department_id is null)
    or (audience = 'department' and department_id is not null and branch_id is null)
  )
);
create index ix_notices_org_publish on public.notices (organization_id, status, publish_at desc);
create trigger trg_notices_updated
  before update on public.notices
  for each row execute function public.set_updated_at();

create table public.notice_receipts (
  notice_id uuid not null references public.notices (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  read_at timestamptz,
  acknowledged_at timestamptz,
  primary key (notice_id, employee_id)
);
create index ix_notice_receipts_employee on public.notice_receipts (employee_id);

-- ---------------------------------------------------------------------
-- Notifications
-- ---------------------------------------------------------------------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  category text not null default 'system'
    check (category in ('notice', 'employee', 'onboarding', 'system', 'security')),
  title text not null,
  body text,
  route text,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index ix_notifications_employee on public.notifications (employee_id, created_at desc);
create index ix_notifications_unread on public.notifications (employee_id) where read_at is null;

create table public.notification_preferences (
  employee_id uuid not null references public.employees (id) on delete cascade,
  category text not null check (category in ('notice', 'employee', 'onboarding', 'system', 'security')),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  in_app boolean not null default true,
  push boolean not null default true,
  primary key (employee_id, category)
);

-- ---------------------------------------------------------------------
-- Audit trail (no FK on organization_id so history survives tenant removal)
-- ---------------------------------------------------------------------
create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid,
  actor_user_id uuid,
  actor_employee_id uuid,
  actor_name text,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  summary text,
  changes jsonb,
  created_at timestamptz not null default now()
);
create index ix_audit_org_created on public.audit_logs (organization_id, created_at desc);
create index ix_audit_entity on public.audit_logs (entity_type, entity_id);
