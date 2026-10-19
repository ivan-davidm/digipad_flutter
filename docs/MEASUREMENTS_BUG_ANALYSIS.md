# Pantoscopic Angle Calculation Bug - Technical Analysis

## Executive Summary

The pantoscopic angle calculation in `lib/screens/native_impl/native_split_screen.dart` (lines 61-76) is **returning the wrong axis of rotation**. It measures horizontal roll when it should measure vertical pitch.

**Impact:** Optical measurements are meaningless; users cannot accurately record device orientation during measurement.

**Severity:** HIGH (functional requirement)

**Status:** Ready to fix

---

## Background: What is Pantoscopic Angle?

### Optical Definition
In ophthalmic/optical contexts, **pantoscopic angle** (also called "pantoscopic tilt" or "face form tilt") is the vertical inclination of eyeglasses relative to the wearer's face and line of sight.

### Physical Meaning
When a wearer looks straight ahead:
- **0° pantoscopic angle** = lenses are perpendicular to the ground (vertical plane)
- **+15° pantoscopic angle** = lenses tilted down/forward naturally (typical reading posture)
- **-15° pantoscopic angle** = lenses tilted up/backward (uncommon, head-back posture)

### Why It Matters for DigiTower 3D
1. **Lens Power Distribution** — Pantoscopic angle affects where progressive lens zones sit relative to the pupil
2. **Optical Aberrations** — Tilt introduces prism and spherical aberration
3. **Simulation Accuracy** — Without knowing the device tilt, simulations are meaningless
4. **Clinical Measurement** — Optical professionals need accurate device orientation during measurement

---

## The Bug in Detail

### Current Implementation (Lines 61-76)

```dart
_accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
  if (!mounted) return;
  final x = event.x;
  final y = event.y;
  final z = event.z;

  final newPitch = atan2(-x, sqrt(y * y + z * z)) * (180 / pi);
  final newRoll = atan2(y, z) * (180 / pi);

  if ((newPitch - _pantoscopicAngle).abs() > 0.3) {
    setState(() {
      _pantoscopicAngle = newPitch;
      _rollAngle = newRoll;
    });
  }
});
```

### Problem Analysis

#### 1. **Wrong Axis Selection**
The code uses `atan2(-x, sqrt(y * y + z * z))` for `newPitch`, which:
- Takes the **X-axis** (side-to-side tilt)
- Calculates roll around a front-to-back axis
- **Does not measure pantoscopic angle** (which should use forward-backward axis)

#### 2. **Axis Confusion**
The developer likely confused:
- **Roll** (rotation around front-back axis, side-to-side tilt) ← currently measuring
- **Pitch** (rotation around left-right axis, forward-backward tilt) ← should measure

#### 3. **Variable Naming**
The variable is called `newPitch`, but the formula calculates roll. This suggests the developer knew the intent but got the math wrong.

---

## Accelerometer Axes (iOS/Android Standard)

On a device held in portrait (top of screen at top):

```
        Z (up/down)
        ↑
        |
        |  X (left/right)
Y ←-----+
(forward/back)

Axes Follow Right-Hand Rule:
X × Y = Z
Y × Z = X
Z × X = Y
```

### Per-Axis Rotation
| Axis | Name | Movement | Example |
|------|------|----------|---------|
| **X-axis** | Roll | Left-right tilt (like rolling head side-to-side) | Device tilted left/right |
| **Y-axis** | Pitch | Forward-backward tilt (like nodding) | Device tilted toward/away from body |
| **Z-axis** | Yaw | Spin around vertical (like turning face) | Device rotated in portrait plane |

### For Pantoscopic Angle
- **Relevant axes:** Y (forward-back) + Z (vertical)
- **Irrelevant axis:** X (left-right) — doesn't affect pantoscopic angle
- **Current code:** Uses X axis ❌

---

## The Correct Formula

### Option 1: Standard Pitch Formula
```dart
// Pitch: tilt around the left-right (X) axis
// Positive = tilted forward (device away from body) = positive pantoscopic angle
final newPitch = atan2(-y, sqrt(x * x + z * z)) * (180 / pi);
```

