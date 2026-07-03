# ABOUTME: ProGuard/R8 keep rules for release APK code shrinking.
# ABOUTME: Preserves Flutter engine, platform channels, SharedPreferences, and reflection-based Android classes.

# Allow duplicate classes from java-opentimestamps fat JAR
# This library bundles Guava, Protobuf, JSR305, and Okio internally
-dontwarn com.google.common.**
-dontwarn com.google.protobuf.**
-dontwarn javax.annotation.**
-dontwarn okio.**

# Keep MainActivity and all its methods (platform channel setup)
-keep class co.openvine.app.MainActivity { *; }

# Keep ProofMode classes (cryptographic proof generation library)
-keep class org.witness.proofmode.** { *; }
-keep class com.eternitywall.** { *; }

# BouncyCastle JCA provider (ProofMode PGP signing, CSR/cert generation) loads algorithm
# classes by name via reflection; without this R8 strips them -> runtime crypto failures.
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# Keep Kotlin metadata and reflection (required for platform channels)
-keep class kotlin.Metadata { *; }
-keepclassmembers class * {
    @kotlin.Metadata <methods>;
}

# Keep all Kotlin lambdas and SAM conversions (MethodChannel handlers)
-keepclassmembernames class * {
    private *** lambda$*(...);
}
-keep class kotlin.jvm.internal.Lambda { *; }
-keepclassmembers class * extends kotlin.jvm.internal.Lambda {
    public *** invoke(...);
}

# Flutter engine core classes (reflection-based platform integration)
# Without these, Flutter engine initialization fails silently in release builds
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragment { *; }

# Platform channels (method invocation via reflection)
# Critical for all Flutter plugin communication (camera, storage, etc)
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.BasicMessageChannel { *; }
-keep class io.flutter.plugin.common.StandardMethodCodec { *; }
-keep class io.flutter.plugin.common.StandardMessageCodec { *; }
-keep class io.flutter.plugin.common.JSONMethodCodec { *; }

# All Flutter plugins (registered via reflection)
-keep class io.flutter.plugins.** { *; }

# GeneratedPluginRegistrant (auto-registration of Flutter plugins)
# Keep: R8 previously stripped this, breaking plugin registration in release builds.
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# SharedPreferences (used in router redirect for TOS check on app startup)
# Keep: R8 previously stripped this, hanging the startup router redirect forever.
-keepclassmembers class * implements android.content.SharedPreferences {
    *;
}

# Firebase classes (crash reporting and analytics)
# These use reflection for initialization
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep all native methods (platform channels rely on JNI)
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all classes with @Keep annotation (standard Android best practice)
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Ignore missing Play Core classes (we don't use deferred components)
# Flutter's embedding layer references these, but we're not using split installs
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
