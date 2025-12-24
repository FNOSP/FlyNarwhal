package com.jankinwu.fntv.client.utils

import android.os.Build

actual object PlatformInfo {
    actual val osName: String = "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})"
    actual val osArch: String = Build.SUPPORTED_ABIS.firstOrNull() ?: "unknown"
    actual val cpuModel: String = Build.HARDWARE ?: "unknown"
    actual val gpuModel: String = "unknown" // Requires OpenGL context to get renderer
    actual val gpuType: String = "Integrated" // Mobile devices are typically integrated
}
