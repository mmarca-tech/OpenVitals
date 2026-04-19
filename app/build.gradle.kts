plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

val releaseStoreFilePath = System.getenv("OPENVITALS_RELEASE_STORE_FILE")
val releaseStorePassword = System.getenv("OPENVITALS_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("OPENVITALS_RELEASE_KEY_ALIAS")
val releaseKeyPassword = System.getenv("OPENVITALS_RELEASE_KEY_PASSWORD")
val isPkcs12ReleaseStore = releaseStoreFilePath
    ?.lowercase()
    ?.let { it.endsWith(".p12") || it.endsWith(".pfx") || it.endsWith(".pkcs12") }
    ?: false
val effectiveReleaseKeyPassword = if (isPkcs12ReleaseStore) {
    releaseStorePassword
} else {
    releaseKeyPassword
}

val hasReleaseSigning = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    effectiveReleaseKeyPassword,
).all { !it.isNullOrBlank() }

fun gitVersionTag(): String = runCatching {
    ProcessBuilder("git", "describe", "--tags", "--exact-match")
        .redirectErrorStream(true)
        .start()
        .inputStream.bufferedReader().readText().trim()
}.getOrDefault("")

fun versionNameFromTag(tag: String): String =
    if (tag.matches(Regex("v\\d+\\.\\d+\\.\\d+"))) tag.removePrefix("v") else "0.0.0-dev"

fun versionCodeFromTag(tag: String): Int {
    val parts = tag.removePrefix("v").split(".").mapNotNull { it.toIntOrNull() }
    return if (parts.size == 3) parts[0] * 10000 + parts[1] * 100 + parts[2] else 0
}

val gitTag = gitVersionTag()
val appVersionName = versionNameFromTag(gitTag)
val appVersionCode = versionCodeFromTag(gitTag)

android {
    namespace = "tech.mmarca.openvitals"
    compileSdk = 36

    defaultConfig {
        applicationId = "tech.mmarca.openvitals"
        minSdk = 26
        targetSdk = 36
        versionCode = appVersionCode
        versionName = appVersionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(checkNotNull(releaseStoreFilePath))
                storePassword = checkNotNull(releaseStorePassword)
                keyAlias = checkNotNull(releaseKeyAlias)
                keyPassword = checkNotNull(effectiveReleaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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
    implementation(libs.androidx.core.ktx)

    // Compose
    val composeBom = platform(libs.androidx.compose.bom)
    implementation(composeBom)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    debugImplementation(libs.androidx.compose.ui.tooling)

    // Activity + Navigation
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)

    // Lifecycle + ViewModel
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)

    // Coroutines
    implementation(libs.kotlinx.coroutines.android)

    // Health Connect
    implementation(libs.health.connect.client)

    // Room
    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    ksp(libs.androidx.room.compiler)

    // WorkManager
    implementation(libs.androidx.work.runtime.ktx)

    // Testing
    testImplementation(libs.junit4)
    testImplementation(libs.mockk)
    testImplementation(libs.kotlinx.coroutines.test)
}
