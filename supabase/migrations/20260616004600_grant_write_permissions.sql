-- Grant write permissions to authenticated users on tables where they have RLS policies to manage records.
GRANT INSERT, UPDATE, DELETE ON TABLE public.users TO authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.teams TO authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.team_golfers TO authenticated;

-- Grant SELECT permissions to anon and authenticated users on security invoker views
-- (needed because views dropped/recreated on 20260616003059 lost their original grants)
GRANT SELECT ON TABLE public.team_hole_scores TO anon, authenticated;
GRANT SELECT ON TABLE public.team_round_scores TO anon, authenticated;
GRANT SELECT ON TABLE public.team_standings TO anon, authenticated;

