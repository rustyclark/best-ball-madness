-- Drop views in reverse dependency order
DROP VIEW IF EXISTS public.team_standings;
DROP VIEW IF EXISTS public.team_round_scores;
DROP VIEW IF EXISTS public.team_hole_scores;

-- Recreate team_hole_scores with security_invoker = true
CREATE OR REPLACE VIEW public.team_hole_scores
WITH (security_invoker = true)
AS
SELECT tg.team_id,
       hs.round,
       hs.hole,
       MIN(hs.par) AS par,
       MIN(hs.score) AS best_ball_score,
       MIN(hs.score) - MIN(hs.par) AS hole_to_par
FROM public.team_golfers tg
JOIN public.hole_scores hs ON hs.tournament_golfer_id = tg.tournament_golfer_id
GROUP BY tg.team_id, hs.round, hs.hole;

-- Recreate team_round_scores with security_invoker = true
CREATE OR REPLACE VIEW public.team_round_scores
WITH (security_invoker = true)
AS
SELECT team_id,
       round,
       SUM(hole_to_par) AS round_to_par,
       COUNT(*) AS holes_counted
FROM public.team_hole_scores
GROUP BY team_id, round;

-- Recreate team_standings with security_invoker = true
CREATE OR REPLACE VIEW public.team_standings
WITH (security_invoker = true)
AS
SELECT t.id AS team_id,
       t.status,
       COALESCE(SUM(trs.round_to_par), 0) AS total_to_par,
       array_agg(trs.round_to_par ORDER BY trs.round_to_par ASC NULLS LAST) AS rounds_sorted,
       (
           SELECT SUM(tgf.price)
           FROM public.team_golfers tgx
           JOIN public.tournament_golfers tgf ON tgf.id = tgx.tournament_golfer_id
           WHERE tgx.team_id = t.id
       ) AS budget_used
FROM public.teams t
LEFT JOIN public.team_round_scores trs ON trs.team_id = t.id
GROUP BY t.id, t.status;
