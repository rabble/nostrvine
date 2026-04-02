plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

group = "com.divinevideo.divine_video_player"
version = "1.0"

android {
    namespace = "com.divinevideo.divine_video_player"
    compileSdk = 35

    defaultConfig {
        minSdk = 28
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    implementation("androidx.media3:media3-exoplayer:1.10.0")
    implementation("androidx.media3:media3-datasource:1.10.0")
    implementation("androidx.media3:media3-ui:1.10.0")
}
