package com.jankinwu.fntv.client.ui.component.login

import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowLeft
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.constants.Colors
import com.multiplatform.webview.jsbridge.WebViewJsBridge
import com.multiplatform.webview.web.WebView
import com.multiplatform.webview.web.WebViewNavigator
import com.multiplatform.webview.web.WebViewState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NasLoginAddressBar(
    addressBarValue: String,
    onAddressBarValueChange: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(
            onClick = onBack,
            modifier = Modifier.pointerHoverIcon(PointerIcon.Hand)
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowLeft,
                contentDescription = "Back",
                tint = Colors.TextSecondaryColor
            )
        }

        BasicTextField(
            value = addressBarValue,
            onValueChange = onAddressBarValueChange,
            modifier = Modifier
                .padding(end = 12.dp)
                .height(30.dp)
                .weight(1f),
            singleLine = true,
            textStyle = LocalTextStyle.current.copy(
                fontSize = 14.sp,
                color = Colors.TextSecondaryColor
            ),
            cursorBrush = SolidColor(Colors.AccentColorDefault),
            keyboardOptions = KeyboardOptions(
                keyboardType = KeyboardType.Uri,
                imeAction = ImeAction.Go
            ),
            decorationBox = { innerTextField ->
                OutlinedTextFieldDefaults.DecorationBox(
                    value = addressBarValue,
                    innerTextField = innerTextField,
                    enabled = true,
                    singleLine = true,
                    visualTransformation = VisualTransformation.None,
                    interactionSource = remember { MutableInteractionSource() },
                    placeholder = {
                        Text(
                            "请输入地址",
                            fontSize = 14.sp,
                            color = Color.White.copy(alpha = 0.6f)
                        )
                    },
                    colors = getTextFieldColors(),
                            container = {
                                OutlinedTextFieldDefaults.Container(
                                    enabled = true,
                                    isError = false,
                                    interactionSource = remember { MutableInteractionSource() },
                                    colors = getTextFieldColors(),
                                    shape = RoundedCornerShape(8.dp),
                                    focusedBorderThickness = 1.dp,
                        )
                    },
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp)
                )
            }
        )
    }
}

@Composable
fun FnConnectWebViewContainer(
    webViewInitialized: Boolean,
    webViewRestartRequired: Boolean,
    webViewInitError: Throwable?,
    webViewState: WebViewState,
    navigator: WebViewNavigator,
    jsBridge: WebViewJsBridge,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(Color.White)
    ) {
        when {
            webViewInitError != null -> {
                Text(
                    text = "WebView 初始化失败：${webViewInitError.message ?: "未知错误"}",
                    color = Color.Black,
                    modifier = Modifier.align(Alignment.Center)
                )
            }

            webViewInitialized -> {
                WebView(
                    state = webViewState,
                    modifier = Modifier.fillMaxSize(),
                    navigator = navigator,
                    webViewJsBridge = jsBridge
                )
            }

            webViewRestartRequired -> {
                Text(
                    text = "WebView 初始化完成，但需要重启应用后生效。",
                    color = Color.Black,
                    modifier = Modifier.align(Alignment.Center)
                )
            }

            else -> {
                Text(
                    text = "WebView 初始化中，请稍候…",
                    color = Color.Black,
                    modifier = Modifier.align(Alignment.Center)
                )
            }
        }
    }
}

@Composable
fun getTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Colors.AccentColorDefault,
    unfocusedBorderColor = Color.White.copy(alpha = 0.35f),
    focusedLabelColor = Colors.AccentColorDefault,
    unfocusedLabelColor = Color.White.copy(alpha = 0.6f),
    cursorColor = Colors.AccentColorDefault,
    focusedTextColor = Colors.TextSecondaryColor,
    unfocusedTextColor = Colors.TextSecondaryColor
)
