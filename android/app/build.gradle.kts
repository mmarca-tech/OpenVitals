plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tech.mmarca.openvitals"
    // compileSdk 37 matches the reference Kotlin app. connect-client 1.2.0-alpha04
    // (pulled by the health_connect_native plugin, on AGP 9.1.1) resolves its newer
    // record/permission mappings against API 37, so the app module compiles against
    // the same SDK. The android-37.0 platform must be installed.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications' AAR metadata mandates Java 8+ core-library
        // desugaring (it relies on desugared java.time APIs), so enable it here.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "tech.mmarca.openvitals"
        // minSdk 26: required by Health Connect (androidx.health) and matches the
        // Kotlin source. This is above the Flutter default (24).
        minSdk = 26
        // targetSdk 36 matches the Kotlin source (and the current Flutter default).
        targetSdk = 36
        // versionName / versionCode are driven by pubspec (`version: 1.8.0+107030340`),
        // mirroring the Kotlin source's baseVersionName 1.8.0 / baseVersionCode.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // Mirrors the Kotlin source's debug build type. Without the suffix a
            // debug build shares `tech.mmarca.openvitals` with the installed
            // release app: the install fails on the signature mismatch, and
            // uninstalling to force it would destroy that app's health data.
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required by flutter_local_notifications (see coreLibraryDesugaring above).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
