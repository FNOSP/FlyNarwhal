package com.jankinwu.fntv.client.ui.dialog

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import com.jankinwu.fntv.client.ui.component.common.dialog.CustomContentDialog
import com.jankinwu.fntv.client.utils.WebViewBootstrap
import io.github.composefluent.component.ContentDialogButton
import kotlinx.coroutines.launch

@Composable
fun KcefInitErrorDialog(
    error: Throwable?,
    onDismiss: () -> Unit
) {
    val scope = rememberCoroutineScope()
    CustomContentDialog(
        title = "组件加载失败",
        visible = true,
        primaryButtonText = "重试",
        secondaryButtonText = "忽略",
        isWarning = true,
        onButtonClick = { button ->
            when (button) {
                ContentDialogButton.Primary -> {
                    scope.launch {
                        WebViewBootstrap.retry()
                    }
                }
                ContentDialogButton.Secondary -> {
                    onDismiss()
                }
                else -> {}
            }
        },
        content = {
            Text("浏览器组件加载失败，NAS 登录等依赖 WebView 的功能可能不可用。\n你仍可继续使用普通登录。\n错误信息：${error?.message}")
        }
    )
}
