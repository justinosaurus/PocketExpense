import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyProperties = Properties()
val releaseKeyPropertiesFile = rootProject.file("key.properties")
if (releaseKeyPropertiesFile.exists()) {
    releaseKeyPropertiesFile.inputStream().use(releaseKeyProperties::load)
}

android {
    namespace = "com.example.pocket_expenses"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        create("release") {
            if (releaseKeyPropertiesFile.exists()) {
                keyAlias = requireNotNull(releaseKeyProperties.getProperty("keyAlias"))
                keyPassword = requireNotNull(releaseKeyProperties.getProperty("keyPassword"))
                storeFile = rootProject.file(requireNotNull(releaseKeyProperties.getProperty("storeFile")))
                storePassword = requireNotNull(releaseKeyProperties.getProperty("storePassword"))
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.pocket_expenses"
        manifestPlaceholders["appLabel"] = "Pocket Expenses"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            manifestPlaceholders["appLabel"] = "Pocket Expenses (Debug)"
        }
        release {
            // A local debug signature keeps release-mode builds testable until a
            // private upload key is configured in android/key.properties.
            signingConfig = if (releaseKeyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
