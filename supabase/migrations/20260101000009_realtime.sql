-- =====================================================================
-- Realtime: stream new in-app notifications to signed-in clients.
-- Row Level Security still applies, so users only receive their own rows.
-- =====================================================================

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.notifications;
    exception
      when duplicate_object then null;
    end;
  end if;
end;
$$;
