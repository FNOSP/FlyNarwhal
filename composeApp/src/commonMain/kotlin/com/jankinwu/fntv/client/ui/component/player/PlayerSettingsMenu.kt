package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.manager.PlayerResourceManager
import com.jankinwu.fntv.client.ui.component.common.AnimatedScrollbarLazyColumn
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import io.github.alexzhirkevich.compottie.animateLottieCompositionAsState
import io.github.alexzhirkevich.compottie.rememberLottieComposition
import io.github.alexzhirkevich.compottie.rememberLottiePainter
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.ExperimentalResourceApi

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
    onAudioSelected: (AudioStream) -> Unit,
    modifier: Modifier = Modifier,
    onHoverStateChanged: ((Boolean) -> Unit)? = null
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
                // isPlaying = false // Keep playing or stop? Original code stopped at end.
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
                offset = IntOffset(-140, -65), // Adjust based on position (similar to QualityControlFlyout)
                alignment = Alignment.BottomCenter,
                properties = PopupProperties(
                    clippingEnabled = false,
                    focusable = false // Important for hover behavior
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
                            // onHoverStateChanged?.invoke(false) // Wait for hide logic
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
                            currentScreen = currentScreen,
                            onNavigate = { currentScreen = it },
                            onAudioSelected = {
                                onAudioSelected(it)
                                isExpanded = false
                                currentScreen = "Main"
                            }
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
    currentScreen: String,
    onNavigate: (String) -> Unit,
    onAudioSelected: (AudioStream) -> Unit
) {
    Surface(
        shape = FlyoutShape,
        color = FlyoutBackgroundColor,
        border = BorderStroke(1.dp, FlyoutBorderColor),
        modifier = Modifier.width(MenuWidth)
    ) {
        Box(modifier = Modifier.padding(start = 8.dp, top = 16.dp, bottom = 16.dp, end = 8.dp)) {
            if (currentScreen == "Main") {
                MainSettingsScreen(
                    playingInfoCache = playingInfoCache,
                    isoTagData = isoTagData,
                    onNavigateToAudio = { onNavigate("Audio") }
                )
            } else if (currentScreen == "Audio") {
                AudioSettingsScreen(
                    playingInfoCache = playingInfoCache,
                    isoTagData = isoTagData,
                    onBack = { onNavigate("Main") },
                    onAudioSelected = onAudioSelected
                )
            }
        }
    }
}

@Composable
fun MainSettingsScreen(
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData?,
    onNavigateToAudio: () -> Unit
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

        // Aspect Ratio (Placeholder)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp, bottom = 8.dp, start = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("画面比例", color = DefaultTextColor, fontSize = 14.sp)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "自动",
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
        val lazyListState = rememberLazyListState()
        AnimatedScrollbarLazyColumn(
            listState = lazyListState,
            modifier = Modifier.height(200.dp),
            scrollbarWidth = 2.dp,
            scrollbarOffsetX = 3.dp
        ) {
            items(audioList) { audio ->
                val isSelected = audio.guid == currentAudioStream?.guid
                val language = FnDataConvertor.getLanguageName(audio.language, isoTagData)
                val details = "${audio.codecName} ${audio.channelLayout}"
                val title = audio.title

                AudioOptionItem(
                    language = language,
                    details = details,
                    title = title,
                    isDefault = audio.isDefault == 1,
                    isSelected = isSelected,
                    onClick = {
                        onAudioSelected(audio)
                        playingInfoCache?.currentAudioStream = audio
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun AudioOptionItem(
    language: String,
    details: String,
    title: String,
    isDefault: Boolean,
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
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = language,
                    color = textColor,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                if (isDefault) {
                    Text(
                        text = " - 默认",
                        color = textColor,
                        fontSize = 14.sp
                    )
                }
            }
            Text(
                text = "$details  $title",
                color = if (isSelected) SelectedTextColor.copy(alpha = 0.8f) else DefaultTextColor.copy(alpha = 0.6f),
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        
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
