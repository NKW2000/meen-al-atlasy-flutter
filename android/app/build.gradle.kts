plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.feudparty.meen_al_atlasy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // نفس applicationId التطبيق الأصلي (Kotlin) — استمرارية على نفس
        // البصمة لمتاجر التطبيقات.
        applicationId = "com.feudparty.app"
        // نفس حدود المشروع الأصلي: minSdk 26 (أندرويد ٨) وtargetSdk 34.
        minSdk = 26
        targetSdk = 34
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["appLabel"] = "مين الأطليسي"
    }

    // نكهتين — نفس فكرة build type «demo» بالمشروع الأصلي (Kotlin)، بس
    // فلاتر بتعرف product flavors بس (`flutter build apk --flavor …`):
    //  - game: اللعبة نفسها.
    //  - demo: بتفتح معرض الشاشات بدل اللعبة (مع `--dart-define=DEMO=true`)،
    //    وبتتركّب جنب النسخة العادية (معرّف مختلف) فبتقدر تجرّب الواجهات
    //    بجهاز واحد.
    flavorDimensions += "variant"
    productFlavors {
        create("game") {
            dimension = "variant"
        }
        create("demo") {
            dimension = "variant"
            applicationIdSuffix = ".demo"
            versionNameSuffix = "-demo"
            manifestPlaceholders["appLabel"] = "مين الأطليسي — ديمو"
        }
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

flutter {
    source = "../.."
}
