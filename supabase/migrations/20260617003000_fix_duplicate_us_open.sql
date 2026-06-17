-- Delete duplicate tournament if it exists (cascade will clean up its 156 golfers)
DELETE FROM public.tournaments
WHERE id = 'af06b230-697e-41e4-8e9c-9f6a2ea730d1';

-- Fix the tournament espn_event_id for the U.S. Open seeded tournament
UPDATE public.tournaments
SET espn_event_id = '401811952'
WHERE id = 'b1111111-1111-1111-1111-111111111111';
