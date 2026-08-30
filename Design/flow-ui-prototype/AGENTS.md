# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

Build app UI in `src/`. Keep `.openai/hosting.json`, `worker/index.js`, `scripts/prepare-sites-build.mjs`, and `tests/sites-worker.test.mjs` intact so the same local prototype can be handed to Sites. Before a Sites handoff, run `npm run build` and `npm run test:sites`; the build must leave `dist/client/index.html`, `dist/server/index.js`, and `dist/.openai/hosting.json`.

## Product direction

- Treat the live `/Applications/Flow.app` 4.8 macOS UI as the visual source of truth.
- Preserve Flow's 380×272 timer proportions, native macOS restraint, typography hierarchy, pale surface, teal accent, rounded corners, and compact controls.
- Use the user-provided legacy Flow statistics screenshot as the statistics source of truth: D/W/M/Y segmented control, period navigation, pale full-height tracks, teal bars, and one concise total.
- Keep timer and statistics inside the same 380×272 main window; the toolbar chart button switches the window content and a back button returns to the timer.
- Remove blocker, insights, tags, mini timer, separate history, and separate statistics windows.
- Treat the macOS menu-bar item as a first-class surface: show the countdown text only, with no NanaFlow half-circle mark, and provide timer, statistics, settings, restart/skip, and quit commands in its popover.
- Statistics must use the real number of columns for each range: 24 hourly columns for day, 7 daily columns for week, the actual 28/29/30/31 days for month, and 12 monthly columns for year.
