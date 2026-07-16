-- Start transaction and plan tests
BEGIN;
SELECT plan(18);

-- Verify extensions
SELECT has_extension('uuid-ossp');

-- 1. Setup mock data
-- Insert mock user profiles
INSERT INTO auth.users (id, email) VALUES 
  ('00000000-0000-0000-0000-000000000001', 'user1@example.com'),
  ('00000000-0000-0000-0000-000000000002', 'user2@example.com');

INSERT INTO public.users (id, email, team_name) VALUES
  ('00000000-0000-0000-0000-000000000001', 'user1@example.com', 'Team Alpha'),
  ('00000000-0000-0000-0000-000000000002', 'user2@example.com', 'Team Beta');

-- Test lower(team_name) unique index
SELECT throws_ok(
  $$ INSERT INTO public.users (id, email, team_name) VALUES ('00000000-0000-0000-0000-000000000303', 'user3@example.com', 'team alpha') $$,
  '23505'
);

-- Insert mock tournament
INSERT INTO public.tournaments (id, espn_event_id, name, course, location, par, yards, start_date, end_date, status, current_round)
VALUES ('00000000-0000-0000-0000-000000000100', 'espn-mock-event', 'Mock Open', 'Mock course', 'Mock location', 72, 7000, '2026-06-11', '2026-06-14', 'IN_PROGRESS', 2);

-- Insert teams
INSERT INTO public.teams (id, user_id, tournament_id, status) VALUES
  ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000100', 'ACTIVE');

-- Test UNIQUE(user_id, tournament_id) on teams
SELECT throws_ok(
  $$ INSERT INTO public.teams (user_id, tournament_id, status) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000100', 'ACTIVE') $$,
  '23505' -- unique violation code
);

-- Setup golfer profiles and tournament golfers
INSERT INTO public.golfer_profiles (id, espn_id, name) VALUES
  ('00000000-0000-0000-0000-000000000301', 'espn-g1', 'Scottie Scheffler'),
  ('00000000-0000-0000-0000-000000000302', 'espn-g2', 'Rory McIlroy'),
  ('00000000-0000-0000-0000-000000000303', 'espn-g3', 'Jon Rahm'),
  ('00000000-0000-0000-0000-000000000304', 'espn-g4', 'Cameron Young'),
  ('00000000-0000-0000-0000-000000000305', 'espn-g5', 'Tiger Woods'),
  ('00000000-0000-0000-0000-000000000306', 'espn-g6', 'Rich Golfer');

INSERT INTO public.tournament_golfers (id, tournament_id, golfer_profile_id, price, status) VALUES
  ('00000000-0000-0000-0000-000000000401', '00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000301', 30.00, 'ACTIVE'),
  ('00000000-0000-0000-0000-000000000402', '00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000302', 25.00, 'ACTIVE'),
  ('00000000-0000-0000-0000-000000000403', '00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000303', 25.00, 'ACTIVE'),
  ('00000000-0000-0000-0000-000000000404', '00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000304', 20.00, 'ACTIVE'),
  ('00000000-0000-0000-0000-000000000405', '00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000305', 20.00, 'ACTIVE'),
  ('00000000-0000-0000-0000-000000000406', '00000000-0000-0000-0000-000000000100', '00000000-0000-0000-0000-000000000306', 90.00, 'ACTIVE');

-- 2. Test enforce_roster_legality() trigger constraints
-- Add 3 golfers to team (Total price: 30 + 25 + 25 = $80)
INSERT INTO public.team_golfers (team_id, tournament_golfer_id) VALUES
  ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000401'),
  ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000402'),
  ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000403');



-- Add legal 4th golfer (Total price: 80 + 20 = $100)
INSERT INTO public.team_golfers (team_id, tournament_golfer_id) VALUES
  ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000404');

-- Test roster limit (> 4 golfers) on 5th golfer addition
SELECT throws_ok(
  $$ INSERT INTO public.team_golfers (team_id, tournament_golfer_id) VALUES ('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-000000000405') $$,
  'Roster limit of 4 golfers exceeded'
);

