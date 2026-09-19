import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.nkw2000.meenalatlasy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // معرّف التطبيق الخاص بهالمشروع (تغيّر عن المشروع الأصلي بالإصدار
        // ٠٫١٢٫٠ — النسخة القديمة بتتركّب جنبه كتطبيق تاني ولازم تنشال).
        applicationId = "io.github.nkw2000.meenalatlasy"
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

    // مفتاح التوقيع الثابت — من `android/key.properties` (مش بالمستودع):
    //   storeFile=…/meen-al-atlasy-release.jks
    //   storePassword=…  keyPassword=…  keyAlias=meen
    // بدون الملف بنوقّع بمفتاح debug (كل جهاز/سيرفر مفتاحه مختلف، فما
    // بيتركّب التحديث فوق النسخة القديمة — هيك كانت قبل).
    val keyProps = Properties()
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) {
        keyPropsFile.inputStream().use { keyProps.load(it) }
    }
    val hasReleaseKey = keyProps.getProperty("storeFile") != null

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
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
