-- =====================================================================
-- SIS — pg_cron: jadwal refresh cache API (opsional, Tahap 3 lanjutan)
-- Prasyarat: aktifkan extension di Dashboard → Database → Extensions:
--   • pg_cron   • pg_net
-- Lalu deploy Edge Function refresh-cache (lihat PANDUAN §5).
-- GANTI <PROJECT_REF> dengan ref project Anda (xxxyyy.supabase.co).
-- =====================================================================
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Hapus jadwal lama bila ada, lalu pasang jadwal 15 menitan
select cron.unschedule('sis-refresh-cache')
where exists (select 1 from cron.job where jobname='sis-refresh-cache');

select cron.schedule(
  'sis-refresh-cache',
  '*/15 * * * *',
  $$
  select net.http_post(
    url := 'https://<PROJECT_REF>.supabase.co/functions/v1/refresh-cache',
    headers := jsonb_build_object('Content-Type','application/json'),
    body := '{}'::jsonb
  ) as req;
  $$
);

-- (Opsional) buang cache lebih tua dari 7 hari, harian pukul 03.00 UTC
select cron.unschedule('sis-prune-cache')
where exists (select 1 from cron.job where jobname='sis-prune-cache');
select cron.schedule(
  'sis-prune-cache',
  '0 3 * * *',
  $$ delete from api_cache where fetched_at < now() - interval '7 days' $$
);

-- Verifikasi jadwal:
select jobname, schedule, active from cron.job;
