-- Migration 20260820000005 introduced the column represented by the Rails
-- migration below. Reconcile databases that applied the original Supabase
-- migration before its Rails version marker was corrected.
insert into public.schema_migrations(version)
values ('20260820000003')
on conflict do nothing;

delete from public.schema_migrations
where version = '20260820000005';
