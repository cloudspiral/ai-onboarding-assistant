-- Keep the deployed review environment useful after the original dated demo
-- fixtures age out. The API exposes only the next nine future openings.
with future_slots(starts_at) as (
  values
    (date_trunc('day', now()) + interval '1 day 14 hours'),
    (date_trunc('day', now()) + interval '1 day 16 hours 30 minutes'),
    (date_trunc('day', now()) + interval '1 day 19 hours'),
    (date_trunc('day', now()) + interval '2 days 15 hours'),
    (date_trunc('day', now()) + interval '2 days 18 hours 30 minutes'),
    (date_trunc('day', now()) + interval '2 days 21 hours 15 minutes'),
    (date_trunc('day', now()) + interval '5 days 14 hours 30 minutes'),
    (date_trunc('day', now()) + interval '5 days 17 hours'),
    (date_trunc('day', now()) + interval '5 days 20 hours')
)
insert into public.appointment_slots(starts_at)
select starts_at from future_slots
on conflict (starts_at) do nothing;
