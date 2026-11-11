# DigiTower 3D Testing Guide - Pantoscopic Angle Fix

## Overview
This guide walks you through testing the pantoscopic angle fix on a real device.

**Estimated Time:** 10-15 minutes per platform (Android/iOS)

---

## Pre-Test Setup

### 1. Deploy the Fixed Build

```bash
# Option A: Run on connected device (debug)
flutter run

# Option B: Build for manual installation
flutter build apk --release        # Android
flutter build ios --release        # iOS
```

### 2. Have a Comparison Tool
- **Recommendation:** Use the device's built-in accelerometer app or third-party accelerometer viewer
- This lets you compare DigiTower 3D's angle against a reference implementation

### 3. Prepare Test Environment
- **Quiet location** with no obstructions (won't affect testing, but better for photos)
- **Good lighting** (camera will be tested)
- **Clear desk/table** where you can rest device at different angles

---

## Test Protocol

### Phase 1: Angle Display Validation

#### Test 1.1: Device Vertical (Baseline)
**Objective:** Verify angle is near 0° when device is upright

**Steps:**
1. Open DigiTower 3D
2. Navigate to camera screen (`NativeSplitScreen`)
3. Hold device **perfectly vertical** in front of you
   - Top of screen pointing up
   - Device facing you directly
4. Look at the angle overlay (top-right corner)

**Expected Result:**
- Angle reads **0° ± 2°** (e.g., -1.2° to +1.8° is OK)
- Overlay has **GREEN border** (good angle)

**If Failed:**
- ❌ Angle shows 80-90°: axes are inverted; use `atan2(y, ...)` instead of `atan2(-y, ...)`
- ❌ Angle shows large negative: try `atan2(y, ...)` (inverted)
- ❌ Angle drifts: accelerometer calibration issue (less critical)

---

#### Test 1.2: Natural Reading Angle
**Objective:** Verify angle is +15° when tilted like reading

**Steps:**
1. Maintain device vertical
2. **Smoothly tilt the device forward** as if reading a book
   - Top of screen should tilt toward your face
   - This mimics natural eyeglass wear angle
3. Watch the angle overlay change in real-time

**Expected Result:**
- Angle **increases smoothly** from 0° to ~15°
- Overlay **turns GREEN** when angle is 0-15° range
- No lag or jumping (smooth transitions)

**If Failed:**
- ❌ Angle goes **negative** instead of positive: formula uses wrong sign; try removing the `-` from `atan2(-y, ...)`
- ❌ Angle **decreases** instead of increases: axes are reversed; negate the entire formula
- ❌ Angle is jerky/jumpy: accelerometer noise (tuning needed, not critical for correctness)

---

#### Test 1.3: Tilted Back (Head-Back Posture)
**Objective:** Verify angle is **negative** when tilted backward

**Steps:**
1. From vertical (0°), **tilt the device backward** (away from your face)
   - This is unnatural, but tests the negative range
2. Tilt to approximately -15° position

**Expected Result:**
- Angle **decreases** from 0° to **negative** values (e.g., -10° to -15°)
- Overlay turns **RED** (outside good range)

**If Failed:**
- ❌ Angle becomes positive: formula is backwards
- ❌ Angle doesn't change: accelerometer issue

---

#### Test 1.4: Rotation Sensitivity
**Objective:** Verify angle responds quickly to tilt changes

**Steps:**
1. Rapidly tilt device forward and backward (vertical ↔ +15°)
2. Watch overlay for latency/lag

**Expected Result:**
- Overlay updates **smoothly and immediately** (within 100ms)
- No significant lag between physical tilt and displayed angle

**If Failed:**
- ⚠️ Overlay lags: sensor read rate issue, not formula issue (acceptable, tune later)
- ❌ Overlay doesn't respond: accelerometer listener not working

---

### Phase 2: Photo Capture & Angle Storage

#### Test 2.1: Capture with Good Angle
**Objective:** Verify angle is captured and passed to editor

**Steps:**
1. Position device at **natural reading angle** (~15°)
2. Tap the **camera button** (white circle, center-bottom)
3. If detection is successful → OpticalEditorScreen opens

**Expected Result:**
- Photo is captured
- Angle **displayed in OpticalEditorScreen** (if UI shows it)
- Angle value is approximately **15°** (or whatever angle you held it at)

**If Failed:**
- ❌ Photo doesn't open editor: detection failed (unrelated to angle bug)
- ❌ Angle in editor is wrong: variable not passed correctly; check line 1010

---

#### Test 2.2: Angle Persistence
**Objective:** Verify angle is stored in `_lastPhotoPantoscopicAngle`

**Steps:**
1. Capture photo at known angle (e.g., 10°)
2. Don't navigate away
3. Tap the **thumbnail** (bottom-left, gray border) to re-open editor

**Expected Result:**
- Same photo re-opens
- Angle matches original capture angle (should be ~10°)

**If Failed:**
- ❌ Angle changes: variable is not being stored; check line 789/1010

---

### Phase 3: Multi-Orientation Testing

#### Test 3.1: Rapid Orientation Changes
**Objective:** Verify angle calculation handles rapid changes

**Steps:**
1. Hold device vertical (0°)
2. Quickly alternate tilt: 0° → 15° → 0° → -15° → 0° (repeat 5 times)
3. Watch overlay for erratic behavior

**Expected Result:**
- Overlay smoothly follows tilts
- No "stuck" values
- No overshooting

---

#### Test 3.2: Landscape Mode (Edge Case)
**Objective:** Verify app doesn't crash in landscape (if supported)

**Steps:**
1. Rotate device to landscape
2. Watch angle overlay

**Expected Result:**
- App either locks to portrait (no change) OR handles landscape correctly
- No crashes

---

### Phase 4: Comparison Against Ground Truth

#### Option A: Using Reference App
**Prerequisite:** Install an accelerometer app (e.g., "Sensor Box for Android")

**Steps:**
1. Open **DigiTower 3D** and **reference app** side-by-side
2. Tilt device to a known angle
3. Compare displayed values

**Expected Result:**
- DigiTower 3D angle ≈ reference app angle (within ±2°)

---

#### Option B: Manual Angle Calculation
**If you don't have a reference app:**

**Steps:**
1. Tilt device to 45° angle (easiest to visualize)
2. Record DigiTower 3D's angle reading

**Expected Result:**
- Should be approximately **45°** (not 0°, not 90°, not negative)

---

## Regression Testing

After the fix, verify previous functionality still works:

### Camera Basics
- [ ] Camera stream displays (Android: AndroidView, iOS: UiKitView)
- [ ] Gallery mode toggle works
- [ ] Front/back camera toggle works
- [ ] Photo capture doesn't crash

### Detection
- [ ] Image with eyes detected → 4 circles found
- [ ] Image without eyes detected → error message shown
- [ ] Detected circles visible in overlay

### Navigation
- [ ] Can navigate back from camera screen
- [ ] Can navigate to OpticalEditorScreen after capture
- [ ] Can re-open recent photo via thumbnail

### Permissions
- [ ] Camera permission request works
- [ ] Gallery permission request works

---

## Logging & Debugging

If tests fail, enable debug logging:

### Add Temporary Logging
**File:** `lib/screens/native_impl/native_split_screen.dart`, line 70:

```dart
if ((newPitch - _pantoscopicAngle).abs() > 0.3) {
  debugPrint('Angle: x=$x, y=$y, z=$z → pitch=$newPitch (was ${_pantoscopicAngle})');
  setState(() {
    _pantoscopicAngle = newPitch;
    _rollAngle = newRoll;
  });
}
```

**In Flutter console, you'll see:**
```
flutter: Angle: x=0.1, y=-2.3, z=9.7 → pitch=13.4 (was 0.0)
flutter: Angle: x=-0.05, y=-4.1, z=9.2 → pitch=23.6 (was 13.4)
```

### Interpret Output
- **Large positive Y values with small Z** → device tilted toward you (correct for positive pitch)
- **Values should be smooth and monotonic** as you tilt
- **If values jump randomly** → accelerometer noise or bad formula

---

## Sign Convention Verification

If you suspect the sign is wrong, try this quick test:

**Test: Forward Tilt**
```
Device vertical:      y ≈ 0,    angle ≈ 0°
Device tilted forward: y ≈ -5,  angle ≈ +15°  (should increase)
Device tilted back:    y ≈ +5,  angle ≈ -15°  (should decrease)
```

If angle decreases when you tilt forward, try:
1. Remove the `-` from `atan2(-y, ...)` → `atan2(y, ...)`
2. Re-run tests

---

## Platform-Specific Notes

### Android
- Accelerometer response is typically **low-latency** (5-10ms)
- Test on multiple devices if possible (accelerometer calibration varies)
- If angle jumps wildly, check device's accelerometer calibration (Settings → Sensor calibration)

### iOS
- May need to **enable motion data** if app requests it
- Check `Info.plist` for `NSMotionUsageDescription`
- Accelerometer calibration typically better than Android

---

## Test Result Template

Print and fill this out for documentation:

```
Device Model: _______________
OS Version: _______________
DigiTower 3D Version: _______________
Test Date: _______________

Test Results:
[ ] 1.1 Vertical (0°) .......... PASS / FAIL
[ ] 1.2 Reading Tilt (+15°) ... PASS / FAIL
[ ] 1.3 Back Tilt (-15°) ...... PASS / FAIL
[ ] 1.4 Responsiveness ........ PASS / FAIL
[ ] 2.1 Photo Capture ......... PASS / FAIL
[ ] 2.2 Angle Persistence ..... PASS / FAIL
[ ] 3.1 Rapid Changes ......... PASS / FAIL
[ ] 3.2 Landscape Mode ........ PASS / FAIL
[ ] 4.x Comparison Test ....... PASS / FAIL

Issues Found:
__________________________

Notes:
__________________________
```

---

## Success Criteria

✅ **All tests PASS** if:
1. Angle is 0° ± 2° when vertical
2. Angle increases to +15° when tilted forward
3. Angle decreases to -15° when tilted back
4. Overlay border is GREEN for 0-15° range
5. Overlay border is RED outside that range
6. Angle changes smoothly (no jumps)
7. Angle is captured and stored correctly
8. Photos can still be captured and processed

❌ **Tests FAIL** if any of the above is not true.

---

## Next Steps After Fix Verification

1. **Push to main branch** with commit message:
   ```
   fix: correct pantoscopic angle calculation (use Y-axis instead of X)
   
   - Changed formula from atan2(-x, ...) to atan2(-y, ...)
   - Pantoscopic angle now correctly measures vertical pitch
   - Tested on [Device] with [OS version]
   ```

2. **Mark old measurements as invalid** (optional):
   - Add version flag to stored angle data
   - Show warning if viewing pre-fix measurements

3. **Update optical editor** if it displays angle:
   - Verify UI expectations (should now see 0-15° range correctly)

4. **Document in changelog:**
   - "Fixed pantoscopic angle calculation to use correct device axis"

---

## Questions?

- Review **CLAUDE.md** for project context
- Check **docs/MEASUREMENTS_BUG_ANALYSIS.md** for technical details
- Test incrementally; don't skip phases
