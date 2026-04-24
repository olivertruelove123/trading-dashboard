# Changelog

## Overhaul v2 — Post-initial polish (2026-04-24)

Phases A–D shipped on branch `overhaul-v2` after the initial redesign. Everything in this section resolves the "Known limitations" list from the original overhaul.

### Live data — Cloudflare Worker proxy (Phase A, worker scaffold)

- New `worker/` directory with `worker.js`, `wrangler.toml`, and `README.md`. The worker is a minimal Yahoo Finance proxy exposing `/quote` and `/chart` endpoints with CORS headers.
- Deployed at `https://finance-proxy.olivertruelove123.workers.dev`; `WORKER_URL` constant wired in `index.html`.
- Breadth bar, right drawer current-price labels, and mini-watchlist now consume real quotes via `refreshLiveQuotes()` on `LIVE_REFRESH_MS` cadence.
- Graceful fallback to static data + `stale` pill in the breadth bar if the worker is unreachable — no hard dependency.
- Resolves **Known limitation 1** ("Live price feed — disabled").

### Correlation matrix (Phase B)

- New **Correlation** tab (`G → C`, keyboard navigable; also wired into the command palette).
- 30-day rolling Pearson correlation computed from daily returns across the full watchlist.
- OHLCV fetched via the worker's `/chart` endpoint, cached in `localStorage` under `oliver_corr_ohlcv` with a 24h TTL. Stale-while-revalidate on load; explicit **Refresh** button forces a re-fetch.
- Heatmap uses red ↔ green colour ramp with muted diagonal; scroll-contained for mobile.
- Resolves **Known limitation 3** ("Correlation matrix — not shipped").

### Kanban click-to-move stage dropdown (Phase C1)

- Each setup card on the **Setups** board carries a per-card `<select>` with options `AUTO / WATCHING / ALERTED / ENTERED / MANAGING / CLOSED`.
- Overrides persist in `oliver_stage_overrides`. Choosing `AUTO` clears the override and reverts to data-derived status.
- Non-destructive: the underlying `ALL_DAYS_DATA` tracker entries are never mutated, so `update tracker` auto-deploy keeps working unchanged.
- Resolves **Known limitation 2** ("Drag-and-drop kanban — not implemented") via the agreed click-to-move fallback, which is robust on mobile where HTML5 DnD is flaky.

### Print stylesheet polish (Phase C2)

- `@page` A4 with 14/14/16/14 mm margins; footer shows document title on the left and `Page N / M` on the right via `counter(page)` + `counter(pages)`.
- `-webkit-print-color-adjust:exact` and `print-color-adjust:exact` preserve semantic colours (long green, short red, warn amber) on paper.
- Kanban prints as a 2-column layout; tables repeat `<thead>` across pages; the correlation heatmap is preserved with a lightened palette; playbook is force-expanded so nothing is clipped by collapsed sections.
- Every panel gets its own page via `page-break-before:always` (first panel exempted).
- Interactive chrome (breadth bar, cmdbar, sidebar, drawer, FAB, toasts, palette, modals, stage dropdowns, feed/stale dots, tab action buttons) is hidden on paper.

### Phase D — final polish (2026-04-24)

- **Shortcuts audit.** Every keyboard shortcut in `QUICKSTART.md` verified against the `keydown()` handler. `G → F` (Signals feed) was missing from the in-app help modal despite being wired and documented — added.
- **Mobile 375 px pass.** Verified: breadth bar horizontal scroll, sidebar → bottom-nav transition at ≤900 px, kanban single-column at ≤640 px, `.cmd-clock` / `.cmd-search .txt` hidden at ≤520 px, drawer full-screen overlay at `min(400px, 100%)`, correlation matrix scroll-contained, FAB repositioned above bottom-nav. No additional CSS changes required.
- **Docs.** `QUICKSTART.md` updated with the `G → C` shortcut, a Correlation matrix section, a Kanban stage dropdown section, and a rewritten Live Feed section reflecting the worker proxy. The "Known limitations" block in this file remains historically correct — see resolutions in the phase sections above.

