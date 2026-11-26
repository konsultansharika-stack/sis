# PANDUAN SIS v2.2 (Realtime Edition)

Space Intelligence System — aplikasi satu-file `index.html` (offline-first) dengan
**lapisan data realtime nyata**: propagasi Kepler/SGP4, JPL Horizons, NASA ExoArchive
TAP, NOAA SWPC, WhereTheISS.at, CelesTrak, Launch Library 2, EONET, NeoWs.

---

## 1. Menjalankan aplikasi

Buka `index.html` langsung di browser (klik dua kali — `file://` didukung penuh),
atau host sebagai file statis (Netlify/GitHub Pages/VPS). Tidak ada build step dan
tidak ada kunci rahasia di dalam file.

## 2. Memastikan NASA API Key aktif

1. Daftar gratis di <https://api.nasa.gov> → **Generate API Key** (kunci dikirim ke email).
2. Aplikasi → **System Settings → DATA & REGIONAL** → isi **NASA api_key** → klik **Test kunci**.
3. Arti hasil uji:
   - **VALID & AKTIF (HTTP 200)** — kunci bekerja; sisa kuota dibaca dari header `X-RateLimit`.
   - **TIDAK VALID (HTTP 403)** — kunci salah/kadaluarsa; daftar ulang.
   - **KUNCI DITERIMA TAPI KUOTA HABIS (429)** — kunci benar, jatah habis. `DEMO_KEY`
     dibagi dengan semua pengguna satu IP; selalu gunakan kunci pribadi.
   - **GAGAL JARINGAN** — periksa koneksi.
4. Indikator lain: Command Center → **STATUS SUMBER DATA** (badge LIVE/CACHED/SIMULATED),
   badge di modul Asteroid & NEO, dan **System Activity Log**.

## 3. Matriks realtime (apa yang berubah di v2.2)

| Modul | Sebelum | Sesudah v2.2 | Sumber |
|---|---|---|---|
| Solar System Explorer | Orbit lingkaran, fase ACAK (SIMULATED) | **Posisi nyata hari ini** — vektor Horizons saat LIVE, atau propagasi Kepler elemen JPL (±1′, valid 1800–2050). Konjungsi/oposisi sesuai kenyataan | ssd-api.jpl.nasa.gov / model JPL |
| Deep Space — Probe | Tidak ada | Panel posisi 6 probe (Voyager 1/2, New Horizons, Parker, Juno, Lucy) + **delay sinyal one-way** (c=499,005 s/AU). Fallback model berlabel SIMULATED | Horizons NAIF −31,−32,−49,−96,−61,−151 |
| Exoplanet Discovery | Katalog kurasi statis | **Feed 120 eksoplanet terbaru** dari NASA Exoplanet Archive (TAP `ps`, `default_flag=1`) di depan katalog; badge LIVE/HISTORICAL | exoplanetarchive.ipac.caltech.edu |
| Satellite / Traffic / Weather / Command | Sudah realtime (SGP4, SWPC, ISS) | Tetap + sumber baru terlihat di panel sumber | SWPC, CelesTrak, WhereTheISS.at, LL2, NeoWs |
| **Space Weather (v2.2b)** | Generator simulasi penuh (badge LIVE tapi isi demo!) | **Kp** (NOAA, riwayat 48 jam), **angin matahari + Bt/Bz** (DSCOVR realtime), **F10.7**, **kelas flare dari GOES X-ray**, **DONKI FLR/CME** bila kunci NASA diisi; densitas tetap simulasi (tak ada endpoint publik) | services.swpc.noaa.gov, api.nasa.gov/DONKI |
| **Earth — Event Geofisika (v2.2b)** | Hanya tombol manual EONET (dan EONET v3 sering 500) | **Otomatis saat halaman dibuka**: gempa M4.5+ 7 hari dari **USGS** (±95 event, CORS terbuka) + EONET bila hidup; marker nyata di globe 3D & peta 2D + link sumber | earthquake.usgs.gov, eonet.gsfc.nasa.gov |

Catatan akurasi Kepler: matematika tervalidasi — Bumi 25-11-2026: lon 62,85° (truth geometris
≈63°), r 0,9871 AU, progresi 30 hari 30,47°; kode JS dan verifikasi Python menghasilkan angka identik.

## 4. Rute transport API (kenapa ada proxy)

