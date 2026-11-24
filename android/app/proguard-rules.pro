# android/app/proguard-rules.pro
-keep class org.tensorflow.** { *; }
-keep class com.ultralytics.** { *; }
-dontwarn org.tensorflow.**


# ML Kit finds its component registrars by reflection (no-arg constructors).
# Without this R8 strips them and ML Kit never initialises in release builds:
# every detection (faces) then fails with a NullPointerException.
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }
