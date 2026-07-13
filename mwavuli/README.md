# mwavuli — Flutter app

Cross-platform (iOS + Android) app for identifying, mapping, and celebrating
the world's trees. The design system, navigation, offline-first data layer, and
all five screens are in place and mirror the Phase 1 prototype 1:1. The `core/`
services are wired to the Phase 3 backend, and the app now includes:

- **Auth** — login / register (13+ gate) with token refresh and auto-login on
  launch (`lib/features/auth/`).
- **Photo capture → presigned upload** — camera/gallery capture with on-device
  EXIF/GPS stripping, then `createTree` → PUT each photo to its presigned S3
  URL. Offline logs cache their (stripped) photos and upload on reconnect.
- **Tests + CI** — unit + widget tests (`test/`) and a GitHub Actions workflow.

## Requirements

- **Flutter 3.27+ / Dart 3.4+** (uses `Color.withValues`, records, and current
  Material 3 theme APIs). Developed against current stable.
- Xcode (iOS) and/or Android SDK for device builds.

## Run

```bash
flutter pub get

# Android emulator → host machine
flutter run --dart-define=MWAVULI_API=http://10.0.2.2:8080

# Physical Android over USB (no Wi‑Fi needed)
adb reverse tcp:8080 tcp:8080
adb reverse tcp:9000 tcp:9000
flutter run -d <device-id> --dart-define=MWAVULI_API=http://127.0.0.1:8080

# Physical device on same Wi‑Fi as your Mac (find IP: ipconfig getifaddr en0)
flutter run -d <device-id> --dart-define=MWAVULI_API=http://192.168.x.x:8080

# iOS simulator
flutter run --dart-define=MWAVULI_API=http://localhost:8080
```

`10.0.2.2` is **emulator-only** — it does not work on a real phone.

`MWAVULI_API` points the app at the backend (defaults to `http://localhost:8080`).
Fonts (Roboto / Roboto Slab) load at runtime via `google_fonts` — no font
files are bundled, so the first launch needs a network connection.

Run the tests:

```bash
flutter test        # unit (model, fuzz, EXIF) + a widget test
flutter analyze
```

Camera, location, and map tiles need platform permissions before those
features work on a real device:

- **iOS** (`ios/Runner/Info.plist`): `NSCameraUsageDescription`,
  `NSLocationWhenInUseUsageDescription`, `NSPhotoLibraryUsageDescription`.
- **Android** (`android/app/src/main/AndroidManifest.xml`): `CAMERA`,
  `ACCESS_FINE_LOCATION`, `INTERNET`.

(Generate the native folders with `flutter create .` in this directory if they
aren't present — only the Dart `lib/` is included here.)

## Architecture

```
lib/
  app/            theme (design system), router (go_router), global state, entry
  core/           service layer, decoupled behind interfaces
    api/          Dio client (TLS): auth+token refresh, feed, trees, identify,
                  presigned photo upload, GDPR
    camera/       capture (image_picker) + on-device EXIF strip + photo cache
    id/           identification via the API (Pl@ntNet / iNaturalist)
    location/     geolocation + ±500 m privacy "fuzzing"
    offline/      connectivity stream, encrypted queue, auto-flush on reconnect
    privacy/      on-device EXIF/GPS stripping + thumbnailing (image pkg)
  data/
    models/       Tree, Species, community types, seed/mock data
    local/        LocalTreeStore (in-memory now; swap for Drift/Isar)
    repositories/ TreeRepository — offline-first (network → cache fallback)
  features/
    auth/ welcome/ explore/ map/ log/ community/ profile/ shell/
  widgets/        shared UI (TreeCard, Pill, SectionHeader, OfflineBanner, …)
```

**State management:** Riverpod. Providers expose services, the repository, and
UI state (`highContrastProvider`, `largeTextProvider`, `offlineModeProvider`,
`syncQueueProvider`).

**Navigation:** `go_router` with a `StatefulShellRoute` for the four bottom-nav
branches (Explore / Map / Community / Profile). Welcome, the Log flow, and Tree
detail are full-screen routes above the shell. The camera FAB is docked in the
notched bottom bar (thumb-zone primary action).

**Offline-first:** `TreeRepository.feed()` tries the API and falls back to the
local cache, so the UI renders offline. A new log POSTs to the API and uploads
its photos to presigned URLs; when offline it's queued **encrypted** via
`flutter_secure_storage` (photos cached to disk), and `SyncController` flushes
the queue automatically when connectivity returns.

## Design system

`lib/app/theme.dart` ports the prototype's earth-toned palette (forest greens,
warm browns, creams, gold accents), Roboto/Roboto-Slab typography, radii, and
component themes. Semantic tokens live on a `MwavuliColors` theme extension
(`context.earth.gold`, `…brown`, `…line`, …). A **high-contrast** variant and a
**large-text** scale back the WCAG toggles (surfaced in Profile → Settings and
driven from `MediaQuery.textScaler`).

## Implemented vs. stubbed

| Area | State |
|---|---|
| Design system, theme, a11y toggles | ✅ implemented |
| Navigation, shell, all 5 screens | ✅ implemented (seed data) |
| Log flow (capture→identify→describe→location→success) | ✅ implemented |
| Offline-first repository + local cache | ✅ implemented (in-memory store) |
| Fuzzing, EXIF strip, thumbnailing | ✅ implemented (real logic) |
| API client, identification, presigned photo upload | ✅ implemented |
| Auth (login / register / refresh, 13+ gate) | ✅ implemented |
| Durable local DB (Drift/Isar) | 🔌 swap `InMemoryTreeStore` |

## Security & privacy mapping (spec → code)

- **EXIF/GPS stripping** → `core/privacy/exif.dart` (`stripMetadata`).
- **Fuzzy location (±500 m)** → `core/location/location_service.dart` (`fuzz`);
  `Tree.displayLocation` only ever exposes the fuzzy point publicly.
- **Exact coords access-controlled** → `Tree.exactLocation` stays separate from
  `fuzzyLocation`; `toCreateRequest` sends the exact point, and the server stores
  it privately while only ever returning the fuzzy point publicly.
- **Encrypted offline storage** → `core/offline/sync_service.dart`
  (`flutter_secure_storage`).
- **TLS** → `core/api/api_client.dart` (HTTPS base URL + presigned uploads).
- **Content moderation** → report action on the Tree detail screen (`/v1/reports`).
- **GDPR export / deletion** → Profile → Settings call `ApiClient.exportData` /
  `scheduleDeletion` against the backend's `/v1/me/*` endpoints.
- **COPPA / 13+** → enforced in the register screen and again by the API/DB.

## Build & deploy

```bash
flutter build apk --release        # Android APK
flutter build appbundle --release  # Play Store
flutter build ipa --release        # iOS (on macOS)
```

Point the build at production with `--dart-define=MWAVULI_API=https://api.mwavuli.app`.
Because only `lib/` and `test/` are tracked here, generate the native folders
first with `flutter create .` (this also happens in CI).

## CI

`.github/workflows/flutter.yml` runs `flutter analyze`, `flutter test`, and a
debug APK build on every push — see the backend repo for the API/deploy pipelines.
