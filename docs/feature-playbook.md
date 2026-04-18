# Feature Playbook

This is the implementation checklist for adding a new metric feature.

Use this before writing code.

## Goal

A new feature should feel native to the app from day one:

- same period navigation model
- same dashboard-first flow
- clear feature ownership
- minimal duplication

## First Decision: What Kind Of Feature Is It?

Before creating files, classify the feature.

### Type A: Period-based metric detail screen

Use this for metrics like:

- blood pressure
- oxygen saturation
- resting heart rate
- body fat
- hydration details

This is the default path.

### Type B: Session/list feature

Use this for:

- workouts
- sleep sessions
- raw record browsing

These still use the same period shell, but the content is more list-driven.

### Type C: Dashboard-only card

Use this only when there is not yet enough detail UX to justify a full feature screen.

## The Required Shape For New Detail Features

Every new detail feature should include:

1. One route
2. One ViewModel
3. One `UiState`
4. One period-based screen shell
5. `Day / Week / Month / Year`
6. Previous/next period navigation
7. Calendar selection
8. Empty state
9. Error state
10. Dashboard entry point if the metric is visible on the dashboard

## File Checklist

For a new feature called `hydration`, the target file shape should look like:

```text
features/hydration/
  HydrationScreen.kt
  HydrationViewModel.kt
```

Optional additions if the feature gets larger:

```text
features/hydration/
  HydrationContract.kt
  HydrationScreen.kt
  HydrationViewModel.kt
  HydrationCharts.kt
  HydrationRows.kt
  HydrationFormatters.kt
```

Keep files split by responsibility, not by arbitrary size.

## Implementation Steps

### 1. Define the feature contract

Create the screen state first.

The state should include:

- `isLoading`
- `selectedRange`
- `selectedDate`
- metric-specific content
- `error`

Add derived values only if they clearly reduce UI complexity.

### 2. Decide the data query model

Prefer a period-based query.

Target shape:

```kotlin
data class DatePeriod(
    val start: LocalDate,
    val end: LocalDate,
)
```

The feature should load data for:

- one selected day for `Day`
- one selected period for `Week / Month / Year`

Avoid inventing feature-specific date navigation rules unless the metric truly requires them.

### 3. Add repository/query support

The data layer should expose feature-oriented reads.

Prefer:

- `loadHydration(period)`
- `loadHydrationDay(date)`
- `loadHydrationTimeline(date)`

over piling more unrelated overloads into one generic repository without a plan.

If adding a reusable query object or period abstraction reduces duplication across multiple features, do that before copying code.

### 4. Implement the ViewModel

The ViewModel should:

- own selected range/date state
- compute the selected period
- load metric data
- expose UI-ready state

The ViewModel should not:

- contain long formatting strings
- know about icon choices or display colors
- duplicate period logic if a shared helper already exists

### 5. Implement the screen

The screen should follow the shared shell:

- refresh
- range selector
- period navigator
- error
- feature content
- date picker

Then split the content into:

- `Day` content
- `Week / Month / Year` content
- optional list/breakdown

### 6. Register navigation

Update:

- route in `navigation/Screen.kt`
- destination in `navigation/AppNavigation.kt`
- dashboard card routing if needed

### 7. Update docs if the pattern changes

If the feature introduces a better reusable pattern:

- update `AGENTS.md`
- update `docs/architecture.md`
- update `docs/refactor-roadmap.md` if it changes migration order

## Reuse Rules

### Reuse these

- period selection logic
- period navigator UI
- screen shell
- common loading/error/empty patterns

### Keep these feature-specific

- metric-specific charts
- metric-specific rows
- metric-specific summaries
- metric-specific formatting language when domain semantics differ

## Legacy Warning

Do not copy these older patterns for new work:

- range-only feature screens with no selected date anchor
- screen-local coroutine loading
- new one-off navigator implementations
- direct repository access from a large screen without a ViewModel

Current legacy examples:

- [../app/src/main/kotlin/dev/manu/hcdashboard/features/body](../app/src/main/kotlin/dev/manu/hcdashboard/features/body)
- [../app/src/main/kotlin/dev/manu/hcdashboard/features/browse](../app/src/main/kotlin/dev/manu/hcdashboard/features/browse)

## Pull Request / Change Checklist

Before finishing a new feature, verify:

- the feature uses the period-based detail model
- the screen can navigate backward and forward correctly
- navigation does not move past the current period
- the dashboard route is wired if relevant
- empty/error states exist
- the feature did not introduce another copy of shared period logic
- docs are still accurate
