-- Migration to add is_amateur column to public.golfer_profiles table
ALTER TABLE public.golfer_profiles ADD COLUMN is_amateur BOOLEAN DEFAULT false NOT NULL;
