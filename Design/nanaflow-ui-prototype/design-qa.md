# NanaFlow simplified design QA

## Comparison target

- Source visual truth: `/var/folders/hy/vsz0d0_d7fz66ywpbwgwfbwh0000gn/T/codex-clipboard-d3d4176c-9391-4ca3-b5bb-26af7eca101d.png`.
- Source state: legacy Flow weekly statistics, D/W/M/Y control, week navigation, seven pale tracks and teal bars.
- Source pixels: 1102 × 824; normalized reference: `qa/simplified/reference-statistics-380.png`, 380 × 284.
- Implementation: `http://127.0.0.1:4173/`, same-window weekly statistics state.
- Browser-rendered evidence: `qa/simplified/08-week-final-full.png`, 1280 × 720.
- Implementation window: 380 × 272 CSS pixels at 1× capture density; cropped to `qa/simplified/08-week-final.png` and padded by 6 px vertically for the comparison canvas.
- Full comparison: `qa/simplified/statistics-comparison-bars.png`, 760 × 284.
- Menu-bar and 31-day month evidence: `qa/simplified/07-month-menu-final.png`.

The source is a larger historical Flow window. The implementation intentionally preserves NanaFlow's requested 380 × 272 main-window size, so comparison is based on hierarchy, proportions, controls, palette and chart anatomy rather than identical source dimensions.

## Findings

- No actionable P0, P1 or P2 findings remain.
- The D/W/M/Y segmented control, navigation row, period total, full-height tracks, teal fills and contextual labels preserve the source hierarchy in the compact window.
- Column counts now follow the selected period: 24 hours for day, 7 days for week, the actual 28/29/30/31 days for month, and 12 months for year.
- Statistics replaces the timer content inside the same window and returns through the back button; no large or secondary statistics window is created.
- The menu-bar item presents only the countdown text. The NanaFlow half-circle mark and all other brand graphics were removed. Its popover uses a native macOS hierarchy and contains no mini timer, blocker, insights, tags or history entry.

## Required fidelity surfaces

- Fonts and typography: macOS system families, compact 14 px statistics header, tabular timer numerals and restrained weights match the reference language; Chinese copy is deliberately localized.
- Spacing and layout rhythm: 380 × 272 frame, 49 px top control row and 42 px period row remain fixed; chart columns adapt from 7 wide weekly bars to 31 narrow monthly bars without clipping or horizontal scrolling.
- Colors and tokens: off-white surface, charcoal text, low-contrast mint tracks and deep teal fills follow the source palette. Focus indicators remain available for keyboard use but are not shown in the static comparison state.
- Image quality and assets: the reference contains no raster content that needs recreation. Phosphor supplies all interface icons; the chart is live data UI, not a substituted image asset.
- Copy and content: only timer, statistics, settings and menu-bar language remains. Blocker, insights, tags and separate history copy are absent.

## Interaction and accessibility checks

- Start, one-second countdown, pause and retained time: passed.
- Focus-to-break transition and menu heading changing to `休息 · 05:00`: passed.
- Statistics D/W/M/Y selection and counts: passed at 24 / 7 / 31 / 12 columns for the current ranges.
- Month navigation: August and July render 31 columns; June renders 30 columns.
- Previous/next period navigation and disabled current-period next button: passed.
- Main-window statistics back navigation: passed.
- Menu-bar start/pause, show/hide, statistics, skip, restart, timer settings, settings, about and quit entries: present and actionable.
- Menu-bar countdown visibility toggle: passed.
- Native buttons expose accessible names; chart has a textual accessible label; keyboard focus and reduced-motion styles are present.
- Clean browser tab errors and warnings: none.

## Comparison history

1. Earlier P1: statistics used a separate 800 × 450 Insights window with overview/history tabs, tag summaries and filtering. Fixed by deleting the blocker, insights, tags, history and large-window routes, then implementing a compact same-window statistics screen.
2. Earlier P1: every range reused seven bars. Fixed by generating 24 hourly, 7 daily, actual calendar-day monthly, and 12 monthly yearly columns. Post-fix evidence: `qa/simplified/07-month-menu-final.png` and browser count checks.
3. Earlier P2: the menu-bar item included a half-circle brand mark. Fixed by removing the mark and the now-invalid countdown visibility toggle; the menu bar always has a visible text target.
4. Earlier P2: the comparison capture showed the keyboard focus ring on the selected W tab. Fixed by reloading into the default weekly state and recapturing without an active focus target. Post-fix evidence: `qa/simplified/statistics-comparison-bars.png`.
5. A fresh browser tab verified the final build with zero current errors or warnings.

## Verification

- `npm run build`: passed.
- `npm run test:sites`: 4 passed, 0 failed.

final result: passed
