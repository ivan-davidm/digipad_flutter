# DigiTower 3D Premium - Quick Reference for Developers

## 🎯 Current Issue (Critical)

**Pantoscopic Angle Calculation is BROKEN**

**File:** `lib/screens/native_impl/native_split_screen.dart`, lines 67-68

**Problem:** Measures horizontal roll instead of vertical pitch

**Current (Wrong):**
```dart
final newPitch = atan2(-x, sqrt(y * y + z * z)) * (180 / pi);
```

**Should Be:**
```dart
final newPitch = atan2(-y, sqrt(x * x + z * z)) * (180 / pi);
```

**Why:** Pantoscopic angle needs forward-backward (Y) axis, not left-right (X) axis.

---

## 📁 Project Structure

```
lib/
├── measurements/           ← STUB (empty, just UI placeholder)
├── screens/native_impl/    ← **REAL MEASUREMENTS HERE**
│   ├── native_split_screen.dart         (camera + angle capture) ⚠️ BUG
│   ├── optical_editor_screen.dart       (post-capture editing)
│   ├── optical_logic_controller.dart    (optical math)
│   └── optical_painter.dart             (rendering)
├── screens/features/       ← Feature screens (cosmetic lenses, 3D, simulations)
├── screens/activation/     ← Onboarding
└── ... other modules
```

---

## 🔧 Key Technologies

| What | Tech | Why |
|------|------|-----|
| **State** | BLoC + Cubit | Clean, testable, scalable |
| **Camera** | Android/iOS native view | Fast, full control |
| **Detection** | TFLite (on-device ML) | Offline, privacy-preserving |
| **Orientation** | sensors_plus accelerometer | Device tilt measurement |
| **Localization** | ARB format | Multi-language support |
| **Storage** | Sembast + SharedPreferences | Local persistence |
| **Backend** | Firebase (optional) | Cloud sync, analytics |

---

## 📊 Data Flow

```
Camera Stream / Gallery Image
  ↓
sensors_plus.accelerometerEvents (real-time orientation)
  ↓
Calculate pantoscopic angle ← **BUG IS HERE** (wrong formula)
  ↓
Show angle overlay (expect 0-15° range)
  ↓
User taps to capture
  ↓
Native code: TFLite detection of 4 circles + pupil centers
  ↓
If successful → OpticalEditorScreen (refine measurements)
If failed → Show error, ask to retake
```

---

## 🐛 Debugging the Angle

### Quick Check
1. Enter camera screen
2. Look at angle overlay (top-right)
3. Tilt device naturally (like reading)
4. Expected: Should show **+10° to +15°**
5. Currently: Shows wrong value (likely outside this range)

### How to Verify Fix
**Before Fix:**
- Device vertical = random value
- Device tilted forward = doesn't increase (or decreases)
- Overlay green/red borders don't match device tilt

**After Fix:**
- Device vertical = ~0°
- Device tilted forward = increases to +15°
- Overlay border changes smoothly, matches physical tilt

---

## 🎮 Common Tasks

### Run the app
```bash
flutter run
```

### Build for Android
```bash
flutter build apk --release
```

### Build for iOS
```bash
flutter build ios --release
```

### Fix the angle bug
1. Open `lib/screens/native_impl/native_split_screen.dart`
2. Find lines 67-68
3. Change `atan2(-x, ...)` to `atan2(-y, ...)`
4. Test on real device in various tilts
5. Commit: "fix: correct pantoscopic angle calculation (use Y-axis instead of X)"

### Add new localization string
1. Open `lib/l10n/arb/app_en.arb` (English)
2. Add: `"newStringKey": "English text"`
3. Open `lib/l10n/arb/app_es.arb` (Spanish, if supported)
4. Add same key + translation
5. Use: `context.l10n.newStringKey`

### Access camera in code
Already done in `native_split_screen.dart` — it's the reference for camera integration

---

## 📋 File Guide

| File | Lines | Purpose |
|------|-------|---------|
| `native_split_screen.dart` | 1033 | **Camera capture + angle measurement** |
| `optical_editor_screen.dart` | 1300+ | Post-capture UI, measurement refinement |
| `optical_logic_controller.dart` | ~350 | Optical geometry calculations |
| `optical_painter.dart` | ~250 | Canvas rendering of detected points |
| `main.dart` | 95 | App setup, orientation lock, Firebase |
| `measurements_screen.dart` | 36 | **STUB** — Empty placeholder |

---

## ⚠️ Common Pitfalls

1. **Accelerometer axes are confusing** — Always verify on device
2. **Formula sign errors** — atan2 is sensitive to argument order
3. **Native channel latency** — Camera methods are async
4. **Permission checks** — Always check before camera/gallery access
5. **Flutter hot reload** — May not reload MethodChannel handlers; do full restart

---

## 🧪 Testing Checklist

- [ ] Can open camera without crashing
- [ ] Angle displays in overlay
- [ ] Angle changes when device tilted
- [ ] Angle is 0° when device vertical
- [ ] Angle is +15° when tilted forward (reading posture)
- [ ] Can capture photo
- [ ] Photo navigates to OpticalEditorScreen
- [ ] Angle is passed to editor correctly

---

## 📚 Full Documentation

- **CLAUDE.md** — Complete project context
- **docs/MEASUREMENTS_BUG_ANALYSIS.md** — Deep dive on the bug
- **Memory Index** — Cross-session persistent context

---

## 💡 Tips

- **Stuck?** Check `CLAUDE.md` for full context
- **Debugging angle?** Enable print statements in accelerometer listener
- **Need sensors data?** `sensors_plus` has gyro too, not just accelerometer
- **Camera fails on iOS?** Check `ios/Runner/Info.plist` for camera permission description
- **MethodChannel not responding?** Verify native code is actually built

---

## 📞 Contact / Notes

Project is owned by: [digipad.io](https://digipad.io) or repo author

Last updated: May 2026
Bug discovered: May 12, 2026 (introduced in angle calculation commit)
Status: Ready to fix
