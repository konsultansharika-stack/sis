-- =====================================================================
-- SPACE INTELLIGENCE SYSTEM v2.2 — Supabase schema lengkap
-- Jalankan SELURUH file di Supabase Dashboard → SQL Editor
-- (project yang SAMA dengan URL yang diisi di aplikasi).
-- Berisi: tabel sinkronisasi sis_records + tabel cache API api_cache
-- + GRANT eksplisit (perbaikan error 42501 "permission denied").
-- =====================================================================

-- ---------- 1) Tabel sinkronisasi record SIS ----------
create table if not exists sis_records (
  id uuid primary key default gen_random_uuid(),
  collection text not null,
  record_id text not null,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (collection, record_id)
);
create index if not exists sis_records_collection_idx on sis_records (collection);
create index if not exists sis_records_updated_idx on sis_records (updated_at desc);

alter table sis_records enable row level security;

-- GRANT eksplisit — WAJIB (project baru dapat dibuat tanpa grants default;
-- tanpa baris ini API mengembalikan "permission denied for table", kode 42501)
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table sis_records to anon, authenticated;

-- DEMO-ONLY policy: anon key boleh baca/tulis semua.
-- Untuk produksi ganti dengan policy berbasis auth.uid() (contoh di README).
drop policy if exists "sis anon demo access" on sis_records;
create policy "sis anon demo access" on sis_records
  for all to anon using (true) with check (true);

create or replace function sis_touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
drop trigger if exists sis_records_touch on sis_records;
create trigger sis_records_touch before update on sis_records
  for each row execute function sis_touch_updated_at();

-- ---------- 2) Tabel cache API (dipakai refresh-cache cron) ----------
create table if not exists api_cache (
  source text primary key,               -- 'swpc_kp', 'eonet', 'll2', 'exo_tap', ...
  payload jsonb not null default '{}'::jsonb,
  fetched_at timestamptz not null default now()
);
alter table api_cache enable row level security;
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table api_cache to anon, authenticated;
drop policy if exists "sis cache anon" on api_cache;
create policy "sis cache anon" on api_cache
  for all to anon using (true) with check (true);

-- ---------- 3) VERIFIKASI ----------
-- a) harus muncul privileges untuk anon:
select grantee, privilege_type from information_schema.role_table_grants
where table_name in ('sis_records','api_cache') order by grantee, table_name;
-- b) tes tulis/baca via path yang sama dengan aplikasi (anon):
--    Dashboard → Table Editor → cek tabel sis_records & api_cache terlihat.
