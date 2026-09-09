plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

// The watch app shares the phone app's applicationId so Play lists it as a
// form factor of OpenVitals, not as a second app. Same rules follow: every
// artifact in one listing needs a unique versionCode, so the watch owns the
// range 2_000_000_000 to 2_099_999_999. The phone counter stays below that.
// Play caps versionCode at 2_100_000_000.
val wearVersionCodeBase = 2_000_000_000
val wearBaseVersionCode = wearVersionCodeBase + 1
val wearBaseVersionName = "1.0.0"
val wearVersionCodeOverride = providers.environmentVariable("OPENVITALS_WEAR_VERSION_CODE")
    .map { it.toInt() }
val wearVersionNameOverride = providers.environmentVariable("OPENVITALS_WEAR_VERSION_NAME")
val wearVersionCode = wearVersionCodeOverride.orElse(wearBaseVersionCode).get()
require(wearVersionCode in (wearVersionCodeBase + 1)..2_099_999_999) {
    "OPENVITALS_WEAR_VERSION_CODE $wearVersionCode is outside the watch range " +
        "${wearVersionCodeBase + 1}..2099999999. Phone codes live below it."
}

android {
    // Kotlin namespace stays under .wear; only the applicationId is shared.
    namespace = "tech.mmarca.openvitals.wear"
    compileSdk = 37
    buildToolsVersion = "37.0.0"

    defaultConfig {
        applicationId = "tech.mmarca.openvitals"
        minSdk = 30
        targetSdk = 36
        versionCode = wearVersionCode
        versionName = wearVersionNameOverride.orElse(wearBaseVersionName).get()
    }

    buildTypes {
        // Same suffix as the phone debug build, so a debug watch pairs with a
        // debug phone.
        debug {
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }

        // R8 on, the same way the phone app does it. The newer
        // optimization.enable DSL needs an experimental AGP flag.
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    val composeBom = platform(libs.androidx.compose.bom)
    implementation(composeBom)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.wear.compose.material)
}
