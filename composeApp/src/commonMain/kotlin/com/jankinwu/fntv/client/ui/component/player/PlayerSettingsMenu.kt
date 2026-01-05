package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.manager.PlayerResourceManager
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import com.jankinwu.fntv.client.ui.selectedSwitcherStyle
import io.github.alexzhirkevich.compottie.animateLottieCompositionAsState
import io.github.alexzhirkevich.compottie.rememberLottieComposition
import io.github.alexzhirkevich.compottie.rememberLottiePainter
import io.github.composefluent.component.Switcher
import io.github.composefluent.component.SwitcherDefaults
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.ExperimentalResourceApi
import kotlin.math.roundToInt

private val FlyoutBackgroundColor = Color.Black.copy(alpha = 0.9f)
private val FlyoutBorderColor = Color.Gray.copy(alpha = 0.5f)
private val SelectedTextColor = Color(0xFF2073DF)
private val HoverBackgroundColor = Color.White.copy(alpha = 0.1f)
private val DefaultTextColor = Color.White.copy(alpha = 0.7843f)
private val MenuWidth = 320.dp
private val FlyoutShape = RoundedCornerShape(8.dp)
private const val HIDE_DELAY_MS = 200L
private const val ANIMATION_DURATION_MS = 200

@OptIn(ExperimentalResourceApi::class, ExperimentalComposeUiApi::class)
@Composable
fun PlayerSettingsMenu(
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData?,
    currentPositionMillis: Long,
    totalDurationMillis: Long,
    onAudioSelected: (AudioStream) -> Unit,
    onWindowAspectRatioChanged: (String) -> Unit,
//    currentVideoAspectRatio: AspectRatioMode?,
//    onVideoAspectRatioChanged: (AspectRatioMode) -> Unit,
    onSkipConfigChanged: (Int, Int) -> Unit,
    modifier: Modifier = Modifier,
    onHoverStateChanged: ((Boolean) -> Unit)? = null,
    smartSkipEnabled: Boolean = true,
    onSmartSkipEnabledChanged: (Boolean) -> Unit = {},
    isSmartAnalysisGloballyEnabled: Boolean = false
) {
    val compositionSpec = PlayerResourceManager.settingsSpec
    val composition = if (compositionSpec != null) {
        val c by rememberLottieComposition { compositionSpec }
        c
    } else {
        null
    }

    var isPlaying by remember { mutableStateOf(false) }

    var isExpanded by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var isButtonHovered by remember { mutableStateOf(false) }
    var popupHovered by remember { mutableStateOf(false) }
    var showPopup by remember { mutableStateOf(false) }
    var currentScreen by remember { mutableStateOf("Main") }

    fun showFlyout() {
        hideJob?.cancel()
        isExpanded = true
        showPopup = true
    }

    fun hideFlyoutWithDelay() {
        hideJob = coroutineScope.launch {
            delay(HIDE_DELAY_MS)
            if (!isButtonHovered && !popupHovered) {
                isExpanded = false
                onHoverStateChanged?.invoke(false)
                delay(ANIMATION_DURATION_MS.toLong())
                showPopup = false
                currentScreen = "Main"
            }
        }
    }

    Box(
        modifier = modifier
            .pointerHoverIcon(PointerIcon.Hand)
            .onPointerEvent(PointerEventType.Enter) {
                isButtonHovered = true
                onHoverStateChanged?.invoke(true)
                isPlaying = true
                showFlyout()
            }
            .onPointerEvent(PointerEventType.Exit) {
                isButtonHovered = false
                popupHovered = false
                onHoverStateChanged?.invoke(false)
                hideFlyoutWithDelay()
            },
        contentAlignment = Alignment.Center
    ) {
        if (composition != null) {
            val progress by animateLottieCompositionAsState(
                composition = composition,
                isPlaying = isPlaying,
                iterations = 1,
                restartOnPlay = true
            )
            LaunchedEffect(progress) {
                if (progress == 1f && isPlaying) {
                    isPlaying = false
                }
            }

            Image(
                painter = rememberLottiePainter(composition, progress = { progress }),
                contentDescription = "设置",
                modifier = Modifier.size(24.dp)
            )
        } else {
            Icon(
                imageVector = Icons.Default.Settings,
                contentDescription = "设置",
                tint = Color.White,
                modifier = Modifier.size(24.dp)
            )
        }

        if (showPopup) {
            Popup(
                offset = IntOffset(0, -70),
                alignment = Alignment.BottomCenter,
                properties = PopupProperties(
                    clippingEnabled = false,
                    focusable = false
                ),
                onDismissRequest = {
                    if (!isButtonHovered && !popupHovered) {
                        isExpanded = false
                        onHoverStateChanged?.invoke(false)
                    }
                }
            ) {
                Box(
                    modifier = Modifier
                        .pointerHoverIcon(PointerIcon.Hand)
                        .onPointerEvent(PointerEventType.Enter) {
                            popupHovered = true
                            onHoverStateChanged?.invoke(true)
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
                        SettingsFlyoutContent(
                            playingInfoCache = playingInfoCache,
                            isoTagData = isoTagData,
                            currentPositionMillis = currentPositionMillis,
                            totalDurationMillis = totalDurationMillis,
                            currentScreen = currentScreen,
                            onNavigate = { currentScreen = it },
                            onAudioSelected = {
                                onAudioSelected(it)
                                isExpanded = false
                                currentScreen = "Main"
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            onWindowAspectRatioChanged = {
                                onWindowAspectRatioChanged(it)
                                isExpanded = false
                                currentScreen = "Main"
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            // currentVideoAspectRatio = currentVideoAspectRatio,
                            // onVideoAspectRatioChanged = {
                            //     onVideoAspectRatioChanged(it)
                            //     isExpanded = false
                            //     currentScreen = "Main"
                            //     if (!isButtonHovered) {
                            //         onHoverStateChanged?.invoke(false)
                            //     }
                            // },
                            onSkipConfigChanged = onSkipConfigChanged,
                            smartSkipEnabled = smartSkipEnabled,
                            onSmartSkipEnabledChanged = onSmartSkipEnabledChanged,
                            isSmartAnalysisGloballyEnabled = isSmartAnalysisGloballyEnabled
                        )
                    }
                }
            }
        }
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
fun SettingsFlyoutContent(
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData?,
    currentPositionMillis: Long,
    totalDurationMillis: Long,
    currentScreen: String,
    onNavigate: (String) -> Unit,
    onAudioSelected: (AudioStream) -> Unit,
    onWindowAspectRatioChanged: (String) -> Unit,
//    currentVideoAspectRatio: AspectRatioMode?,
//    onVideoAspectRatioChanged: (AspectRatioMode) -> Unit,
    onSkipConfigChanged: (Int, Int) -> Unit,
    smartSkipEnabled: Boolean,
    onSmartSkipEnabledChanged: (Boolean) -> Unit,
    isSmartAnalysisGloballyEnabled: Boolean
) {
    Surface(
        shape = FlyoutShape,
        color = FlyoutBackgroundColor,
        border = BorderStroke(1.dp, FlyoutBorderColor),
        modifier = Modifier.width(MenuWidth)
    ) {
        Box(modifier = Modifier.padding(start = 8.dp, top = 16.dp, bottom = 16.dp, end = 8.dp)) {
            when (currentScreen) {
                "Main" -> MainSettingsScreen(
                    playingInfoCache = playingInfoCache,
                    isoTagData = isoTagData,
                    smartSkipEnabled = smartSkipEnabled,
                    isSmartAnalysisGloballyEnabled = isSmartAnalysisGloballyEnabled,
                    //                    currentVideoAspectRatio = currentVideoAspectRatio,
                    onNavigateToAudio = { onNavigate("Audio") },
                    onNavigateToWindowAspectRatio = { onNavigate("WindowAspectRatio") },
                    //                    onNavigateToVideoAspectRatio = { onNavigate("VideoAspectRatio") },
                    onNavigateToSkipConfig = { onNavigate("SkipConfig") }
                )

                "Audio" -> AudioSettingsScreen(
                    playingInfoCache = playingInfoCache,
                    isoTagData = isoTagData,
                    onBack = { onNavigate("Main") },
                    onAudioSelected = onAudioSelected
                )

                "WindowAspectRatio" -> WindowAspectRatioSettingsScreen(
                    onBack = { onNavigate("Main") },
                    onAspectRatioSelected = onWindowAspectRatioChanged
                )
//                "VideoAspectRatio" -> VideoAspectRatioSettingsScreen(
//                    currentAspectRatio = currentVideoAspectRatio,
//                    onBack = { onNavigate("Main") },
//                    onAspectRatioSelected = onVideoAspectRatioChanged
//                )
                "SkipConfig" -> SkipConfigSettingsScreen(
                    playingInfoCache = playingInfoCache,
                    currentPositionMillis = currentPositionMillis,
                    totalDurationMillis = totalDurationMillis,
                    onBack = { onNavigate("Main") },
                    onConfigChanged = onSkipConfigChanged,
                    smartSkipEnabled = smartSkipEnabled,
                    onSmartSkipEnabledChanged = onSmartSkipEnabledChanged,
                    isSmartAnalysisGloballyEnabled = isSmartAnalysisGloballyEnabled
                )
            }
        }
    }
}

@Composable
fun MainSettingsScreen(
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData?,
    smartSkipEnabled: Boolean,
    isSmartAnalysisGloballyEnabled: Boolean,
//    currentVideoAspectRatio: AspectRatioMode?,
    onNavigateToAudio: () -> Unit,
    onNavigateToWindowAspectRatio: () -> Unit,
//    onNavigateToVideoAspectRatio: () -> Unit,
    onNavigateToSkipConfig: () -> Unit
) {
    val currentAudio = playingInfoCache?.currentAudioStream
    val language = if (currentAudio != null) {
        FnDataConvertor.getLanguageName(currentAudio.language, isoTagData)
    } else {
        "未知"
    }
    val audioDetails = if (currentAudio != null) {
        "${currentAudio.codecName} ${currentAudio.channelLayout}"
    } else {
        ""
    }

    Column(modifier = Modifier) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "设置",
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(vertical = 12.dp),
            color = Color.White.copy(alpha = 0.1f)
        )

        // Skip Config
        if (playingInfoCache?.isEpisode == true || playingInfoCache?.item?.type == FnTvMediaType.EPISODE.value) {
            val skipOpening = playingInfoCache.playConfig?.skipOpening ?: 0
            val skipEnding = playingInfoCache.playConfig?.skipEnding ?: 0
            val skipText = when {
                isSmartAnalysisGloballyEnabled && smartSkipEnabled -> "智能跳过"
                skipOpening > 0 && skipEnding > 0 -> "跳过片头片尾"
                skipOpening > 0 -> "已设置片头"
                skipEnding > 0 -> "已设置片尾"
                else -> "未设置"
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onNavigateToSkipConfig() }
                    .padding(top = 8.dp, bottom = 8.dp, start = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("跳过片头/片尾", color = DefaultTextColor, fontSize = 14.sp)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = skipText,
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
        }

        // Aspect Ratio
//        val videoAspectRatioText = when (currentVideoAspectRatio) {
//            AspectRatioMode.FIT -> "适应"
//            AspectRatioMode.STRETCH -> "拉伸"
//            AspectRatioMode.CROP -> "裁剪"
//            AspectRatioMode.ORIGINAL -> "原始"
//            else -> "自动"
//        }

//        Row(
//            modifier = Modifier
//                .fillMaxWidth()
//                .clickable { onNavigateToVideoAspectRatio() }
//                .padding(top = 8.dp, bottom = 8.dp, start = 8.dp),
//            horizontalArrangement = Arrangement.SpaceBetween,
//            verticalAlignment = Alignment.CenterVertically
//        ) {
//            Text("画面比例", color = DefaultTextColor, fontSize = 14.sp)
//            Row(verticalAlignment = Alignment.CenterVertically) {
//                Text(
//                    text = videoAspectRatioText,
//                    color = DefaultTextColor,
//                    fontSize = 14.sp
//                )
//                Icon(
//                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
//                    contentDescription = null,
//                    tint = DefaultTextColor,
//                    modifier = Modifier.size(16.dp)
//                )
//            }
//    }

        val currentWindowAspectRatio = PlayingSettingsStore.playerWindowAspectRatio
        val currentWindowAspectRatioText = when (currentWindowAspectRatio) {
            "AUTO" -> "自动"
            else -> currentWindowAspectRatio
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onNavigateToWindowAspectRatio() }
                .padding(top = 8.dp, bottom = 8.dp, start = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("窗口比例", color = DefaultTextColor, fontSize = 14.sp)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = currentWindowAspectRatioText,
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

        // Audio
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onNavigateToAudio() }
                .padding(top = 8.dp, bottom = 8.dp, start = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("音频", color = DefaultTextColor, fontSize = 14.sp)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "$language $audioDetails",
                    color = DefaultTextColor,
                    fontSize = 14.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = DefaultTextColor,
                    modifier = Modifier.size(16.dp)
                )
            }
        }
    }
}

@Composable
fun WindowAspectRatioSettingsScreen(
    onBack: () -> Unit,
    onAspectRatioSelected: (String) -> Unit
) {
    val currentRatio = PlayingSettingsStore.playerWindowAspectRatio
    val options = listOf("AUTO", "4:3", "16:9", "21:9")
    val optionLabels = mapOf(
        "AUTO" to "自动",
        "4:3" to "4:3",
        "16:9" to "16:9",
        "21:9" to "21:9"
    )

    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onBack() }
                .padding(bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp).graphicsLayer { rotationZ = 180f }
            )
            Text(
                text = "窗口比例",
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 8.dp)
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(bottom = 12.dp),
            color = Color.White.copy(alpha = 0.1f)
        )

        Column {
            options.forEach { option ->
                val isSelected = option == currentRatio
                val label = optionLabels[option] ?: option

                AspectRatioOptionItem(
                    label = label,
                    isSelected = isSelected,
                    onClick = { onAspectRatioSelected(option) }
                )
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun AspectRatioOptionItem(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val textColor = if (isSelected) SelectedTextColor else DefaultTextColor
    var isHovered by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 4.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(if (isHovered) HoverBackgroundColor else Color.Transparent)
            .clickable(onClick = onClick)
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            color = textColor,
            fontSize = 14.sp,
            fontWeight = FontWeight.Bold
        )

        if (isSelected) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = null,
                tint = SelectedTextColor,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}

@Composable
fun AudioSettingsScreen(
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData?,
    onBack: () -> Unit,
    onAudioSelected: (AudioStream) -> Unit
) {
    val currentAudioStream = playingInfoCache?.currentAudioStream
    LaunchedEffect(currentAudioStream) {
        Logger.i("AudioSettingsScreen: currentAudioStream changed to ${currentAudioStream?.title} (${currentAudioStream?.guid}), index: ${playingInfoCache?.currentAudioStream?.index}")
    }
    val audioList = playingInfoCache?.currentAudioStreamList ?: emptyList()

    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onBack() }
                .padding(bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(16.dp).graphicsLayer { rotationZ = 180f }
            )
            Text(
                text = "音频",
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(start = 8.dp)
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(bottom = 12.dp),
            color = Color.White.copy(alpha = 0.1f)
        )

        Column {
            audioList.forEach { audio ->
                val isSelected = currentAudioStream?.index == audio.index
                val language = FnDataConvertor.getLanguageName(audio.language, isoTagData)
                val label = "$language ${audio.codecName} ${audio.channelLayout}"

                AspectRatioOptionItem(
                    label = label,
                    isSelected = isSelected,
                    onClick = { onAudioSelected(audio) }
                )
            }
        }
    }
}

