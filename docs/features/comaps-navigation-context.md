# CoMaps Navigation Context

> **Implementation:** `lib/domain/model/comaps_navigation.dart`, `lib/data/source/comaps/`, `lib/data/repository/{contract,impl}/comaps_navigation_repository*.dart`, `lib/features/manualentry/activity/recording/` (the panel, the overlay, the polling), `lib/features/activity/application/activity_navigation_display.dart`, and the `comaps_navigation` MethodChannel in `android/app/src/main/kotlin/tech/mmarca/openvitals/MainActivity.kt`.

## The boundary

**CoMaps plans and navigates. OpenVitals records.**

That sentence is the whole design. OpenVitals reads what CoMaps is already doing and shows it next to the workout it is recording; it cannot start, stop or steer a route, and it never will. Nothing read from CoMaps is written to Health Connect — it is app-local activity history.

## What it reads

CoMaps exposes a live-navigation `ContentProvider` (upstream PR #4588, merged 2026-07-01):

- authority `<comapsPackage>.provider.navigation`, row at `/live`
- read-protected by `app.comaps.permission.READ_NAVIGATION_DATA`, declared by CoMaps with `protectionLevel="dangerous"` — a runtime grant, and one that does not exist while CoMaps is not installed
- twelve columns: session state, car/pedestrian turn direction, distance to turn/target/next stop, total route time, time to next stop, current and next street, completion percent, exit number

**The distances arrive already formatted** ("450 m", "1.2 km"). CoMaps formats them against its own locale and unit settings, and we keep the string it gives us: a distance the user reads in CoMaps should read the same in OpenVitals, and the number we could parse back is not one we could re-format any better.

## The shape of it

The platform surface — a `ContentResolver` query, a `PackageManager` lookup, a runtime grant, an intent launch — is the one thing Dart cannot do, so it lives in `MainActivity` behind a `MethodChannel`. **It classifies nothing.** It reports what it found and hands the raw row up, because "is this navigating?" is a domain question and domain questions belong where they can be answered without a device.

Everything above it is ordinary Dart, and ordinary architecture: a sealed `CoMapsNavigationState`, a `Result`-returning repository, a display built in the view-model, widgets that only render.

### Package visibility is load-bearing

From Android 11 an app cannot see a package it has not declared. `AndroidManifest.xml` therefore lists every known CoMaps package **and** every provider authority in `<queries>`. Without it, `resolveContentProvider()` silently returns null and CoMaps looks uninstalled *while it is running* — which is exactly the kind of failure that reads like a bug in the feature rather than a missing manifest entry.

## Every unavailable state is a normal state

The recording never depends on guidance, and none of these is an error to shout about:

| State | What it means | What the user is offered |
|---|---|---|
| `Disabled` | The integration is switched off | Nothing at all is rendered |
| `AppUnavailable` | No CoMaps is installed | A calm line; recording continues |
| `ProviderUnavailable` | CoMaps is installed but this build has no provider | A calm line; recording continues |
| `PermissionMissing` | We may not read the provider | **A button** — this is the one the user can fix |
| `NotNavigating` | CoMaps is there, guiding nobody | A calm line |
| `Active` | CoMaps is guiding someone | The panel, and the turn overlay on the map |
| `Error` | The query itself failed | A calm line; the raw message is never shown |

## Polling, and why

A `ContentProvider` has no change feed, so the only way to see a turn coming is to ask. It is asked **every two seconds, and only while a GPS-route recording is actively running and the user has switched the integration on.** A gym session has nothing to navigate; a paused recording is not going anywhere; a user who never asked for this never has their `ContentResolver` touched.

Almost every answer is the same as the last. A sample is **kept** when the guidance actually changed, or when 15 seconds have passed since the last one kept — so a long straight road costs one sample rather than seven, and a flurry of turns loses none.

The samples ride out on the recording **snapshot**, the same route the BLE samples take. They have to: the poll tears itself down the moment the recording goes inactive and resets the recorder as it goes, so a form that went looking for them at save time would find them already gone.

## What it cannot do

The provider exposes live navigation metadata only — **no route geometry, no tiles, no rendered map content**. OpenVitals can draw a turn instruction from the metadata; it cannot draw CoMaps' planned route.

Offline maps stay a user-granted import through OpenVitals' own importer, in the formats OpenVitals renders (`.pmtiles`, Mapsforge `.map` / `.maps`). CoMaps' own `.mwm` packs are not compatible and are not read. OpenVitals does not touch CoMaps' private storage.

## If CoMaps exposes more later

`https://comaps.at/api` documents public deep links, which are app-to-app handoffs rather than a data source: a richer **Plan in CoMaps** (`cm://route` with the current fix as `sll`), **Choose destination in CoMaps**, **Open in CoMaps** for saved markers, **Search in CoMaps**. All of them would sit *beside* this integration and none of them changes the boundary: OpenVitals records activities, CoMaps plans and navigates routes.
