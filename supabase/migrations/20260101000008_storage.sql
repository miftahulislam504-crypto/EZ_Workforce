-- =====================================================================
-- Storage buckets and policies. Object paths always start with the
-- organization id:  {organization_id}/{...}
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit)
values
  ('org-assets', 'org-assets', true, 5242880),
  ('avatars', 'avatars', true, 5242880),
  ('employee-documents', 'employee-documents', false, 15728640),
  ('notice-attachments', 'notice-attachments', false, 15728640)
on conflict (id) do nothing;

-- Company logo: path = {org}/logo-*.ext
create policy org_assets_write on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'org-assets'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and public.has_permission('org.manage')
  );
create policy org_assets_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'org-assets'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and public.has_permission('org.manage')
  );
create policy org_assets_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'org-assets'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and public.has_permission('org.manage')
  );

-- Profile photos: path = {org}/{employee}/photo-*.ext
create policy avatars_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and (
      (storage.foldername(name))[2] = public.auth_employee_id()::text
      or (public.has_permission('employees.edit')
          and public.employee_in_scope(((storage.foldername(name))[2])::uuid))
    )
  );
create policy avatars_update on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and (
      (storage.foldername(name))[2] = public.auth_employee_id()::text
      or (public.has_permission('employees.edit')
          and public.employee_in_scope(((storage.foldername(name))[2])::uuid))
    )
  );
create policy avatars_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and (
      (storage.foldername(name))[2] = public.auth_employee_id()::text
      or (public.has_permission('employees.edit')
          and public.employee_in_scope(((storage.foldername(name))[2])::uuid))
    )
  );

-- Employee documents (private): path = {org}/{employee}/{file}
create policy employee_documents_storage_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'employee-documents'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and (
      (storage.foldername(name))[2] = public.auth_employee_id()::text
      or (public.has_permission('employees.documents')
          and public.employee_in_scope(((storage.foldername(name))[2])::uuid))
    )
  );
create policy employee_documents_storage_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'employee-documents'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and public.has_permission('employees.documents')
    and public.employee_in_scope(((storage.foldername(name))[2])::uuid)
  );
create policy employee_documents_storage_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'employee-documents'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and public.has_permission('employees.documents')
    and public.employee_in_scope(((storage.foldername(name))[2])::uuid)
  );

-- Notice attachments (private): path = {org}/{notice-or-draft}/{file}
create policy notice_attachments_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'notice-attachments'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
  );
create policy notice_attachments_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'notice-attachments'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and public.has_permission('notices.manage')
  );
create policy notice_attachments_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'notice-attachments'
    and (storage.foldername(name))[1] = public.auth_org_id()::text
    and public.has_permission('notices.manage')
  );
