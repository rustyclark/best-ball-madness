-- Unschedule old weekly jobs
SELECT cron.unschedule('weekly-tournament-field-ingest');
SELECT cron.unschedule('weekly-pricing-run');

-- Schedule weekly tournament field ingestion (Monday, Tuesday, Wednesday morning at 11:00 AM UTC / 6:00 AM EST)
SELECT cron.schedule(
  'weekly-tournament-field-ingest',
  '0 11 * * 1,2,3', -- 11:00 AM UTC on Mon, Tue, Wed
  $$
  SELECT net.http_post(
    url := COALESCE((SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url' LIMIT 1), 'http://api.supabase.internal/project') || '/functions/v1/ingest-tournament-field',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', (SELECT 'Bearer ' || decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    ),
    timeout_milliseconds := 60000
  );
  $$
);

-- Schedule weekly pricing algorithm run (Monday, Tuesday, Wednesday morning at 11:05 AM UTC / 6:05 AM EST)
SELECT cron.schedule(
  'weekly-pricing-run',
  '5 11 * * 1,2,3', -- 11:05 AM UTC on Mon, Tue, Wed
  $$
  SELECT net.http_post(
    url := COALESCE((SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'supabase_url' LIMIT 1), 'http://api.supabase.internal/project') || '/functions/v1/run-pricing-algorithm',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', (SELECT 'Bearer ' || decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    ),
    timeout_milliseconds := 60000
  );
  $$
);

-- Alter team_golfers to add price_at_draft column
ALTER TABLE public.team_golfers
ADD COLUMN price_at_draft NUMERIC NULL;

-- Populate existing price_at_draft values with the current golfer price
UPDATE public.team_golfers tg
SET price_at_draft = tgf.price
FROM public.tournament_golfers tgf
WHERE tg.tournament_golfer_id = tgf.id;

-- Create function to populate price_at_draft automatically
CREATE OR REPLACE FUNCTION public.populate_price_at_draft()
RETURNS TRIGGER AS $$
BEGIN
    SELECT price INTO NEW.price_at_draft
    FROM public.tournament_golfers
    WHERE id = NEW.tournament_golfer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on team_golfers to auto-fill price_at_draft on insert or update
CREATE OR REPLACE TRIGGER trg_populate_price_at_draft
BEFORE INSERT OR UPDATE OF tournament_golfer_id ON public.team_golfers
FOR EACH ROW
EXECUTE FUNCTION public.populate_price_at_draft();
