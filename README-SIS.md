# SPACE INTELLIGENCE SYSTEM (SIS) v2.2.0 — Realtime Edition

**Beyond Earth, Beyond Intelligence.**
Advanced Cosmic Monitoring, Exploration & Intelligence Platform — aplikasi satu file `index.html` (HTML5 + CSS3 + JavaScript), tanpa build step, langsung dibuka di browser.

---

## 1. Cara Menjalankan

1. Simpan / salin `index.html` ke komputer atau hosting statis apa pun (GitHub Pages, Netlify, Vercel, cPanel, dsb.).
2. Buka dengan browser modern (Chrome, Edge, Firefox, Safari).
3. Selesai — tidak ada instalasi, server, atau build. Semua fitur berjalan pada **mode demo lokal** meski tanpa internet.

> Saat daring, SIS otomatis mencoba sumber data publik resmi (NOAA SWPC — Kp, **DSCOVR solar wind, GOES X-ray**, **USGS gempa**, NASA NeoWs, Launch Library 2, NASA EONET, WhereTheISS.at, CelesTrak, **JPL Horizons**, **NASA Exoplanet Archive TAP**) dan memberi label **LIVE / CACHED / SIMULATED / MODEL REAL** pada tiap panel — setiap angka KPI sekarang mencantumkan sumbernya (mis. "LIVE DSCOVR"). Posisi ISS/Tiangong dihitung dengan **propagasi SGP4 nyata** (library `satellite.js`) dari TLE resmi CelesTrak; bila CelesTrak tidak terjangkau, posisi ISS tetap **nyata** dari API WhereTheISS.at; tanpa keduanya, model orbit demo (**SIMULATED**). **Baru di v2.2:** planet di Solar System Explorer memakai **ephemeris nyata** (Horizons LIVE, atau propagasi Kepler dari elemen orbit JPL — tervalidasi, ±1′), panel **probe antarpelanet** (Voyager, Parker, dll.) dengan delay sinyal one-way, **feed eksoplanet terbaru** dari NASA EA TAP, **cuaca antariksa DSCOVR/GOES nyata** (Kp, angin, Bt/Bz, F10.7, flare; DONKI FLR/CME dengan kunci NASA), dan **event geofisika aktif otomatis** (USGS gempa M4.5+ + EONET) serta **alert resmi NOAA SWPC** (`products/alerts.json` — WATCH/WARNING/ALERT geomagnetik & X-ray, 30 hari). **Sinkronisasi antar perangkat v2.2.1:** koneksi Supabase & kunci NASA bisa ditarik otomatis di perangkat baru (snapshot `api_cache`/`sis_settings`) atau lewat **Tautan gabung** — kredensial memang tidak pernah tertanam di file (LocalStorage per-device). Detail + verifikasi koneksi: **PANDUAN.md**.

## 2. Fitur Utama

- **19 modul lengkap** (Command Center → System Settings), semua tombol/menu/filter/form berfungsi.
- **3D interaktif (Three.js):** globe Bumi bertekstur prosedural dengan terminator siang-malam real-time, posisi satelit, marker geofisika, dan tata surya 14 objek (klik planet = katalog ilmiah; drag = rotasi; scroll = zoom; kecepatan/pause/reset).
- **Grafik (Chart.js):** 25+ grafik (Kp index, angin matahari, pertumbuhan objek, sebaran eksoplanet, risiko, dll.).
- **Data & penyimpanan:** LocalStorage persisten + CRUD generik di Data Management (tambah/edit/hapus/pencarian/sorting/pagination), import–export CSV/JSON, backup & restore, reset demo.
- **Propagasi orbital SGP4 (Tahap 3):** posisi & ground track ISS/Tiangong dihitung ilmiah dari TLE NORAD (CelesTrak) dengan `satellite.js`, dengan rantai fallback TLE → posisi ISS live → model demo, semua berlabel sumbernya.
- **Supabase opsional** (lihat §3): sinkronisasi cloud push/pull tanpa API key tertanam.
- **ASTRA** — asisten AI demo berbasis basis pengetahuan lokal (±50 topik + jawaban dinamis dari data SIS), riwayat chat, saran pertanyaan, tombol salin.
- **Laporan:** 10 jenis laporan profesional (executive summary, temuan, grafik, analisis, kesimpulan, rekomendasi, sumber) + cetak/PDF, CSV, JSON, riwayat.
- **Alert Center** dengan prioritas, mark-as-read, simulasi alert & suara WebAudio.
- **Fitur unggulan:** global search, command palette (Ctrl+K), keyboard shortcuts (Ctrl+/), kalkulator ilmiah, kalender observasi, cosmic timeline, presentation mode, fullscreen, kustomisasi dashboard, activity log.
- **Responsif** desktop / tablet / smartphone (sidebar drawer di mobile).

