// Oliver's finance proxy — Cloudflare Worker
// Forwards quote + chart requests to Yahoo Finance, strips CORS, caches at the edge.
// Endpoints:
//   GET /                            → health + endpoint list
//   GET /quote?symbols=SPY,QQQ,IWM   → batch quotes (up to 25)
//   GET /chart?symbol=SPY&range=3mo&interval=1d  → raw OHLCV chart payload
//
// Paste this file verbatim into the Cloudflare dashboard Worker editor,
// or deploy via `wrangler deploy` from this directory.

const ALLOWED_ORIGINS = new Set([
  'https://olivertruelove123.github.io',
  'http://localhost:3000',
  'http://localhost:5173',
  'http://localhost:8080',
  'http://127.0.0.1:3000',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:8080',
  'null', // file:// origin when opening index.html directly
]);

const YAHOO_BASE = 'https://query1.finance.yahoo.com';
const QUOTE_CACHE_SECONDS = 5;
const CHART_CACHE_SECONDS = 300;
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

function corsHeaders(origin) {
  const allow = ALLOWED_ORIGINS.has(origin) ? origin : '';
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'GET, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Vary': 'Origin',
  };
}

function json(data, origin, init = {}) {
  const extra = init.headers || {};
  return new Response(JSON.stringify(data), {
    status: init.status || 200,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ...corsHeaders(origin),
      ...extra,
    },
  });
}

async function fetchChart(symbol, range, interval) {
  const qs = new URLSearchParams({
    range,
    interval,
    includePrePost: 'false',
  });
  const url = `${YAHOO_BASE}/v8/finance/chart/${encodeURIComponent(symbol)}?${qs}`;
  const res = await fetch(url, {
    headers: { 'User-Agent': UA, 'Accept': 'application/json' },
    cf: { cacheTtl: QUOTE_CACHE_SECONDS, cacheEverything: true },
  });
  if (!res.ok) {
    throw new Error(`yahoo_${res.status}`);
  }
  return res.json();
}

function extractQuote(symbol, chartJson) {
  const result = chartJson && chartJson.chart && chartJson.chart.result && chartJson.chart.result[0];
  if (!result) return { symbol, error: 'no_data' };
  const meta = result.meta || {};
  const price = meta.regularMarketPrice ?? null;
  const prev = meta.chartPreviousClose ?? meta.previousClose ?? null;
  const change = price != null && prev != null ? price - prev : null;
  const changePercent = change != null && prev ? (change / prev) * 100 : null;
  return {
    symbol,
    price,
    previousClose: prev,
    change,
    changePercent,
    currency: meta.currency || null,
    exchange: meta.exchangeName || null,
    marketState: meta.marketState || null,
    regularMarketTime: meta.regularMarketTime || null,
    dayHigh: meta.regularMarketDayHigh ?? null,
    dayLow: meta.regularMarketDayLow ?? null,
    volume: meta.regularMarketVolume ?? null,
  };
}

export default {
  async fetch(request) {
    const origin = request.headers.get('Origin') || '';

    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: corsHeaders(origin) });
    }
    if (request.method !== 'GET') {
      return json({ error: 'method_not_allowed' }, origin, { status: 405 });
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, '') || '/';

    try {
      if (path === '/') {
        return json(
          {
            ok: true,
            name: 'oliver-finance-proxy',
            endpoints: {
              quote: '/quote?symbols=SPY,QQQ,IWM,BTC-USD,DX-Y.NYB',
              chart: '/chart?symbol=SPY&range=3mo&interval=1d',
            },
          },
          origin,
        );
      }

      if (path === '/quote') {
        const raw = url.searchParams.get('symbols') || '';
        const symbols = raw
          .split(',')
          .map((s) => s.trim())
          .filter(Boolean)
          .slice(0, 25);
        if (symbols.length === 0) {
          return json({ error: 'missing_symbols' }, origin, { status: 400 });
        }
        const quotes = await Promise.all(
          symbols.map(async (sym) => {
            try {
              const data = await fetchChart(sym, '5d', '1d');
              return extractQuote(sym, data);
            } catch (e) {
              return { symbol: sym, error: String((e && e.message) || e) };
            }
          }),
        );
        return json(
          { quotes, fetchedAt: new Date().toISOString() },
          origin,
          { headers: { 'Cache-Control': `public, max-age=${QUOTE_CACHE_SECONDS}` } },
        );
      }

      if (path === '/chart') {
        const symbol = url.searchParams.get('symbol');
        const range = url.searchParams.get('range') || '3mo';
        const interval = url.searchParams.get('interval') || '1d';
        if (!symbol) {
          return json({ error: 'missing_symbol' }, origin, { status: 400 });
        }
        const data = await fetchChart(symbol, range, interval);
        return json(data, origin, {
          headers: { 'Cache-Control': `public, max-age=${CHART_CACHE_SECONDS}` },
        });
      }

      return json({ error: 'not_found', path }, origin, { status: 404 });
    } catch (err) {
      return json(
        { error: 'upstream_failed', message: String((err && err.message) || err) },
        origin,
        { status: 502 },
      );
    }
  },
};
