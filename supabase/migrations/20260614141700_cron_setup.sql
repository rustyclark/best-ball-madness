-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 1. minutely idempotent check for team locks
SELECT cron.schedule(
  'lock-teams-minutely',
  '* * * * *', -- Every minute
  $$
  SELECT net.http_post(
    url := 'http://api.supabase.internal/project/functions/v1/lock-teams',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', (SELECT 'Bearer ' || decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    )
  );
  $$
);

-- 2. 5-minute scoring ingestion during play
SELECT cron.schedule(
  'ingest-competition-5min',
  '*/5 * * * *', -- Every 5 minutes
  $$
  SELECT net.http_post(
    url := 'http://api.supabase.internal/project/functions/v1/ingest-competition',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', (SELECT 'Bearer ' || decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    )
  );
  $$
);

-- 3. Weekly golfer statistics sync (Monday morning at 4:00 AM UTC)
SELECT cron.schedule(
  'weekly-golfer-stats-sync',
  '0 4 * * 1', -- 04:00 AM on Monday
  $$
  SELECT net.http_post(
    url := 'http://api.supabase.internal/project/functions/v1/update-golfer-stats',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', (SELECT 'Bearer ' || decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    )
  );
  $$
);
