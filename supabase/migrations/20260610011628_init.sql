-- Enable Extensions if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==========================================
-- 1. TABLE CREATIONS
-- ==========================================

-- Persistent golfer identity + season stats
CREATE TABLE public.golfer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    espn_id TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    
    -- Current season stats (resets weekly/seasonally)
    world_rank INTEGER NULL,
    scoring_avg NUMERIC NULL,
    wins INTEGER NULL,
    top_10s INTEGER NULL,
    cuts_made INTEGER NULL,
    events_played INTEGER NULL,
    rounds_played INTEGER NULL,
    
    -- Prior season stats (stable weekly baseline)
    prior_scoring_avg NUMERIC NULL,
    prior_wins INTEGER NULL,
    prior_top_10s INTEGER NULL,
    prior_cuts_made INTEGER NULL,
    prior_events_played INTEGER NULL,
    prior_rounds_played INTEGER NULL,
    
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- Tournaments (Single active tournament for MVP)
CREATE TABLE public.tournaments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    espn_event_id TEXT UNIQUE NOT NULL,
    golfapi_course_id TEXT NULL,
    name TEXT NOT NULL,
    course TEXT NOT NULL,
    location TEXT NOT NULL,
    par INTEGER NOT NULL,
    yards INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status VARCHAR NOT NULL, -- SCHEDULED, IN_PROGRESS, SUSPENDED, COMPLETED
    current_round INTEGER NULL,
    lock_time_utc TIMESTAMP WITH TIME ZONE NULL
);

CREATE TABLE public.tournament_golfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_id UUID REFERENCES public.tournaments(id) ON DELETE CASCADE NOT NULL,
    golfer_profile_id UUID REFERENCES public.golfer_profiles(id) ON DELETE CASCADE NOT NULL,
    price NUMERIC NOT NULL,
    status VARCHAR DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE, MC, WD
    CONSTRAINT unique_tournament_golfer UNIQUE (tournament_id, golfer_profile_id)
);

-- Authenticated user profiles (Linked to Supabase Auth)
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    team_name VARCHAR(25) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- User teams drafted per tournament
CREATE TABLE public.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    tournament_id UUID REFERENCES public.tournaments(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    status VARCHAR DEFAULT 'ACTIVE' NOT NULL, -- ACTIVE, DQ, CUT
    CONSTRAINT unique_user_tournament UNIQUE (user_id, tournament_id)
);

-- Roster spots representing selected golfers (max 4 per team)
CREATE TABLE public.team_golfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE NOT NULL,
    tournament_golfer_id UUID REFERENCES public.tournament_golfers(id) ON DELETE CASCADE NOT NULL
);

-- Hole-by-hole scores recorded per tournament golfer
CREATE TABLE public.hole_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_golfer_id UUID REFERENCES public.tournament_golfers(id) ON DELETE CASCADE NOT NULL,
    round INTEGER NOT NULL,
    hole INTEGER NOT NULL,
    par INTEGER NOT NULL,
    score INTEGER NOT NULL,
    score_type VARCHAR NOT NULL, -- PAR, BIRDIE, EAGLE, BOGEY, DOUBLE_BOGEY
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL,
    CONSTRAINT unique_golfer_round_hole UNIQUE (tournament_golfer_id, round, hole)
);

-- Tee times recorded per tournament golfer per round
CREATE TABLE public.tee_times (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tournament_golfer_id UUID REFERENCES public.tournament_golfers(id) ON DELETE CASCADE NOT NULL,
    round INTEGER NOT NULL,
    tee_time_utc TIMESTAMP WITH TIME ZONE NOT NULL,
    start_tee INTEGER DEFAULT 1 NOT NULL,
    status VARCHAR DEFAULT 'SCHEDULED' NOT NULL -- SCHEDULED, MC, WD
);

-- Leaderboard standings table (mirrored for realtime broadcast support)
CREATE TABLE public.leaderboard_standings (
    team_id UUID PRIMARY KEY REFERENCES public.teams(id) ON DELETE CASCADE NOT NULL,
    tournament_id UUID REFERENCES public.tournaments(id) ON DELETE CASCADE NOT NULL,
    status VARCHAR NOT NULL, -- ACTIVE, CUT, DQ
    rank INTEGER NULL, -- NULL for CUT/DQ teams
    total_to_par INTEGER NOT NULL,
    r1 INTEGER NULL,
    r2 INTEGER NULL,
    r3 INTEGER NULL,
    r4 INTEGER NULL,
    budget_used NUMERIC NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now() NOT NULL
);

-- ==========================================
-- 2. INDEXES & CONSTRAINTS
-- ==========================================

-- Case-insensitive team name uniqueness index
CREATE UNIQUE INDEX users_team_name_lower_idx ON public.users (lower(team_name));

-- Foreign key indexes for query optimizations
CREATE INDEX idx_tournament_golfers_tournament ON public.tournament_golfers(tournament_id);
CREATE INDEX idx_tournament_golfers_profile ON public.tournament_golfers(golfer_profile_id);
CREATE INDEX idx_teams_tournament ON public.teams(tournament_id);
CREATE INDEX idx_team_golfers_team ON public.team_golfers(team_id);
CREATE INDEX idx_team_golfers_golfer ON public.team_golfers(tournament_golfer_id);
CREATE INDEX idx_hole_scores_golfer ON public.hole_scores(tournament_golfer_id);
CREATE INDEX idx_tee_times_golfer ON public.tee_times(tournament_golfer_id);

-- ==========================================
-- 3. SCORING VIEWS
-- ==========================================