- **api.nasa.gov, SWPC (Kp/DSCOVR/GOES + alert resmi `products/alerts.json`), WhereTheISS, LL2, USGS, Spaceflight News API (SNAPI v4)** → CORS terbuka → langsung dari browser.
- **CelesTrak GP (TLE)** → CORS terbuka tetapi sering memblokir/melambatkan akses dari jaringan datacenter/VPN
  → aplikasi mencoba langsung (15 s), lalu otomatis via `nasa-proxy` bila switch Proxy aktif; gagal keduanya =
  badge SIMULATED untuk baris TLE (posisi ISS tetap nyata via WhereTheISS.at).
- **EONET v3** → CORS terbuka, tetapi layanannya sendiri sering 500 → aplikasi otomatis memakai USGS sebagai sumber event nyata; EONET dipakai begitu pulih.
- **Exoplanet Archive (IPAC)** → **tanpa header CORS** → langsung dari `file://` pasti diblokir
  → butuh **Edge Function `nasa-proxy`** (§5) atau server kecil milik Anda.
- **JPL Horizons** → CORS terbuka menurut dokumentasi, tetapi beberapa jaringan memblokir hostnya
  → aplikasi mencoba langsung, lalu otomatis mencoba proxy bila tersedia; gagal keduanya =
  fallback model (dilabel jujur di UI).

## 5. Deploy Supabase (sinkronisasi + proxy) — ±10 menit

Prasyarat: Node 20+, CLI `supabase` (`npm i -g supabase`), login `supabase login`.

1. **Database**: Dashboard → SQL Editor → jalankan `supabase/schema.sql`
   (tabel `sis_records` + `api_cache` + GRANT + policy). Verifikasi bawahnya menampilkan
   privileges `anon`.
2. **Sync di aplikasi**: Data Management → Supabase Sync → isi URL + anon key → Connect/Test.
   Ada error `permission denied`? Jalankan blok GRANT (tombol **Schema SQL** di aplikasi
   memuat versi terbaru).
3. **Edge Functions**:
   ```bash
   mkdir -p sis/supabase/functions && cd sis
   # salin folder supabase/functions/{nasa-proxy,refresh-cache} + config.toml dari paket ini
   supabase functions deploy nasa-proxy
   supabase functions deploy refresh-cache
   supabase secrets set NASA_API_KEY=kunci_nasa_anda
   ```
4. **Aktifkan proxy di aplikasi**: System Settings/Data Management → Supabase Sync →
   nyalakan **Proxy API via Edge Function**. Sekarang ExoArchive & Horizons dirutekan
   lewat `<project>/functions/v1/nasa-proxy?p=<url>`.
5. **Cron cache** (opsional): SQL Editor → jalankan `supabase/cron.sql`
   (aktifkan pg_cron & pg_net dulu; ganti `<PROJECT_REF>`).

## 5b. Pindah perangkat — kenapa kunci tidak "tersimpan" di GitHub

Koneksi Supabase (URL + anon key) dan NASA api_key disimpan di **LocalStorage
browser** — milik perangkat & browser itu saja. File `index.html` sengaja **tidak
memuat kunci apa pun** supaya aman di-commit ke GitHub; GitHub hanya menyimpan
kode, bukan pengaturan runtime. Dua cara membawa kredensial ke perangkat lain:

1. **Otomatis via cloud (v2.2.0)** — saat Connect, aplikasi menyimpan snapshot
   koneksi ke tabel `api_cache` project Supabase (`source='sis_settings'`) lalu
   **menariknya kembali**: perangkat baru cukup isi URL + anon key yang sama →
   Connect → pengaturan dan kunci NASA (bila switch **Sertakan kunci NASA**
   aktif) langsung terisi tanpa diketik ulang.
2. **Tautan gabung** — Data Management → Supabase Sync → **Tautan gabung** →
   salin tautan, buka di browser/perangkat lain: kredensial diterapkan otomatis
   + auto-connect + data sinkron ikut ditarik.

Keamanan: anon key memang dirancang terbuka (asal RLS policy aktif), tetapi kunci
NASA bersifat pribadi — matikan "Sertakan kunci NASA" bila project atau tautan
bisa diakses orang lain; tautan gabung memuat kredensial di dalam hash URL.

## 6. Checklist verifikasi koneksi (2 menit)

