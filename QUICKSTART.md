# Quickstart — Overhaul v2

## Command palette

**⌘ / Ctrl + K** opens the palette. Fuzzy type anything:

- `aapl` → jumps to AAPL's detail drawer
- `perf` → jumps to the Performance tab
- `sizer` → opens the position sizer
- `export csv` → downloads the trades table
- `theme` → toggles terminal ↔ midnight

`↑ / ↓` navigate, `↵` selects, `Esc` closes.

## Keyboard shortcuts

| Key | Action |
|---|---|
| `⌘K` / `Ctrl+K` | Command palette |
| `G` then `S` | Setups |
| `G` then `P` | Performance |
| `G` then `F` | Signals (feed) |
| `G` then `R` | RSI scan |
| `G` then `W` | Week review |
| `G` then `E` | EZPZ deep |
| `G` then `C` | Correlation matrix |
| `G` then `J` | Journal |
| `G` then `B` | Playbook |
| `N` | New journal entry |
| `S` | Position sizer |
| `T` | Toggle theme (terminal / midnight) |
| `D` | Cycle density (compact / comfortable / spacious) |
| `B` | Toggle sidebar (full / icons-only) |
| `?` | Show this shortcut list |
| `Esc` | Close the current palette, modal, or drawer |

The `G`-prefix chord is vim-style — press `G` then the letter within 1 second.

Shortcuts don't fire while you're typing in an input.

## Drawer

Click any ticker anywhere in the app — the kanban cards, the all-trades table, the signals feed, the RSI scan, the mini-watchlist — and a 380px drawer slides in from the right containing:

- A lightweight **TradingView embed** (60m chart) for that symbol.
- The **latest setup card** (entry / stop / target / current / P&L).
- The **EZPZ breakdown** (if the ticker has been analyzed).
- The **RSI scan result** (if scanned).
- Action buttons: `✎ Journal entry` · `Open in TradingView ↗` · `⎘ Copy trade plan`.

## Position sizer

Floating **$** button bottom-right, or press `S`.

Inputs: account size, risk %, entry, stop.
Outputs: shares, notional, dollar risk, risk-per-share, +1R / +2R / +3R price levels.
Your last inputs persist.

## Trade journal

Press `N` or go to the Journal tab and hit **+ New Entry**.

Each entry stores ticker, date, realized P&L (optional), free-text notes, comma-separated setup tags, and clickable emotion tags (`confident` · `patient` · `fomo` · `revenge` · `anxious` · `disciplined`).

All entries live in `localStorage` under key `oliver_journal`. Export to markdown any time (Journal tab → **Export Markdown**), which writes a file you can drop in `C:\Users\Oliver\tradingview-mcp-jackson\trades\` alongside your daily tracker files.

## Export

- **Trades CSV** — Performance tab → `Export CSV` (or palette → `export csv`).
- **Journal markdown** — Journal tab → `Export Markdown`.
- **Dashboard PDF** — `Cmd/Ctrl+P` or palette → `print dashboard`. The print stylesheet hides the shell and paginates tabs.

## Theme & density

- **Theme** (T): `terminal` (default deep navy + electric blue) or `midnight` (warmer near-black + indigo).
- **Density** (D): `compact` / `comfortable` / `spacious` — affects padding and font sizes globally.

Both preferences persist across sessions.

## Auto-deploy flows still work

The `run ezpz $TICKER`, `run ezpz watchlist`, and `run tv rsi scan` commands documented in your `CLAUDE.md` continue to work unchanged — the sentinel-comment data blocks (`EZPZ_INDIVIDUAL`, `EZPZ_WATCHLIST`, `RSI_SCAN_DATA`, `ALL_DAYS_DATA`) are preserved verbatim and at the same locations. No pipeline changes required.

## Correlation matrix

`G` then `C` (or sidebar → **Correlation**). 30-day rolling Pearson correlation across the watchlist, computed from daily returns. Colour ramp red ↔ green, diagonal muted. The first render fetches OHLCV via the worker; subsequent loads hit a 24h localStorage cache (`oliver_corr_ohlcv`) and the **Refresh** button forces a re-fetch.

## Kanban stage dropdown

Each setup card on the **Setups** board now has a small per-card stage dropdown (`AUTO / WATCHING / ALERTED / ENTERED / MANAGING / CLOSED`). Selecting a stage moves the card to that column immediately; picking `AUTO` clears the override and lets the underlying data decide again. Overrides are non-destructive and stored under `oliver_stage_overrides` — the source tracker files are never mutated.

## Live feed

Live prices are wired via a Cloudflare Worker proxy at `https://finance-proxy.olivertruelove123.workers.dev`. The breadth bar, right drawer, and mini-watchlist pull real Yahoo quotes through this endpoint; if the worker is unreachable the UI falls back gracefully to the static data values and a small `stale` indicator appears next to the feed.

- Worker source: `worker/worker.js`
- Endpoints: `/quote?symbols=SPY,QQQ,IWM,BTC-USD,DX-Y.NYB` · `/chart?symbol=SPY&range=3mo&interval=1d`
- Deploy guide: `worker/README.md`

Refresh cadence is controlled by `LIVE_REFRESH_MS` in `index.html`.
