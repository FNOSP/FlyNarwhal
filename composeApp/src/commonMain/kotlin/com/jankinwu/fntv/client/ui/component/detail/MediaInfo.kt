package com.jankinwu.fntv.client.ui.component.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.ui.screen.CurrentStreamData
import com.jankinwu.fntv.client.ui.screen.LocalIsoTagData
import io.github.composefluent.FluentTheme

// 文件信息数据
data class FileInfoData(
    val location: String = "",
    val size: String = "",
    val createdDate: String = "",
    val addedDate: String = ""
)

// 媒体轨道信息 (用于视频、音频、字幕)
data class MediaTrackInfo(
    // "视频", "音频", "字幕"
    val type: String = "",
    var details: String = "",
    val icon: ImageVector
)

// 聚合数据
data class MediaDetails(
    val fileInfo: FileInfoData,
    val videoTrack: MediaTrackInfo,
    val audioTrack: MediaTrackInfo,
    val subtitleTrack: MediaTrackInfo,
    val imdbLink: String
)

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun MediaInfo(modifier: Modifier = Modifier, currentStreamData: CurrentStreamData, imdbId: String?) {
    val isoTagData = LocalIsoTagData.current
    val uriHandler = LocalUriHandler.current
    val mediaDetailData =
        FnDataConvertor.convertToMediaDetails(currentStreamData, isoTagData, imdbId)

    // 整体容器
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Transparent)
            .padding(vertical = 24.dp)
    ) {
        // 1. 文件信息部分
        FileInfoSection(mediaDetailData.fileInfo)

        Spacer(modifier = Modifier.height(24.dp))

        // 2. 视频信息部分
        VideoInfoSection(
            video = mediaDetailData.videoTrack,
            audio = mediaDetailData.audioTrack,
            subtitle = mediaDetailData.subtitleTrack
        )

        Spacer(modifier = Modifier.height(24.dp))

        // 3. 底部链接
        if (mediaDetailData.imdbLink.isNotBlank()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = "链接:  ",
                    color = FluentTheme.colors.text.text.secondary,
                    fontSize = 14.sp
                )
                var isImdbHovered by remember { mutableStateOf(false) }
                Text(
                    text = "IMDB链接",
                    color = FluentTheme.colors.text.text.primary,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    modifier = Modifier
                        .onPointerEvent(PointerEventType.Enter) { isImdbHovered = true }
                        .onPointerEvent(PointerEventType.Exit) { isImdbHovered = false }
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null
                        ) {
                            uriHandler.openUri(mediaDetailData.imdbLink)
                        }
                        .pointerHoverIcon(PointerIcon.Hand),
                    style = if (isImdbHovered) {
                        TextStyle(textDecoration = TextDecoration.Underline) // 悬停时添加下划线
                    } else {
                        LocalTextStyle.current
                    }
                )
            }
        }
    }
}


// --- 组件：文件信息区域 ---
@Composable
fun FileInfoSection(info: FileInfoData) {
    SectionHeader(title = "文件信息")

    Surface(
        color = FluentTheme.colors.stroke.control.default,
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            // 文件位置 (可能很长，需要换行)
            InfoRow(label = "文件位置:", value = info.location, isLongText = true)

            Spacer(modifier = Modifier.height(12.dp))

            // 第二行：大小、日期等
            Row(modifier = Modifier.fillMaxWidth()) {
                InfoLabelValue(label = "文件大小:", value = info.size, modifier = Modifier.width(140.dp))
//                Spacer(modifier = Modifier.width(24.dp))
                InfoLabelValue(label = "文件创建日期:", value = info.createdDate, modifier = Modifier.width(220.dp))
//                Spacer(modifier = Modifier.width(24.dp))
                InfoLabelValue(label = "添加日期:", value = info.addedDate)
            }
        }
    }
}

// --- 组件：视频/媒体信息区域 ---
@Composable
fun VideoInfoSection(
    video: MediaTrackInfo,
    audio: MediaTrackInfo,
    subtitle: MediaTrackInfo
) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(bottom = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "视频信息",
            color = FluentTheme.colors.text.text.primary,
            fontWeight = FontWeight.Bold,
            fontSize = 14.sp
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) { /* 查看全部 */ }
        ) {
            Text(
                text = "查看全部",
                color = FluentTheme.colors.text.text.secondary,
                fontSize = 12.sp
            )
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = FluentTheme.colors.text.text.secondary,
                modifier = Modifier.size(16.dp)
            )
        }
    }

    Surface(
        color = FluentTheme.colors.stroke.control.default,
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .padding(16.dp)
                .fillMaxWidth()
        ) {
            // 使用 Weight 平分三列
            Box(modifier = Modifier.weight(1f)) {
                TrackItem(video)
            }
            Box(modifier = Modifier.weight(1f)) {
                TrackItem(audio)
            }
            Box(modifier = Modifier.weight(1f)) {
                TrackItem(subtitle)
            }
        }
    }
}

// --- 辅助小组件 ---

@Composable
fun SectionHeader(title: String) {
    Text(
        text = title,
        color = FluentTheme.colors.text.text.primary,
        fontWeight = FontWeight.Bold,
        fontSize = 14.sp,
        modifier = Modifier.padding(bottom = 8.dp)
    )
}

@Composable
fun InfoRow(label: String, value: String, isLongText: Boolean = false) {
    Row(verticalAlignment = if (isLongText) Alignment.Top else Alignment.CenterVertically) {
        Text(
            text = label,
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 13.sp,
            modifier = Modifier.padding(end = 8.dp)
        )
        Text(
            text = value,
            color = FluentTheme.colors.text.text.primary,
            fontSize = 13.sp,
            lineHeight = 20.sp
        )
    }
}

@Composable
fun InfoLabelValue(label: String, value: String, modifier: Modifier = Modifier) {
    Row(modifier = modifier) {
        Text(
            text = "$label ",
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 13.sp
        )
        Text(
            text = value,
            color = FluentTheme.colors.text.text.primary,
            fontSize = 13.sp,
            fontWeight = FontWeight.Normal
        )
    }
}

@Composable
fun TrackItem(track: MediaTrackInfo) {
    Column(horizontalAlignment = Alignment.Start) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = track.icon,
                contentDescription = null,
                tint = FluentTheme.colors.text.text.secondary,
                modifier = Modifier.size(18.dp)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = track.type,
                color = FluentTheme.colors.text.text.secondary,
                fontSize = 14.sp
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = track.details,
            color = FluentTheme.colors.text.text.primary,
            fontSize = 13.sp,
            fontWeight = FontWeight.Normal
        )
    }
}