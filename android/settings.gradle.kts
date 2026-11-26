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
    // AGP 9 + Gradle 9.5 (wrapper): required by Flutter 3.50. The opt-outs in
    // gradle.properties (builtInKotlin/newDsl = false) keep the AGP 8
    // behaviour Flutter plugins still expect — remove them once plugins
    // support AGP 9's defaults (they go away in a future AGP).
    id("com.android.application") version "9.3.1" apply false
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