-- 3.1 Best Ball per team/round/hole
CREATE OR REPLACE VIEW public.team_hole_scores AS
SELECT tg.team_id,
       hs.round,
       hs.hole,
       MIN(hs.par) AS par,
       MIN(hs.score) AS best_ball_score,
       MIN(hs.score) - MIN(hs.par) AS hole_to_par
FROM public.team_golfers tg
JOIN public.hole_scores hs ON hs.tournament_golfer_id = tg.tournament_golfer_id
GROUP BY tg.team_id, hs.round, hs.hole;

-- 3.2 Total To-Par score per team per round
CREATE OR REPLACE VIEW public.team_round_scores AS
SELECT team_id,
       round,
       SUM(hole_to_par) AS round_to_par,
       COUNT(*) AS holes_counted
FROM public.team_hole_scores
GROUP BY team_id, round;

-- 3.3 Aggregated standings metrics for tie-breaks
CREATE OR REPLACE VIEW public.team_standings AS
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

-- ==========================================
-- 4. DB TRIGGERS (BUDGET & SIZE LIMIT)
-- ==========================================

CREATE OR REPLACE FUNCTION public.enforce_roster_legality() 
RETURNS TRIGGER AS $$
DECLARE
    cnt INTEGER;
    spend NUMERIC;
    new_price NUMERIC;
BEGIN
    -- Count current golfers and sum budget on team
    SELECT COUNT(*), COALESCE(SUM(tgf.price), 0)
    INTO cnt, spend
    FROM public.team_golfers tg
    JOIN public.tournament_golfers tgf ON tgf.id = tg.tournament_golfer_id
    WHERE tg.team_id = NEW.team_id;

    -- Enforce max roster size of 4
    IF cnt >= 4 THEN
        RAISE EXCEPTION 'Roster limit of 4 golfers exceeded';
    END IF;

    -- Retrieve price of the golfer being inserted
    SELECT price INTO new_price FROM public.tournament_golfers WHERE id = NEW.tournament_golfer_id;

    -- Enforce max budget limit of $100
    IF spend + new_price > 100 THEN
        RAISE EXCEPTION 'Budget limit of $100 exceeded';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_roster_legality
BEFORE INSERT ON public.team_golfers
FOR EACH ROW EXECUTE FUNCTION public.enforce_roster_legality();

-- ==========================================
-- 5. ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournaments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.golfer_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tournament_golfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_golfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hole_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tee_times ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.leaderboard_standings ENABLE ROW LEVEL SECURITY;

-- 5.1 Users RLS Policies
CREATE POLICY "Allow authenticated users to read all profiles" 
ON public.users FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow users to manage their own profile" 
ON public.users FOR ALL TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 5.2 Tournaments RLS Policies
CREATE POLICY "Allow public read-only access to tournaments" 
ON public.tournaments FOR SELECT TO anon, authenticated USING (true);

-- 5.3 Golfer Profiles RLS Policies
CREATE POLICY "Allow public read-only access to golfer_profiles" 
ON public.golfer_profiles FOR SELECT TO anon, authenticated USING (true);

-- 5.4 Tournament Golfers RLS Policies
CREATE POLICY "Allow public read-only access to tournament_golfers" 
ON public.tournament_golfers FOR SELECT TO anon, authenticated USING (true);

-- 5.5 Teams RLS Policies
CREATE POLICY "Allow authenticated users to read all teams" 
ON public.teams FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow users to manage own team before lock" 
ON public.teams FOR ALL TO authenticated 
USING (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
          AND t.status != 'COMPLETED'
          AND (t.lock_time_utc IS NULL OR now() < t.lock_time_utc)
    )
)
WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
        SELECT 1 FROM public.tournaments t
        WHERE t.id = tournament_id
          AND t.status != 'COMPLETED'
          AND (t.lock_time_utc IS NULL OR now() < t.lock_time_utc)
    )
);

-- 5.6 Team Golfers RLS Policies
CREATE POLICY "Allow authenticated users to read all team_golfers" 
ON public.team_golfers FOR SELECT TO authenticated USING (true);

CREATE POLICY "Allow users to manage own team roster before lock" 
ON public.team_golfers FOR ALL TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.tournaments tr ON tr.id = t.tournament_id
        WHERE t.id = team_id
          AND t.user_id = auth.uid()
          AND (tr.lock_time_utc IS NULL OR now() < tr.lock_time_utc)
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.teams t
        JOIN public.tournaments tr ON tr.id = t.tournament_id
        WHERE t.id = team_id
          AND t.user_id = auth.uid()
          AND (tr.lock_time_utc IS NULL OR now() < tr.lock_time_utc)
    )
);

-- 5.7 Hole Scores RLS Policies
CREATE POLICY "Allow public read-only access to hole_scores" 
ON public.hole_scores FOR SELECT TO anon, authenticated USING (true);

-- 5.8 Tee Times RLS Policies
CREATE POLICY "Allow public read-only access to tee_times" 
ON public.tee_times FOR SELECT TO anon, authenticated USING (true);

-- 5.9 Leaderboard Standings RLS Policies
CREATE POLICY "Allow public read-only access to leaderboard_standings" 
ON public.leaderboard_standings FOR SELECT TO anon, authenticated USING (true);

-- ==========================================
-- 6. REALTIME REPLICATION SETUP
-- ==========================================

-- Enable Realtime for scorecards, standings, and tournaments
ALTER PUBLICATION supabase_realtime ADD TABLE public.leaderboard_standings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.hole_scores;
ALTER PUBLICATION supabase_realtime ADD TABLE public.tournaments;
ALTER PUBLICATION supabase_realtime ADD TABLE public.teams;
