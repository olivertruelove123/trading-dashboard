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

## Live feed

The breadth bar currently uses a mock feed (static values with a sine-wave shimmer) because Yahoo Finance's quote endpoint is CORS-blocked for browser origins. To wire real prices:

1. Deploy a tiny CORS proxy (Cloudflare Worker: 15 lines; or Netlify / Vercel function).
2. Edit `renderBreadth()` in `index.html` and replace the mock calc with `fetch('<your-proxy>?symbols=SPY,QQQ,IWM,BTC-USD,DX-Y.NYB')`.
3. Yahoo's response shape is `{quoteResponse:{result:[{symbol,regularMarketPrice,regularMarketChangePercent}]}}`.

Ping me when you want it wired up.
