# OpenVitals: a privacy-first Health Connect dashboard

OpenVitals is an Android app for exploring your Health Connect data on-device.

It is built around a simple idea: your health data should stay yours. The app is local-first, read-only, dashboard-first, and designed to work without an account, cloud sync, ads, or analytics.

OpenVitals is still in an early stage, but the core product direction is already in place: a daily dashboard, period-based detail screens, feature-first architecture, and per-metric Health Connect permissions.

## Screenshots

Screenshots will be added once the UI stabilizes further.

## Features

- Daily dashboard with cards for steps, distance, calories, hydration, workout, sleep, heart, and body metrics
- Period-based detail screens with `Day / Week / Month / Year` navigation
- Feature screens for Activity, Activities, Sleep, Heart, Body, Browse, Onboarding, and Settings
- Health Connect onboarding flow with availability checks and phased permission requests
- Shared detail-screen scaffold with pull-to-refresh, range selection, period navigation, and calendar date picking
- Read-only access to Health Connect data; the app does not write health data back

## Current coverage

- Activity: steps, distance, calories burned, workout sessions
- Sleep: sessions, duration, and sleep stages
- Heart: heart rate samples and summaries, resting heart rate, HRV
- Body: weight, BMI, body fat, lean mass, basal metabolic rate
- Dashboard-only summaries: hydration and calorie burn snapshots
- Browse: workout, sleep, and weight records by selected period

## Privacy

- No account required
- No cloud sync of health data
- No ads
- No analytics SDKs
- No Google Play Services dependency for app functionality
- Permissions are requested per Health Connect category and can be managed later in Settings
- Health Connect remains the source of truth; OpenVitals reads only the data you choose to share

The current manifest does not request the `INTERNET` permission.

## Platform requirements

- Android only
- `minSdk 26`
- `targetSdk 36`
- JDK 17 / Java 17 toolchain
- Health Connect required

Health Connect platform notes:

- On Android 14 and newer, Health Connect is part of the system
- On Android 13 and older, the Health Connect app must be installed separately
- Health Connect is not supported in work profiles

## Build from source

1. Install a recent Android Studio with Android SDK 36 and JDK 17 support.
2. Clone this repository.
3. Open the project in Android Studio, or build from the command line:

```bash
./gradlew assembleDebug
```

To install on a connected device or emulator:

```bash
./gradlew installDebug
```

After launching the app:

1. Complete onboarding
2. Grant the Health Connect categories you want to expose
3. Use the dashboard as the main entry point into detail screens

## Architecture at a glance

OpenVitals is intentionally simple today:

- one Android app module
- Jetpack Compose UI
- Navigation Compose
- `ViewModel` + `StateFlow`
- manual dependency wiring in `OpenVitalsApp`
- Health Connect AndroidX client wrapped by `HealthConnectManager`
- feature-specific repositories for activity, sleep, heart, and body

The current architecture is documented in more detail in [`docs/architecture.md`](docs/architecture.md).

## Project layout

- [`app/`](app): Android app module
- [`app/src/main/kotlin/dev/manu/openvitals/features/`](app/src/main/kotlin/dev/manu/openvitals/features): feature screens, state, and ViewModels
- [`app/src/main/kotlin/dev/manu/openvitals/data/repository/`](app/src/main/kotlin/dev/manu/openvitals/data/repository): repositories over Health Connect reads
- [`app/src/main/kotlin/dev/manu/openvitals/ui/components/`](app/src/main/kotlin/dev/manu/openvitals/ui/components): shared UI scaffolding and navigation components
- [`docs/`](docs): architecture notes, playbooks, and roadmap

## Documentation

- [`plan.md`](plan.md): product direction and scope
- [`docs/architecture.md`](docs/architecture.md): current architecture and target direction
- [`docs/feature-playbook.md`](docs/feature-playbook.md): checklist for adding a new metric feature
- [`docs/metrics-roadmap.md`](docs/metrics-roadmap.md): metric coverage gaps and future feature roadmap
- [`AGENTS.md`](AGENTS.md): implementation guidance for future coding agents

## Roadmap

Near-term roadmap items already tracked in [`docs/metrics-roadmap.md`](docs/metrics-roadmap.md) include:

- activity extras such as floors climbed, active calories, and elevation gain
- nutrition
- vitals
- mindfulness
- opt-in cycle tracking

## Status

OpenVitals is actively being shaped into a consistent Health Connect dashboard app. The current codebase already has the shared period-based detail architecture in place, but the product surface and project documentation are still evolving.
