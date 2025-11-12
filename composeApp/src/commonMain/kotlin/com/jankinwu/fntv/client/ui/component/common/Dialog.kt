package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.sp
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