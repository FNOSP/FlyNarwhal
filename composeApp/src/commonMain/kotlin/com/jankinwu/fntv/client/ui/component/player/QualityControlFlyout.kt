package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.jankinwu.fntv.client.data.model.response.QualityResponse
import com.jankinwu.fntv.client.ui.component.common.AnimatedScrollbarLazyColumn
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val FlyoutBackgroundColor = Color.Black.copy(alpha = 0.9f)
private val FlyoutBorderColor = Color.Gray.copy(alpha = 0.5f)
private val SelectedTextColor = Color(0xFF2073DF)
private val DefaultTextColor = Color.White.copy(alpha = 0.7843f)
private val HoverBackgroundColor = Color.White.copy(alpha = 0.1f)
private val FlyoutShape = RoundedCornerShape(8.dp)
private const val HIDE_DELAY_MS = 200L
private const val ANIMATION_DURATION_MS = 200

/**
 * 将比特率(bps)转换为易读的格式，只保留整数部分
 */
private fun formatBitrateSimple(bps: Int): String {
    if (bps < 0) return "0 bps"

    val units = arrayOf("bps", "Kbps", "Mbps", "Gbps")
    var bitrate = bps.toDouble()
    var unitIndex = 0

    while (bitrate >= 1000 && unitIndex < units.size - 1) {
        bitrate /= 1000
        unitIndex++
    }

    return "${String.format(java.util.Locale.ROOT, "%.0f", bitrate)}${units[unitIndex]}"
}

private fun formatResolution(resolution: String): String {
    return if (resolution.all { it.isDigit() }) "${resolution}p" else resolution
}

@Stable
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun QualityControlFlyout(
    modifier: Modifier = Modifier,
    qualities: List<QualityResponse>,
    currentResolution: String,
    currentBitrate: Int?,
    yOffset: Int = 0,
    onHoverStateChanged: ((Boolean) -> Unit)? = null,
    onQualitySelected: (QualityResponse) -> Unit = {}
) {
    var isExpanded by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var isButtonHovered by remember { mutableStateOf(false) }
    var popupHovered by remember { mutableStateOf(false) }
    var showPopup by remember { mutableStateOf(false) }

    // reset to page 1 when closed
    var isCustomPage by remember { mutableStateOf(false) }

    fun showFlyout() {
        hideJob?.cancel()
        isExpanded = true
        showPopup = true
        onHoverStateChanged?.invoke(true)
    }

    fun hideFlyoutWithDelay() {
        hideJob = coroutineScope.launch {
            delay(HIDE_DELAY_MS)
            if (!isButtonHovered && !popupHovered) {
                isExpanded = false
                onHoverStateChanged?.invoke(false)
                delay(ANIMATION_DURATION_MS.toLong())
                showPopup = false
                isCustomPage = false // Reset to default page
            }
        }
    }

    Box(
        modifier = modifier
            .pointerHoverIcon(PointerIcon.Hand)
            .onPointerEvent(PointerEventType.Enter) {
                isButtonHovered = true
                showFlyout()
            }
            .onPointerEvent(PointerEventType.Exit) {
                isButtonHovered = false
                popupHovered = false
                hideFlyoutWithDelay()
            },
        contentAlignment = Alignment.Center
    ) {
        if (showPopup) {
            Popup(
                offset = IntOffset(0, -yOffset),
                alignment = Alignment.BottomCenter,
                properties = PopupProperties(
                    clippingEnabled = false,
                    focusable = false
                ),
                onDismissRequest = {
                    if (!isButtonHovered && !popupHovered) {
                        isExpanded = false
                    }
                }
            ) {
                Box(
                    modifier = Modifier
                        .pointerHoverIcon(PointerIcon.Hand)
                        .onPointerEvent(PointerEventType.Enter) {
                            popupHovered = true
                            hideJob?.cancel()
                        }
                        .onPointerEvent(PointerEventType.Exit) {
                            popupHovered = false
                            hideFlyoutWithDelay()
                        }
                ) {
                    FlyoutWithAnimation(
                        isExpanded = isExpanded,
                        onAnimationFinished = {
                            if (!isExpanded) {
                                showPopup = false
                            }
                        }
                    ) {
                        QualityFlyoutContent(
                            qualities = qualities,
                            currentResolution = currentResolution,
                            currentBitrate = currentBitrate,
                            isCustomPage = isCustomPage,
                            onSwitchPage = { isCustomPage = it },
                            onQualitySelected = {
                                onQualitySelected(it)
                                isExpanded = false
                                isCustomPage = false
                            }
                        )
                    }
                }
            }
        }
        Text(
            text = if (qualities.firstOrNull()?.resolution == currentResolution && currentBitrate == qualities.firstOrNull()?.bitrate) "原画质" else formatResolution(
                currentResolution
            ),
            style = LocalTypography.current.title,
            color = if (isButtonHovered) Color.White else DefaultTextColor,
            fontSize = 17.sp,
            fontWeight = FontWeight.Normal
        )
    }
}