### LocalStorage keys (consolidated)

Added this session:
- `oliver_corr_ohlcv` — correlation matrix OHLCV cache (24h TTL).
- `oliver_stage_overrides` — kanban manual stage placements, non-destructive.

Pre-existing (unchanged): `oliver_day`, `oliver_nav`, `oliver_theme`, `oliver_density`, `oliver_sidebar_collapsed`, `oliver_sizer`, `oliver_journal`.

### Sentinel comments (unchanged)

`EZPZ_INDIVIDUAL`, `EZPZ_WATCHLIST`, `RSI_SCAN_DATA`, `ALL_DAYS_DATA` blocks preserved verbatim. All `run ezpz`, `run tv rsi scan`, and `update tracker` auto-deploy pipelines continue to work.

---

## Overhaul v2 — 2026-04-23 (branch `overhaul-v2`)

Institutional terminal redesign. Fully rewritten shell, tokenized design system, all tabs rebuilt, plus several new features.

### Design system

- Design tokens (CSS custom properties) in a single `:root` block at the top of `<style>`:
  - **Palette:** deep navy base (`#0A1628`), elevated surfaces `#0F1E35 → #162A44 → #1E3555`, subtle/emphasis borders, soft-white text, electric blue accent, signal green/red/amber, conviction gold.
  - **Typography:** Inter (UI), Space Grotesk (display headlines), JetBrains Mono (prices, tickers, P&L), all via Google Fonts with `display=swap`.
  - **Spacing:** 4px base unit, scale `4/8/12/16/24/32/48/64`.
  - **Elevation:** three layered navy shadows (not black) + accent/long/short glows.
  - **Motion:** all transitions 200ms with `cubic-bezier(0.4, 0, 0.2, 1)`.
  - **Radii:** 4/6/8/12/16 px, plus `--r-full`.
- **Two themes** via `data-theme`:
  - `terminal` (default) — deep navy with electric blue accent.
  - `midnight` — warmer near-black for late-night sessions.
- **Three densities** via `data-density`: `compact` / `comfortable` (default) / `spacious`. Adjusts spacing and font sizes globally.

### Shell architecture

- **Top breadth bar (28px):** SPY · QQQ · IWM · BTC · DXY with live-ish prices + change %. *Uses a mock feed — see "Known limitations" below.*
- **Command bar (56px):** Logo + Cmd/Ctrl+K search + live clock + NY/LN/TK session pills + theme/density/sidebar toggles.
- **Sidebar (240px, collapsible to 64px icon-only):** Tabs with counts + persistent mini-watchlist showing top 5 movers.
- **Workspace:** CSS-grid content area with scoped header (title, subtitle, per-tab action buttons).
- **Right drawer (380px):** Opens on any ticker click. Contains a live TradingView embed, latest setup card, EZPZ signal breakdown, RSI scan result, journal + copy-trade buttons.
- **Floating action button:** Opens Position Sizer.

### Tabs (all rebuilt)

| Tab | What it does |
|---|---|
| Setups | Kanban columns `Watching → Alerted → Entered → Managing → Closed`. Each card shows ticker, direction, entry/stop/target, live price + change, status pill, progress bar toward target, R:R, and a conviction radial ring. |
| Performance | Equity curve (SVG area) · P&L calendar heatmap · Win-rate donut · R-multiple histogram · Source attribution · Expectancy panel · Best/Worst cards · Full trades table with CSV export. |
| Signals | Feed with source-colored left border, filter chips (All/Buy/Sell). |
| RSI Scan | Sortable table with per-row synthesized RSI sparkline. Click a row to open the ticker drawer. |
| Week Review | Magazine layout — hero P&L stat, day-by-day cards, highlights column (top performer + attention + patterns). |
| EZPZ Deep | Expanded ticker cards with 17-signal radar chart + thesis + scored signal table. |
| Journal *(new)* | localStorage-backed trade journal with setup tags, emotion tags, realized P&L, markdown export. |
| Playbook | Content preserved verbatim, restyled. Expand/collapse all controls. |

