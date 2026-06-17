-- ==========================================
-- SEED DATA FOR BEST BALL MADNESS
-- ==========================================

-- 1. Seed Golfer Profiles
INSERT INTO public.golfer_profiles (id, espn_id, name, world_rank, scoring_avg, wins, top_10s, cuts_made, events_played, rounds_played, prior_scoring_avg, prior_wins, prior_top_10s, prior_cuts_made, prior_events_played, prior_rounds_played)
VALUES
  ('a1111111-1111-1111-1111-111111111111', '9478', 'Scottie Scheffler', 1, 68.20, 4, 8, 10, 10, 40, 68.60, 3, 7, 12, 12, 48),
  ('a2222222-2222-2222-2222-222222222222', '3470', 'Rory McIlroy', 2, 69.10, 1, 5, 8, 8, 30, 68.90, 2, 6, 10, 10, 40),
  ('a3333333-3333-3333-3333-333333333333', '3092599', 'Jon Rahm', 5, 69.50, 0, 3, 6, 6, 24, 69.00, 3, 8, 12, 12, 48),
  ('a4444444-4444-4444-4444-444444444444', '4425906', 'Cameron Young', 15, 70.10, 0, 2, 7, 8, 32, 69.80, 0, 4, 11, 12, 46),
  ('a5555555-5555-5555-5555-555555555555', '462', 'Tiger Woods', 120, 72.80, 0, 0, 1, 2, 6, 73.10, 0, 0, 2, 3, 8),
  ('a6666666-6666-6666-6666-666666666666', '3091154', 'Collin Morikawa', 8, 69.80, 1, 4, 9, 9, 36, 69.40, 1, 5, 11, 11, 44),
  ('a7777777-7777-7777-7777-777777777777', '11099', 'Brooks Koepka', 12, 70.30, 1, 2, 5, 6, 24, 69.90, 2, 4, 8, 8, 32)
ON CONFLICT (espn_id) DO UPDATE SET
  world_rank = EXCLUDED.world_rank,
  scoring_avg = EXCLUDED.scoring_avg,
  wins = EXCLUDED.wins,
  updated_at = now();

-- 2. Seed a Sample Tournament (U.S. Open)
INSERT INTO public.tournaments (id, espn_event_id, golfapi_course_id, name, course, location, par, yards, start_date, end_date, status, current_round, lock_time_utc)
VALUES
  (
    'b1111111-1111-1111-1111-111111111111', 
    '401811952', 
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

-- 3. Seed Tournament Golfers with Prices and Statuses
INSERT INTO public.tournament_golfers (id, tournament_id, golfer_profile_id, price, status)
VALUES
  ('c1111111-1111-1111-1111-111111111111', 'b1111111-1111-1111-1111-111111111111', 'a1111111-1111-1111-1111-111111111111', 35.35, 'ACTIVE'), -- Scottie
  ('c2222222-2222-2222-2222-222222222222', 'b1111111-1111-1111-1111-111111111111', 'a2222222-2222-2222-2222-222222222222', 33.50, 'ACTIVE'), -- Rory
  ('c3333333-3333-3333-3333-333333333333', 'b1111111-1111-1111-1111-111111111111', 'a3333333-3333-3333-3333-333333333333', 33.00, 'ACTIVE'), -- Jon
  ('c4444444-4444-4444-4444-444444444444', 'b1111111-1111-1111-1111-111111111111', 'a4444444-4444-4444-4444-444444444444', 34.11, 'ACTIVE'), -- Cameron
  ('c5555555-5555-5555-5555-555555555555', 'b1111111-1111-1111-1111-111111111111', 'a5555555-5555-5555-5555-555555555555', 12.00, 'ACTIVE'), -- Tiger (floor fallback)
  ('c6666666-6666-6666-6666-666666666666', 'b1111111-1111-1111-1111-111111111111', 'a6666666-6666-6666-6666-666666666666', 31.15, 'ACTIVE'), -- Collin
  ('c7777777-7777-7777-7777-777777777777', 'b1111111-1111-1111-1111-111111111111', 'a7777777-7777-7777-7777-777777777777', 28.00, 'ACTIVE')  -- Brooks
ON CONFLICT (tournament_id, golfer_profile_id) DO NOTHING;
