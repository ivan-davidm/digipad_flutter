# DigiTower 3D Premium

Professional optical measurement and lens-simulation app for ópticas, built with Flutter (Android and iOS, portrait only). Formerly called **DigiPad**.

The companion app that sends photos to this one is **DigiTower 3D Remote Control** (`../digipad_totem`).

## Modules

| Module | What it does |
|--------|--------------|
| Virtual mirror | Capture and browse photos/videos, with live pantoscopic angle |
| Simulations | Scenario-based lens demos (myopia, multifocal, bifocal, photochromic, polarized, …) |
| 3D lenses | Lens image viewer |
| Measurements | Detects the reference accessory and eyes in a photo, then measures DNP, heights, bridge, frame size… in an editor |
| Visagismo | Face-shape detection (ML Kit) and frame suggestions |
| Visual health | Vision test charts |
| Photo sync | Turns the device into a **Tótem** that receives photos from operator phones (LAN + Nearby Connections) |

Cosmetic lenses exists in the code but is currently hidden from the home screen.

## Requirements

- Flutter stable and Dart `>=3.8.1 <4.0.0`
- Android Studio (Android SDK, `minSdk 26`) and/or Xcode (iOS)
- A **real device** for camera, sensors, native detection and photo sync — the simulator/emulator can't exercise those

## Getting started

```bash
flutter pub get
flutter run
```

Other useful commands:

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build ios --release
```

### Localization

ARB files are in `lib/l10n/arb/` (`app_en.arb` is the template; `app_es.arb`, `app_pt.arb`). Add every key to all three, then regenerate — the generated Dart files are committed:

```bash
flutter gen-l10n
```

### Activation

Device activation is backed by Firestore (`device_activations`) and is **on** in every build. To skip it while developing, run with `--dart-define=BYPASS_ACTIVATION=true`:

```bash
flutter run --dart-define=BYPASS_ACTIVATION=true
```

## More documentation

See [`CLAUDE.md`](CLAUDE.md) for architecture, module details, the photo-sync protocol, native bridges and known pitfalls.
