-- Complete the production synthetic analytics fixture set without adding PII.
with synthetic_sessions as (
  select id, user_id, (right(user_id::text, 12))::integer as series
  from public.onboarding_sessions
  where user_id::text like '00000000-0000-4000-8000-%'
)
insert into public.analytics_events(anonymous_session_id, event_name, step, duration_ms)
select user_id, 'step_completed', 'chat', 45000 + ((series - 1) * 511)
from synthetic_sessions source
where series >= 19
  and not exists (
    select 1 from public.analytics_events event
    where event.anonymous_session_id = source.user_id
      and event.event_name = 'step_completed'
      and event.step = 'chat'
  );

with synthetic_sessions as (
  select id, user_id, (right(user_id::text, 12))::integer as series
  from public.onboarding_sessions
  where user_id::text like '00000000-0000-4000-8000-%'
)
insert into public.analytics_events(anonymous_session_id, event_name, step, duration_ms)
select user_id, 'step_completed', 'details', 58000 + ((series - 1) * 719)
from synthetic_sessions source
where series >= 41
  and not exists (
    select 1 from public.analytics_events event
    where event.anonymous_session_id = source.user_id
      and event.event_name = 'step_completed'
      and event.step = 'details'
  );

with synthetic_sessions as (
  select id, user_id, (right(user_id::text, 12))::integer as series
  from public.onboarding_sessions
  where user_id::text like '00000000-0000-4000-8000-%'
)
insert into public.analytics_events(anonymous_session_id, event_name, step, duration_ms, properties)
select
  user_id,
  'ocr_completed',
  'details',
  900 + ((series - 1) * 23),
  jsonb_build_object('outcome', case when (series - 1) % 9 = 0 then 'failed' else 'success' end)
from synthetic_sessions source
where series between 21 and 100
  and not exists (
    select 1 from public.analytics_events event
    where event.anonymous_session_id = source.user_id
      and event.event_name = 'ocr_completed'
  );

with synthetic_sessions as (
  select id, user_id, (right(user_id::text, 12))::integer as series
  from public.onboarding_sessions
  where user_id::text like '00000000-0000-4000-8000-%'
)
insert into public.analytics_events(anonymous_session_id, event_name, step, duration_ms)
select user_id, 'onboarding_completed', 'done', 31000 + ((series - 1) * 347)
from synthetic_sessions source
where series >= 69
  and not exists (
    select 1 from public.analytics_events event
    where event.anonymous_session_id = source.user_id
      and event.event_name = 'onboarding_completed'
  );
