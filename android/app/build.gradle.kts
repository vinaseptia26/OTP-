plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pertamina.kmj.project_otp_kmj"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ UBAH dari 1_8 ke 17
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // ✅ UBAH dari "1.8" ke "17"
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.pertamina.kmj.project_otp_kmj"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    packagingOptions {
        resources {
            excludes += "META-INF/DEPENDENCIES"
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/license.txt"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/notice.txt"
            excludes += "META-INF/ASL2.0"
            excludes += "META-INF/AL2.0"
            excludes += "META-INF/LGPL2.1"
            excludes += "META-INF/versions/9/previous-compilation-data.bin"
        }
    }
    
    // FORCE untuk tidak menggunakan firebase-iid
    configurations.all {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Pakai BOM versi terbaru
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    
    // Firebase libraries
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-perf")
    implementation("com.google.firebase:firebase-crashlytics")
    
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}