-dontwarn androidx.compose.desktop.DesktopTheme*
-dontoptimize
-keep class org.fife.** { *; }
-dontnote org.fife.**
-keep class sun.misc.Unsafe { *; }
-dontnote sun.misc.Unsafe
-keep class com.jetbrains.JBR* { *; }
-dontnote com.jetbrains.JBR*
-printmapping mapping.txt
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable,MethodParameters

# Project ViewModels & Logic
-keep class com.jankinwu.fntv.client.viewmodel.** { *; }
-keep class com.jankinwu.fntv.client.data.network.impl.** { *; }
-keep class com.jankinwu.fntv.client.manager.** { *; }
-keep class com.jankinwu.fntv.client.utils.** { *; }
-keep class com.jankinwu.fntv.client.jna.** { *; }
-keep class com.jankinwu.fntv.client.ui.providable.** { *; }

# Kotlin Reflect & Metadata
-keep class kotlin.reflect.** { *; }
-keep class kotlin.Metadata { *; }

# Compose Resources
-keep class fntv_client_multiplatform.composeapp.generated.resources.** { *; }

# JNA
-keep class com.sun.jna.** { *; }
-keep interface * extends com.sun.jna.Library { *; }
-keep interface * extends com.sun.jna.win32.StdCallLibrary { *; }
-keep class * extends com.sun.jna.Structure { *; }
-keep class * extends com.sun.jna.win32.W32APIType { *; }
-dontnote com.sun.jna.**
-dontwarn com.sun.jna.**

-dontwarn org.slf4j**
-keep class org.slf4j** { *; }
-dontnote org.jetbrains.skiko**
-keep class org.jetbrains.skiko** { *; }
-dontnote okhttp3**
-dontnote com.googlecode**
-keep class org.cef.** { *; }
-keep class kotlinx.coroutines.swing.SwingDispatcherFactory
# VLCJ
-keep class uk.co.caprica.vlcj.** { *; }
-dontwarn uk.co.caprica.vlcj.**

# Project Models
-keep class com.jankinwu.fntv.client.data.model.** { *; }

# Kotlinx Serialization
-keepclassmembers class * {
    *** Companion;
}
-keep @kotlinx.serialization.Serializable class * { *; }
-keep class kotlinx.serialization.json.** { *; }

# Ktor
-keep class io.ktor.** { *; }

# Jackson
-keep class com.fasterxml.jackson.** { *; }
-dontwarn com.fasterxml.jackson.**

# Koin
-keep class org.koin.** { *; }

# Coil
-keep class coil3.** { *; }

# OkHttp & Okio & Kotlinx IO
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-keep class kotlinx.io.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Coroutines
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlinx.coroutines.**

# Compottie
-keep class io.github.alexzhirkevich.compottie.** { *; }
-keep class io.github.alexzhirkevich.keight.** { *; }

# Kotlinx Datetime
-keep class kotlinx.datetime.** { *; }

# Oshi
-keep class oshi.** { *; }
-dontwarn oshi.**

# Kotlin Atomics (experimental in some versions/targets)
-dontwarn kotlin.concurrent.atomics.**

# Generic dontwarn for unresolved references in libraries
-dontwarn javafx.**
-dontwarn androidx.compose.**
-keep class androidx.compose.** { *; }
-dontwarn com.jogamp.**
-dontwarn jogamp.**
-dontwarn org.eclipse.swt.**
-dontwarn org.apache.thrift.**
-dontwarn com.jetbrains.cef.**
-dontwarn com.google.common.truth.**
-dontwarn org.objectweb.asm.**
-dontwarn okhttp3.internal.platform.**
-dontwarn org.conscrypt.**
-dontwarn androidx.compose.ui.test.**
-dontwarn org.junit.**
-dontwarn okio.**
-dontwarn com.google.common.reflect.**
-dontwarn org.apache.logging.log4j.**
-dontwarn org.json.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn okhttp3.internal.graal.**
-dontwarn org.graalvm.nativeimage.**
-dontwarn com.oracle.svm.core.**
-dontwarn org.tukaani.xz.**
-dontwarn org.brotli.dec.**
-dontwarn com.github.luben.zstd.**
-dontwarn org.apache.commons.compress.harmony.pack200.**
-dontwarn kotlinx.atomicfu.**
-dontwarn com.mikepenz.markdown.**
-dontwarn io.github.alexzhirkevich.compottie.**
-dontwarn io.ktor.client.plugins.**
-dontwarn androidx.compose.**
-dontnote androidx.compose.**
-keep class androidx.compose.** { *; }
-keep interface androidx.compose.** { *; }
-dontwarn coil3.**
-dontwarn io.ktor.**
-dontwarn kotlin.**
-dontwarn kotlinx.atomicfu.**
-ignorewarnings

# Mediamp
-keep class org.openani.mediamp.** { *; }
-dontwarn org.openani.mediamp.**

# Compose Scene & Reflection (used by LayoutHitTestOwner)
-keep class androidx.compose.ui.scene.CanvasLayersComposeSceneImpl { *; }
-keep class androidx.compose.ui.scene.PlatformLayersComposeSceneImpl { *; }
-keep class androidx.compose.ui.scene.CanvasLayersComposeSceneImpl$AttachedComposeSceneLayer { *; }
-keep class androidx.compose.ui.scene.** { *; }
-keep class androidx.compose.ui.node.** { *; }
-keep class androidx.compose.ui.platform.** { *; }
-keep class androidx.compose.ui.window.** { *; }
-dontwarn androidx.compose.ui.scene.**
-dontwarn androidx.compose.ui.node.**
-dontwarn androidx.compose.ui.platform.**
-dontwarn androidx.compose.ui.window.**
