// ============================================================
// SIS Edge Function: nasa-proxy
// Proxy CORS untuk API yang tidak mengirim header Access-Control
// (wajib untuk Exoplanet Archive/IPAC; berguna juga untuk JPL
// Horizons di jaringan yang memblokir) + menyuntikkan NASA_API_KEY
// dari secrets untuk api.nasa.gov sehingga DEMO_KEY tak dipakai.
// Deploy:  supabase functions deploy nasa-proxy
// Secrets: supabase secrets set NASA_API_KEY=xxxxxxxx
// ============================================================
const ALLOW = new Set([
  'api.nasa.gov',
  'ssd-api.jpl.nasa.gov',
  'ssd.jpl.nasa.gov', // v2.2.5: Horizons API pindah ke host/path ini
  'exoplanetarchive.ipac.caltech.edu',
  'services.swpc.noaa.gov',
  'eonet.gsfc.nasa.gov',
  'api.wheretheiss.at',
  'll.thespacedevs.com',
  'celestrak.org',
]);

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET,OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    const url = new URL(req.url);
    const p = url.searchParams.get('p');
    if (!p) {
      return new Response(JSON.stringify({ error: "missing ?p=<urlencoded target URL>" }),
        { status: 400, headers: { ...CORS, 'Content-Type': 'application/json' } });
    }
    let target;
    try { target = new URL(p); } catch { target = null; }
    if (!target || !ALLOW.has(target.hostname)) {
      return new Response(JSON.stringify({ error: 'host not allowed: ' + (target ? target.hostname : p) }),
        { status: 403, headers: { ...CORS, 'Content-Type': 'application/json' } });
    }
    // Suntik kunci NASA dari secrets (jangan pernah hardcode di klien)
    const nk = Deno.env.get('NASA_API_KEY');
    if (nk && target.hostname === 'api.nasa.gov') target.searchParams.set('api_key', nk);

    const r = await fetch(target.toString(), {
      headers: { 'User-Agent': 'SIS-Edge-Proxy/2.2' },
    });
    const body = await r.text();
    return new Response(body, {
      status: r.status,
      headers: {
        ...CORS,
        'Content-Type': r.headers.get('content-type') ?? 'application/json',
        'Cache-Control': 'max-age=120',
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...CORS, 'Content-Type': 'application/json' } });
  }
});
