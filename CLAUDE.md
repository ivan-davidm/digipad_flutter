# DigiTower 3D Premium (`digipad_flutter`) — Agent Context

> Sibling repo: [`../digipad_totem`](../digipad_totem/CLAUDE.md) — **DigiTower 3D Remote Control** ("Totem Connect"), the operator-phone companion app that sends photos to this app. Several modules are **copied** between the two repos: Photo Sync has diverged; **Visagismo is shared code** (see "Visagismo").
> This app was formerly called **DigiPad**; the repo/package names (`digipad_flutter`, `ar.com.digipad`) still use the old name.

## What this is

A professional optical measurement and lens-simulation app for ópticas (optical shops), in Flutter for **Android and iOS** (portrait only). It is typically run on a **Tótem**: a kiosk device (tablet / Android TV-class box) in the shop. Operators send it photos from their phones using the companion app, and the shop measures and demonstrates lenses with them.

- Version `4.0.1+29` · Dart `>=3.8.1 <4.0.0` · Android `applicationId` `ar.com.digipad`, `minSdk 26` · iOS bundle id `ar.com.digipad`
- Languages: **es / en / pt** (all three ARB files have the same ~305 keys)
- State management: **BLoC/Cubit** (`flutter_bloc`); `provider` only inside `optical_editor_screen.dart`
- Local storage: **Sembast** (`gallery.db`, `measurements.db`) + SharedPreferences. Cloud: Firebase Firestore (activation, visagismo catalog)

## ⚠️ Read this first — known traps

1. **Activation bypass is OFF by default** (`ActivationCubit.kBypassActivation = bool.fromEnvironment('BYPASS_ACTIVATION')`), so every normal/release build has the activation gate. To develop without activating: `flutter run --dart-define=BYPASS_ACTIVATION=true`. A test (`test/screens/activation/bypass_flag_test.dart`) fails if someone hardcodes it back to `true`.
2. **Detection is native, not Dart.** The 4-marker/eye detection (YOLOv8 + TFLite) runs in a native platform view. `tflite_flutter` is in `pubspec.yaml` but nothing in `lib/` imports it, and `assets/haar_cascade/` is neither listed in `pubspec.yaml` nor referenced. Don't look for the model in Dart.
3. **iOS detection model not found in the repo.** The Android model is `android/app/src/main/assets/model3.tflite` (+ `labels.txt`). I found no `model3.tflite` under `ios/` and it is not in `pubspec.yaml` assets, although `NativeYoloView.swift` asks for `assets/model3.tflite`. Verify on iOS before assuming detection works there.
4. **The pantoscopic angle formula exists in three places** (this repo: `measurement_capture_screen.dart`, `vm_camera_screen.dart`; companion repo: `photo_capture_screen.dart`). Change one → change all, and check the companion repo.
5. **Photo sync protocol is a contract between two repos.** The receiver lives here; the sender is mostly in `digipad_totem`. See "Photo Sync".
6. **Generated l10n files are committed** (`lib/l10n/arb/app_localizations*.dart`). After editing an ARB file, regenerate and commit them.
7. **ML Kit needs an R8 keep rule in release builds.** `android/app/proguard-rules.pro` keeps `ComponentRegistrar` implementations (`-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }`). Without it R8 strips their constructors, ML Kit never initialises and every face detection fails with a NullPointerException — debug builds work, release doesn't. The visagismo reports detector failures as `FaceCaptureIssue.detectorError` (never as "no face"). If you add another ML Kit plugin, check a release build.
8. **Some modules are hidden on purpose** (product decisions recorded as dated comments in code). See "Hidden / flagged-off features". They are not broken.
9. Orphans: `lib/home_view.dart` and `lib/splash_screen.dart` are not referenced anywhere. `script.py` and `convert_images.sh` are stale one-off scripts with machine-specific paths (`q:\REPO\digipad\…`, `/Volumes/KINGSTON/…`).

## App flow

```
main.dart
 └─ Firebase.initializeApp (failure is tolerated) · portrait lock
     └─ BlocProvider<ActivationCubit> → InteractionObserver → MaterialApp(navigatorKey: rootNavigatorKey)
         └─ ActivationWrapper ── approved ──► HomeScreen
```