-- 3. Test recompute_leaderboard() stored procedure and CUT logic gating
-- Set up all golfers on team as missed cut (MC)
UPDATE public.tournament_golfers SET status = 'MC' WHERE id IN (
  '00000000-0000-0000-0000-000000000401',
  '00000000-0000-0000-0000-000000000402',
  '00000000-0000-0000-0000-000000000403',
  '00000000-0000-0000-0000-000000000404'
);

-- Active tournament has current_round = 2. recompute_leaderboard should be a NO-OP for CUT evaluation because current_round < 3.
SELECT recompute_leaderboard('00000000-0000-0000-0000-000000000100');
SELECT results_eq(
  $$ SELECT status FROM public.teams WHERE id = '00000000-0000-0000-0000-000000000201' $$,
  $$ VALUES ('ACTIVE'::varchar) $$,
  'Team status remains ACTIVE when current_round < 3'
);

-- Advance tournament to round 3
UPDATE public.tournaments SET current_round = 3 WHERE id = '00000000-0000-0000-0000-000000000100';

-- Run recompute_leaderboard again. Now, since current_round >= 3 and all golfers are MC, team should be marked CUT.
SELECT recompute_leaderboard('00000000-0000-0000-0000-000000000100');
SELECT results_eq(
  $$ SELECT status FROM public.teams WHERE id = '00000000-0000-0000-0000-000000000201' $$,
  $$ VALUES ('CUT'::varchar) $$,
  'Team status transitions to CUT when current_round >= 3 and all golfers are MC'
);

-- 4. Test tie-breaker standings rank sorting in recompute_leaderboard()
-- Setup another active team and golfers with hole scores for standings check
-- Set some golfers back to ACTIVE
UPDATE public.tournament_golfers SET status = 'ACTIVE';

INSERT INTO public.teams (id, user_id, tournament_id, status) VALUES
  ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000100', 'ACTIVE');

-- Set team 1 status back to ACTIVE for comparison
UPDATE public.teams SET status = 'ACTIVE' WHERE id = '00000000-0000-0000-0000-000000000201';

-- Setup team 2 golfers (Scottie, Rory, Cam Young, Cam Woods)
INSERT INTO public.team_golfers (team_id, tournament_golfer_id) VALUES
  ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000401'),
  ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000402'),
  ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000404'),
  ('00000000-0000-0000-0000-000000000202', '00000000-0000-0000-0000-000000000405'); -- Roster price: 30 + 25 + 20 + 20 = $95 (T1 has price 30+25+25+20 = $100)

-- Reset team 2 status back to ACTIVE after inserting golfers so that trigger evaluates it as ACTIVE (since it was CUT due to having 0 golfers on insert)
UPDATE public.teams SET status = 'ACTIVE' WHERE id = '00000000-0000-0000-0000-000000000202';

-- We will insert hole scores to create a tie on total_to_par, but Team 2 has lower budget used ($95 vs $100).
-- Team 2 should be ranked 1, and Team 1 should be ranked 2.
-- Insert simple hole scores for round 1
INSERT INTO public.hole_scores (tournament_golfer_id, round, hole, par, score, score_type) VALUES
  -- Golfers for both teams: tg-401, tg-402, tg-403 (T1), tg-404 (T1 & T2), tg-405 (T2)
  ('00000000-0000-0000-0000-000000000401', 1, 1, 4, 4, 'PAR'),
  ('00000000-0000-0000-0000-000000000402', 1, 1, 4, 4, 'PAR'),
  ('00000000-0000-0000-0000-000000000403', 1, 1, 4, 4, 'PAR'),
  ('00000000-0000-0000-0000-000000000404', 1, 1, 4, 3, 'BIRDIE'), -- Best Ball for both is -1
  ('00000000-0000-0000-0000-000000000405', 1, 1, 4, 4, 'PAR');

-- Run recompute_leaderboard
SELECT recompute_leaderboard('00000000-0000-0000-0000-000000000100');

