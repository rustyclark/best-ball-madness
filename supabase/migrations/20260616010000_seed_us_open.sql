-- Seed or update the U.S. Open tournament details to make it the active open tournament
INSERT INTO public.tournaments (id, espn_event_id, golfapi_course_id, name, course, location, par, yards, start_date, end_date, status, current_round, lock_time_utc)
VALUES (
    'b1111111-1111-1111-1111-111111111111', 
    '401812000', 
    'shinnecock_hills_01', 
    'U.S. Open', 
    'Shinnecock Hills Golf Club', 
    'Southampton, New York', 
    70, 
    7082, 
    '2026-06-18', 
    '2026-06-21', 
    'SCHEDULED', 
    1, 
    '2026-06-18T11:00:00Z'
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  course = EXCLUDED.course,
  location = EXCLUDED.location,
  par = EXCLUDED.par,
  yards = EXCLUDED.yards,
  start_date = EXCLUDED.start_date,
  end_date = EXCLUDED.end_date,
  status = EXCLUDED.status,
  lock_time_utc = EXCLUDED.lock_time_utc,
  espn_event_id = EXCLUDED.espn_event_id;

-- Ensure any other tournament in the database is set to COMPLETED so U.S. Open is selected as active
UPDATE public.tournaments 
SET status = 'COMPLETED' 
WHERE id != 'b1111111-1111-1111-1111-111111111111';
