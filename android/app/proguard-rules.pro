# OWASP MASVS-RESILIENCE: ProGuard / R8 Obfuscation & Shrinking Rules

# Flutter Wrapper & Plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase SDKs
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
-dontwarn com.google.firebase.**
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# SQLCipher / SQLite Encryption
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# ML Kit (Text Recognition / Vision)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }

# Flutter Secure Storage (Hardware Keystore Bridge)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Redact debug logs from production release binaries
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
}

# Suppress warnings for optional Play Core Deferred Components & MLKit language models
-dontwarn com.google.android.play.core.**
-dontwarn com.google.mlkit.vision.text.**
