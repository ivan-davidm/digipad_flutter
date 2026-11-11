pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // Bumped from 8.7.3: SceneView 4.31.0 (Visagismo AR feature) pulls in
    // androidx.core:core-ktx 1.18.0, which requires AGP 8.9.1+. Gradle 8.13
    // (already the project's wrapper version) supports this AGP line.
    id("com.android.application") version "8.9.1" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version("4.3.15") apply false
    // END: FlutterFire Configuration
    // Bumped from 2.2.0: SceneView 4.31.0 pulls in kotlin-stdlib 2.4.10,
    // whose metadata the 2.2.0 compiler can't read (collateral compile
    // errors across unrelated files once that stdlib wins dependency
    // resolution). Match the plugin version to the stdlib it forces in.
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
}

include(":app")
