-- Unschedule old weekly jobs if they exist
SELECT cron.unschedule('weekly-tournament-field-ingest');
SELECT cron.unschedule('weekly-pricing-run');

-- Schedule weekly tournament field ingestion (Tuesday and Wednesday morning at 10:00 AM UTC / 6:00 AM Eastern)
SELECT cron.schedule(
  'weekly-tournament-field-ingest',
  '0 10 * * 2,3', -- 10:00 AM UTC on Tue, Wed
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

-- Schedule weekly pricing algorithm run (Tuesday and Wednesday morning at 10:05 AM UTC / 6:05 AM Eastern)
SELECT cron.schedule(
  'weekly-pricing-run',
  '5 10 * * 2,3', -- 10:05 AM UTC on Tue, Wed
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
