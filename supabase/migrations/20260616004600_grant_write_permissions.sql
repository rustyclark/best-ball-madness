-- Grant write permissions to authenticated users on tables where they have RLS policies to manage records.
GRANT INSERT, UPDATE, DELETE ON TABLE public.users TO authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.teams TO authenticated;
GRANT INSERT, UPDATE, DELETE ON TABLE public.team_golfers TO authenticated;