@Composable
private fun FlyoutWithAnimation(
    isExpanded: Boolean,
    onAnimationFinished: () -> Unit,
    content: @Composable () -> Unit
) {
    val alpha = remember { Animatable(0f) }
    val scale = remember { Animatable(0.4f) }
    val offsetY = remember { Animatable(0f) }

    LaunchedEffect(isExpanded) {
        if (isExpanded) {
            launch { alpha.animateTo(1f, tween(ANIMATION_DURATION_MS)) }
            launch { scale.animateTo(1f, tween(ANIMATION_DURATION_MS)) }
            launch { offsetY.animateTo(0f, tween(ANIMATION_DURATION_MS)) }
        } else {
            launch { alpha.animateTo(0f, tween(ANIMATION_DURATION_MS)) }
            launch { scale.animateTo(0.4f, tween(ANIMATION_DURATION_MS)) }
            launch { offsetY.animateTo(10f, tween(ANIMATION_DURATION_MS)) }
            delay(ANIMATION_DURATION_MS.toLong())
            onAnimationFinished()
        }
    }

    Box(
        modifier = Modifier
            .alpha(alpha.value)
            .graphicsLayer {
                scaleX = scale.value
                scaleY = scale.value
                transformOrigin = TransformOrigin(0.5f, 1f)
            }
            .padding(bottom = offsetY.value.dp)
    ) {
        content()
    }
}