- [ ] Command Center → STATUS SUMBER DATA: minimal SWPC + WhereTheISS + LL2 **LIVE** (tanpa key).
- [ ] Space Weather → badge **LIVE — NOAA SWPC DSCOVR/GOES**; angin ≈ 250–800 km/s (bukan angka acak).
- [ ] Space Weather → panel **Alert Resmi NOAA SWPC (30 hari)**: badge LIVE + alert nyata (K04W/K05A/ALTXRM — WATCH/WARNING/ALERT geomagnetik & X-ray).
- [ ] Command Center → **Peringatan Terbaru**: baris dengan badge hijau `LIVE · NOAA SWPC`/`LIVE · USGS` (di atas riwayat demo).
- [ ] Global Space Intelligence → **Space News Feed**: badge `LIVE · SNAPI` + artikel nyata (Spaceflight Now, NASA, dll.) dengan tautan artikel.
- [ ] Earth Observation → badge **USGS: LIVE (±95 gempa)**; daftar "Event Geofisika Aktif" berisi gempa M4.5+ nyata.
- [ ] Settings → Test kunci NASA → **VALID & AKTIF** (dengan kunci pribadi).
- [ ] Solar System → badge **MODEL REAL / LIVE** + planet di posisi hari ini.
- [ ] Deep Space → tabel probe: LIVE (Horizons) atau fallback berlabel SIMULATED.
- [ ] Exoplanet → badge **LIVE DATA — NASA EA TAP** (butuh proxy) atau HISTORICAL.
- [ ] Data Management → Connect/Test Supabase → "Terhubung!" (opsional).
- [ ] Pindah perangkat: Connect di device baru → pengaturan & kunci NASA ditarik otomatis, atau via **Tautan gabung** (§5b).

## 7. Pemecahan masalah

| Gejala | Penyebab | Solusi |
|---|---|---|
| `permission denied for table` (42501) | GRANT anon tidak ada | Jalankan `supabase/schema.sql` penuh / tombol Schema SQL |
| `row-level security` saat Push | Policy tidak ada | Blok policy di schema.sql |
| `relation does not exist` | Tabel di project lain / belum dibuat | Jalankan SQL di project yang SAMA dengan URL |
| NASA 429 | Kuota habis (DEMO_KEY) | Kunci pribadi di api.nasa.gov |
| NeoWs 403 | Kunci salah | Test kunci di Settings; daftar ulang |
| Exo tetap HISTORICAL | TAP diblokir CORS | Deploy nasa-proxy + nyalakan switch Proxy (§5) |
| Probe tetap SIMULATED | Horizons diblokir jaringan | Sama — lewat nasa-proxy |
| Earth list tetap SIMULASI | EONET 500 **dan** USGS diblokir | Periksa akses earthquake.usgs.gov; proxy juga mendukungnya |
| Weather badge SIMULATED | services.swpc.noaa.gov tidak terjangkau | Koneksi internet; tanpa proxy pun SWPC biasanya jalan |
| Panel Alert Resmi kosong | `products/alerts.json` tidak terjangkau | Tombol Refresh; panel menampilkan catatan fallback berlabel jujur |
| CelesTrak GP tetap SIMULATED | celestrak.org memblokir/melambatkan jaringan Anda | Deploy nasa-proxy + nyalakan switch Proxy (§5); ISS tetap LIVE via WhereTheISS.at |
| Space News Feed tanpa artikel LIVE | api.spaceflightnewsapi.net tidak terjangkau | Feed seed demo tetap tampil berlabel SIMULASI; coba Refresh |
| Horizons/Probe tetap SIMULATED | ssd-api.jpl.nasa.gov diblokir jaringan | Sama — lewat nasa-proxy (§5) |
| Kunci tidak muncul di device baru | LocalStorage = per-device | Connect ke project Supabase yang sama / pakai Tautan gabung (§5b) |
| Push pengaturan gagal (`api_cache` tidak ada) | Project dibuat dengan SQL lama | Jalankan ulang `sis_supabase.sql` / tombol **Schema SQL** versi baru |
| Chart kosong | CDN Chart.js offline | Koneksi internet; data tetap ada di tabel |

## 8. Batasan yang jujur di-deklarasikan UI

- Label **SIMULATED** = model/fallback, bukan data nyata; **MODEL REAL** = mekanika nyata dari
  elemen orbit resmi; **LIVE** = fetch API berhasil; **HISTORICAL** = katalog statis berlabel sumber.
- Ukuran/jarak di visual 3D dikompresi (tidak berskala); angka di panel tabel memakai nilai asli.
- SETI Signal Intelligence tetap simulasi secara disengaja: tidak ada stream sinyal radio
  publik realtime — klaim lain akan tidak jujur.
