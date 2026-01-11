package com.jankinwu.fntv.client.ui.component.common.dialog

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.icons.SkipLink
import com.jankinwu.fntv.client.icons.Warning
import com.jankinwu.fntv.client.ui.customAccentButtonColors
import com.jankinwu.fntv.client.ui.customDangerButtonColors
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.ui.screen.HintColor
import io.github.composefluent.FluentTheme
import io.github.composefluent.LocalContentColor
import io.github.composefluent.LocalTextStyle
import io.github.composefluent.component.AccentButton
import io.github.composefluent.component.Button
import io.github.composefluent.component.ContentDialogButton
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FluentDialog
import io.github.composefluent.component.Text

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun ForgotPasswordDialog() {
    var displayDialog by remember { mutableStateOf(false) }
    if (displayDialog) {
        FluentDialog(
            visible = true,
            size = DialogSize.Standard
        ) {
            Column(modifier = Modifier.padding(24.dp)) {
                Text("忘记密码", style = FluentTheme.typography.subtitle)
                Spacer(Modifier.height(12.dp))
                Text(
                    "1. 如果您是 NAS 用户，请尝试 NAS 登录；" +
                            "\n" +
                            "2. 请联系管理员修改密码。"
                )
                Spacer(Modifier.height(24.dp))
                Row(
                    horizontalArrangement = Arrangement.End,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    DialogAccentButton("好的", onClick = { displayDialog = false })
                }
            }
        }
    }
    var isHovered by remember { mutableStateOf(false) }
    Text(
        "忘记密码?",
        color = if (isHovered) Color.White else HintColor,
        fontSize = 14.sp,
        modifier = Modifier
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = { displayDialog = true })
            .pointerHoverIcon(PointerIcon.Hand)
    )
}

@Composable
fun AboutDialog() {
    var displayDialog by remember { mutableStateOf(false) }
    val uriHandler = LocalUriHandler.current
    if (displayDialog) {
        FluentDialog(
            visible = true,
            size = DialogSize.Standard
        ) {
            Column(modifier = Modifier.padding(24.dp)) {
                Text("支持作者", style = FluentTheme.typography.subtitle)
                Spacer(Modifier.height(24.dp))
                Text(
                    "您的支持就是我持续更新的动力，如果觉得好用的话，请给项目点一个 Star ⭐，谢谢！(^_−)☆" +
                            "\n" +
                            "\n" +
                            "项目诚然还有很多地方需要完善，如果遇到软件问题或者 Bug 欢迎提交 Issue 或者 PR。" +
                            "\n" +
                            "\n" +
                            Constants.PROJECT_URL
                )
                Spacer(Modifier.height(16.dp))
                Row(
                    horizontalArrangement = Arrangement.End,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    DialogAccentButtonWithIcon("打开 Github 仓库", SkipLink, onClick = {
                        displayDialog = false
                        uriHandler.openUri(Constants.PROJECT_URL)
                    })
                    Spacer(Modifier.width(8.dp))
                    DialogSecondaryButton("稍后再说", onClick = { displayDialog = false })
                }
            }
        }
    }
    io.github.composefluent.component.Button(
        onClick = {
            displayDialog = true
        },
        modifier = Modifier
            .pointerHoverIcon(PointerIcon.Hand)
    ) {
        Text("支持作者", color = FluentTheme.colors.text.text.primary, fontSize = 14.sp)
    }
}

// --- 对话框样式中使用的特定颜色 ---
private val dialogBackgroundColor = Color(0xFF2B2B2B)
private val primaryTextColor = Color.White
private val secondaryTextColor = Color(0xFFB0B0B0)
private val confirmButtonColor = Color(0xFFE53935) // 红色
private val dismissButtonColor = Color(0xFF424242) // 深灰色

/**
 * 一个通用的、样式化的确认对话框，模仿图片中的暗色主题样式。
 *
 * @param onDismissRequest 当用户点击对话框外部或按下返回键时调用。
 * @param icon 对话框顶部的图标，默认为一个红色的警告图标。
 * @param iconTint 图标的颜色。
 * @param title 对话框的标题。
 * @param contentText 对话框的主要内容文本。
 * @param dismissButtonText “取消”或“否定”按钮上的文字。
 * @param onDismissClick “取消”或“否定”按钮的点击事件。
 * @param confirmButtonText “确认”或“删除”按钮上的文字。
 * @param onConfirmClick “确认”或“删除”按钮的点击事件。
 */
