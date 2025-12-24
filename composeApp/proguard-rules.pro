# Android specific ProGuard rules
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Kotlinx Serialization
-keepclassmembers class * {
    *** Companion;
}
-keep @kotlinx.serialization.Serializable class * { *; }
-keep class kotlinx.serialization.json.** { *; }

# Ktor
-keep class io.ktor.** { *; }

# OkHttp
-keepattributes Signature
-keepattributes *Annotation*
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**

# Jackson
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

# Koin
-keep class org.koin.** { *; }

# Coil
-keep class coil3.** { *; }

# Oshi
-keep class oshi.** { *; }
-dontwarn oshi.**

# Project Models
-keep class com.jankinwu.fntv.client.data.model.** { *; }

# Okio & Kotlinx IO
-keep class okio.** { *; }
-keep class kotlinx.io.** { *; }

# Compottie
-keep class io.github.alexzhirkevich.compottie.** { *; }
-keep class io.github.alexzhirkevich.keight.** { *; }

# Kotlinx Datetime
-keep class kotlinx.datetime.** { *; }

# JNA
-keep class com.sun.jna.** { *; }
-dontwarn com.sun.jna.**

# Mediamp
-keep class org.openani.mediamp.** { *; }
-dontwarn org.openani.mediamp.**
