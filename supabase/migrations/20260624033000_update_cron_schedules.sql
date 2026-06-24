-- Unschedule the old weekly job
SELECT cron.unschedule('weekly-tournament-field-ingest');

-- Reschedule to run on Tuesday and Wednesday mornings at 5:00 AM UTC
SELECT cron.schedule(
  'weekly-tournament-field-ingest',
  '0 5 * * 2,3', -- Tuesday & Wednesday at 05:00 AM UTC
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