@Composable
fun CustomConfirmDialog(
    onDismissRequest: () -> Unit,
    icon: ImageVector? = null,
    iconTint: Color = confirmButtonColor,
    title: String,
    contentText: String,
    dismissButtonText: String = "取消",
    onDismissClick: () -> Unit = {},
    confirmButtonText: String,
    onConfirmClick: () -> Unit = {}
) {
    val store = LocalStore.current
    Dialog(onDismissRequest = onDismissRequest) {
        // 使用 Surface 来创建圆角和背景色
        Surface(
            shape = RoundedCornerShape(12.dp),
            color = if (store.darkMode) dialogBackgroundColor else Colors.BackgroundColorLight,
            contentColor = primaryTextColor
        ) {
            Column(
                modifier = Modifier.padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                // 1. 图标
                icon?.let {
                    Icon(
                        imageVector = icon,
                        contentDescription = "Dialog Icon",
                        tint = iconTint,
                        modifier = Modifier.size(36.dp)
                    )
                    Spacer(Modifier.height(36.dp))
                }

                // 2. 标题
                Text(
                    text = title,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = primaryTextColor
                )
                Spacer(Modifier.height(8.dp))

                // 3. 内容
                Text(
                    text = contentText,
                    fontSize = 16.sp,
                    color = secondaryTextColor,
                    textAlign = TextAlign.Center
                )
                Spacer(Modifier.height(24.dp))

                // 4. 按钮
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // 取消按钮
                    Button(
                        onClick = {
                            onDismissClick()
                            onDismissRequest() // 点击按钮后也关闭对话框
                        },
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = dismissButtonColor
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(dismissButtonText, color = primaryTextColor)
                    }

                    // 确认按钮
                    Button(
                        onClick = {
                            onConfirmClick()
                            onDismissRequest() // 点击按钮后也关闭对话框
                        },
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = confirmButtonColor
                        ),
                        modifier = Modifier.weight(1f)
                    ) {
                        Text(confirmButtonText, color = primaryTextColor)
                    }
                }
            }
        }
    }
}

@Composable
fun CustomContentDialog(
    title: String,
    visible: Boolean,
    content: @Composable () -> Unit,
    primaryButtonText: String,
    secondaryButtonText: String? = null,
    onButtonClick: (ContentDialogButton) -> Unit,
    size: DialogSize = DialogSize.Standard,
    isWarning: Boolean = false
) {
    FluentDialog(visible, size) {
        Column {
            Column(
                Modifier
                    .fillMaxWidth()
//                    .background(FluentTheme.colors.background.layer.alt)
                    .padding(24.dp)
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    if (isWarning) {
                        Icon(
                            imageVector = Warning,
                            contentDescription = null,
                            tint = Colors.DangerDefaultColor,
                            modifier = Modifier
                                .size(32.dp)
                                .padding(end = 8.dp)
                        )
                    }
                    Text(
                        style = FluentTheme.typography.subtitle,
                        fontSize = 18.sp,
                        text = title,
                    )
                }
                Spacer(Modifier.height(12.dp))
                CompositionLocalProvider(
                    LocalTextStyle provides FluentTheme.typography.body,
                    LocalContentColor provides FluentTheme.colors.text.text.primary
                ) {
                    Box(
                        Modifier
                            .padding(start = if (isWarning) 32.dp else 0.dp)
                    ) {
                        content()
                    }
                }
            }
            Box(
                Modifier
                    .height(50.dp)
                    .fillMaxWidth()
                    .padding(horizontal = 25.dp, vertical = 8.dp),
                Alignment.CenterEnd
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.End),
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    if (secondaryButtonText != null) Button(
                        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                        onClick = { onButtonClick(ContentDialogButton.Secondary) },
                    ) {
                        Text(
                            secondaryButtonText,
                            style = LocalTypography.current.bodyStrong,
                            color = FluentTheme.colors.text.text.primary
                        )
                    }
                    AccentButton(
                        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                        onClick = { onButtonClick(ContentDialogButton.Primary) },
                        buttonColors = if (isWarning) customDangerButtonColors() else customAccentButtonColors()
                    ) {
                        Text(
                            primaryButtonText,
                            style = LocalTypography.current.bodyStrong,
                            color = FluentTheme.colors.text.text.primary
                        )
                    }
                }
            }
        }
    }
}