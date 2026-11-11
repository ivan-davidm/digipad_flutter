# DigiTower 3D Premium (Flutter) - Project Context

## Project Overview

**DigiTower 3D Premium** is a professional optical measurement and simulation app built with Flutter. It provides optical professionals with tools to:
- Measure and evaluate optical parameters using device sensors
- Simulate lens effects and corrections (cosmetic lenses, bifocals, photochromic, etc.)
- Process and analyze optical measurements through camera-based detection
- Perform cross-platform deployment (iOS/Android)

**Current Version:** 4.0.0 (build 27)
**SDK Requirement:** Dart 3.8.1 to <4.0.0

## Stack & Dependencies

### Core Framework
- **Flutter** (latest stable)
- **Dart** (3.8.1+)
- **BLoC** pattern for state management (`bloc: 9.1.0`, `flutter_bloc: 9.1.1`)

### Key Modules

#### Vision & Measurement
- **tflite_flutter** (0.12.1) - TensorFlow Lite for on-device ML detection
- **camera** (0.11.2+1) - Native camera integration
- **sensors_plus** (7.0.0) - **CRITICAL** - Accelerometer/gyroscope data for angle calculations
- **image** (4.7.2) - Image processing
- **image_picker** (1.2.1) - Gallery & camera selection
- **exif** (3.3.0) - EXIF metadata extraction

#### Data & Storage
- **sembast** (3.8.5+1) - Local NoSQL database
- **path_provider** (2.1.5) - File system access
- **shared_preferences** (2.5.3) - User preferences
- **firebase_core** & **cloud_firestore** - Cloud sync & analytics

#### UI/UX
- **Material Design 3** with custom theming
- **flutter_svg** (2.2.3) - SVG asset rendering
- **auto_size_text** (3.0.0) - Responsive text
- **provider** (6.1.5+1) - Additional state management
- **cached_network_image** (3.4.1) - Image caching

#### Platform Integration
- **permission_handler** (12.0.1) - Permission management (camera, gallery, location)
- **device_info_plus** (10.1.1) - Device information
- **geolocator** (14.0.2) - Location services
- **nearby_connections** (4.3.0) - Peer-to-peer sync
- **connectivity_plus** (7.0.0) - Network monitoring

#### Localization
- **intl** (0.20.2) - Internationalization framework
- **ARB format** files in `lib/l10n/arb/` for translations

## Project Structure

```
lib/
├── main.dart                      # App entry point, orientation & Firebase setup
├── home_view.dart                 # Home navigation
├── splash_screen.dart             # Launch screen
├── digi_locale.dart               # Locale configuration
├── firebase_options.dart          # Firebase config
│
├── common/                        # Shared components
│   ├── components/                # Reusable UI widgets
│   ├── managers/                  # Image & SVG managers
│   └── utils/                     # Responsive utilities
│
├── core/                          # Core utilities
│   └── utils/                     # Image rotation, etc.
│
├── data/                          # Data layer
│   └── local/                     # Gallery storage, local persistence
│
├── l10n/                          # Localization
│   └── arb/                       # ARB translation files
│
├── measurements/                  # MEASUREMENTS MODULE (UI placeholder)
│   └── measurements_screen.dart   # Empty screen - feature placeholder
│
├── screens/                       # Main feature screens
│   ├── activation/                # App activation/onboarding
│   │   ├── cubit/                 # State management
│   │   ├── data/                  # Service layer
│   │   └── presentation/          # UI widgets
│   │
│   ├── features/                  # Core optical features
│   │   ├── cosmetic_lenses/       # Cosmetic lens simulation
│   │   ├── lenses_3d/             # 3D lens visualization
│   │   └── simulations/           # 9+ lens simulation types
│   │
│   └── native_impl/               # Native camera & optical engine
│       ├── native_split_screen.dart     # **Camera capture + angle measurement**
│       ├── optical_editor_screen.dart   # Post-capture editing UI
│       ├── optical_logic_controller.dart # Optical math & geometry
│       ├── optical_painter.dart         # Canvas rendering of detections
│       └── optical_models.dart          # Data structures
│
└── features/                      # Cross-cutting features
    └── nearby_sync/               # Peer-to-peer device sync
```

## Critical Module: MEASUREMENTS & SENSOR INTEGRATION

### Location: `lib/screens/native_impl/native_split_screen.dart`

The "measurements" module is currently **a placeholder UI** (`lib/measurements/measurements_screen.dart`), but **the real measurement logic** is in `native_split_screen.dart`, which:

1. **Captures photos** from the device camera
2. **Detects optical landmarks** (circles, eye centers) via TFLite
3. **Measures device orientation** using the accelerometer to calculate the **pantoscopic angle**
4. Navigates to `OpticalEditorScreen` to refine and edit measurements

### 🐛 BUG: PANTOSCOPIC ANGLE CALCULATION (CRITICAL)

**Status:** Last commit (May 12, 2026) introduced incorrect angle calculation.

**Location:** Lines 61-76 in `native_split_screen.dart`

**Problem:**
```dart
final newPitch = atan2(-x, sqrt(y * y + z * z)) * (180 / pi);
final newRoll = atan2(y, z) * (180 / pi);
```

The code calculates a **horizontal angle** instead of the **vertical pantoscopic angle** on the device axis.

**Expected Behavior:**
- **Pantoscopic angle** = vertical tilt angle of the device (pitch) around the horizontal axis that passes through the lenses
- When device is vertical (lenses facing user): angle ≈ 0°
- When device is tilted down (lenses toward nose): angle ≈ 15-20° (typical natural reading angle)
- When device is tilted up (lenses toward forehead): angle ≈ -15-20°

