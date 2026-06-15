-- Fix missing UNIQUE constraint on tee_times for (tournament_golfer_id, round)
ALTER TABLE public.tee_times 
  ADD CONSTRAINT unique_golfer_round_tee_time 
  UNIQUE (tournament_golfer_id, round);
