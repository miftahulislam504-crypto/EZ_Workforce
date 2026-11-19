-- =====================================================================
-- Workflow triggers: audit trail, onboarding checklist, notifications
-- =====================================================================

-- ---------------------------------------------------------------------
-- Audit trail
-- ---------------------------------------------------------------------
create or replace function public.audit_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
  v_new jsonb;
  v_old jsonb;
  v_org uuid;
  v_action text;
  v_changes jsonb;
  v_entity uuid;
  v_actor_emp uuid;
  v_actor_name text;
  v_redact boolean := coalesce(tg_argv[0], '') = 'redact';
begin
  if tg_op = 'DELETE' then
    v_row := to_jsonb(old);
    v_old := v_row;
    v_action := 'delete';
  elsif tg_op = 'INSERT' then
    v_row := to_jsonb(new);
    v_new := v_row;
    v_action := 'create';
  else
    v_row := to_jsonb(new);
    v_new := v_row;
    v_old := to_jsonb(old);
    v_action := 'update';
  end if;

  v_org := coalesce((v_row ->> 'organization_id')::uuid,
                    case when tg_table_name = 'organizations' then (v_row ->> 'id')::uuid end);
  v_entity := coalesce(v_row ->> 'id', v_row ->> 'employee_id')::uuid;

  if tg_op = 'UPDATE' then
    select coalesce(jsonb_object_agg(n.key, jsonb_build_object('old', o.value, 'new', n.value)), '{}'::jsonb)
      into v_changes
    from jsonb_each(v_new) n
    join jsonb_each(v_old) o on o.key = n.key
    where n.value is distinct from o.value
      and n.key not in ('updated_at', 'notified_at', 'employee_seq');
    if v_changes = '{}'::jsonb then
      return new;
    end if;
  elsif tg_op = 'INSERT' then
    v_changes := v_new;
  else
    v_changes := v_old;
  end if;

  if v_redact then
    select coalesce(jsonb_object_agg(key, '"redacted"'::jsonb), '{}'::jsonb)
      into v_changes
    from jsonb_each(v_changes);
  end if;

  select e.id, e.full_name into v_actor_emp, v_actor_name
  from public.employees e
  where e.user_id = auth.uid()
  limit 1;

  insert into public.audit_logs
    (organization_id, actor_user_id, actor_employee_id, actor_name, action, entity_type, entity_id, summary, changes)
  values
    (v_org, auth.uid(), v_actor_emp, v_actor_name, v_action, tg_table_name, v_entity,
     coalesce(v_row ->> 'name', v_row ->> 'title', v_row ->> 'full_name', v_row ->> 'file_name'),
     v_changes);

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger trg_audit_organizations after insert or update or delete on public.organizations
  for each row execute function public.audit_row_change();
create trigger trg_audit_branches after insert or update or delete on public.branches
  for each row execute function public.audit_row_change();
create trigger trg_audit_departments after insert or update or delete on public.departments
  for each row execute function public.audit_row_change();
create trigger trg_audit_designations after insert or update or delete on public.designations
  for each row execute function public.audit_row_change();
create trigger trg_audit_roles after insert or update or delete on public.roles
  for each row execute function public.audit_row_change();
create trigger trg_audit_employees after insert or update or delete on public.employees
  for each row execute function public.audit_row_change();
create trigger trg_audit_employee_private after insert or update or delete on public.employee_private
  for each row execute function public.audit_row_change('redact');
create trigger trg_audit_employee_documents after insert or update or delete on public.employee_documents
  for each row execute function public.audit_row_change();
create trigger trg_audit_notices after insert or update or delete on public.notices
  for each row execute function public.audit_row_change();

