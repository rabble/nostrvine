group = "co.openvine.caption_generator"
version = "1.0-SNAPSHOT"

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

repositories {
    google()
    mavenCentral()
}

val flutterRootCandidates = listOf(
    providers.environmentVariable("FLUTTER_ROOT").orNull,
    providers.environmentVariable("FLUTTER_HOME").orNull,
    providers.environmentVariable("CODEMAGIC_FLUTTER_ROOT").orNull,
).filterNotNull().distinct()

if (flutterRootCandidates.isEmpty()) {
    throw GradleException(
        "FLUTTER_ROOT, FLUTTER_HOME, or CODEMAGIC_FLUTTER_ROOT must be set to compile caption_generator",
    )
}

val flutterEmbeddingJarCandidates = flutterRootCandidates.flatMap { root ->
    listOf(
        file("$root/bin/cache/artifacts/engine/android-arm64/flutter.jar"),
        file("$root/bin/cache/artifacts/engine/android-arm64-release/flutter.jar"),
    )
}
val flutterEmbeddingJar = flutterEmbeddingJarCandidates.firstOrNull { it.isFile }
    ?: throw GradleException(
        "Could not find Flutter Android embedding jar. Checked: " +
            flutterEmbeddingJarCandidates.joinToString { it.absolutePath },
    )

android {
    namespace = "co.openvine.caption_generator"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
        }
    }
}

dependencies {
    compileOnly(files(flutterEmbeddingJar))
    testImplementation(files(flutterEmbeddingJar))
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
    testImplementation("org.robolectric:robolectric:4.14.1")
    testImplementation("junit:junit:4.13.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
