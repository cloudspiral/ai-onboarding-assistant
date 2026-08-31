-- Keep the review environment bookable as time passes. Generate six months of
-- weekday availability; the API returns only the next nine unbooked openings.
with weekdays(day) as (
  select value::date
  from generate_series(
    current_date + 1,
    current_date + 180,
    interval '1 day'
  ) as value
  where extract(isodow from value) between 1 and 5
), future_slots(starts_at) as (
  select day + slot_time
  from weekdays
  cross join (values
    (time '09:00'),
    (time '12:30'),
    (time '16:00')
  ) as schedule(slot_time)
)
insert into public.appointment_slots(starts_at)
select starts_at
from future_slots
on conflict (starts_at) do nothing;
