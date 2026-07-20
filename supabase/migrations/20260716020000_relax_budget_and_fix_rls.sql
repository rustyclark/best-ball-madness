-- Migration: Relax budget limit check from DB trigger to allow transient over-budget states during draft swaps.
-- Also fix the FOR ALL RLS policy on team_golfers to use qualified team_golfers.team_id to prevent silent delete failures.

-- 1. Re-define enforce_roster_legality trigger function without the budget check
CREATE OR REPLACE FUNCTION public.enforce_roster_legality() 
RETURNS TRIGGER AS $$
DECLARE
    cnt INTEGER;
BEGIN
    -- Count current golfers on team
    SELECT COUNT(*)
    INTO cnt
    FROM public.team_golfers tg
    WHERE tg.team_id = NEW.team_id;

    -- Enforce max roster size of 4
    IF cnt >= 4 THEN
        RAISE EXCEPTION 'Roster limit of 4 golfers exceeded';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Drop and recreate the FOR ALL RLS policy on team_golfers to resolve team_id cleanly
DROP POLICY IF EXISTS "Allow users to manage own team roster before lock" ON public.team_golfers;

CREATE POLICY "Allow users to manage own team roster before lock" 
ON public.team_golfers FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.tournaments tr ON tr.id = t.tournament_id
        WHERE t.id = team_golfers.team_id
          AND t.user_id = auth.uid()
          AND tr.status != 'COMPLETED'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.tournaments tr ON tr.id = t.tournament_id
        WHERE t.id = team_golfers.team_id
          AND t.user_id = auth.uid()
          AND tr.status != 'COMPLETED'
    )
);
