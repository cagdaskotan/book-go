import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Yayın imzası android/key.properties dosyasından okunur. Bu dosya git'e
// girmez ve anahtarın kendisi de depoda durmaz: kaybedilirse uygulama bir
// daha güncellenemez, sızdırılırsa başkası senin adına sürüm yayınlayabilir.
//
// Dosya yoksa derleme hata vermez, hata ayıklama anahtarıyla imzalanır —
// böylece geliştirme akışı bozulmaz. Mağazaya çıkarken dosyanın varlığı
// kontrol edilmeli.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.book.bilge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.book.bilge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                // Anahtar yoksa geliştirme sürsün; bu APK mağazaya yüklenemez.
                signingConfigs.getByName("debug")
            }

            // R8 kuralları: kullanılmayan ML Kit dil paketleri olmadan
            // release derlemesi tamamlanmıyor (bkz. proguard-rules.pro).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Kotlin'in JVM hedefi Java ile aynı olmalı. Kotlin 2.3'te eski
// `android.kotlinOptions.jvmTarget` kaldırıldı; karşılığı bu blok.
kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
