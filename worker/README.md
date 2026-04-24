# Finance proxy Worker

Cloudflare Worker that forwards quote + chart requests to Yahoo Finance, strips CORS, and caches at the edge. The dashboard (`index.html` one directory up) calls it to power the breadth bar, drawer prices, mini-watchlist, and 30-day correlation matrix.

- **Free tier:** 100,000 requests/day. The whole dashboard uses maybe 200/day.
- **Edge cache:** 5 seconds on `/quote`, 5 minutes on `/chart`. Repeated loads within that window don't hit Yahoo.
- **CORS allowlist:** `https://olivertruelove123.github.io` + localhost variants + `file://`.

## Endpoints

| Method | Path | Params | Purpose |
|---|---|---|---|
| GET | `/` | — | Health check / endpoint list |
| GET | `/quote` | `symbols=SPY,QQQ,IWM` (≤25) | Batch quotes — last price, prev close, change %, volume, day H/L |
| GET | `/chart` | `symbol=SPY&range=3mo&interval=1d` | Raw Yahoo OHLCV payload (for correlation matrix) |

Response shape for `/quote`:

```json
{
  "quotes": [
    {
      "symbol": "SPY",
      "price": 512.34,
      "previousClose": 510.10,
      "change": 2.24,
      "changePercent": 0.439,
      "currency": "USD",
      "marketState": "REGULAR",
      "dayHigh": 513.22,
      "dayLow": 509.88,
      "volume": 42123456,
      "regularMarketTime": 1745421300
    }
  ],
  "fetchedAt": "2026-04-24T18:15:00.123Z"
}
```

---

## Deploy (dashboard, 10–15 min, no CLI)

### 1. Create a Cloudflare account

1. Go to **https://dash.cloudflare.com/sign-up**.
2. Enter email + password. Verify the email.
3. You'll land on the Cloudflare dashboard home. **Skip** any "add your website" prompts — you don't need a domain for this.

### 2. Create the Worker

1. In the left sidebar click **Workers & Pages**. (If prompted to set up a free Workers subdomain, pick any name — e.g. `olivertruelove`. It becomes `*.olivertruelove.workers.dev`.)
2. Click **Create application** → **Create Worker**.
3. Give it a name. Suggested: `finance-proxy`. The final URL will be `https://finance-proxy.<your-subdomain>.workers.dev`.
4. Click **Deploy**. (Cloudflare deploys a "Hello World" placeholder — that's fine, we'll overwrite it.)
5. On the success screen click **Edit code**.

### 3. Paste the Worker code

1. In the code editor, **select all** and delete the placeholder.
2. Open `worker/worker.js` from this repo and paste its full contents.
3. Click **Save and Deploy** (top right). Confirm.

That's it — the Worker is live. You should see the URL at the top of the page, something like:
```
https://finance-proxy.olivertruelove.workers.dev
```

Copy that URL — you'll need it to wire the dashboard.

### 4. Verify it's working

In a browser, visit:

```
https://finance-proxy.<your-subdomain>.workers.dev/
```

You should see JSON like:
```json
{"ok":true,"name":"oliver-finance-proxy","endpoints":{...}}
```

Then try a live quote:

```
https://finance-proxy.<your-subdomain>.workers.dev/quote?symbols=SPY,QQQ,IWM,BTC-USD,DX-Y.NYB
```

You should see 5 quote objects with current prices.

Or from a terminal:

```bash
curl "https://finance-proxy.<your-subdomain>.workers.dev/quote?symbols=SPY,QQQ,IWM"
```

If all three return a `price` and `changePercent`, the Worker is healthy. Tell me the URL and I'll wire the dashboard.

---

## Alternative: deploy via Wrangler CLI

If you'd rather deploy from the command line:

```bash
npm install -g wrangler
cd worker
wrangler login         # opens browser
wrangler deploy        # reads wrangler.toml, pushes worker.js
wrangler tail          # stream logs
```

The account binding and subdomain are handled by `wrangler login`. After the first `wrangler deploy`, the URL prints to stdout.

---

## Updating the Worker later

- **Via dashboard:** Workers & Pages → `finance-proxy` → Edit code → paste → Save and Deploy.
- **Via CLI:** edit `worker.js` locally, run `wrangler deploy`.

Both are atomic — traffic cuts over at the edge in under a second.

## Rolling back

Dashboard: Workers & Pages → `finance-proxy` → **Deployments** tab → pick a previous version → **Rollback**.

## Troubleshooting

- **CORS error in browser console.** The origin isn't in `ALLOWED_ORIGINS`. Add it in `worker.js` and redeploy.
- **`yahoo_429` error.** Yahoo rate-limited the edge node. The 5s cache usually prevents this; if it happens repeatedly raise `QUOTE_CACHE_SECONDS` to 15.
- **`no_data` for a symbol.** Yahoo doesn't know that symbol — check the ticker format. Examples that work: `SPY`, `BTC-USD`, `DX-Y.NYB`, `^VIX`, `ES=F`, `EURUSD=X`.

## Security notes

- No secrets or API keys in this Worker. Anyone can call it — the CORS allowlist limits *browser* callers but a curl request works from anywhere. That's fine: it only proxies public Yahoo data.
- Free-tier limit is 100,000 requests/day per account. If you ever approach that (you won't), add a simple rate limiter keyed on `request.headers.get('CF-Connecting-IP')`.
