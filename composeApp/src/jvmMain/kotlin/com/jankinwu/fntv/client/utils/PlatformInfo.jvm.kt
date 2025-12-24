package com.jankinwu.fntv.client.utils

import oshi.SystemInfo
import java.util.Locale

actual object PlatformInfo {
    private val systemInfo = SystemInfo()
    actual val osName: String = System.getProperty("os.name") ?: "Unknown JVM"
    actual val osArch: String = System.getProperty("os.arch")?.lowercase(Locale.getDefault()) ?: "unknown"
    actual val cpuModel: String = try {
        systemInfo.hardware.processor.processorIdentifier.name.trim()
    } catch (_: Exception) {
        "unknown"
    }

    private val selectedGpu = try {
        systemInfo.hardware.graphicsCards.maxByOrNull { it.vRam }
    } catch (_: Exception) {
        null
    }

    actual val gpuModel: String = selectedGpu?.name ?: "unknown"

    actual val gpuType: String = selectedGpu?.let { gpu ->
        val vendor = gpu.vendor.lowercase(Locale.getDefault())
        val name = gpu.name.lowercase(Locale.getDefault())
        when {
            // NVIDIA: 绝大多数情况下都是独显
            vendor.contains("nvidia") || name.contains("geforce") || name.contains("quadro") ||
            name.contains("rtx") || name.contains("gtx") -> "Dedicated"

            // Intel: 只有 Arc 系列是独显，其他 (Iris, UHD, HD) 均为核显
            vendor.contains("intel") -> if (name.contains("arc")) "Dedicated" else "Integrated"

            // AMD: 区分 Radeon RX/Pro (独显) 和 Radeon Graphics (核显)
            vendor.contains("amd") || vendor.contains("advanced micro devices") || name.contains("radeon") -> {
                if (name.contains("rx ") || name.contains("pro") || name.contains("firepro") ||
                    name.contains("instinct") || name.contains(" r9 ") || name.contains(" r7 ")) {
                    "Dedicated"
                } else {
                    "Integrated"
                }
            }

            // Apple: M1/M2/M3 等系列均为集成架构
            vendor.contains("apple") -> "Integrated"

            // 通用关键词匹配
            name.contains("integrated") || name.contains("internal") ||
            name.contains("apu") || name.contains("iris") || name.contains("uhd") -> "Integrated"

            // 兜底逻辑：如果无法确定，默认归类为 Integrated (更符合当前移动/轻薄办公本的主流情况)
            else -> "Integrated"
        }
    } ?: "Integrated"
}