**Actual Behavior:**
- Current formula calculates horizontal roll/tilt, not vertical pitch
- Angle values are meaningless for optical measurement context

**Root Cause:**
Confusion between accelerometer axes:
- X = side-to-side (left/right)
- Y = forward-backward (user pushing device away/toward)
- Z = vertical (up/down)

Pantoscopic angle should use **Y and Z** (forward-backward + vertical), not X.

**Correct Formula (preliminary):**
```dart
// Pitch (vertical tilt around the horizontal axis)
final newPitch = atan2(-y, sqrt(x * x + z * z)) * (180 / pi);
```

**Related Code:**
- Line 346: `_buildInclinometerOverlay()` displays the angle (expects 0-15° range)
- Line 369: UI shows angle as `${_pantoscopicAngle.toStringAsFixed(1)}°`
- Lines 701, 789, 800, 1010: Angle is captured and passed to `OpticalEditorScreen`

### Accelerometer Data Flow

```
sensors_plus.accelerometerEvents
    ↓
_accelerometerSubscription (line 61)
    ↓
Calculate pitch & roll from (x, y, z)
    ↓
setState() → _pantoscopicAngle, _rollAngle
    ↓
_buildInclinometerOverlay() shows real-time feedback
    ↓
_capturePhoto() / _pickImage() → stores angle in _lastPhotoPantoscopicAngle
    ↓
OpticalEditorScreen receives angle for measurement refinement
```

## Architecture Patterns

### State Management
- **BLoC Pattern** for screen state (Activation, Cosmetic Lenses, Simulations, Lenses 3D)
- **ValueNotifier** for simple toggle state (`_galleryModeNotifier` in native_split_screen.dart)
- **Provider** for cross-widget dependencies

### Separation of Concerns
- **Cubit** layer: State logic (`activation_cubit.dart`, `simulations_cubit.dart`)
- **Data** layer: Service/repository logic (`activation_service.dart`, `gallery_storage.dart`)
- **Presentation** layer: UI widgets

### Localization
- ARB files define all translatable strings
- `context.l10n.xxx` pattern for runtime string access
- Supports multiple languages (detect from device locale or let user choose)

## Key Screens & Features

| Screen | Module | Purpose |
|--------|--------|---------|
| **ActivationWrapper** | activation/ | Onboarding, license activation |
| **Cosmetic Lenses** | cosmetic_lenses/ | Apply cosmetic lens overlays to photos |
| **Lenses 3D** | lenses_3d/ | 3D lens visualization |
| **Simulations** | simulations/ | 9+ lens condition simulations (myopia, bifocal, etc.) |
| **NativeSplitScreen** | native_impl/ | **Camera capture + pantoscopic angle measurement** |
| **OpticalEditorScreen** | native_impl/ | Refine detection points & measurements |

## Data Contracts

### Photo Processing Pipeline
1. Capture from camera or pick from gallery
2. Resize image for TFLite (max 1920px, preserving aspect ratio)
3. Send to native bridge via `invokeMethod('detectFromImage', {'path': path})`
4. Parse detections: `{'circles': [...], 'eyes': [...]}`
5. If 4 circles detected → navigate to editor
6. If <4 circles → show error snackbar

### Angle Measurement
- Accelerometer sampled continuously
- Angle stored when photo is captured
- Passed to `OpticalEditorScreen` for display/refinement
- **Currently broken** — formula returns wrong axis

## Platform-Specific Notes

### Android
- Min SDK: 21
- Uses `AndroidView` for native camera rendering
- MethodChannel `'native-left-view/$id'` for communication

### iOS
- Uses `UiKitView` for native camera rendering
- Same MethodChannel protocol as Android

### Orientation
- **Forced to portrait** (`DeviceOrientation.portraitUp/Down`) in main.dart
- Camera displays in landscape internally via native views

## Permissions

Required (request at runtime):
- **Camera** - Photo capture
- **Photos/Gallery** - Gallery import on Android
- **Location** (optional) - Geolocator feature

## Configuration & Environment

- **Firebase** optional (initialization fails gracefully)
- **TFLite models** expected at `assets/model3.tflite` & `assets/labels.txt`
- **Translations** auto-generated from ARB files during build (`flutter pub run intl_utils:generate`)

## Next Steps for Development

1. **Fix pantoscopic angle calculation** (lines 61-76)
   - Update formula to use correct accelerometer axes
   - Test with device in various orientations
   - Verify values are 0-15° when tilted naturally

2. **Implement real measurements module** (currently stub in `lib/measurements/measurements_screen.dart`)
   - Consider housing `NativeSplitScreen` or reference it
   - Add measurement history/tracking UI

3. **Enhance optical detection accuracy**
   - Fine-tune TFLite model thresholds
   - Add fallback detection methods

4. **Cross-platform testing**
   - Test on real iOS & Android devices
   - Verify MethodChannel communication works
   - Profile ML inference performance

## Common Commands

```bash
# Get dependencies
flutter pub get

# Run dev build
flutter run

# Build for Android
flutter build apk --release

# Build for iOS
flutter build ios --release

# Generate localization
flutter pub run intl_utils:generate

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Notes for AI Agents

- **Always verify sensor axis assumptions** before modifying angle calculations
- The accelerometer is the **source of truth** for device orientation
- Visual feedback in `_buildInclinometerOverlay()` helps debug angle values
- Changes to `native_split_screen.dart` affect photo capture quality
- Tests should include orientation simulation (portrait, landscape, tilted)
