alter table public.onboarding_sessions
  add column if not exists calm_mode_active boolean not null default false;

update public.onboarding_sessions
set calm_mode_active = calm_mode_opt_in
where calm_mode_opt_in = true;

insert into public.schema_migrations(version)
values ('20260820000003')
on conflict do nothing;