@Composable
fun SkipConfigSettingsScreen(
    playingInfoCache: PlayingInfoCache?,
    currentPositionMillis: Long,
    totalDurationMillis: Long,
    onBack: () -> Unit,
    onConfigChanged: (Int, Int) -> Unit,
    smartSkipEnabled: Boolean,
    onSmartSkipEnabledChanged: (Boolean) -> Unit,
    isSmartAnalysisGloballyEnabled: Boolean
) {
    val playConfig = playingInfoCache?.playConfig
    var skipOpening by remember { mutableIntStateOf(playConfig?.skipOpening ?: 0) }
    var skipEnding by remember { mutableIntStateOf(playConfig?.skipEnding ?: 0) }

    // Max value for sliders.
    val maxDuration = 600f

    // Scope text
    val scopeText = playingInfoCache?.item?.let {
        "《${it.tvTitle}》 第 ${it.seasonNumber} 季"
    } ?: "未知"

    val manualEnabled = !isSmartAnalysisGloballyEnabled || !smartSkipEnabled

    Column {
        // Header with Back Button, Title, and Reset Button
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = Modifier
                    .weight(1f)
                    .clickable { onBack() },
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp).graphicsLayer { rotationZ = 180f }
                )
                Text(
                    text = "跳过片头/片尾",
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.padding(start = 8.dp)
                )
            }

            // Reset Button
            Text(
                text = "重置",
                color = if (manualEnabled) Colors.TextSecondaryColor else Colors.TextSecondaryColor.copy(alpha = 0.5f),
                fontSize = 14.sp,
                modifier = Modifier
                    .padding(horizontal = 8.dp)
                    .border(
                        width = 1.dp,
                        color = if (manualEnabled) Colors.TextSecondaryColor else Colors.TextSecondaryColor.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(50)
                    )
                    .clickable(enabled = manualEnabled) {
                        skipOpening = 0
                        skipEnding = 0
                        onConfigChanged(0, 0)
                    }
                    .padding(horizontal = 8.dp, vertical = 2.dp)
            )
        }

        // Scope Text
        Text(
            text = "生效范围: $scopeText",
            color = DefaultTextColor,
            fontSize = 12.sp,
            modifier = Modifier
                .padding(start = 8.dp, end = 8.dp, bottom = 12.dp)
        )

        if (isSmartAnalysisGloballyEnabled) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 8.dp, end = 8.dp, bottom = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("智能跳过片头/片尾", color = DefaultTextColor, fontSize = 14.sp)
                Switch(
                    checked = smartSkipEnabled,
                    onCheckedChange = { onSmartSkipEnabledChanged(it) },
                    modifier = Modifier.scale(0.7f).height(30.dp),
                    colors = SwitchDefaults.colors(
                        checkedThumbColor = Color.White,
                        checkedTrackColor = SelectedTextColor,
                        uncheckedThumbColor = Color.White,
                        uncheckedTrackColor = Color.Gray.copy(alpha = 0.5f),
                        uncheckedBorderColor = Color.Transparent
                    )
                )
