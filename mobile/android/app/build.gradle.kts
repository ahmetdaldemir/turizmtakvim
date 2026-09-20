import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase: google-services.json eklenince açın
    // id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystorePropertiesFile =
    listOf(
        rootProject.file("key.properties"),
        rootProject.file("../../.deploy/android/key.properties"),
    ).firstOrNull { it.exists() }

if (keystorePropertiesFile != null) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.musaitvillam.yonetim"
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
        applicationId = "com.musaitvillam.yonetim"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "sector"
    productFlavors {
        create("villa") {
            dimension = "sector"
            applicationId = "com.musaitvillam.villa.yonetim"
            resValue("string", "app_name", "Villa Yönetim")
        }
        create("kuafor") {
            dimension = "sector"
            applicationId = "com.musaitvillam.kuafor.yonetim"
            resValue("string", "app_name", "Kuaför Yönetim")
        }
    }

    signingConfigs {
        if (keystorePropertiesFile != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile != null) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

flutter {
    source = "../.."
}
