plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.happiness.threads"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    androidResources {
        // SoundPool预加载包内PCM，不在出牌时解压或创建临时文件。
        noCompress += "wav"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = "com.happiness.threads"
        minSdk = flutter.minSdkVersion
        // Android 16 / target 36+ can ignore orientation locks on large displays.
        // This local tablet MVP targets 35 to keep landscape compatibility behavior.
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    buildTypes {
        release {
            // Local MVP sideloading only; production distribution needs a private release key.
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
