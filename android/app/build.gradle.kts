plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cemililik.markdown_viewer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Release builds intentionally have NO signing configuration
            // wired up here. Local `flutter run --release` will fail until
            // the developer (or CI) supplies a release keystore — this is
            // the desired behaviour because falling back to the debug
            // keystore would let an unintended key reach production.
            //
            // To produce a signable release build, populate the following
            // properties in `android/key.properties` (gitignored):
            //
            //   storeFile=path/to/release.keystore
            //   storePassword=...
            //   keyAlias=...
            //   keyPassword=...
            //
            // and add a matching `signingConfigs.create("release") { ... }`
            // block above this `buildTypes` section that reads them.
            // CI release pipelines should populate `key.properties` from
            // secrets at build time and never commit it.
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
