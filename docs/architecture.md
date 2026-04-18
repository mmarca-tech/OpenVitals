# Architecture

## Intent

This document defines the target architecture for the Health Connect Dashboard app.

It is intentionally practical:

- keep the app simple enough for a single-module Android project
- make metric features easy to add
- reduce repetition across detail screens
- avoid premature abstractions that make charts harder to understand

## Architectural Principles

### 1. Feature-first organization

The app should stay organized by feature, not by widget type.

Use:

- `features/dashboard`
- `features/activity`
- `features/sleep`
- `features/heart`
- `features/body`
- `features/<new-metric>`

Each feature owns its own screen, state, ViewModel, and metric-specific UI.

### 2. Shared shells, feature-specific visuals

The repeated shell around metric detail screens should be reusable.

The actual metric cards and charts should remain feature-owned.

Reusable:

- pull-to-refresh shell
- time range selector
- period navigator
- date picker handling
- period math and period formatting
- generic empty/error/loading blocks

Feature-owned:

- steps charts
- sleep session timeline and sleep stages
- heart timeline and range chart
- metric-specific rows and summaries

### 3. Period-driven detail screens

All metric detail screens should follow the same interaction model:

- `Day / Week / Month / Year`
- selected anchor date
- previous/next period navigation
- calendar date selection
- navigation blocked beyond the current period

This is the canonical pattern for new metric detail screens.

### 4. Thin screen composables

Screens should mostly:

- collect state
- wire callbacks
- compose sections

Screens should not:

- implement loading orchestration
- duplicate period math
- contain large formatting policy blocks

### 5. Feature ViewModels own screen state

Each screen should have one ViewModel responsible for:

- selected range/date state
- loading and refresh
- combining repository results
- exposing UI-ready state

### 6. Query-oriented data access

Health Connect is the source of truth.

The data layer should expose feature-oriented queries instead of screen-specific overload growth.

Target direction:

- `DatePeriod`
- `MetricQuery`
- feature repositories or query services

Avoid endless API growth like:

- `loadX(range)`
- `loadX(date)`
- `loadX(start, end)`
- `loadXForChart(...)`
- `loadXForSummary(...)`

unless those are temporary migration steps.

## Target Layers

Within the current single app module, aim for these logical layers:

### App layer

Responsible for:

- app startup
- manual DI or future DI migration
- navigation graph
- screen registration

Relevant files today:

- [../app/src/main/kotlin/dev/manu/hcdashboard/HCDashboardApp.kt](../app/src/main/kotlin/dev/manu/hcdashboard/HCDashboardApp.kt)
- [../app/src/main/kotlin/dev/manu/hcdashboard/MainActivity.kt](../app/src/main/kotlin/dev/manu/hcdashboard/MainActivity.kt)
- [../app/src/main/kotlin/dev/manu/hcdashboard/navigation/AppNavigation.kt](../app/src/main/kotlin/dev/manu/hcdashboard/navigation/AppNavigation.kt)

### Data layer

Responsible for:

- Health Connect reads
- permission-aware reads
- mapping raw records to domain models

Relevant files today:

- [../app/src/main/kotlin/dev/manu/hcdashboard/healthconnect/HealthConnectManager.kt](../app/src/main/kotlin/dev/manu/hcdashboard/healthconnect/HealthConnectManager.kt)
- [../app/src/main/kotlin/dev/manu/hcdashboard/data/repository/HealthRepository.kt](../app/src/main/kotlin/dev/manu/hcdashboard/data/repository/HealthRepository.kt)

Target split over time:

- raw Health Connect access stays in `healthconnect`
- feature-facing repositories/query services move toward per-feature boundaries

### Shared UI / core presentation layer

Responsible for:

- period selection model
- period formatting
- reusable navigator
- reusable detail screen scaffold
- formatting utilities that are not metric-specific

Current partial location:

- [../app/src/main/kotlin/dev/manu/hcdashboard/ui/components](../app/src/main/kotlin/dev/manu/hcdashboard/ui/components)

Target additions over time:

- `core/period`
- `core/presentation`

### Feature layer

Responsible for:

- feature contract
- ViewModel
- feature-specific cards
- feature-specific rows
- feature-specific visual logic

## Canonical Detail Screen Pattern

New detail features should follow this shape:

### Contract

Each feature should expose a clear screen contract:

- `UiState`
- screen actions
- optional derived display fields

### Period selection

Use a shared period model:

```kotlin
data class DatePeriod(
    val start: LocalDate,
    val end: LocalDate,
)
```

And shared helpers:

- `periodFor(range, anchorDate)`
- `periodTitle(range, period)`
- `periodSubtitle(range, period)`
- `canGoForward(range, anchorDate)`

### Screen scaffold

The screen shell should eventually be standardized around:

- `PullToRefreshBox`
- `TimeRangeSelector`
- shared period navigator
- date picker dialog
- error block
- content slot

### Content slots

The feature provides:

- `Day` content
- `Week / Month / Year` content
- optional list/breakdown section

## Recommended Shared Building Blocks

These are the abstractions worth building.

### Worth extracting

- `DatePeriod`
- period calculator
- period title/subtitle formatter
- shared period navigator
- shared detail screen scaffold
- shared metric bar card primitive
- shared intraday line card primitive if it stays simple

### Not worth over-abstracting

- sleep stages bar
- heart rate min/max/avg chart
- workout list rows
- steps plus calories plus distance combined feature cards

These remain easier to reason about when they stay local to the feature.

## State Management Pattern

Use a lightweight screen-state pattern.

Recommended minimum:

- `UiState`
- ViewModel methods for screen actions

This codebase does not currently need a full reducer/event/effect framework everywhere.

Add that only if flows become significantly more complex.

## Navigation Pattern

The dashboard is the entry point.

Metric cards route to feature detail screens.

New features should:

- have one route
- have one top bar title
- have one dashboard entry point when appropriate

Avoid making the navigation graph the place where feature logic lives.

## Dependency Injection Pattern

Current state is manual DI through `HCDashboardApp` and `remember(...)` ViewModel construction.

This is acceptable for now.

Do not introduce a DI framework only for this refactor.

If DI grows later, the target should be:

- repositories/query services provided centrally
- ViewModels created through a consistent factory approach

## Current Legacy Exceptions

These features do not yet follow the target pattern and should be treated as migration targets:

- [../app/src/main/kotlin/dev/manu/hcdashboard/features/body](../app/src/main/kotlin/dev/manu/hcdashboard/features/body)
- [../app/src/main/kotlin/dev/manu/hcdashboard/features/browse](../app/src/main/kotlin/dev/manu/hcdashboard/features/browse)

Do not use them as the template for new features.

## Anti-Patterns To Avoid

- giant abstract `BaseMetricViewModel`
- one mega chart component for all metrics
- screen-local coroutine loading for new feature work
- new per-feature copies of period math and period navigator UI
- continuing to grow one repository with screen-specific methods forever
- pushing raw Health Connect quirks directly into composables
