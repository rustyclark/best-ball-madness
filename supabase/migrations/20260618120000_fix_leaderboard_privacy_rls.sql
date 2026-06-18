-- Migration: Fix team_golfers SELECT RLS policy to resolve outer columns cleanly

DROP POLICY IF EXISTS "Allow authenticated users to read all team_golfers" ON public.team_golfers;

CREATE POLICY "Allow authenticated users to read all team_golfers" 
ON public.team_golfers FOR SELECT TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.teams t
        WHERE t.id = team_golfers.team_id
          AND (
              t.user_id = auth.uid()
              OR EXISTS (
                  SELECT 1 FROM public.tee_times tt
                  WHERE tt.tournament_golfer_id = team_golfers.tournament_golfer_id
                    AND tt.round = 1
                    AND now() >= tt.tee_time_utc
              )
          )
    )
);
