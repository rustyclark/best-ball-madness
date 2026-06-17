-- Schedule weekly tournament field ingestion (Tuesday morning at 5:00 AM UTC)
SELECT cron.schedule(
  'weekly-tournament-field-ingest',
  '0 5 * * 2', -- 05:00 AM on Tuesday
  $$
  SELECT net.http_post(
    url := 'http://api.supabase.internal/project/functions/v1/ingest-tournament-field',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', (SELECT 'Bearer ' || decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    )
  );
  $$
);

-- Schedule weekly pricing algorithm run (Wednesday night at 10:00 PM UTC)
SELECT cron.schedule(
  'weekly-pricing-run',
  '0 22 * * 3', -- 10:00 PM on Wednesday
  $$
  SELECT net.http_post(
    url := 'http://api.supabase.internal/project/functions/v1/run-pricing-algorithm',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', (SELECT 'Bearer ' || decrypted_secret FROM vault.decrypted_secrets WHERE name = 'service_role_key' LIMIT 1)
    )
  );
  $$
);
