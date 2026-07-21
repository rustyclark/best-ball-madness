-- Unschedule previous field ingest cron job if it exists
SELECT cron.unschedule('weekly-tournament-field-ingest');
SELECT cron.unschedule('hourly-tournament-field-ingest');

-- Schedule hourly tournament field ingestion (Runs at top of every hour on Tuesday and Wednesday)
SELECT cron.schedule(
  'hourly-tournament-field-ingest',
  '0 * * * 2,3', -- Top of every hour on Tuesday and Wednesday
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