### New features

- **Command palette (Cmd+K / Ctrl+K).** Fuzzy search over every ticker, every tab, and 10+ actions. Arrow-key navigation, Enter to run, Esc to close.
- **Position sizer.** Account size × risk % × entry × stop → shares, dollar risk, notional, 1R/2R/3R targets. Persists inputs.
- **Trade journal modal.** Ticker, date, optional P&L, notes, comma-separated setup tags, click-chip emotion tags. Exports to markdown.
- **Keyboard shortcuts** (full list in `QUICKSTART.md`).
- **Toast notifications** for actions (bottom-right, auto-dismiss, colored borders).
- **Theme & density toggles** (persisted).
- **Print stylesheet** — shell hides, tabs stack, each becomes a page. Use `Cmd/Ctrl+P` to save as PDF.

### Polish

- Full responsive layout. On `< 900px` the sidebar collapses to a bottom nav bar and the drawer becomes a fixed overlay.
- Accessibility: ARIA roles on overlays, focus-visible rings in accent blue, keyboard navigation on all interactive elements, tabular-numerals on every number.
- Favicon (inline SVG) + OG tags.
- All async sections render progressively; no jarring full-page reloads between tabs.

### Data preservation (critical — do not edit these rules)

The auto-deploy pipeline documented in `CLAUDE.md` (`run ezpz`, `run tv rsi scan`, `update tracker`) performs string replacement against sentinel comments inside this file. These are untouched:

- `/* EZPZ_INDIVIDUAL_START */` / `/* EZPZ_INDIVIDUAL_END */` around `const EZPZ_INDIVIDUAL = [...]`
- `/* EZPZ_WATCHLIST_START */` / `/* EZPZ_WATCHLIST_END */` around `const EZPZ_WATCHLIST = [...]`
- `/* RSI_SCAN_START */` / `/* RSI_SCAN_END */` around `const RSI_SCAN_DATA = {...}`
- `/* ALLDAYS_START */` / `/* ALLDAYS_END */` around `const ALL_DAYS_DATA = {...}`

Data shapes unchanged. Constant names unchanged. `localStorage` keys `oliver_day` and `oliver_nav` preserved. New keys namespaced: `oliver_theme`, `oliver_density`, `oliver_sidebar_collapsed`, `oliver_sizer`, `oliver_journal`.

### Known limitations (needs your input)

1. **Live price feed — disabled.** The breadth bar and drawer's "current price" labels use static data from the data blocks plus a gentle sinusoidal jitter on the breadth bar. Yahoo Finance's `query1.finance.yahoo.com/v7/finance/quote` endpoint blocks browser origins (CORS). To go live: wire a CORS proxy URL (Cloudflare Worker, Netlify Function, etc.) or an API key (Polygon, Alpha Vantage) and call it from `renderBreadth()`.
2. **Drag-and-drop kanban — not implemented.** Ticker stage is derived from `t.status` in the data. If you want to move cards manually, say the word and I'll add a per-card menu (click-to-move) — full HTML5 DnD is fragile on mobile.
3. **Correlation matrix — not shipped.** It needs 30 days of OHLCV per watchlist ticker. No historical feed is wired yet. Once the live-feed plumbing exists, it's a ~40-line addition.
4. **PDF export** uses `window.print()` + print stylesheet rather than a bundled jsPDF library — keeps the file light. Works for the dashboard snapshot use case; if you want programmatic per-trade PDF reports, we'd add jsPDF (~40KB).
5. **Alert inbox & scheduled cleanup offers — not shipped.** Out of scope for v2. Say the word if you want them.

### How to preview

The branch is pushed. To see it on GitHub Pages:

- **Option A (recommended for preview):** in GitHub repo settings → Pages, temporarily set the source branch to `overhaul-v2`. Merge to `main` once approved and switch back.
- **Option B:** `git checkout overhaul-v2` locally and open `index.html` directly in a browser.

### Rollback

The v1 dashboard is still on the `main` branch. To revert: `git checkout main`.