@Composable
private fun QualityFlyoutContent(
    qualities: List<QualityResponse>,
    currentResolution: String,
    currentBitrate: Int?,
    isCustomPage: Boolean,
    onSwitchPage: (Boolean) -> Unit,
    onQualitySelected: (QualityResponse) -> Unit
) {
    Surface(
        shape = FlyoutShape,
        color = FlyoutBackgroundColor,
        border = BorderStroke(1.dp, FlyoutBorderColor),
    ) {
        if (isCustomPage) {
            CustomQualityPage(
                qualities = qualities,
                currentResolution = currentResolution,
                currentBitrate = currentBitrate,
                onBack = { onSwitchPage(false) },
                onQualitySelected = onQualitySelected
            )
        } else {
            SimpleQualityPage(
                qualities = qualities,
                currentResolution = currentResolution,
                currentBitrate = currentBitrate,
                onToCustom = { onSwitchPage(true) },
                onQualitySelected = onQualitySelected
            )
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun SimpleQualityPage(
    qualities: List<QualityResponse>,
    currentResolution: String,
    currentBitrate: Int?,
    onToCustom: () -> Unit,
    onQualitySelected: (QualityResponse) -> Unit
) {
    // Group qualities by resolution. 
    // We assume the first quality in the list is always "Original" regardless of its resolution value matching others.

    val originalQuality = qualities.firstOrNull()
    val grouped = remember(qualities) {
        qualities.groupBy { it.resolution }
    }

    // We need a list of display items. 
    // If original quality exists, it should be the first item.
    // Then other resolutions.

    val distinctResolutions = remember(qualities) {
        qualities.map { it.resolution }.distinct()
    }

    // Check if current selection is "Custom"
    // Custom means: It is NOT the "Original" (first item), AND it is NOT the highest bitrate for its resolution group.
    val isCustomSelection = remember(currentResolution, currentBitrate, qualities) {
        if (originalQuality == null) return@remember false

        // If it matches Original, it's not custom
        if (currentResolution == originalQuality.resolution && currentBitrate == originalQuality.bitrate) {
            return@remember false
        }

        // Find highest bitrate for current resolution
        val highestForCurrentRes = grouped[currentResolution]?.maxByOrNull { it.bitrate }


        // So: Not Original AND Not Highest for resolution.
        val isHighest = highestForCurrentRes?.bitrate == currentBitrate
        !isHighest
    }

    Column(
        modifier = Modifier
            .width(240.dp) // Wider to accommodate extra info
            .padding(vertical = 10.dp)
    ) {
        // Header with Custom button
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "视频质量",
                color = DefaultTextColor,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium
            )
            Row(
                modifier = Modifier
                    .clickable { onToCustom() }
                    .pointerHoverIcon(PointerIcon.Hand),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "自定义",
                    color = DefaultTextColor,
                    fontSize = 14.sp
                )
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = DefaultTextColor,
                    modifier = Modifier.size(16.dp)
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        // Custom Item (if active)
        if (isCustomSelection) {
            val label = "自定义"
            val rightInfo = "${formatResolution(currentResolution)} ${
                currentBitrate?.let {
                    formatBitrateSimple(it)
                } ?: ""
            }"
            QualityItem(
                label = label,
                rightText = rightInfo,
                isSelected = true,
                showCheck = false,
                onClick = { /* Already selected, maybe nothing or just re-select current? */ }
            )
        }

        // List
        distinctResolutions.forEach { resolution ->
            val isOriginal = originalQuality != null && originalQuality.resolution == resolution &&
                    resolution == qualities.first().resolution

            val targetQuality = if (isOriginal) {
                qualities.first()
            } else {
                grouped[resolution]?.maxByOrNull { it.bitrate } ?: qualities.first()
            }

            val isSelected = if (isCustomSelection) false else {
                currentResolution == resolution &&
                        (if (isOriginal) currentBitrate == targetQuality.bitrate else true)
            }

            val label = if (isOriginal) "原画质" else formatResolution(resolution)
            val rightInfo = if (isOriginal) {
                "${formatResolution(targetQuality.resolution)} ${formatBitrateSimple(targetQuality.bitrate)}"
            } else null

            QualityItem(
                label = label,
                rightText = rightInfo,
                isSelected = isSelected,
                showCheck = false, // Requirement: No checkmark in simple list
                onClick = { onQualitySelected(targetQuality) }
            )
        }
    }
}

@Composable
private fun CustomQualityPage(
    qualities: List<QualityResponse>,
    currentResolution: String,
    currentBitrate: Int?,
    onBack: () -> Unit,
    onQualitySelected: (QualityResponse) -> Unit
) {
    // Two columns.
    // Left: Resolutions. Right: Bitrates for selected resolution.

    // We need state for selected resolution in this view (initially currentResolution).
    var selectedRes by remember { mutableStateOf(currentResolution) }

    val grouped = remember(qualities) { qualities.groupBy { it.resolution } }
    val resolutions = remember(qualities) { qualities.map { it.resolution }.distinct() }

    Column(
        modifier = Modifier
            .width(360.dp)
            .height(345.dp) // Fixed height for scrolling
            .padding(vertical = 10.dp)
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "自定义视频质量",
                color = DefaultTextColor,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium
            )
            // Current info on right
            val currentQ =
                qualities.find { it.resolution == currentResolution && it.bitrate == currentBitrate }
            // Or construct from params
            if (currentQ != null) {
                val isOriginal = currentQ == qualities.first()
                val info = "${formatBitrateSimple(currentQ.bitrate)} - ${
                    if (isOriginal) "原画质" else formatResolution(currentQ.resolution)
                }"
                Text(
                    text = info,
                    color = SelectedTextColor,
                    fontSize = 14.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        Row(modifier = Modifier.weight(1f)) {
            // Left Column: Resolutions
            Column(
                modifier = Modifier
                    .weight(0.4f)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 4.dp)
            ) {
                resolutions.forEach { res ->
                    val isSelected = res == selectedRes
                    QualityItem(
                        label = formatResolution(res),
                        isSelected = isSelected,
                        showCheck = false, // Just highlight
                        showArrow = true,
                        onClick = { selectedRes = res }
                    )
                }
            }

            // Divider
            Box(
                modifier = Modifier.width(1.dp).fillMaxWidth()
                    .background(Color.Gray.copy(alpha = 0.2f))
            )
            val lazyListState = rememberLazyListState()

            AnimatedScrollbarLazyColumn(
                listState = lazyListState,
                modifier = Modifier.weight(0.6f).padding(horizontal = 4.dp),
                scrollbarWidth = 2.dp
            ) {
                val bitrates = grouped[selectedRes] ?: emptyList()
                items(bitrates) { q ->
                    val isOriginal = q == qualities.first()
                    val label =
                        if (isOriginal) "${formatBitrateSimple(q.bitrate)} - 原画质" else formatBitrateSimple(
                            q.bitrate
                        )
                    val isSelected =
                        currentResolution == q.resolution && currentBitrate == q.bitrate
                    QualityItem(
                        label = label,
                        isSelected = isSelected,
                        onClick = { onQualitySelected(q) }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun QualityItem(
    label: String,
    rightText: String? = null,
    isSelected: Boolean,
    showCheck: Boolean = true,
    showArrow: Boolean = false,
    onClick: () -> Unit
) {
    var isHovered by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(if (isHovered || (isSelected && !showCheck)) HoverBackgroundColor else Color.Transparent) // Highlight if selected in left col
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 10.dp)
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            color = if (isSelected) SelectedTextColor else DefaultTextColor,
            fontSize = 16.sp,
            fontWeight = FontWeight.Normal
        )

        Row(verticalAlignment = Alignment.CenterVertically) {
            if (rightText != null) {
                Text(
                    text = rightText,
                    color = if (isSelected) SelectedTextColor else DefaultTextColor,
                    fontSize = 14.sp,
                    modifier = Modifier.padding(end = 8.dp)
                )
            }

            if (isSelected && showCheck) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Selected",
                    tint = SelectedTextColor,
                    modifier = Modifier.size(20.dp)
                )
            }

            if (showArrow) {
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = if (isSelected) SelectedTextColor else DefaultTextColor,
                    modifier = Modifier.size(20.dp)
                )
            }
        }
    }
}
