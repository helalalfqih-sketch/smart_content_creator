plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.smart_content_creator"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.smart_content_creator"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true

        // 🚀 تم التعليق للسماح بخيار --split-per-abi بالعمل بدون تعارض
        // ndk {
        //     abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        // }
    }

    /*
    // 🔥 تقسيم APK حسب المعمارية = حجم أصغر بكثير
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a")
            isUniversalApk = true // APK واحد شامل كاحتياط
        }
    }
    */

    signingConfigs {
        create("release") {
            val propertiesFile = rootProject.file("key.properties")
            val properties = java.util.Properties()
            if (propertiesFile.exists()) {
                properties.load(java.io.FileInputStream(propertiesFile))
                storeFile = file(properties.getProperty("storeFile"))
                storePassword = properties.getProperty("storePassword")
                keyAlias = properties.getProperty("keyAlias")
                keyPassword = properties.getProperty("keyPassword")
            } else {
                // Fallback to debug configuration if key.properties doesn't exist (e.g. on GitHub Actions CI)
                val debugConfig = signingConfigs.getByName("debug")
                storeFile = debugConfig.storeFile
                storePassword = debugConfig.storePassword
                keyAlias = debugConfig.keyAlias
                keyPassword = debugConfig.keyPassword
            }
        }
    }

    buildTypes {
        getByName("release") {
            // 🚀 تعطيل مؤقت لحل مشكلة الشاشة السوداء (R8 Optimization issue)
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }

        debug {
            // ⚡ Debug أسرع بدون تحسينات
            isMinifyEnabled = false
            isShrinkResources = false

            // ndk {
            //    abiFilters += listOf("arm64-v8a")
            // }
        }
    }

    // Resolve potential version conflicts for media3 libraries
    configurations.all {
        resolutionStrategy {
            force("androidx.media3:media3-exoplayer:1.3.0")
            force("androidx.media3:media3-extractor:1.3.0")
        }
    }

    packagingOptions {
        resources {
            excludes += "/META-INF/AL2.0"
            excludes += "/META-INF/LGPL2.1"
            excludes += "/META-INF/LICENSE*"
        }
        jniLibs {
            excludes += "**/libVkLayer_khronos_validation.so"
        }
    }

    lint {
        disable.add("InvalidPackage")
        abortOnError = false
        checkReleaseBuilds = false
    }
}


flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.media3:media3-exoplayer:1.3.0")
    implementation("androidx.media3:media3-exoplayer-dash:1.3.0")
    implementation("androidx.media3:media3-exoplayer-hls:1.3.0")
    implementation("androidx.media3:media3-extractor:1.3.0")

    // Import the Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
}

