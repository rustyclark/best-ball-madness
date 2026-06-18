-- Migration: Golfer-Level Tee Time Locking & Standings Trigger

-- 1. Recreate recompute_leaderboard with SECURITY DEFINER to avoid RLS/permission errors when invoked by triggers
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
    SELECT team_id, total_to_par, budget_used, status,
           RANK() OVER (
             ORDER BY total_to_par ASC,
                      rounds_sorted[1] ASC NULLS LAST,
                      rounds_sorted[2] ASC NULLS LAST,
                      rounds_sorted[3] ASC NULLS LAST,
                      rounds_sorted[4] ASC NULLS LAST,
                      budget_used ASC
           ) AS computed_rank
    FROM public.team_standings
    WHERE status = 'ACTIVE'
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


-- 2. Modify team_golfers SELECT RLS policy to dynamically hide/reveal lineups
DROP POLICY IF EXISTS "Allow authenticated users to read all team_golfers" ON public.team_golfers;

CREATE POLICY "Allow authenticated users to read all team_golfers" 
ON public.team_golfers FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.tournaments tr ON tr.id = t.tournament_id
        LEFT JOIN public.tee_times tt ON tt.tournament_golfer_id = team_golfers.tournament_golfer_id AND tt.round = 1
        WHERE t.id = team_golfers.team_id
          AND (
              t.user_id = auth.uid()
              OR (tt.tee_time_utc IS NOT NULL AND now() >= tt.tee_time_utc)
          )
    )
);


-- 3. Modify teams and team_golfers write RLS policies to remove global lock restriction
DROP POLICY IF EXISTS "Allow users to manage own team before lock" ON public.teams;

CREATE POLICY "Allow users to manage own team" 
ON public.teams FOR ALL TO authenticated 
USING (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
          AND t.status != 'COMPLETED'
    )
)
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
          AND t.status != 'COMPLETED'
    )
);

DROP POLICY IF EXISTS "Allow users to manage own team roster before lock" ON public.team_golfers;

CREATE POLICY "Allow users to manage own team roster" 
ON public.team_golfers FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.tournaments tr ON tr.id = t.tournament_id
        WHERE t.id = team_id
          AND t.user_id = auth.uid()
          AND tr.status != 'COMPLETED'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.tournaments tr ON tr.id = t.tournament_id
        WHERE t.id = team_id
          AND t.user_id = auth.uid()
          AND tr.status != 'COMPLETED'
    )
);


-- 4. Create Golfer Lock Trigger to enforce individual tee time locking (15-minute buffer)
CREATE OR REPLACE FUNCTION public.enforce_golfer_lock()
RETURNS TRIGGER AS $$
DECLARE
    g_tee_time TIMESTAMP WITH TIME ZONE;
    g_id UUID;
    t_status VARCHAR;
BEGIN
    -- Determine which golfer is affected
    IF TG_OP = 'DELETE' THEN
        g_id := OLD.tournament_golfer_id;
    ELSE
        g_id := NEW.tournament_golfer_id;
    END IF;

    -- Check if tournament is COMPLETED
    SELECT tr.status INTO t_status
    FROM public.teams t
    JOIN public.tournaments tr ON tr.id = t.tournament_id
    WHERE t.id = COALESCE(NEW.team_id, OLD.team_id);

    IF t_status = 'COMPLETED' THEN
        RAISE EXCEPTION 'Tournament is completed. Cannot modify roster.';
    END IF;

    -- Get Round 1 tee time for this golfer
    SELECT tee_time_utc INTO g_tee_time
    FROM public.tee_times
    WHERE tournament_golfer_id = g_id AND round = 1;

    -- Enforce lock 15 minutes before golfer's Round 1 tee time
    IF g_tee_time IS NOT NULL AND now() >= (g_tee_time - INTERVAL '15 minutes') THEN
        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION 'Golfer has already teed off and cannot be removed from roster';
        ELSE
            RAISE EXCEPTION 'Golfer has already teed off and cannot be added to roster';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_team_golfers_lock ON public.team_golfers;
CREATE TRIGGER trg_team_golfers_lock
BEFORE INSERT OR UPDATE OR DELETE ON public.team_golfers
FOR EACH ROW EXECUTE FUNCTION public.enforce_golfer_lock();


-- 5. Create Standings Trigger to keep leaderboard mirrored physical table in sync automatically
CREATE OR REPLACE FUNCTION public.trigger_recompute_leaderboard()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM public.recompute_leaderboard(COALESCE(NEW.tournament_id, OLD.tournament_id));
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_recompute_leaderboard ON public.teams;
CREATE TRIGGER trg_recompute_leaderboard
AFTER INSERT OR UPDATE OR DELETE ON public.teams
FOR EACH ROW EXECUTE FUNCTION public.trigger_recompute_leaderboard();
