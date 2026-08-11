# Accessibility

Engineering checklist for keeping OpenVitals usable with TalkBack, large fonts,
high contrast, and reduced motion. This is the app-side companion to the design
system floors described in [design-system.md](design-system.md).

There is no single Android “accessibility certificate.” The bar this app aims
for is WCAG 2.2 AA–aligned mobile behavior, an honest Google Play accessibility
declaration, and CI/instrumentation gates so regressions do not ship quietly.

## Already enforced

| Concern | Gate |
|---|---|
| Metric accent contrast (WCAG 1.4.11, 3:1) | `MetricAccentContrastTest` |
| Shared chart screen-reader summaries | `chartSemanticSummary` / `chartSemantics` on period, line, and heatmap charts |
| Dashboard TalkBack names | `DashboardSemanticsTest` |
| Font scale 2.0 on core screens | `TextScalingSweepTest` |
| Reduced motion | `LocalReducedMotion`, `animationDuration()`, `loopingMotionAllowed()` |
| Outdoor glare during recording | High-contrast outdoor recording theme |

## Manual regression (before release)

Run on a physical device. Record failures in the release PR or changelog notes.

1. **TalkBack** — Dashboard → Steps / Sleep / Heart → Manual entry → Activity
   recording → Settings → Device sync. Confirm no unlabeled icon buttons, silent
   charts, or stranded multi-step flows.
2. **Accessibility Scanner** — same screens; export and triage contrast / touch
   target / unlabeled node findings.
3. **Display size + font 200%** — core journeys still show titles and primary
   actions without horizontal clipping of critical controls.
4. **Remove animations** — recording edit wiggle and mindfulness pulse freeze;
   one-shot reveals jump to end state.

## Implementation rules

For every new or changed screen:

- Interactive controls need an accessible name (`contentDescription`, visible
  text, or `onClickLabel`). Decorative icons next to a text label stay
  `contentDescription = null`.
- Icon-only buttons must never use `null`.
- New charts and map surfaces publish a one-line summary via
  `chartSemantics(chartSemanticSummary(...))` or an equivalent
  `contentDescription`.
- Prefer merged semantics on metric tiles so TalkBack announces
  “Steps, 6,432” as one node when that reads better than fragmented children.
- Live values that change without focus (recording elapsed time, sync progress,
  mindfulness countdown) use a polite `liveRegion` and throttle announcements.
- Touch targets are at least **48×48 dp** (`OpenVitalsIconButton` default).
  Shrink the glyph, not the hit box.
- Swipe-to-delete always exposes a `CustomAccessibilityAction` for delete
  (`SwipeToDeleteEntryRow`).
- Looping / decorative motion gates on `loopingMotionAllowed()`; non-press
  tweens use `animationDuration()`.
- Do not convey meaning by color alone — keep labels, patterns, or text beside
  stage / zone / readiness colors.
- Accessibility strings go in `values/strings.xml` only. Never edit
  `values-*/strings.xml` by hand.

Add these checks to the feature playbook when shipping a metric screen.

## Code audit baseline (2026-08-10)

Findings closed in the accessibility wave:

- Shared sparkline, route preview, map surface, sleep stage / schedule, caffeine
  bars, and body-energy timeline summaries for TalkBack.
- `SwipeToDeleteEntryRow` delete custom action for gesture-only rows.
- `OpenVitalsIconButton` default target raised to 48 dp; undersized overrides
  removed on dashboard / heart / CoMaps controls.
- Polite live regions on recording duration tiles and the mindfulness timer.
- Device sync range radios selectable as a labeled group; progress indicator
  announces phase and counts.
- Instrumentation: period navigator semantics; text-scale sweep extended to
  caffeine / nutrition / body energy / device sync surfaces.

Still prefer a device TalkBack + Scanner pass before claiming Play Console
answers — code review cannot replace that.

## Google Play accessibility declaration

Use this section when filling **Play Console → App content → Accessibility**.
Answer only what the app actually supports after the manual regression above.

| Declaration topic | Honest answer (when gates are green) |
|---|---|
| Screen reader / TalkBack | Supported for primary journeys; charts expose text summaries; icon-only chrome is labeled |
| Display size / font scale | Supported; `TextScalingSweepTest` covers high-traffic screens at 2.0 |
| Contrast | Metric accents meet 3:1 against light and dark surfaces; outdoor recording high-contrast mode available |
| Touch targets | Shared icon buttons target ≥48 dp; Scanner may still flag dense feature chrome — triage before claiming “fully compliant” everywhere |
| Captions / audio | N/A — app has no media playback requiring captions |

Do not claim support for a journey that still fails TalkBack or Scanner until it
is fixed. Prefer “partial / improving” over an inaccurate full claim.

## Related docs

- [Design system](design-system.md) — contrast floors, reduced motion contract
- [Feature playbook](feature-playbook.md) — per-feature a11y checklist
- [Development](development.md) — verification tasks
