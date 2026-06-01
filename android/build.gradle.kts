// Build configuration for the flutter_music_picker Android plugin library.
// This builds the Kotlin plugin source into an .aar that consuming apps can use.
plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.rnd.flutter_music_picker"

    compileSdk = 35

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            manifest.srcFile("src/main/AndroidManifest.xml")
        }
    }

    defaultConfig {
        minSdk = 21
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:2.1.0")
}
