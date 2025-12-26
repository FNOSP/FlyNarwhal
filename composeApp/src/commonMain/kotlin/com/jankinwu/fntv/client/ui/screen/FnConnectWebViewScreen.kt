package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowLeft
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitError
import com.jankinwu.fntv.client.ui.providable.LocalWebViewInitialized
import com.jankinwu.fntv.client.ui.providable.LocalWebViewRestartRequired
import com.multiplatform.webview.web.WebView
import com.multiplatform.webview.web.rememberWebViewState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource
import dev.chrisbanes.haze.materials.ExperimentalHazeMaterialsApi
import dev.chrisbanes.haze.materials.FluentMaterials
import dev.chrisbanes.haze.rememberHazeState
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.login_background
import org.jetbrains.compose.resources.painterResource

@OptIn(ExperimentalHazeMaterialsApi::class, ExperimentalMaterial3Api::class)
@Composable
fun FnConnectWebViewScreen(
    initialUrl: String,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    val toastManager = rememberToastManager()
    val hazeState = rememberHazeState()

    val webViewInitialized = LocalWebViewInitialized.current
    val webViewRestartRequired = LocalWebViewRestartRequired.current
    val webViewInitError = LocalWebViewInitError.current

    var addressBarValue by remember(initialUrl) { mutableStateOf(initialUrl) }
    var currentUrl by remember(initialUrl) { mutableStateOf(initialUrl) }
    val webViewState = rememberWebViewState(currentUrl)

    LaunchedEffect(webViewState.lastLoadedUrl) {
        webViewState.lastLoadedUrl?.let {
            if (it.isNotBlank()) {
                addressBarValue = it
            }
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        Image(
            painterResource(Res.drawable.login_background),
            contentDescription = "Login background",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .hazeSource(state = hazeState)
        )

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF14171A).copy(alpha = 0.6f)),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                color = Color.Transparent,
                shape = RoundedCornerShape(0.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .hazeEffect(
                        state = hazeState,
                        style = FluentMaterials.acrylicDefault(true)
                    )
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(top = 48.dp, end = 12.dp)
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
//                        horizontalArrangement = Arrangement.spacedBy(12.dp)
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
                            onValueChange = { addressBarValue = it },
                            modifier = Modifier
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
                            keyboardActions = KeyboardActions(
                                onGo = {
                                    val target = normalizeFnConnectUrl(addressBarValue)
                                    if (target.isNotBlank()) {
                                        currentUrl = target
                                        addressBarValue = target
                                    } else {
                                        toastManager.showToast("请输入有效地址", ToastType.Info)
                                    }
                                }
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
                                        OutlinedTextFieldDefaults.ContainerBox(
                                            enabled = true,
                                            isError = false,
                                            interactionSource = remember { MutableInteractionSource() },
                                            colors = getTextFieldColors(),
                                            shape = RoundedCornerShape(8.dp),
                                            focusedBorderThickness = 1.dp,
                                            unfocusedBorderThickness = 1.dp
                                        )
                                    },
                                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp)
                                )
                            }
                        )
                    }

                    Spacer(modifier = Modifier.height(12.dp))

                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .background(Color.White)
                    ) {
                        when {
                            webViewInitialized -> {
                                WebView(
                                    state = webViewState,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }

                            webViewRestartRequired -> {
                                Text(
                                    text = "WebView 初始化完成，但需要重启应用后生效。",
                                    color = Color.Black,
                                    modifier = Modifier.align(Alignment.Center)
                                )
                            }

                            webViewInitError != null -> {
                                Text(
                                    text = "WebView 初始化失败：${webViewInitError.message ?: "未知错误"}",
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
            }
        }

        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
private fun getTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = Colors.AccentColorDefault,
    unfocusedBorderColor = Color.White.copy(alpha = 0.35f),
    focusedLabelColor = Colors.AccentColorDefault,
    unfocusedLabelColor = Color.White.copy(alpha = 0.6f),
    cursorColor = Colors.AccentColorDefault,
    focusedTextColor = Colors.TextSecondaryColor,
    unfocusedTextColor = Colors.TextSecondaryColor
)

internal fun normalizeFnConnectUrl(value: String): String {
    // Normalize FN Connect host and ensure HTTPS is always used.
    val trimmed = value.trim()
    if (trimmed.isBlank()) return ""

    if (trimmed.startsWith("https://") || trimmed.startsWith("http://")) {
        return trimmed
    }

    val host = trimmed.substringBefore("/")
    val path = trimmed.removePrefix(host)
    val normalizedHost = if (host.contains('.')) host else "$host.5ddd.com"
    return "https://$normalizedHost$path"
}

