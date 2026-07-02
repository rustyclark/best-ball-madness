-- Migration to add hole_pars column to tournaments table
ALTER TABLE public.tournaments
ADD COLUMN hole_pars INTEGER[] NULL;
