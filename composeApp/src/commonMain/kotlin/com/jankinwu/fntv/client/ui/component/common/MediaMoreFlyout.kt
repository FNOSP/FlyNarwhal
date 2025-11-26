package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.icons.Delete
import com.jankinwu.fntv.client.icons.Edit
import com.jankinwu.fntv.client.icons.Lifted
import com.jankinwu.fntv.client.icons.VersionManagement
import com.jankinwu.fntv.client.ui.providable.LocalStore
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.FlyoutPlacement
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.MenuFlyoutSeparator

@Composable
fun MediaMoreFlyout(
    onMoreClick: () -> Unit = {},
    onManageVersionsClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val store = LocalStore.current
    val scaleFactor = store.scaleFactor
    MenuFlyoutContainer(
        flyout = {
            MenuFlyoutItem(
                text = {
                    Text(
                        "管理版本",
                        fontSize = (12 * scaleFactor).sp,
                        fontWeight = FontWeight.Bold,
                        color = FluentTheme.colors.text.text.tertiary
                    )
                },
                onClick = {
                    isFlyoutVisible = false
                    onManageVersionsClick?.invoke()
                },
                icon = {
                    Icon(
                        VersionManagement,
                        contentDescription = "管理版本",
                        tint = FluentTheme.colors.text.text.tertiary,
                        modifier = Modifier.requiredSize((20 * scaleFactor).dp)
                    )
                },
                modifier = Modifier.pointerHoverIcon(PointerIcon.Hand))
            MenuFlyoutItem(
                text = {
                    Text(
                        "手动匹配影片",
                        fontSize = (12 * scaleFactor).sp,
                        fontWeight = FontWeight.Bold,
                        color = FluentTheme.colors.text.text.tertiary
                    )
                },
                onClick = {
                    isFlyoutVisible = false
                    // TODO: 处理手动匹配影片按钮点击事件
                },
                icon = {
                    Icon(
                        Edit,
                        contentDescription = "手动匹配影片",
                        tint = FluentTheme.colors.text.text.tertiary,
                        modifier = Modifier.requiredSize((20 * scaleFactor).dp)
                    )
                },
                modifier = Modifier.pointerHoverIcon(PointerIcon.Hand))
            MenuFlyoutItem(
                text = {
                    Text(
                        "解除匹配影片",
                        fontSize = (12 * scaleFactor).sp,
                        fontWeight = FontWeight.Bold,
                        color = FluentTheme.colors.text.text.tertiary
                    )
                },
                onClick = {
                    isFlyoutVisible = false
                    // TODO: 处理解除匹配影片按钮点击事件
                },
                icon = {
                    Icon(
                        Lifted,
                        tint = FluentTheme.colors.text.text.tertiary,
                        contentDescription = "解除匹配影片",
                        modifier = Modifier.requiredSize((20 * scaleFactor).dp)
                    )
                },
                modifier = Modifier.pointerHoverIcon(PointerIcon.Hand))
            MenuFlyoutSeparator(modifier = Modifier.padding(horizontal = 1.dp))
            MenuFlyoutItem(
                text = {
                    Text(
                        "删除",
                        fontSize = (12 * scaleFactor).sp,
                        color = FluentTheme.colors.text.text.tertiary,
                        fontWeight = FontWeight.Bold,
                    )
                },
                onClick = {
                    isFlyoutVisible = false
                    // TODO: 处理删除按钮点击事件
                },
                icon = {
                    Icon(
                        Delete,
                        tint = FluentTheme.colors.text.text.tertiary,
                        contentDescription = "删除",
                        modifier = Modifier.requiredSize((20 * scaleFactor).dp)
                    )
                },
                modifier = Modifier.pointerHoverIcon(PointerIcon.Hand))
        },
        content = {
            Box(modifier = Modifier.clickable(interactionSource = remember { MutableInteractionSource() },
                indication = null,) {
                onMoreClick()
                isFlyoutVisible = !isFlyoutVisible
            }) {
                content()
            }
        },
        adaptivePlacement = true,
        placement = FlyoutPlacement.BottomAlignedEnd
    )
}
