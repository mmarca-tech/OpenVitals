# OpenVitals App — UI Kit

An interactive, click-through recreation of the OpenVitals Android app, composed
entirely from the design system's component primitives (`window.OpenVitalsDesignSystem_626946`).
Rendered in the canonical **blue/teal** static scheme (the deterministic brand
default). The app also ships a warm Material You instance — set `data-theme="warm"`
on the phone frame to preview the wallpaper-tinted look from the reference screenshots.

## Screens
- **DashboardScreen** — home: summary rings (Steps, Weekly cardio), Log/Start quick
  actions, metric stat grid, Activities preview. Tap tiles to drill in.
- **DailyReadinessScreen** — recovery hero banner with score, Body Energy / Training
  Readiness sub-tiles, HRV / intensity / stress insights, and recommendations.
- **SettingsScreen** — grouped settings list rows + Support section.
- **BeverageScreen** — hydration logging; tap the "water" saved drink to add 0.35 L.
- **ActivityDetailScreen** — recorded walk: header, Metrics list, Heart-rate card.
- **RecordingScreen** — live activity recording (Stats tab) with outdoor accent.
- **BodyEnergyScreen** — Body Energy detail with a `MetricLineChart` timeline and a `DataConfidenceCard`.
- **DisplaySettingsScreen** — Settings › Display sub-screen built from the form controls (Select, RadioGroup, Switch).
- **AchievementsScreen** — badge progress list with filter chips and `AchievementBadge` cards.
- **DeviceSyncScreen** — "Sync with another phone" over Bluetooth: a state-driven wizard
  (role choice → make discoverable / find a phone + code entry → time range → data-type
  checklist → transfer progress → import-style report). Reached from Settings ›
  "Sync with another phone". Type `999999` at the code step to preview the wrong-code error.

A persistent Material 3 `BottomNavBar` (Summary / Activity / Sleep / Body) sits under
every screen except live recording.

## Flow
Start on the dashboard. Settings icon → Settings. Log / Beverages → Beverage entry.
Start → Recording → Finish → Activity detail. Sleep tile / Recovery → Daily Readiness.
Every back chevron returns to the dashboard.

## Notes
- `index.html` mounts React + the DS bundle, then each `Screen.jsx` (each registers
  itself on `window`), then a small router.
- Components are the real DS primitives — this kit does not re-implement them.
