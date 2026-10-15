plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.william.treino"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Preserve the native app identity for in-place data migration.
        applicationId = "com.william.treino"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures { resValues = true }
    flavorDimensions += "edition"
    productFlavors {
        create("personal") { dimension = "edition"; resValue("string", "app_name", "SetHarbor") }
        create("preview") { dimension = "edition"; applicationIdSuffix = ".preview"; resValue("string", "app_name", "SetHarbor Trial") }
        create("e2e") { dimension = "edition"; applicationIdSuffix = ".e2e"; resValue("string", "app_name", "SetHarbor E2E") }
    }
    val personalKey = file("../../../signing/personal-debug.jks")
    if (personalKey.exists()) {
        signingConfigs.create("personal") {
            storeFile = personalKey
            storePassword = "android"; keyAlias = "androiddebugkey"; keyPassword = "android"
        }
        buildTypes.getByName("debug").signingConfig = signingConfigs.getByName("personal")
    }
    buildTypes {
        release {
            // Development distribution; retain the optional original personal key.
            signingConfig = signingConfigs.findByName("personal") ?: signingConfigs.getByName("debug")
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

dependencies {
    // integration_test carries older transitive versions; align the debug host
    // and instrumentation classpaths for AGP consistent dependency resolution.
    debugImplementation("androidx.test:runner:1.6.2")
    debugImplementation("androidx.test:rules:1.6.1")
    debugImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
    androidTestImplementation("junit:junit:4.13.2")
}
