plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "tech.mmarca.openvitals"
    // Kotlin source used compileSdk 37 (an Android preview SDK). The Flutter port
    // pins the stable compileSdk that this Flutter release ships with (36), which
    // satisfies every plugin (health, flutter_local_notifications 22, etc.) and
    // builds against a standard installed SDK. Bump if a plugin needs newer.
    compileSdk = flutter.compileSdkVersion
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
