-- =====================================================================
-- SPACE INTELLIGENCE SYSTEM (SIS) v2.2.0 — Supabase schema (FIXED)
-- Jalankan SELURUH file ini di Supabase Dashboard → SQL Editor,
-- pada project yang SAMA dengan URL yang diisi di aplikasi.
-- Perbaikan: GRANT eksplisit untuk anon/authenticated — project baru
-- Supabase dapat dibuat tanpa grants default, sehingga API mengembalikan
-- "permission denied for table sis_records" (kode 42501).
-- Cocok dengan lapisan Supabase di index.html:
--   upsert(rows, { onConflict: 'collection,record_id' })
--   select('*').order('updated_at', asc:false).limit(2000)
-- =====================================================================

-- 1) Tabel penyimpanan record SIS
create table if not exists sis_records (
  id uuid primary key default gen_random_uuid(),
  collection text not null,          -- nama koleksi data SIS
  record_id text not null,           -- id record di dalam koleksi
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (collection, record_id)
);

-- Indeks bantu untuk pola akses aplikasi
create index if not exists sis_records_collection_idx
  on sis_records (collection);
create index if not exists sis_records_updated_idx
  on sis_records (updated_at desc);

-- 2) Row Level Security
alter table sis_records enable row level security;

-- 3) GRANT eksplisit — INI YANG MEMPERBAIKI
--    "permission denied for table sis_records" (42501)
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table sis_records to anon, authenticated;

-- 4) DEMO-ONLY policy: anon key boleh baca/tulis semua.
--    Untuk produksi, hapus policy ini dan ganti policy ketat, mis.:
--    create policy "own rows" on sis_records
--      for all to authenticated
--      using (auth.uid() = (payload->>'owner_uid')::uuid)
--      with check (auth.uid() = (payload->>'owner_uid')::uuid);
drop policy if exists "sis anon demo access" on sis_records;
create policy "sis anon demo access" on sis_records
  for all to anon using (true) with check (true);

-- 5) (Opsional) sinkronisasi updated_at otomatis
create or replace function sis_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists sis_records_touch on sis_records;
create trigger sis_records_touch
  before update on sis_records
  for each row execute function sis_touch_updated_at();

-- 6) VERIFIKASI — hasil query ini HARUS memuat baris untuk anon
--    (select/insert/update/delete). Kalau kosong → grants belum jalan.
select grantee, privilege_type
from information_schema.role_table_grants
where table_name in ('sis_records','api_cache')
order by grantee, table_name;

-- 7) Tabel cache API — WAJIB sejak v2.2.0: dipakai untuk sinkronisasi
--    pengaturan antar perangkat (source='sis_settings' berisi URL + anon key
--    + opsi kunci NASA) serta cache proxy/scheduler (Edge Function + pg_cron).
create table if not exists api_cache (
  source text primary key,
  payload jsonb not null default '{}'::jsonb,
  fetched_at timestamptz not null default now()
);
alter table api_cache enable row level security;
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table api_cache to anon, authenticated;
drop policy if exists "sis cache anon" on api_cache;
create policy "sis cache anon" on api_cache
  for all to anon using (true) with check (true);

-- 8) (Opsional, pengembangan lanjutan) refresh cache periodik via pg_cron.
--    Aktifkan extension di Dashboard → Database → Extensions:
--      pg_cron, pg_net
-- select cron.schedule(
--   'sis-swpc-kp', '*/2 * * * *',
--   $$ select net.http_get('https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json') $$
-- );

-- Selesai. Kembali ke aplikasi → Data Management → Supabase Sync
-- → Connect / Test. Harus tampil "Terhubung" dan badge LIVE.
-- Pindah perangkat: device lain cukup Connect ke project yang SAMA —
-- snapshot koneksi di api_cache (sis_settings) ditarik otomatis (PANDUAN §5b).
