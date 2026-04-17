import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing credentials loaded from one of two sources, in order:
//
//   1. `android/key.properties` (gitignored) — the lokal dev path. A
//      contributor who needs to produce a signed release build locally
//      populates this file and Gradle reads it synchronously during
//      configuration.
//   2. Environment variables (CI path) — the release workflow decodes
//      the keystore from a GitHub secret to a file on the runner and
//      then exports ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD /
//      ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD before invoking
//      `flutter build appbundle`.
//
// When neither source is populated, the signing config is NOT applied
// to the release build type at all (see below) — `flutter run --release`
// locally still fails loudly instead of silently falling back to the
// debug keystore, matching the original intent of this project.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

fun resolveKeystoreField(propertyKey: String, envKey: String): String? {
    val fromProperties = keystoreProperties.getProperty(propertyKey)
    if (!fromProperties.isNullOrBlank()) return fromProperties
    val fromEnv = System.getenv(envKey)
    if (!fromEnv.isNullOrBlank()) return fromEnv
    return null
}

// Gradle's `file()` resolves relative paths against the Gradle project
// directory (`android/app/`) and does not expand `~` into the user home
// directory. Both behaviours are surprising when key.properties is
// hand-edited — a developer following the setup doc with a typical
// `storeFile=~/Desktop/markdown-viewer-release.keystore` line would
// see a confusing "file not found" error at the absurd resolved path
// `android/app/~/Desktop/...`. Expand `~/` explicitly so the same
// shell shorthand works in key.properties and in env vars.
fun expandHome(path: String?): String? {
    if (path == null) return null
    val home = System.getProperty("user.home") ?: return path
    return when {
        path == "~" -> home
        path.startsWith("~/") -> home + path.substring(1)
        else -> path
    }
}

val releaseStoreFile =
    expandHome(resolveKeystoreField("storeFile", "ANDROID_KEYSTORE_PATH"))
val releaseStorePassword = resolveKeystoreField("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = resolveKeystoreField("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = resolveKeystoreField("keyPassword", "ANDROID_KEY_PASSWORD")

val hasReleaseSigning =
    releaseStoreFile != null &&
        releaseStorePassword != null &&
        releaseKeyAlias != null &&
        releaseKeyPassword != null

android {
    namespace = "com.cemililik.markdown_viewer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.cemililik.markdown_viewer"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Only define the "release" signing config when the required material
    // is actually present — declaring it with empty strings would let
    // `flutter build appbundle --release` succeed against an invalid
    // key and ship an unsignable artifact. The null-guarded block below
    // keeps the old "fail loudly with no signing config" behaviour intact
    // for local developers who have not populated key.properties yet.
    if (hasReleaseSigning) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Wire the release signing config only when it exists —
            // otherwise a local `flutter run --release` keeps failing
            // with the original "no signing config" error, which is
            // the correct outcome: falling back to the debug key would
            // let an unintended signature reach production artifacts.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            // R8 / resource shrinking — requested by the 2026-04-17
            // security review (L-3) and the performance audit. Cuts
            // roughly 15–20 % off the shipped AAB by stripping unused
            // Kotlin metadata, obfuscating class names, and pruning
            // unreachable resource entries.
            //
            // `proguard-android-optimize.txt` is AGP's default rule
            // file with optimisation passes enabled. The additional
            // `proguard-rules.pro` (committed at the sibling path) is
            // where project-specific keep-rules live — anything that
            // gets reflected on at runtime (Sentry, Drift codegen,
            // GoRouter's generated route table) needs an explicit
            // keep rule there.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Used by `LibraryFoldersChannel` to enumerate the contents of
    // a Storage Access Framework tree URI without re-implementing
    // the platform-specific cursor walks. The DocumentFile abstraction
    // gives us a uniform handle for both the picked tree root and any
    // descendant document, which keeps the channel code small.
    implementation("androidx.documentfile:documentfile:1.0.1")
}
