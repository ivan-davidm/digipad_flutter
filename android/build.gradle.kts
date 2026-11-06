buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // See settings.gradle.kts for why this was bumped from 8.7.3.
        classpath("com.android.tools.build:gradle:8.9.1")
        // See settings.gradle.kts for why this was bumped from 2.2.0.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.10")
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")

    configurations.all {
        resolutionStrategy {
            force("androidx.concurrent:concurrent-futures:1.1.0")
        }
    }

    plugins.withId("com.android.library") {
        dependencies {
            add("implementation", "androidx.concurrent:concurrent-futures:1.1.0")
        }
    }

    plugins.withId("com.android.application") {
        dependencies {
            add("implementation", "androidx.concurrent:concurrent-futures:1.1.0")
        }
    }

}

// gradle.afterProject fires for each project AFTER it's fully evaluated (including libraries).
// This ensures minSdk=23 wins over "minSdkVersion flutter.minSdkVersion" (= 24 hardcoded in
// FlutterExtension.kt). Required for Lenovo YT3 X50F (Android 6.0.1, API 23).
gradle.afterProject {
    if (this == rootProject) return@afterProject
    val android = extensions.findByName("android") ?: return@afterProject
    try {
        val defaultConfig = android.javaClass.getMethod("getDefaultConfig").invoke(android)
        val methods = defaultConfig.javaClass.methods
        val setMinSdk = methods.find { it.name == "setMinSdk" && it.parameterCount == 1 }
            ?: methods.find { it.name == "setMinSdkVersion" && it.parameterCount == 1 }
        setMinSdk?.invoke(defaultConfig, 23)
    } catch (e: Exception) {
        // Non-fatal
    }
}

// `receive_sharing_intent` 1.8.1's own build.gradle (pinned there — 1.9.0's
// has an unrelated Gradle DSL bug) declares no Java compileOptions at all,
// so it falls back to an old default (1.8) that mismatches whatever Kotlin
// target this project graph resolves to, failing the build with
// "Inconsistent JVM Target Compatibility". Reusing the same proven
// gradle.afterProject timing as the minSdk fix above (a blanket
// subprojects{}-level override tried first raced against — and lost to —
// AGP's own internal compileOptions wiring for other, unrelated plugins
// like camera_android_camerax that were already working fine, so this is
// scoped to just this one project instead of every subproject).
gradle.afterProject {
    if (project.name != "receive_sharing_intent") return@afterProject
    val android = extensions.findByName("android") ?: return@afterProject
    try {
        val compileOptions = android.javaClass.getMethod("getCompileOptions").invoke(android)
        val jvm17 = JavaVersion.VERSION_17
        compileOptions.javaClass.getMethod("setSourceCompatibility", JavaVersion::class.java)
            .invoke(compileOptions, jvm17)
        compileOptions.javaClass.getMethod("setTargetCompatibility", JavaVersion::class.java)
            .invoke(compileOptions, jvm17)
    } catch (e: Exception) {
        // Non-fatal
    }
    // Java side fixed above; Kotlin's own default jvmTarget for this project
    // resolves to 21 (not inferred from the Java side) under this Kotlin
    // Gradle Plugin version, so it needs its own matching override. Per-task
    // (not `kotlin { jvmToolchain(...) }`) on purpose: the toolchain
    // extension's `languageVersion` property gets finalized/locked once
    // Gradle resolves it, and failed with "the value for property
    // 'languageVersion' is final" when tried first; a plain task property
    // assignment doesn't touch that property at all.
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
