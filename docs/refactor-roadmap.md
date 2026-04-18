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
- shared period scaffold — `MetricDetailScaffold` composable in `ui/components/` handles refresh shell, time range selector, period navigator, date picker, and error block; all six feature screens (`ActivityScreen`, `ActivitiesScreen`, `SleepScreen`, `HeartScreen`, `BodyScreen`, `BrowseScreen`) use it

## Recommended Refactor Order

### Phase 1: Shared period foundation ✓ Done

Extracted `DatePeriod`, `periodFor`, `periodTitle`, `periodSubtitle`, and `PeriodNavigator` to `ui/components/PeriodNavigator.kt`.

### Phase 2: Shared detail screen scaffold ✓ Done

Extracted `MetricDetailScaffold` to `ui/components/MetricDetailScaffold.kt`.

Responsibilities handled:

- refresh shell (`PullToRefreshBox`)
- time range selector
- shared period navigator + date picker
- error block
- `headerItems` slot (used by Browse for category chips)
- `content: LazyListScope.(DatePeriod) -> Unit` slot for feature-specific content

All six feature screens now delegate the shell entirely to the scaffold.

### Phase 3: Data layer cleanup ✓ Done

`HealthRepository` trimmed to permissions + dashboard only. Feature data split into `ActivityRepository`, `SleepRepository`, `HeartRepository`, `BodyRepository`. Each ViewModel takes only its own repository.

### Phase 4: Legacy feature migration ✓ Done

Body and Browse migrated to the same UX model as all other screens (period navigation, `MetricDetailScaffold`, feature-specific repository). All metric detail screens now follow one consistent model.

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
