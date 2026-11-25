// ============================================================
// SIS Edge Function: refresh-cache (dipanggil pg_cron tiap 15 menit)
// Mengambil sumber publik dan menulis ke tabel api_cache agar
// aplikasi tetap punya data LIVE-ish meski klien sedang offline.
// Deploy:  supabase functions deploy refresh-cache
// (verify_jwt=false di config.toml — hanya menulis data publik)
// ============================================================
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SOURCES: [string, string][] = [
  ['swpc_kp', 'https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json'],
  ['eonet', 'https://eonet.gsfc.nasa.gov/api/v3/events?limit=50'],
  ['ll2', 'https://ll.thespacedevs.com/2.2.0/launch/upcoming/?limit=8'],
  ['exo_tap', 'https://exoplanetarchive.ipac.caltech.edu/TAP/sync?format=json&query=select+top+120+pl_name,hostname,sy_dist,pl_orbper,pl_rade,pl_bmasse,disc_year,discoverymethod,pl_eqt+from+ps+where+default_flag=1+and+disc_year+is+not+null+order+by+disc_year+desc'],
];

Deno.serve(async () => {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'); // otomatis tersedia di runtime
  if (!url || !key) return new Response('missing env', { status: 500 });
  const sb = createClient(url, key);
  let ok = 0;
  for (const [source, endpoint] of SOURCES) {
    try {
      const r = await fetch(endpoint, { headers: { 'User-Agent': 'SIS-refresh/2.2' } });
      if (!r.ok) continue;
      const payload = await r.json();
      const { error } = await sb.from('api_cache')
        .upsert({ source, payload, fetched_at: new Date().toISOString() }, { onConflict: 'source' });
      if (!error) ok++;
    } catch (_) { /* lanjut sumber berikutnya */ }
  }
  return new Response(JSON.stringify({ refreshed: ok, at: new Date().toISOString() }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