## 3. Sinkronisasi Supabase (Opsional)

Tidak ada kunci rahasia di dalam file. Untuk mengaktifkan cloud sync:

1. Buat proyek di [supabase.com](https://supabase.com) → SQL Editor, jalankan SQL lengkap dari file **`sis_supabase.sql`** (atau tombol **Schema SQL** di aplikasi). Ringkasannya:

```sql
-- SIS Supabase schema (ringkas — versi lengkap di sis_supabase.sql)
create table if not exists sis_records (
  id uuid primary key default gen_random_uuid(),
  collection text not null,
  record_id text not null,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (collection, record_id)
);
alter table sis_records enable row level security;

-- GRANT eksplisit — WAJIB. Project baru Supabase dapat dibuat tanpa
-- grants default ke anon, sehingga muncul error
-- "permission denied for table sis_records" (42501) tanpa baris ini.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on table sis_records to anon, authenticated;

-- DEMO-ONLY: izinkan anon key menulis/membaca.
-- Untuk produksi, ganti dengan policy ketat (mis. berbasis auth.uid()).
drop policy if exists "sis anon demo access" on sis_records;
create policy "sis anon demo access" on sis_records
  for all to anon using (true) with check (true);
```

2. Ambil **Project URL** dan **anon key** dari Supabase → Settings → API (project yang **sama** dengan tempat SQL dijalankan).
3. Di aplikasi: buka **Data Management → panel Supabase Sync** → isi URL, anon key, tabel (`sis_records`, huruf kecil semua) → **Connect / Test** → gunakan **Push** / **Pull**. Opsional aktifkan **Auto-sync**.
4. Tanpa konfigurasi, seluruh aplikasi tetap berjalan penuh secara lokal.
5. **Pemecahan masalah:** pesan *permission denied* → jalankan blok GRANT di atas; pesan *row-level security* → jalankan blok policy; pesan *relation does not exist* → tabel belum dibuat / URL dari project yang berbeda. Aplikasi kini menampilkan petunjuk ini otomatis di pesan errornya.

## 4. Sumber Data Publik yang Dicoba SIS

| Sumber | Endpoint (dokumentasi resmi) | Kebutuhan |
|---|---|---|
| NOAA SWPC | `services.swpc.noaa.gov/products/noaa-planetary-k-index.json` | tanpa key |
| WhereTheISS.at | `api.wheretheiss.at/v1/satellites/25544` | tanpa key (posisi ISS nyata, ±1 req/dtk) |
| NASA NeoWs | `api.nasa.gov/neo/rest/v1/feed` | `api_key` (default `DEMO_KEY`, bisa diganti di Settings) |
| NASA EONET | `eonet.gsfc.nasa.gov/api/v3/events` | tanpa key |
| Launch Library 2 | `ll.thespacedevs.com/2.2.0/launch/upcoming/` | rate-limit publik |
| CelesTrak GP (TLE) | `celestrak.org/NORAD/elements/gp.php?GROUP=stations` | tanpa key; fetch dibatasi 1x/2 jam → SGP4 |
| NOAA SWPC DSCOVR/GOES | `services.swpc.noaa.gov/products/summary/*`, `/json/goes/primary/xrays-1-day.json` | tanpa key; angin matahari, Bt/Bz, F10.7, kelas flare 24 jam |
| USGS Earthquakes | `earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.geojson` | tanpa key; CORS terbuka; gempa M4.5+ 7 hari (±95 event) |
| NASA DONKI FLR/CME | `api.nasa.gov/DONKI/...` | `api_key` pribadi; daftar flare/CME 7 hari (fallback: GOES XRS) |
| **JPL Horizons** | `ssd-api.jpl.nasa.gov/horizons.api` (VECTORS, ECLIPTIC) | tanpa key; vektor planet & probe (NAIF −31…−151); bila diblokir jaringan → proxy Edge / fallback Kepler |
| **NASA Exoplanet Archive (TAP)** | `exoplanetarchive.ipac.caltech.edu/TAP/sync` (tabel `ps`) | tanpa key; **tanpa CORS** → wajib proxy Edge; fallback katalog kurasi HISTORICAL |
| NASA DONKI / APOD | `api.nasa.gov/DONKI/...`, `api.nasa.gov/planetary/apod` | `api_key` (masukkan sendiri di Settings) |
| JPL SBDB, SIMBAD, ESA Open Data | katalog (mode demo memakai salinan lokal berlabel HISTORICAL) | — |

Kegagalan jaringan/CORS/rate-limit ditangani dengan fallback berlapis: **vektor Horizons → propagasi Kepler (MODEL REAL) → demo (SIMULATED)** untuk planet; **TAP via proxy → katalog kurasi (HISTORICAL)** untuk eksoplanet; **USGS → EONET → demo (SIMULASI)** untuk event geofisika; **DSCOVR/GOES → generator simulasi berlabel** untuk cuaca antariksa — tidak pernah ada data yang diklaim real-time padahal simulasi. Akurasi Kepler tervalidasi: Bumi 25-11-2026 → lon 62,85° (truth ≈63°), r 0,9871 AU, progresi 30 hari 30,47° (script `scripts/verify_kepler.py`).

### Memastikan NASA API Key terkoneksi & aktif

1. Buka **System Settings → panel DATA & REGIONAL** → isi **NASA api_key** (tersimpan di LocalStorage perangkat; untuk memindahkannya antar perangkat lihat PANDUAN §5b — snapshot via tabel `api_cache` Supabase atau **Tautan gabung**) → klik **Test kunci**. Aplikasi mengirim 1 request uji ke endpoint APOD `api.nasa.gov` dan menampilkan hasilnya:
   - **VALID & AKTIF (HTTP 200)** — kunci bekerja; sisa kuota dibaca dari header `X-RateLimit-Remaining/Limit` bila tersedia, beserta konten APOD hari ini sebagai bukti nyata.
   - **TIDAK VALID (HTTP 403)** — kunci salah/kadaluarsa. Daftar ulang gratis di [api.nasa.gov](https://api.nasa.gov) → *Generate API Key* (kunci dikirim ke email).
   - **KUNCI DITERIMA TAPI KUOTA HABIS (HTTP 429)** — kunci benar tapi jatah permintaan habis. `DEMO_KEY` dibagi dengan semua pengguna pada IP yang sama sehingga cepat habis; gunakan kunci pribadi.
   - **GAGAL JARINGAN** — periksa koneksi internet.
2. Indikator lain di aplikasi: **Command Center → STATUS SUMBER DATA** menampilkan baris *NASA NeoWs* dengan badge **LIVE / CACHED / SIMULATED** dan waktu sinkron; badge di halaman **Asteroid & NEO Monitoring** ikut berubah LIVE saat fetch NeoWs sukses; setiap hasil uji tercatat di **System Activity Log**.
3. Cek mandiri tanpa aplikasi: buka di browser `https://api.nasa.gov/neo/rest/v1/feed?start_date=YYYY-MM-DD&api_key=KEY_ANDA` — JSON berisi data = kunci aktif; pesan `API_KEY_INVALID` / HTTP 403 = kunci salah; HTTP 429 = kuota habis.

## 5. Batasan yang Dinyatakan di Antarmuka

- Semua angka demonstrasi berlabel **SIMULATED**; nilai katalog astronomi berlabel **HISTORICAL** (aproksimasi publik).
- Analisis konjungsi/tabrakan bersifat edukatif, **tidak untuk keputusan operasional wahana**.
- PHA ≠ asteroid yang pasti menabrak; probabilitas tumbukan hanya dikutip dari publikasi resmi.
- Sinyal SETI 100% simulasi dan tidak pernah diklaim sebagai sinyal kehidupan ekstraterestrial.
- Berada di habitable zone tidak menyatakan adanya kehidupan.
- Ukuran & jarak visual tata surya tidak berskala sebenarnya.
- Terjemahan Bahasa Inggris mencakup navigasi & label UI utama; konten isi memakai Bahasa Indonesia.

## 6. Shortcut

| Tombol | Fungsi |
|---|---|
| `Ctrl + K` | Command palette |
| `Ctrl + /` | Daftar shortcut |
| `Alt + 1…9` | Navigasi cepat modul |
| `Alt + P` | Presentation mode |
| `Ctrl + Shift + C` | Kalkulator ilmiah |
| `Ctrl + Shift + O` | Kalender observasi |
| `Esc` | Tutup modal / keluar presentasi |

SIS v2.1.0 · build 2026.11 · dibuat sebagai aplikasi demonstrasi mandiri.