`HomeScreen` (`lib/screens/home_screen.dart`) is an animated background (see "Home background" below) with **7 module cards in an arch** (`left` 75→30→75, evenly spaced `top`, starting just below the top bar, `_kMenuTopOffset`) and the DTCP logo (`assets/images/logo_dtcp.png`, on a white oval backdrop) at the bottom-right. The arch was accidentally replaced by a straight column once (2026-11-24) — keep it:

| Key | Screen | Notes |
|-----|--------|-------|
| `virtual_mirror` | `VirtualMirrorScreen` | Camera/gallery of photos + videos with live pantoscopic angle (`vm_camera_screen.dart`) |
| `simulations` | `MainSimulationsGridScreen` → `SimulationViewerScreen` | Scenario-based lens demos (myopia, monofocal, multifocal, bifocal, photochromic, polarized, blue filter, …). Data in `simulations/data/simulation_data.dart` (~1.7k lines) + images in `assets/images/simulations/` |
| `lenses_3d` | `Lenses3DScreen` | Lens image viewer, assets in `assets/images/lenses_3d/` |
| `measurements` | `MeasurementHubScreen` | The core feature — see below |
| `visagismo` | `VisagismoEntryScreen` | Face-shape detection (ML Kit), real frames ranked by match, try-on on the photo |
| `visual_health` | `VisualHealthScreen` | Vision test charts/images |
| `photo_sync` | `PhotoSyncRoleScreen` | Tótem host role — see "Photo Sync" |

`HomeScreen` owns a **`TotemCubit` for its whole lifetime** (`_hostCubit`), so the Tótem keeps receiving photos while the user is in another module; an active-Tótem badge shows on the card. It also starts `SharedImageIntentHandler`.

### Home background — `lib/screens/home/`

`HomeBackgroundController` (state machine, unit-tested with a fake player) + `HomeBackground` widget (wallpaper underneath, video fading in on top) + a settings sheet. The still image is always `assets/images/background.webp` (the original wallpaper); when a video ends it fades back to it instead of freezing on the last frame.

- **Videos** (`kBackgroundVideos`): `home_background.mp4` (V1, **cut at 17 s in code** — the file is ~20 s), `home_background_2.mp4` (V2, 10 s), `home_background_3.mp4` (V3, 20 s). All 1080×1920 H.264. Only one decoder is alive at a time: `_play` pauses and disposes the current player *before* initialising the next one (Tótem-class devices may have a single 1080p hardware decoder; opening V2 while V1 was alive broke double tap). Covered by a test.
- **Gestures on empty background**: tap = pause/play (on the wallpaper it plays the current video) · double tap = next video V1→V2→V3→V1 · long press = wallpaper only (long press again resumes).
- **Modes** (`HomeBackgroundMode`, persisted in SharedPreferences `home_bg_mode`): loop of V1 (default), V2 or V3; periodic V1, V2 or V3; image only. Periodic = wallpaper, plays the video once every N min (`home_bg_interval_min`: 1/2/5/10, default 2) and returns to the wallpaper. Picking a periodic mode plays once immediately as a preview.
- **Settings sheet**: **long press on the logo** (bottom-right) — deliberately hidden so customers in the shop don't change it. Strings: `homeBg*` keys in the ARB files.
- The video pauses when the app goes to the background. It does **not** yet pause while a module screen is open on top of the home.
- Double-tap-chosen video is sticky for the session only; after a restart the persisted mode decides again.

