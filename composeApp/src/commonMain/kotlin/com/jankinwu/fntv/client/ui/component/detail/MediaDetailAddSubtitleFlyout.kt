package com.jankinwu.fntv.client.ui.component.detail

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Arrangement.spacedBy
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.LocalFrameWindowScope
import com.jankinwu.fntv.client.icons.ArrowUp
import com.jankinwu.fntv.client.icons.Computer
import com.jankinwu.fntv.client.icons.Nas
import com.jankinwu.fntv.client.icons.Search
import com.jankinwu.fntv.client.utils.chooseFile
import com.jankinwu.fntv.client.viewmodel.SubtitleUploadViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.FlyoutPlacement
import io.github.composefluent.component.Icon
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.Text
import org.jetbrains.compose.ui.tooling.preview.Preview
import org.koin.compose.viewmodel.koinViewModel
import java.io.File

@Preview
@Composable
fun MediaDetailAddSubtitleFlyout(
    guid: String,
    modifier: Modifier = Modifier
) {
    val frameWindowScope = LocalFrameWindowScope.current
    val subtitleUploadViewModel: SubtitleUploadViewModel = koinViewModel()
    
    fun handleFileSelection(file: File?) {
        file?.let { selectedFile ->
            // 将文件转换为ByteArray并上传
            val byteArray = selectedFile.readBytes()
            subtitleUploadViewModel.uploadSubtitle(guid, byteArray)
        }
    }
    
    MenuFlyoutContainer(
        flyout = {
            MenuFlyoutItem(
                text = {
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "搜索字幕",
                            color = FluentTheme.colors.text.text.secondary,
                            fontWeight = FontWeight.Normal,
                            fontSize = 14.sp,
                            modifier = Modifier
                                .width(120.dp)
                        )
                    }
                },
                onClick = {
                    isFlyoutVisible = false
                },
                icon = {
                    Icon(
                        imageVector = Search,
                        contentDescription = "",
                        tint = FluentTheme.colors.text.text.primary,
                        modifier = Modifier.size(16.dp)
                    )
                },
                modifier = modifier
                    .pointerHoverIcon(PointerIcon.Hand)
            )
            MenuFlyoutItem(
                text = {
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "添加 NAS 字幕文件",
                            color = FluentTheme.colors.text.text.secondary,
                            fontWeight = FontWeight.Normal,
                            fontSize = 14.sp,
                            modifier = Modifier
                                .width(120.dp)
                        )
                    }
                },
                onClick = {
                    isFlyoutVisible = false
                },
                icon = {
                    Icon(
                        imageVector = Nas,
                        contentDescription = "",
                        tint = FluentTheme.colors.text.text.primary,
                        modifier = Modifier.size(16.dp)
                    )
                },
                modifier = modifier
                    .pointerHoverIcon(PointerIcon.Hand)
            )
            MenuFlyoutItem(
                text = {
                    Row(
                        horizontalArrangement = Arrangement.SpaceBetween,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "添加电脑字幕文件",
                            color = FluentTheme.colors.text.text.secondary,
                            fontWeight = FontWeight.Normal,
                            fontSize = 14.sp,
                            modifier = Modifier
                                .width(120.dp)
                        )
                    }
                },
                onClick = {
                    isFlyoutVisible = false
                    val file = chooseFile(frameWindowScope, arrayOf("srt", "ass", "vtt"), "选择字幕文件")
                    handleFileSelection(file)
                },
                icon = {
                    Icon(
                        imageVector = Computer,
                        contentDescription = "",
                        tint = FluentTheme.colors.text.text.primary,
                        modifier = Modifier.size(16.dp)
                    )
                },
                modifier = modifier
                    .pointerHoverIcon(PointerIcon.Hand)
            )
        },
        content = {
            SubtitleButton(
                isSelected = isFlyoutVisible,
                onClick = {
                    isFlyoutVisible = !isFlyoutVisible
                },
                buttonText = "添加",
            )
        },
        placement = FlyoutPlacement.BottomAlignedEnd,
        modifier = Modifier.offset(x = 16.dp)
    )
}

@Composable
private fun SubtitleButton(
    isSelected: Boolean,
    onClick: () -> Unit,
    buttonText: String,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isHovered by interactionSource.collectIsHoveredAsState()
    val backgroundColor by animateColorAsState(
        targetValue = if (isHovered || isSelected) FluentTheme.colors.stroke.control.default else Color.Transparent
    )

    // 根据isSelected状态计算目标旋转角度
    val targetRotation = if (isSelected) -180f else 0f
    val animatedRotation by animateFloatAsState(targetValue = targetRotation)
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .border(1.dp, Color.Gray.copy(alpha = 0.4f), CircleShape)
            .background(backgroundColor)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick
            )
            .hoverable(interactionSource)
            .padding(horizontal = 12.dp, vertical = 4.dp)
            .pointerHoverIcon(PointerIcon.Hand),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = spacedBy(4.dp, Alignment.CenterHorizontally)
    ) {
        Text(
            text = buttonText,
            color = FluentTheme.colors.text.text.primary,
            fontSize = 14.sp
        )
        Icon(
            imageVector = ArrowUp,
            contentDescription = "下拉图标",
            tint = FluentTheme.colors.text.text.primary,
            modifier = Modifier
                .size(16.dp)
                .rotate(animatedRotation)
        )

    }
}