-- ---------------------------------------------------------------------
-- Notification helper (respects the in-app preference of the recipient)
-- ---------------------------------------------------------------------
create or replace function public.notify_employee(
  p_employee uuid,
  p_category text,
  p_title text,
  p_body text default null,
  p_route text default null,
  p_data jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org uuid;
begin
  select organization_id into v_org from public.employees where id = p_employee and user_id is not null;
  if v_org is null then
    return;
  end if;
  if exists (
    select 1 from public.notification_preferences p
    where p.employee_id = p_employee and p.category = p_category and not p.in_app
  ) then
    return;
  end if;
  insert into public.notifications (organization_id, employee_id, category, title, body, route, data)
  values (v_org, p_employee, p_category, p_title, p_body, p_route, p_data);
end;
$$;

-- Role changes are security relevant, so the employee is told.
create or replace function public.employees_after_update_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
begin
  if new.role_id is distinct from old.role_id and new.user_id is not null then
    select name into v_role from public.roles where id = new.role_id;
    perform public.notify_employee(new.id, 'security', 'Your access role was updated',
      'Your role is now ' || coalesce(v_role, 'unknown') || '.', '/profile', '{}'::jsonb);
  end if;
  return new;
end;
$$;

create trigger trg_employees_3_after_update_notify
  after update on public.employees
  for each row execute function public.employees_after_update_notify();

-- ---------------------------------------------------------------------
-- Onboarding checklist
-- ---------------------------------------------------------------------
create or replace function public.employees_after_insert_onboarding()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.onboarding_items (organization_id, employee_id, title, description, sort_order, due_date)
  select t.organization_id, new.id, t.title, t.description, t.sort_order, new.joining_date + 7
  from public.onboarding_template_items t
  where t.organization_id = new.organization_id and t.is_active;
  return new;
end;
$$;

create trigger trg_employees_4_after_insert_onboarding
  after insert on public.employees
  for each row execute function public.employees_after_insert_onboarding();

create or replace function public.onboarding_items_before_write()
returns trigger
language plpgsql
as $$
begin
  if new.is_done and (tg_op = 'INSERT' or not old.is_done) then
    new.done_at := now();
    new.done_by := auth.uid();
  elsif not new.is_done then
    new.done_at := null;
    new.done_by := null;
  end if;
  return new;
end;
$$;

create trigger trg_onboarding_items_1_before_write
  before insert or update on public.onboarding_items
  for each row execute function public.onboarding_items_before_write();

create or replace function public.refresh_onboarding_status(p_employee uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total int;
  v_done int;
  v_status text;
  v_prev text := coalesce(current_setting('app.bypass_guard', true), '');
begin
  select count(*), count(*) filter (where is_done)
    into v_total, v_done
  from public.onboarding_items
  where employee_id = p_employee;

  v_status := case
    when v_total = 0 or v_done = v_total then 'completed'
    when v_done = 0 then 'pending'
    else 'in_progress'
  end;

  perform set_config('app.bypass_guard', 'on', true);
  update public.employees
     set onboarding_status = v_status
   where id = p_employee and onboarding_status is distinct from v_status;
  perform set_config('app.bypass_guard', v_prev, true);
end;
$$;

create or replace function public.onboarding_items_after_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_onboarding_status(old.employee_id);
    return old;
  end if;
  perform public.refresh_onboarding_status(new.employee_id);
  return new;
end;
$$;

create trigger trg_onboarding_items_2_after_write
  after insert or update or delete on public.onboarding_items
  for each row execute function public.onboarding_items_after_write();

-- ---------------------------------------------------------------------
-- Notice board fan-out. Notices become notifications once they are
-- published and due. Scheduled notices are dispatched lazily when any
-- user opens the app, or by pg_cron if the project enables it.
-- ---------------------------------------------------------------------
create or replace function public.dispatch_due_notice_notifications(p_notice_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  n record;
  v_count int := 0;
begin
  for n in
    select *
    from public.notices
    where status = 'published'
      and notified_at is null
      and publish_at <= now()
      and (expires_at is null or expires_at > now())
      and (p_notice_id is null or id = p_notice_id)
      and (auth.uid() is null or organization_id = public.auth_org_id())
    order by publish_at
  loop
    insert into public.notifications (organization_id, employee_id, category, title, body, route, data)
    select e.organization_id, e.id, 'notice', n.title,
           left(regexp_replace(n.body, '\s+', ' ', 'g'), 140),
           '/notices/' || n.id::text,
           jsonb_build_object('notice_id', n.id)
    from public.employees e
    where e.organization_id = n.organization_id
      and e.user_id is not null
      and e.archived_at is null
      and (n.audience = 'all'
           or (n.audience = 'branch' and e.branch_id = n.branch_id)
           or (n.audience = 'department' and e.department_id = n.department_id))
      and e.id is distinct from n.created_by_employee_id
      and not exists (
        select 1 from public.notification_preferences p
        where p.employee_id = e.id and p.category = 'notice' and not p.in_app
      );

    update public.notices set notified_at = now() where id = n.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

grant execute on function public.dispatch_due_notice_notifications(uuid) to authenticated;

create or replace function public.notices_after_write_dispatch()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.dispatch_due_notice_notifications(new.id);
  return new;
end;
$$;

create trigger trg_notices_2_dispatch
  after insert or update on public.notices
  for each row
  when (new.notified_at is null and new.status = 'published')
  execute function public.notices_after_write_dispatch();
