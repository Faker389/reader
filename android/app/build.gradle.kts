plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.apka"
    // flutter_tts compiles against Android SDK 36.
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    // Firebase and other plugins require NDK 27.
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Required by flutter_local_notifications (java.time on older Android).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO(release): Choose your own application id (e.g. app.fovea.reader) and
        // use the same id when registering the Android app in Firebase.
        applicationId = "com.example.apka"
        // Firebase needs API 23+. Reading words aloud needs API 24+.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
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

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// TODO(firebase): `flutterfire configure` adds the google-services (and, for
// Crashlytics, firebase-crashlytics) Gradle plugins here and in
// settings.gradle.kts, and places google-services.json in this folder.