**Explanation:**
- `atan2(-y, sqrt(x*x + z*z))` measures angle between -Y vector and the XZ plane
- When Y is negative (device tilted toward you), angle is positive
- Denominator `sqrt(x*x + z*z)` is the "up" reference plane
- **Range:** -90° to +90° (we'll see ~-15° to +15° in practice)

### Option 2: Alternative (if Y-axis is inverted)
```dart
final newPitch = atan2(y, sqrt(x * x + z * z)) * (180 / pi);
```

**Use this if:**
- Device axes are reversed on your platform
- Testing shows inverted values

### Verification Method

**Test 1: Device Vertical**
- Hold device straight up (lenses facing you)
- Expected angle: close to 0° (±2°)
- If angle is 80-90°, axes are wrong

**Test 2: Device Tilted Down (Natural Reading)**
- Tilt device forward like reading a book
- Expected angle: +10° to +15°
- If angle goes to -10° to -15°, try Option 2

**Test 3: Device Tilted Up**
- Tilt device backward (head-back posture)
- Expected angle: -10° to -15°
- If angle goes to +10° to +15°, try Option 2

---

## Files to Modify

### Primary Fix
**File:** `lib/screens/native_impl/native_split_screen.dart`

**Lines to change:** 67-68
```dart
// OLD (BROKEN):
final newPitch = atan2(-x, sqrt(y * y + z * z)) * (180 / pi);
final newRoll = atan2(y, z) * (180 / pi);

// NEW (CORRECT):
final newPitch = atan2(-y, sqrt(x * x + z * z)) * (180 / pi);
final newRoll = atan2(x, z) * (180 / pi);  // Optional: also fix roll for consistency
```

### Secondary Changes (Optional)
- **Line 346:** `_buildInclinometerOverlay()` expects range 0-15°, which is now correct
- **Line 70:** Threshold `0.3` may need adjustment if values stabilize better now
- **Comments:** Add explanation of axes to prevent future confusion

---

## Testing Plan

### Unit Test (If Available)
```dart
// Test pantoscopic angle calculation
void testPantoscopicAngleCalculation() {
  // Device vertical (no tilt)
  double angle = calculatePitch(x: 0, y: 0, z: 9.8);
  expect(angle, closeTo(0, 2));  // Within ±2°

  // Device tilted forward
  double angle = calculatePitch(x: 0, y: -3, z: 9);
  expect(angle, greaterThan(10));  // Should be +10°+
}
```

### Manual Testing on Device

#### Setup
1. Install app on test device
2. Navigate to `NativeSplitScreen` (camera capture screen)
3. Watch the angle display in the top-right overlay

#### Test Cases
| Device Position | Expected Angle | What to Look For |
|-----------------|-----------------|-----------------|
| Vertical (normal) | 0° ± 2° | Overlay shows near-zero |
| Tilted forward slightly | +5° to +10° | Overlay increases when tilted toward body |
| Tilted forward more (reading) | +15° to +20° | Overlay reaches natural reading angle |
| Tilted backward | -5° to -15° | Overlay shows negative when tilted away |
| Horizontal (lying) | ±90° | Angle caps at ±90° (edge case) |

#### Visual Verification
- **Green border** on overlay = good angle (0-15°)
- **Red border** on overlay = bad angle (outside 0-15°)
- **Smooth transitions** as you tilt (currently may be erratic)

---

## Impact Assessment

### Before Fix
- ❌ Angle measurements are wrong (horizontal instead of vertical)
- ❌ UI overlay shows meaningless values
- ❌ Photos stored with incorrect angle data
- ❌ OpticalEditorScreen receives garbage angle

### After Fix
- ✅ Angle matches physical device tilt
- ✅ Users can reliably capture device orientation
- ✅ Optical simulations become accurate
- ✅ Measurement history is meaningful

### Breaking Changes
- **None** — This is a bug fix, not an API change
- The `_pantoscopicAngle` variable will have correct values; any code reading it will benefit

### Backward Compatibility
- ⚠️ Stored angles from buggy version are garbage — may want to invalidate old data
- Consider adding a version flag if re-displaying old measurements

---

## Code Review Checklist

When implementing the fix:

- [ ] Change formula on lines 67-68
- [ ] Test on real Android device (multiple orientations)
- [ ] Test on real iOS device (multiple orientations)
- [ ] Verify overlay shows 0-15° range for typical use
- [ ] Check that `_lastPhotoPantoscopicAngle` is stored correctly
- [ ] Verify OpticalEditorScreen receives correct angle
- [ ] Add comment explaining axes (prevent future confusion)
- [ ] Consider removing unused `_rollAngle` if not needed elsewhere
- [ ] Update line 1010 comment if it exists

---

## Related Code Sections

### Display
**File:** `native_split_screen.dart`, line 345-379
```dart
Widget _buildInclinometerOverlay() {
  final isGoodAngle = _pantoscopicAngle >= 0 && _pantoscopicAngle <= 15;
  // Renders the overlay with angle value
}
```

### Storage
**File:** `native_split_screen.dart`, lines 789, 999
```dart
_lastPhotoPantoscopicAngle = angle;  // Stores during photo capture
```

### Consumption
**File:** `optical_editor_screen.dart` (lines unknown)
```dart
pantoscopicAngle: _lastPhotoPantoscopicAngle  // Passed to editor
```

---

## References

### Physics
- **Euler Angles:** https://en.wikipedia.org/wiki/Euler_angles
- **Accelerometer Orientation:** Android: https://developer.android.com/guide/topics/sensors/sensors_position#sensors-pos-accel
- **atan2 Function:** https://en.wikipedia.org/wiki/Atan2

### Optics
- **Pantoscopic Angle:** Ophthalmic Optics (2015) — Standard definition in eyeglasses fitting
- **Face Form Angle:** Brookman, R.R. (2004). Ophthalmic Optics 3rd Edition

---

## Summary

| Item | Details |
|------|---------|
| **Bug Type** | Formula error (axis confusion) |
| **Severity** | HIGH |
| **File(s)** | `lib/screens/native_impl/native_split_screen.dart` |
| **Lines** | 67-68 |
| **Fix Complexity** | LOW (one-line formula change) |
| **Test Complexity** | MEDIUM (requires device orientation testing) |
| **Risk** | LOW (fixing obvious bug, no breaking changes) |
| **Time to Fix** | 15-30 minutes (code + manual testing) |
