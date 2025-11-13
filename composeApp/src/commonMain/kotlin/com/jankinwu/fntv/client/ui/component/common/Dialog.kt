package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.ui.screen.HintColor
import io.github.composefluent.component.ContentDialog
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.Text

@Composable
fun ForgotPasswordDialog() {
    var displayDialog by remember { mutableStateOf(false) }
    ContentDialog(
        title = "忘记密码",
        visible = displayDialog,
        size = DialogSize.Standard,
        primaryButtonText = "Confirm",
//        closeButtonText = "Cancel",
        onButtonClick = { displayDialog = false },
        content = {
            Text(
                "1. 如果您是 NAS 用户，请尝试 NAS 登录；" +
                        "\n" +
                        "2. 请联系管理员修改密码。"
            )
        }
    )
    TextButton(onClick = { displayDialog = true }) {
        androidx.compose.material3.Text("忘记密码?", color = HintColor, fontSize = 14.sp)
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
    icon: ImageVector = Icons.Default.Warning,
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
                Icon(
                    imageVector = icon,
                    contentDescription = "Dialog Icon",
                    tint = iconTint,
                    modifier = Modifier.size(36.dp)
                )
                Spacer(Modifier.height(16.dp))

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