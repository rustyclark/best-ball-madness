CREATE OR REPLACE FUNCTION public.recompute_leaderboard(t_id UUID)
RETURNS VOID AS $$
BEGIN
  -- 1. Run the CUT evaluation first
  -- If current_round >= 3, apply the CUT logic to ACTIVE teams
  IF EXISTS (
    SELECT 1 FROM public.tournaments 
    WHERE id = t_id AND COALESCE(current_round, 0) >= 3
  ) THEN
    UPDATE public.teams t
    SET status = 'CUT'
    WHERE t.tournament_id = t_id
      AND t.status = 'ACTIVE'
      AND NOT EXISTS (
        SELECT 1 
        FROM public.team_golfers tg
        JOIN public.tournament_golfers tgf ON tgf.id = tg.tournament_golfer_id
        WHERE tg.team_id = t.id
          AND tgf.status = 'ACTIVE'
      );
  END IF;

  -- 2. Insert/Update the standings in the physical mirror table
  WITH team_ranks AS (
    SELECT ts.team_id, ts.total_to_par, ts.budget_used, ts.status,
           RANK() OVER (
             ORDER BY ts.total_to_par ASC,
                      ts.rounds_sorted[1] ASC NULLS LAST,
                      ts.rounds_sorted[2] ASC NULLS LAST,
                      ts.rounds_sorted[3] ASC NULLS LAST,
                      ts.rounds_sorted[4] ASC NULLS LAST,
                      ts.budget_used ASC
           ) AS computed_rank
    FROM public.team_standings ts
    JOIN public.teams t ON t.id = ts.team_id
    WHERE ts.status = 'ACTIVE'
      AND t.tournament_id = t_id
  ),
  pivoted_rounds AS (
    SELECT team_id,
           SUM(CASE WHEN round = 1 THEN round_to_par END) as r1,
           SUM(CASE WHEN round = 2 THEN round_to_par END) as r2,
           SUM(CASE WHEN round = 3 THEN round_to_par END) as r3,
           SUM(CASE WHEN round = 4 THEN round_to_par END) as r4
    FROM public.team_round_scores
    GROUP BY team_id
  )
  INSERT INTO public.leaderboard_standings (
    team_id,
    tournament_id,
    status,
    rank,
    total_to_par,
    r1,
    r2,
    r3,
    r4,
    budget_used,
    updated_at
  )
  SELECT 
    t.id AS team_id,
    t.tournament_id,
    t.status,
    CASE WHEN t.status = 'ACTIVE' THEN tr.computed_rank ELSE NULL END AS rank,
    COALESCE(ts.total_to_par, 0) AS total_to_par,
    pr.r1,
    pr.r2,
    pr.r3,
    pr.r4,
    COALESCE(ts.budget_used, 0) AS budget_used,
    NOW()
  FROM public.teams t
  LEFT JOIN public.team_standings ts ON ts.team_id = t.id
  LEFT JOIN team_ranks tr ON tr.team_id = t.id
  LEFT JOIN pivoted_rounds pr ON pr.team_id = t.id
  WHERE t.tournament_id = t_id
  ON CONFLICT (team_id) DO UPDATE SET
    status = EXCLUDED.status,
    rank = EXCLUDED.rank,
    total_to_par = EXCLUDED.total_to_par,
    r1 = EXCLUDED.r1,
    r2 = EXCLUDED.r2,
    r3 = EXCLUDED.r3,
    r4 = EXCLUDED.r4,
    budget_used = EXCLUDED.budget_used,
    updated_at = EXCLUDED.updated_at;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
