package com.jankinwu.fntv.client.utils

import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.data.model.response.VideoStream
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore

fun calculateOptimalPlayerWindowSize(
    videoStream: VideoStream,
    baseWidth: Float,
    baseHeight: Float,
    aspectRatioSetting: String = "AUTO",
    isPipMode: Boolean = false
): DpSize? {
    val videoW = videoStream.width.toDouble()
    val videoH = videoStream.height.toDouble()

    if (videoW <= 0.0 || videoH <= 0.0) return null

    // Determine target aspect ratio
    val targetAspectRatio = when (aspectRatioSetting) {
        "4:3" -> 4.0 / 3.0
        "16:9" -> 16.0 / 9.0
        "21:9" -> 21.0 / 9.0
        else -> parseAspectRatio(videoStream.displayAspectRatio) ?: (videoW / videoH)
    }

    val currentWidth = baseWidth.toDouble()
    val currentHeight = baseHeight.toDouble()
    var targetH = currentHeight
    var targetW = currentWidth

    val currentAspectRatio = if (currentHeight > 0.0) currentWidth / currentHeight else targetAspectRatio

    // Compensation only applies in AUTO mode
    var compensation =
        if (aspectRatioSetting == "AUTO") PlayingSettingsStore.playerWindowWidthCompensation.toDouble() else 0.0

    // In PiP mode, the compensation is halved
    if (isPipMode) {
        compensation /= 2.0
    }

    // Logic to expand window rather than shrink content
    // 为了防止基于当前窗口大小计算导致无限膨胀，我们采用"保持宽度"的策略，除非必须变宽
    if (targetAspectRatio > currentAspectRatio) {
        // Wider target: Keep Height, Expand Width
        // 只有当目标比当前更宽时，才增加宽度 (例如 4:3 -> 16:9)
        targetH = currentHeight
        targetW = targetH * targetAspectRatio
    } else {
        // Narrower/Taller target: Keep Width, Expand Height
        // 如果目标比当前窄 (例如 16:9 -> 4:3)，保持宽度，增加高度
        targetW = currentWidth
        targetH = targetW / targetAspectRatio
        // No width compensation needed when keeping baseWidth
    }

    // Constraints: +/- 50% of Base (Applied to Result)
    val minW = currentWidth * 0.5
    val maxW = currentWidth * 1.5

    // Clamp width if needed (though Expand logic usually stays reasonable unless base was very distorted)
    if (targetW < minW) targetW = minW
    if (targetW > maxW) targetW = maxW

    if (targetW != (if (targetAspectRatio > currentAspectRatio) currentHeight * targetAspectRatio else currentWidth)) {
        val effectiveW = targetW - compensation
        targetH = effectiveW / targetAspectRatio
    }

    return DpSize(targetW.toFloat().dp, targetH.toFloat().dp)
}

fun parseAspectRatio(dar: String?): Double? {
    if (dar.isNullOrBlank()) return null
    return try {
        val parts = dar.split(":")
        if (parts.size == 2) {
            val w = parts[0].toDouble()
            val h = parts[1].toDouble()
            if (h > 0.0) w / h else null
        } else {
            null
        }
    } catch (e: Exception) {
        null
    }
}
