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
    val videoW = videoStream.width.toFloat()
    val videoH = videoStream.height.toFloat()

    if (videoW <= 0 || videoH <= 0) return null

    // Determine target aspect ratio
    val targetAspectRatio = when (aspectRatioSetting) {
        "4:3" -> 4f / 3f
        "16:9" -> 16f / 9f
        "21:9" -> 21f / 9f
        else -> parseAspectRatio(videoStream.displayAspectRatio) ?: (videoW / videoH)
    }

    var targetH = baseHeight
    var targetW = baseWidth

    val currentAspectRatio = if (baseHeight > 0) baseWidth / baseHeight else targetAspectRatio

    // Compensation only applies in AUTO mode
    var compensation =
        if (aspectRatioSetting == "AUTO") PlayingSettingsStore.playerWindowWidthCompensation else 0f

    // In PiP mode, the compensation is halved
    if (isPipMode) {
        compensation /= 2f
    }

    // Logic to expand window rather than shrink content
    // 为了防止基于当前窗口大小计算导致无限膨胀，我们采用"保持宽度"的策略，除非必须变宽
    if (targetAspectRatio > currentAspectRatio) {
        // Wider target: Keep Height, Expand Width
        // 只有当目标比当前更宽时，才增加宽度 (例如 4:3 -> 16:9)
        targetH = baseHeight
        targetW = targetH * targetAspectRatio
        targetW += compensation
    } else {
        // Narrower/Taller target: Keep Width, Expand Height
        // 如果目标比当前窄 (例如 16:9 -> 4:3)，保持宽度，增加高度
        targetW = baseWidth
        targetH = targetW / targetAspectRatio
        // No width compensation needed when keeping baseWidth
    }

    // Constraints: +/- 50% of Base (Applied to Result)
    val minW = baseWidth * 0.5f
    val maxW = baseWidth * 1.5f

    // Clamp width if needed (though Expand logic usually stays reasonable unless base was very distorted)
    if (targetW < minW) targetW = minW
    if (targetW > maxW) targetW = maxW

    if (targetW != (if (targetAspectRatio > currentAspectRatio) baseHeight * targetAspectRatio + compensation else baseWidth)) {

        val effectiveW = targetW - compensation
        targetH = effectiveW / targetAspectRatio
    }

    return DpSize(targetW.dp, targetH.dp)
}

fun parseAspectRatio(dar: String?): Float? {
    if (dar.isNullOrBlank()) return null
    return try {
        val parts = dar.split(":")
        if (parts.size == 2) {
            val w = parts[0].toFloat()
            val h = parts[1].toFloat()
            if (h > 0) w / h else null
        } else {
            null
        }
    } catch (e: Exception) {
        null
    }
}