//                Switcher(
//                    checked = smartSkipEnabled,
//                    onCheckStateChange = { onSmartSkipEnabledChanged(it) },
//                    styles = if (smartSkipEnabled) {
//                        selectedSwitcherStyle()
//                    } else {
//                        SwitcherDefaults.defaultSwitcherStyle()
//                    },
//                )
            }
        }

        HorizontalDivider(
            modifier = Modifier.padding(bottom = 12.dp),
            color = Color.White.copy(alpha = 0.1f)
        )


        Spacer(modifier = Modifier.height(8.dp))

        // Intro Skip
        Column(modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp).alpha(if (manualEnabled) 1f else 0.5f)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("跳过片头", color = DefaultTextColor, fontSize = 14.sp)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = FnDataConvertor.formatDurationToDateTime(skipOpening * 1000L),
                        color = DefaultTextColor,
                        fontSize = 14.sp
                    )
                }
                val formattedCurrentPosition = FnDataConvertor.formatDurationToDateTime(currentPositionMillis)
                if (currentPositionMillis <= maxDuration * 1000) {
                    Text(
                        text = "将当前时间 $formattedCurrentPosition 设为片头",
                        color = SelectedTextColor,
                        fontSize = 12.sp,
                        modifier = Modifier
                            .clickable(enabled = manualEnabled) {
                                val newSkipOpening = (currentPositionMillis / 1000).toInt()
                                skipOpening = newSkipOpening
                                onConfigChanged(skipOpening, skipEnding)
                            }
//                            .padding(vertical = 4.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            HorizontalTimeSlider(
                value = skipOpening.toFloat(),
                maxValue = maxDuration,
                isReverse = false,
                onValueChange = {
                    if (manualEnabled) skipOpening = it.roundToInt()
                },
                onValueChangeFinished = {
                    if (manualEnabled) onConfigChanged(skipOpening, skipEnding)
                },
                enabled = manualEnabled
            )
            Spacer(modifier = Modifier.height(4.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "开始",
                    color = DefaultTextColor,
                    fontSize = 14.sp
                )
                Text(
                    text = "10 分钟",
                    color = DefaultTextColor,
                    fontSize = 14.sp
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Outro Skip
        Column(modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp).alpha(if (manualEnabled) 1f else 0.5f)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("跳过片尾", color = DefaultTextColor, fontSize = 14.sp)
                    Spacer(modifier = Modifier.width(4.dp))
                    Text(
                        text = FnDataConvertor.formatDurationToDateTime(skipEnding * 1000L),
                        color = DefaultTextColor,
                        fontSize = 14.sp
                    )
                }
                // Set Remaining as Outro
                val remainingMillis = if (totalDurationMillis > currentPositionMillis) {
                    totalDurationMillis - currentPositionMillis
                } else {
                    0L
                }
                val formattedRemaining = FnDataConvertor.formatDurationToDateTime(remainingMillis)

                if (remainingMillis <= maxDuration * 1000) {
                    Text(
                        text = "将当前剩余时长 $formattedRemaining 设为片尾",
                        color = SelectedTextColor,
                        fontSize = 12.sp,
                        modifier = Modifier
                            .clickable(enabled = manualEnabled) {
                                val newSkipEnding = (remainingMillis / 1000).toInt()
                                skipEnding = newSkipEnding
                                onConfigChanged(skipOpening, skipEnding)
                            }
//                            .padding(vertical = 4.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            HorizontalTimeSlider(
                value = skipEnding.toFloat(),
                maxValue = maxDuration,
                isReverse = true,
                onValueChange = {
                    if (manualEnabled) skipEnding = it.roundToInt()
                },
                onValueChangeFinished = {
                    if (manualEnabled) onConfigChanged(skipOpening, skipEnding)
                },
                enabled = manualEnabled
            )

            Spacer(modifier = Modifier.height(4.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(
                    text = "10 分钟",
                    color = DefaultTextColor,
                    fontSize = 14.sp
                )
                Text(
                    text = "结束",
                    color = DefaultTextColor,
                    fontSize = 14.sp
                )
            }
        }
    }
}

@Composable
fun HorizontalTimeSlider(
    value: Float,
    maxValue: Float,
    isReverse: Boolean = false,
    onValueChange: (Float) -> Unit,
    onValueChangeFinished: () -> Unit,
    enabled: Boolean = true
) {
    val barHeight = 4.dp
    val thumbRadius = 6.dp

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(20.dp)
            .pointerInput(enabled) {
                if (enabled) {
                    detectTapGestures { offset ->
                        val rawRatio = offset.x / size.width
                        val newValue = if (isReverse) {
                            ((1f - rawRatio) * maxValue).coerceIn(0f, maxValue)
                        } else {
                            (rawRatio * maxValue).coerceIn(0f, maxValue)
                        }
                        onValueChange(newValue)
                        onValueChangeFinished()
                    }
                }
            }
            .pointerInput(enabled) {
                if (enabled) {
                    detectDragGestures(
                        onDragEnd = { onValueChangeFinished() }
                    ) { change, _ ->
                        val rawRatio = change.position.x / size.width
                        val newValue = if (isReverse) {
                            ((1f - rawRatio) * maxValue).coerceIn(0f, maxValue)
                        } else {
                            (rawRatio * maxValue).coerceIn(0f, maxValue)
                        }
                        onValueChange(newValue)
                        change.consume()
                    }
                }
            }
            .alpha(if (enabled) 1f else 0.5f)
    ) {
        Canvas(modifier = Modifier.fillMaxWidth().height(20.dp)) {
            val trackYCenter = size.height / 2
            val trackHeight = barHeight.toPx()

            // Background
            drawLine(
                color = Color.White.copy(alpha = 0.3f),
                start = Offset(0f, trackYCenter),
                end = Offset(size.width, trackYCenter),
                strokeWidth = trackHeight,
                cap = StrokeCap.Round
            )

            // Active Progress
            val progressRatio = if (maxValue > 0) value / maxValue else 0f
            val activeWidth = progressRatio * size.width

            if (activeWidth > 0) {
                val startX = if (isReverse) size.width else 0f
                val endX = if (isReverse) size.width - activeWidth else activeWidth

                drawLine(
                    color = Color(0xFF3B82F6),
                    start = Offset(startX, trackYCenter),
                    end = Offset(endX, trackYCenter),
                    strokeWidth = trackHeight,
                    cap = StrokeCap.Round
                )
            }

            // Thumb
            val thumbX = if (isReverse) size.width - activeWidth else activeWidth
            drawCircle(
                color = Color.White,
                radius = thumbRadius.toPx(),
                center = Offset(thumbX, trackYCenter)
            )
        }
    }
}
