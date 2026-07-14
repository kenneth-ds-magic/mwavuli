plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mwavuli"
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
        applicationId = "com.example.mwavuli"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
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

    // APK base name: mwavuli-release.apk / mwavuli-debug.apk (instead of app-*).
    base {
        archivesName.set("mwavuli")
    }
}

flutter {
    source = "../.."
}

// Also emit mwavuli.apk (no build-type suffix) for easy sharing.
afterEvaluate {
    tasks.named("assembleRelease").configure {
        doLast {
            val built =
                layout.buildDirectory
                    .get()
                    .asFile
                    .resolve("outputs/apk/release/mwavuli-release.apk")
            if (!built.exists()) return@doLast
            val outDir =
                rootProject.projectDir.resolve("../build/app/outputs/flutter-apk")
            outDir.mkdirs()
            built.copyTo(outDir.resolve("mwavuli.apk"), overwrite = true)
        }
    }
}