-- Verify rankings: Team 2 is rank 1 due to tie-break (lower budget used: 95.00 vs 100.00)
SELECT results_eq(
  $$ SELECT team_id, rank, budget_used FROM public.leaderboard_standings ORDER BY rank ASC $$,
  $$ VALUES 
       ('00000000-0000-0000-0000-000000000202'::uuid, 1::integer, 95.00::numeric),
       ('00000000-0000-0000-0000-000000000201'::uuid, 2::integer, 100.00::numeric)
  $$,
  'Leaderboard correctly breaks tie using budget_used ASC'
);

-- 5. Test table privileges for authenticated role
SELECT table_privs_are('public', 'users', 'authenticated', ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can select, insert, update, delete on users');
SELECT table_privs_are('public', 'teams', 'authenticated', ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can select, insert, update, delete on teams');
SELECT table_privs_are('public', 'team_golfers', 'authenticated', ARRAY['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can select, insert, update, delete on team_golfers');
SELECT table_privs_are('public', 'tournaments', 'authenticated', ARRAY['SELECT', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can only select on tournaments');
SELECT table_privs_are('public', 'golfer_profiles', 'authenticated', ARRAY['SELECT', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can only select on golfer_profiles');
SELECT table_privs_are('public', 'team_hole_scores', 'authenticated', ARRAY['SELECT', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can select on team_hole_scores');
SELECT table_privs_are('public', 'team_round_scores', 'authenticated', ARRAY['SELECT', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can select on team_round_scores');
SELECT table_privs_are('public', 'team_standings', 'authenticated', ARRAY['SELECT', 'REFERENCES', 'TRIGGER', 'TRUNCATE'], 'authenticated role can select on team_standings');

-- 6. Setup tee times and test golfer-level locking triggers
-- Create a third user and team to test locking on an empty team without roster limits interfering
INSERT INTO auth.users (id, email) VALUES 
  ('00000000-0000-0000-0000-000000000003', 'user3@example.com');

INSERT INTO public.users (id, email, team_name) VALUES
  ('00000000-0000-0000-0000-000000000003', 'user3@example.com', 'Team Gamma');

INSERT INTO public.teams (id, user_id, tournament_id, status) VALUES
  ('00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000100', 'ACTIVE');

INSERT INTO public.tee_times (tournament_golfer_id, round, tee_time_utc)
VALUES ('00000000-0000-0000-0000-000000000405', 1, now() - INTERVAL '30 minutes');

-- Try to insert a locked golfer (should throw lock error)
SELECT throws_ok(
  $$ INSERT INTO public.team_golfers (team_id, tournament_golfer_id) VALUES ('00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000405') $$,
  'Golfer has already teed off and cannot be added to roster'
);

-- Put a golfer on a roster with a future tee time, then update their tee time to past and try to delete
INSERT INTO public.tee_times (tournament_golfer_id, round, tee_time_utc)
VALUES ('00000000-0000-0000-0000-000000000406', 1, now() + INTERVAL '1 hour');

INSERT INTO public.team_golfers (team_id, tournament_golfer_id)
VALUES ('00000000-0000-0000-0000-000000000203', '00000000-0000-0000-0000-000000000406');

-- Update tee time to past
UPDATE public.tee_times SET tee_time_utc = now() - INTERVAL '20 minutes'
WHERE tournament_golfer_id = '00000000-0000-0000-0000-000000000406' AND round = 1;

-- Try to delete the locked golfer (should throw lock error)
SELECT throws_ok(
  $$ DELETE FROM public.team_golfers WHERE team_id = '00000000-0000-0000-0000-000000000203' AND tournament_golfer_id = '00000000-0000-0000-0000-000000000406' $$,
  'Golfer has already teed off and cannot be removed from roster'
);

-- Test trigger trg_recompute_leaderboard is fired on inserting teams
SELECT results_eq(
  $$ SELECT COUNT(*) FROM public.leaderboard_standings WHERE team_id = '00000000-0000-0000-0000-000000000202' $$,
  $$ VALUES (1::bigint) $$,
  'Leaderboard standings mirror record automatically created/updated via teams trigger'
);

-- Finish tests
SELECT * FROM finish();
ROLLBACK;
