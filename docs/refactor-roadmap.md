# Refactor Roadmap

This document describes how to move the current codebase toward the target architecture incrementally.

It exists so future iterations can improve the structure while still shipping features.

## Current Snapshot

### Already aligned with the target direction

- steps/activity detail screen
- activities detail screen
- sleep detail screen
- heart detail screen

These features already use:

- selected range
- selected anchor date
- previous/next period navigation
- calendar selection
- feature-specific content over a shared interaction model

### Resolved

- body feature — uses `PeriodNavigator`, `selectedDate`, `previousPeriod`/`nextPeriod`/`selectDate`, aligned with the other detail screens
- duplicated period helper types and navigator composables — `DatePeriod`, `periodFor`, `periodTitle`, `periodSubtitle`, and `PeriodNavigator` are centralized in `ui/components/PeriodNavigator.kt`
- browse feature — now uses `selectedDate`, `PeriodNavigator`, and `HealthDatePickerDialog`, consistent with all other metric screens
- centralized repository growth — `HealthRepository` is now permissions + dashboard only; feature data is in `ActivityRepository`, `SleepRepository`, `HeartRepository`, `BodyRepository`

## Recommended Refactor Order

### Phase 1: Shared period foundation

Extract the concepts already repeated across features:

- `DatePeriod`
- one shared `periodFor(...)`
- one shared title/subtitle formatter
- one shared period navigator composable

Expected outcome:

- `ActivityScreen`, `SleepScreen`, `HeartScreen`, and `ActivitiesScreen` stop carrying their own copies of period shell code

### Phase 2: Shared detail screen scaffold

Extract a reusable scaffold for period-based metric screens.

Responsibilities:

- refresh shell
- time range selector
- shared period navigator
- date picker visibility and handling
- error block
- content slot

Expected outcome:

- new metrics can be implemented by focusing mainly on their cards/charts instead of rebuilding the shell

### Phase 3: Data layer cleanup

Refactor `HealthRepository` away from overload growth.

Target direction:

- feature-oriented repositories or query services
- shared period query objects
- consistent day/period loading model

Expected outcome:

- fewer ad hoc APIs
- less screen-specific repository creep

### Phase 4: Legacy feature migration

Migrate:

1. body
2. browse or replace browse with feature-owned raw record screens

Expected outcome:

- one consistent UX model across all metric detail screens

### Phase 5: Dashboard and metric registration cleanup

Introduce a metric registry/spec pattern if dashboard surface area keeps growing.

Use this only when adding metrics becomes repetitive enough to justify it.

Possible responsibilities:

- metric id
- route
- dashboard title
- icon
- accent color
- card click destination

## What Not To Refactor Yet

Avoid these until the previous phases are stable:

- full DI framework migration
- full multi-module split
- Room caching architecture
- universal chart abstraction
- full MVI reducer system

These may become useful later, but they are not the highest-value moves right now.

## Success Criteria

The architecture is in a good place when:

- a new metric feature can be added without copying period logic
- a new detail screen only needs feature-specific charts/cards
- repository APIs feel query-oriented instead of screen-oriented
- body and browse no longer stand apart from the newer feature model

## Ongoing Rule

During normal feature delivery:

- if duplication touches two or more aligned detail features, extract shared scaffolding
- if duplication is only inside one metric's actual visualization, keep it local