### Activation (`lib/screens/activation/`)
Firestore collection `device_activations`, document id `{email}_{deviceId}`. `deviceId` is a **locally generated UUID persisted in SharedPreferences** (deliberately *not* `device_info_plus`'s `androidInfo.id`, which is the OS build id and collides across devices). A new device writes `isApproved: false` plus device info / IP / location; an admin flips `isApproved` in the Firestore console and the app's stream moves it to `approved`. Once approved it is cached (`is_device_approved_locally`) and works **offline permanently**. States: `checking`, `approved`, `blockedOffline`, `notRegistered`, `pendingApproval`, `error`. `InteractionObserver` calls `handleInteraction()` on every pointer-down.

## Measurements (the core module) — `lib/screens/features/measurements/`

| File | Role |
|------|------|
| `measurement_hub_screen.dart` | Hub with tiles; also hosts the hidden native platform view used for `detectFromImage` |
| `measurement_capture_screen.dart` | Live camera + inclinometer overlay; **currently unreachable** (`_kShowNewMeasurementTile = false`) |
| `optical_editor_screen.dart` (~1.7k lines) | Post-capture editor: drag markers, calibrate, results sheet, screenshot/share |
| `optical_logic_controller.dart` | `OpticalController` (`ChangeNotifier`): geometry → millimetres. Spanish-named outputs: `di`, `puente`, `dnpRight/Left`, `altRight/Left`, `aroAlt`, `aroAnc`, `diametro*`, `altSup*`, `anchoExtArmazon`, bifocal line |
| `optical_painter.dart` | `CustomPainter` for markers/lines |
| `measurements_list_screen.dart` | Saved measurements (`MeasurementStorage`), reopen via `OpticalEditorScreen(savedRecord: …)` |
| `shared_image_intent_handler.dart` | Android share-sheet target: a photo shared from WhatsApp etc. opens straight in the editor |

**Hub tiles:** internal gallery (photos received by the Tótem) · my measurements · system gallery · "Medición remota" (no accessory). "New measurement" is flagged off.

**Two modes** (`MeasurementMode`):
- `conAccesorio` — photo includes the physical reference accessory. Native detector returns `circles` (expects **4**) and `eyes`; < 4 circles shows a snackbar but still opens the editor. Reference circle diameter defaults to 40 mm.
- `sinAccesorio` — no accessory (photo from the Tótem/WhatsApp/gallery "remote" flow). Empty detections; the controller seeds default pupil/lens markers in the middle of the image and the user calibrates by typing the **frame width** (mm).

**Detection bridge:** `AndroidView`/`UiKitView` viewType `native-left-view` → `MethodChannel('native-left-view/$id')` → `invokeMethod('detectFromImage', {'path': path})` → `{'circles': [x0,y0,x1,y1,…], 'eyes': […]}` (flat lists of normalized coordinates). Native code: `android/app/src/main/kotlin/ar/com/fennoma/digipad_flutter/yolov8tflite/` and `NativeYolo*.kt` in the same folder, and `ios/Runner/NativeYolo/*.swift`. Dart-side: `_inflateDetections` in the hub. After a Flutter hot reload, MethodChannel handlers may not re-register — do a full restart.

**Lens "L" corners & mirroring:** each lens is a rectangle defined by two diagonal corners drawn as L's — right lens (patient's right = the **left** side of the image) `R_TL` (outer-top) + `R_BR` (nasal-bottom); left lens `L_TL` (nasal-top) + `L_BR` (outer-bottom). With the "link lenses" switch on (`OpticalController.linkLenses`, persisted as `linkLenses`, default on; link icon in the editor's top bar), moving a *right* corner mirrors onto the left lens: heights pair top↔top / bottom↔bottom, but the horizontal edges **cross** — `R_TL`(outer) → `L_BR`.x and `R_BR`(nasal) → `L_TL`.x (this was the "side doesn't mirror" bug). Left corners never move the right lens. The mirror works along screen axes using `viewRotation` (kept in sync with the editor's auto-rotation). Covered by `test/screens/features/measurements/optical_lens_mirror_test.dart`.

**Pantoscopic angle:** `sensors_plus` accelerometer, throttled to ~10 Hz, EMA smoothing (`alpha = 0.15`), `raw = -atan2(z, sqrt(x²+y²))` in degrees, displayed as `smoothed − angleCalibrationOffset`. The user can calibrate zero; the offset is stored in SharedPreferences (`angleCalibrationOffset`). The angle travels with the photo: capture → `GalleryStorage` metadata (`pantoscopic_angle`) → hub `getAngle(file)` → `OpticalEditorScreen(pantoscopicAngle: …)` → results sheet and `MeasurementRecord.stateJson['pantoscopicAngle']`.

**Persistence:** `MeasurementRecord` (id, imagePath, patient first/last name, createdAt, `stateJson` containing `results` and `pantoscopicAngle`) in `MeasurementStorage` (`measurements.db`). Received/captured photos and their metadata (`path`, `timestamp`, `type`, `pantoscopic_angle`, `patient_first_name`, `patient_last_name`, `capture_date`) are in `GalleryStorage` (`gallery.db`, singleton with a `watchImages()` stream).

## Photo Sync — `lib/features/photo_sync/`

In **this app only the Tótem (host) role is exposed** (`PhotoSyncRoleScreen`); the client code path is still present but hidden. The sender is normally `digipad_totem`.

**Pairing:** the Tótem shows a QR (`qr_flutter`): `digipad-totem/v2 <base64(utf8(json))>` with json `{"name", "hosts": ["http://ip:port", …], "port"}`; legacy form `digipad-totem:<name>` when the LAN server isn't up. The Tótem name is generated once and stored (`ps_my_totem_name`).

`TotemCubit.startTotem()` runs **two transports at once** and only errors if *both* fail:

1. **LAN** — `LanSyncService`: `HttpServer` on the first free port in **8823–8833**, UDP beacon on **8824** every 2 s (`DIGIPAD-TOTEM-BEACON/1`). `GET /ping` → `{"app":"digipad-photosync","name","port"}`; `POST /upload` → raw bytes with headers `x-photo-name`, `x-angle`, `x-frame-width-mm`, `x-patient-first`, `x-patient-last`, `x-capture-date`. No permissions needed.
2. **Nearby Connections** — `PhotoSyncService`: `serviceId = ar.com.digipad.photosync`, `Strategy.P2P_STAR`, Tótem advertises. Per photo: a BYTES payload with JSON meta (`name`, `pantoscopic_angle`, `patient_first_name`, `patient_last_name`, `capture_date`, `frame_width_mm`) followed by the FILE payload. On Android 10+ `payload.uri` is a `content://` URI → copy with `Nearby().copyFileAndDeleteOriginal`. Needs Bluetooth/location/Nearby-Wi-Fi permissions (any one group is enough).

`frame_width_mm` / `x-frame-width-mm` is part of the wire format (parsed into `LanIncomingFile.frameWidthMm`), but `TotemCubit` does **not** persist it and `digipad_totem` never sends it. Only angle, patient names and capture date reach `GalleryStorage`.

Received files are written under `<documents>/totem_received/` and registered in `GalleryStorage` with their metadata. Android uses `NearbyForegroundService` (`connectedDevice` type) to stay alive; `MethodChannel('ar.com.digipad.photosync/capabilities')` in `MainActivity.kt` (**Android only** — iOS registers no handler and `PhotoSyncCapabilities` falls back to safe defaults) exposes capability/state checks (`getCapabilities` incl. `isAndroidTV`, Wi-Fi/Bluetooth/location enabled, open settings, foreground service, multicast lock).

`lan_sync_service.dart` is byte-identical in both repos; the rest of `photo_sync/` has diverged. `ios/Runner/PhotoSyncWifiPlugin.swift` (channel `ar.com.digipad/photo_sync`, hotspot-era `NEHotspotConfiguration`) is registered but **not called from Dart**.

## Visagismo — `lib/screens/features/visagismo/`

**Shared module (since 2026-11-25): the SAME code as `../digipad_totem/lib/features/visagismo/`** — only the package prefix in the imports differs (`digipad_flutter/screens/features/…` ↔ `digipad_totem/features/…`). Tests are shared the same way (`test/screens/features/visagismo/`). Change one → copy it to the other with that rename. Everything app-specific stays outside the module:
- **Tótem link** — `data/visagismo_totem_link.dart` is an interface the host app may pass to `VisagismoEntryScreen(totemLink: …)`. The Remote Control passes its own (`ClientTotemLink`, over its `ClientCubit`) to send photos to the Tótem. **This app runs on the Tótem, so it passes nothing**: the result screen then only saves to the local gallery and hides every Tótem control.
- **Translations** — every key the module uses starts with `visagismo` (50 keys: texts, frame names `visagismoFrameName`/`visagismoFrameDetail` by `frameId`, face shapes, match levels, diagnostics). Keep them identical in both repos' ARB files.

**Camera:** rear first (the operator aims it), flip button when the device has front + rear. `VisagismoCubit` counts ANY camera as available — including one Android reports as **external (USB)**, which matters on Tótem hardware — and shows the "no camera" message only when there is none; the capture screen falls back to the first camera when the requested side doesn't exist. **No extra mirroring**: the camera plugin already mirrors the front preview; flipping it again (as this screen used to) made the selfie view move the wrong way (field reports 2026-11-25). An **external (USB) camera** faces the client like a selfie camera but the plugin doesn't mirror it, so the capture screen mirrors its preview itself (product decision 2026-11-25; only the preview — the photo is analysed and saved as captured).

Flow: capture → `google_mlkit_face_detection` (contours + eye landmarks, accurate mode) → `analyzeFaces()` (`logic/face_measurements_from_mlkit.dart`): largest face; rejects yaw/pitch > 20° (`FaceCaptureIssue.headTurned` / `headTilted` / `noFace`, detector failures as `detectorError`); levels roll with the eye line; also returns `GlassesAnchor` (eye centres + face width at eye level) → `classifyFaceShape()` (`FaceShape`: redondo, cuadrado, ovalado, corazón, diamante, alargado; round/square thresholds tuned so a beard doesn't make a round jaw read square).

**Frames:** `data/bundled_frame_catalog.dart` — 25 real front-view frames (`assets/images/visagismo/frames/`, transparent background and lenses, 5 styles × 5 finishes, cut from the client's "Armazones Reales Transparentes" sheets). `logic/frame_match.dart` shows **every** frame, best first, colour-coded on its card: green ideal (top recommended tag) / yellow good (other recommended) / orange possible / red not recommended (an `avoidFrameTags` match). Frames carry descriptive tags (anguloso, browline_pesado, bajo, …) so the red level can trigger. Real/Firestore catalog later: `fetchCatalog()` keeps its signature; `firestore.rules` already reserves `frame_catalog` and `opticas/{id}/entitlements`.

**Try-on on the captured photo:** the best frame is drawn over the eyes right away (`widgets/glasses_try_on_view.dart`). `logic/frame_lens_detector.dart` finds each picture's two lens holes (transparent areas enclosed by the frame) — no per-frame measurements — and `logic/glasses_fit.dart` puts the lens centres over the eyes, 6 % wider than the pupils, following the head tilt, sanity-clamped against the eye distance. Drag / pinch / twist adjusts it; "Guardar con marco" exports the same painting at full photo resolution (PNG in `<app documents>/visagismo/`) to the gallery. Captures are copied there too (the gallery stores paths; the camera's temp file is deleted on "Repetir").

**Result screen:** app bar = (Tótem link when there is one) + "Repetir" icon; snackbars for saved/sent; long press on the face-shape badge opens the hidden debug panel (raw ratios, head pose, why a photo failed). Frame cards are bigger on screens with shortestSide ≥ 600 (tablets, Tótem).

**Known limits — read before tuning:** ML Kit's contour reaches mid-forehead, not the hairline (inflates width/height); thresholds are pixel-based and **not validated against reference faces** — tune with the debug panel. Not verified on a device: the try-on placement and frame size on real faces.

## Hidden / flagged-off features

- **Cosmetic lenses**: hidden from Home (2026-11-05). Code intact; the comment in `home_screen.dart` explains how to bring it back (re-add `_ModuleDef` + `_navigateToModule` branch, set `_moduleCount` to 8, re-tune each card's `top`).
- **Measurements hub — "New measurement"**: `_kShowNewMeasurementTile = false`.
- **Photo sync — client role** hidden in this app.
- `kBypassActivation = true` (see traps).

## Firebase

Project id `digipad-max` (`firebase.json`; `lib/firebase_options.dart`; `google-services.json`/`GoogleService-Info.plist`). `firestore.rules`: `device_activations/{id}` is **public read/write** (no user auth exists); `frame_catalog` and `opticas` read-only; everything else denied. Initialization failure is tolerated in `main()`.

## Project structure

```
lib/
├── main.dart, digi_locale.dart, firebase_options.dart
├── home_view.dart, splash_screen.dart          # unused
├── common/{components,managers,utils}          # d_image, d_svg, gallery_photo_strip, responsive_utils
├── core/utils/image_rotation_util.dart         # uses package:image
├── data/
│   ├── local/{gallery_storage,measurement_storage}.dart
│   └── models/measurement_record.dart
├── features/photo_sync/                        # cubit/ + presentation/ + 2 transport services
├── l10n/{l10n.dart, arb/*.arb, arb/app_localizations*.dart (generated)}
└── screens/
    ├── home_screen.dart
    ├── home/{home_background_controller,home_background}.dart   # wallpaper + videos + gestures + settings sheet
    ├── activation/{cubit,data,presentation}
    └── features/{measurements,simulations,lenses_3d,virtual_mirror,visagismo,visual_health,cosmetic_lenses}
```

Feature modules follow `cubit/` + `presentation/` (+ `widgets/`, `data/`, `models/`). Measurements is the exception: plain `StatefulWidget`s + `OpticalController`.

## Native / platform

- **Android** (`android/app/src/main/kotlin/ar/com/fennoma/digipad_flutter/`, package `ar.com.digipad`): `MainActivity.kt` registers the `native-left-view` platform view factory and the capabilities channel; `NativeYolo*.kt` + `yolov8tflite/` (detector); `NearbyForegroundService.kt`. Permissions include camera, audio, location, Bluetooth (scan/advertise/connect), Nearby Wi-Fi, media images, multicast, foreground service. The manifest registers an `image/*` SEND/SEND_MULTIPLE intent filter (share sheet).
- **iOS**: `AppDelegate.swift` registers the `native-left-view` factory and `PhotoSyncWifiPlugin`; `ios/Runner/NativeYolo/*.swift`. `Info.plist` has camera, photo library, location, Bluetooth, microphone, documents and local-network usage strings.
- `macos/`, `windows/`, `linux/`, `web/` are Flutter scaffolding only — camera, native detection and Nearby Connections are mobile-only; these are not supported targets.
- Min Android is **26** (older docs said 21).

## Commands

```bash
flutter pub get
flutter run
flutter analyze
flutter test                 # see note below about test/widget_test.dart
flutter build apk --release
flutter build ios --release

# After editing lib/l10n/arb/app_*.arb (output is committed):
flutter gen-l10n             # l10n.yaml: arb-dir lib/l10n/arb, template app_en.arb, class AppLocalizations
```

Tests (`test/`): `activation_device_collision_test`, `screens/features/visagismo/{face_shape_classifier,face_analysis,frame_catalog,glasses_fit}_test`, `screens/features/measurements/optical_lens_mirror_test`, `screens/home/home_background_controller_test`. **`test/widget_test.dart` is the untouched Flutter "Counter" template from the first commit and always fails** (this app has no counter and `MyApp` needs Firebase) — ignore it or delete it, don't "fix" the app for it.

Strings: `context.l10n.someKey` (extension in `lib/l10n/l10n.dart`). Add every key to **all three** ARB files (`app_en.arb` is the template). The old docs mention `intl_utils:generate` — this repo uses Flutter's built-in `gen-l10n` (`flutter: generate: true`).

Icons/splash: `flutter_launcher_icons` (`assets/images/ic_launcher.png`) and `flutter_native_splash` (black background, `assets/images/splash_image.png`).

## Git workflow

Default branch `main`; work lands through pull requests from feature branches (e.g. `feature/visagismo-ar`). Other remote branches exist (`Panthoscopic`, `WIFI-SHARE`, `digitower-v1`, `digipad-simulation-3d-fixes`, `fix-digitower-misc`).

## Notes for AI agents

- **The code is the source of truth.** If this file and the code disagree, trust the code, then fix this file. An earlier version of these docs described a `native_impl/native_split_screen.dart` pantoscopic-angle bug in a file that was later refactored away; don't resurrect it.
- Product decisions live as dated comments in the code. "Hidden" ≠ "broken".
- `optical_editor_screen.dart` and `simulation_data.dart` are huge; read the relevant range, don't rewrite wholesale.
- For anything touching photo sync, visagismo or the angle formula, check `../digipad_totem` before calling the change done.
- Real-device behavior (camera, sensors, Nearby, native detection) can't be verified from unit tests or the simulator — say so instead of claiming it works.
