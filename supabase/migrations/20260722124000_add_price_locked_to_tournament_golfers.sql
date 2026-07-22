-- Add price_locked column to tournament_golfers table
ALTER TABLE public.tournament_golfers 
ADD COLUMN price_locked BOOLEAN DEFAULT FALSE NOT NULL;

-- Lock existing prices for already priced tournament golfers
UPDATE public.tournament_golfers SET price_locked = TRUE;
