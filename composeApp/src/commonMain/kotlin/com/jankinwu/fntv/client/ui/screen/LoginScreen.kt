package com.jankinwu.fntv.client.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.components
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.model.LoginHistory
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.icons.Delete
import com.jankinwu.fntv.client.icons.DoubleArrowLeft
import com.jankinwu.fntv.client.icons.History
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.manager.LoginStateManager.handleLogin
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.NumberInput
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.component.common.dialog.ForgotPasswordDialog
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.customSelectedCheckBoxColors
import com.jankinwu.fntv.client.ui.providable.LocalWindowHandle
import com.jankinwu.fntv.client.ui.selectedSwitcherStyle
import com.jankinwu.fntv.client.utils.setWindowImeDisabled
import com.jankinwu.fntv.client.viewmodel.LoginViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import dev.chrisbanes.haze.hazeEffect
import dev.chrisbanes.haze.hazeSource
import dev.chrisbanes.haze.materials.ExperimentalHazeMaterialsApi
import dev.chrisbanes.haze.materials.FluentMaterials
import dev.chrisbanes.haze.rememberHazeState
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.login_background
import fntv_client_multiplatform.composeapp.generated.resources.login_fn_logo
import io.github.composefluent.component.CheckBox
import io.github.composefluent.component.CheckBoxDefaults
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.Switcher
import io.github.composefluent.component.SwitcherDefaults
import io.github.composefluent.component.rememberScrollbarAdapter
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.viewmodel.koinViewModel

private val logger = Logger.withTag("LoginScreen")

// 自定义颜色以匹配图片风格
val CardBackgroundColor = Color(0xFF1A1D26).copy(alpha = 1f)
val PrimaryBlue = Color(0xFF3A7BFF)
val HintColor = Color.Gray

@OptIn(ExperimentalHazeMaterialsApi::class, ExperimentalComposeUiApi::class)
@Suppress("RememberReturnType")
@Composable
fun LoginScreen(navigator: ComponentNavigator) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var host by remember { mutableStateOf("") }
    var port by remember { mutableIntStateOf(0) }
    var isHttps by remember { mutableStateOf(false) }
    var passwordVisible by remember { mutableStateOf(false) }
    var rememberMe by remember { mutableStateOf(false) }
    val loginViewModel: LoginViewModel = koinViewModel()
    val loginUiState by loginViewModel.uiState.collectAsState()
    val toastManager = rememberToastManager()
    val hazeState = rememberHazeState()
    var showHistorySidebar by remember { mutableStateOf(false) }
    val windowHandle = LocalWindowHandle.current
    // 登录历史记录列表
    var loginHistoryList by remember { mutableStateOf<List<LoginHistory>>(emptyList()) }

    // 初始化时加载保存的账号信息
    remember {
        host = AccountDataCache.host
        port = AccountDataCache.port
        username = AccountDataCache.userName
        password = AccountDataCache.password
        isHttps = AccountDataCache.isHttps
        rememberMe = AccountDataCache.rememberMe

        // 加载历史记录
        val preferencesManager = PreferencesManager.getInstance()
        loginHistoryList = preferencesManager.loadLoginHistory()
    }

    // 处理登录结果
    LaunchedEffect(loginUiState) {
        when (val state = loginUiState) {
            is UiState.Success -> {
                // 登录成功，更新缓存中的登录状态
                LoginStateManager.updateLoginStatus(true)
                // 保存token到SystemAccountData
                AccountDataCache.authorization = state.data.token
                AccountDataCache.isLoggedIn = true
                AccountDataCache.insertCookie("Trim-MC-token" to state.data.token)
                logger.i("登录成功，cookie: ${AccountDataCache.cookieState}")
                val preferencesManager = PreferencesManager.getInstance()
                preferencesManager.saveToken(state.data.token)
                loginViewModel.clearError()
                val targetComponent = components
                    .firstOrNull { it.name == "首页" }
                // 登录后跳转到首页
                targetComponent?.let { navigator.addStartItem(it) }

                // 保存登录历史记录
                val loginHistory = LoginHistory(
                    host = host,
                    port = port,
                    username = username,
                    password = if (rememberMe) password else null,
                    isHttps = isHttps,
                    rememberMe = rememberMe
                )

                // 更新历史记录列表
                val updatedList = loginHistoryList.filterNot { it == loginHistory } + loginHistory
                loginHistoryList = updatedList.sortedByDescending { it.lastLoginTimestamp }
                // 保存到偏好设置
                preferencesManager.saveLoginHistory(loginHistoryList)
            }

            is UiState.Error -> {
                // 登录失败，可以显示错误信息
                toastManager.showToast("登录失败，${state.message}", ToastType.Failed)
                logger.e("登录失败: ${state.message}")

                // 检查是否是证书错误
                if (state.message.contains("PKIX path building failed") || state.message.contains("unable to find valid certification path")) {
                    // Todo 这里应该显示一个对话框询问用户是否信任证书
                    logger.w("检测到SSL证书错误，需要用户确认是否信任证书")
                }
            }

            else -> {
                // 其他状态，如Initial或Loading，可以不做处理
            }
        }
    }
    DisposableEffect(windowHandle) {
        onDispose {
            if (windowHandle != null) {
                setWindowImeDisabled(windowHandle, false)
            }
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Image(
            painterResource(Res.drawable.login_background),
            contentDescription = "登录背景图",
            contentScale = ContentScale.Crop,
            modifier = Modifier
                .fillMaxSize()
                .hazeSource(state = hazeState)
        )
        Surface(
            color = Color.Transparent,
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier
                .width(400.dp)
                .clip(RoundedCornerShape(16.dp))
                .hazeEffect(
                    state = hazeState,
                    style = FluentMaterials.acrylicDefault(true)
                )
        ) {
            Column(
                modifier = Modifier
                    .padding(horizontal = 40.dp, vertical = 40.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // 1. Logo
                Image(
                    painterResource(Res.drawable.login_fn_logo),
                    contentDescription = "飞牛logo",
                    modifier = Modifier
                        .width(174.dp)
                )
                Text("FN_Media", color = HintColor, fontSize = 16.sp)

//                Spacer(modifier = Modifier.height(8.dp))
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    var isHistoryHovered by remember { mutableStateOf(false) }
                    OutlinedTextField(
                        value = host,
                        onValueChange = { host = it },
                        modifier = Modifier
                            .weight(2.0f),
                        label = { Text("ip 或域名") },
                        singleLine = true,
                        placeholder = { Text("请输入ip或域名") },
                        colors = getTextFieldColors(),
                        textStyle = LocalTextStyle.current.copy(fontSize = 18.sp),
                        trailingIcon = {
                            val image = History
                            val description = "历史登录记录"
                            IconButton(onClick = { showHistorySidebar = !showHistorySidebar }) {
                                Icon(
                                    imageVector = image,
                                    description,
                                    tint = if (isHistoryHovered) Color.White else HintColor,
                                    modifier = Modifier
                                        .size(20.dp)
                                        .onPointerEvent(PointerEventType.Enter) {
                                            isHistoryHovered = true
                                        }
                                        .onPointerEvent(PointerEventType.Exit) {
                                            isHistoryHovered = false
                                        }
                                        .pointerHoverIcon(PointerIcon.Hand)
                                )
                            }
                        },

                        )
                    Text(
                        ":",
                        color = HintColor,
                        fontSize = 30.sp,
                        modifier = Modifier
                            .padding(horizontal = 4.dp, vertical = 12.dp)
                    )
                    NumberInput(
                        onValueChange = { port = it },
                        value = port,
                        modifier = Modifier.weight(1.0f),
                        placeholder = "请输入端口",
                        minValue = 0,
                        label = "",
                        textColor = Colors.TextSecondaryColor,
                        defaultValue = 5666
                    )
                }

                // 2. 用户名输入框
                OutlinedTextField(
                    value = username,
                    onValueChange = { username = it },
                    modifier = Modifier.fillMaxWidth(),
                    label = { Text("用户名或邮箱") },
                    singleLine = true,
                    colors = getTextFieldColors(),
                    textStyle = LocalTextStyle.current.copy(fontSize = 18.sp)
                )
                var isPasswordVisibilityHovered by remember { mutableStateOf(false) }
                var isPasswordFocused by remember { mutableStateOf(false) }
                LaunchedEffect(windowHandle, isPasswordFocused) {
                    if (windowHandle != null) {
                        setWindowImeDisabled(windowHandle, isPasswordFocused)
                    }
                }
                // 3. 密码输入框
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    modifier = Modifier
                        .fillMaxWidth()
                        .onFocusChanged { isPasswordFocused = it.isFocused },
                    label = { Text("密码") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = if (passwordVisible) KeyboardType.Ascii else KeyboardType.Password,
                        autoCorrect = false,
                        imeAction = ImeAction.Done
                    ),
                    visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
                    trailingIcon = {
                        val image =
                            if (passwordVisible) Icons.Filled.Visibility else Icons.Filled.VisibilityOff
                        val description = if (passwordVisible) "隐藏密码" else "显示密码"
                        IconButton(onClick = { passwordVisible = !passwordVisible }) {
                            Icon(
                                imageVector = image,
                                description,
                                tint = if (isPasswordVisibilityHovered) Color.White else HintColor,
                                modifier = Modifier
                                    .size(20.dp)
                                    .onPointerEvent(PointerEventType.Enter) {
                                        isPasswordVisibilityHovered = true
                                    }
                                    .onPointerEvent(PointerEventType.Exit) {
                                        isPasswordVisibilityHovered = false
                                    }
                                    .pointerHoverIcon(PointerIcon.Hand)
                            )
                        }
                    },
                    colors = getTextFieldColors(),
                    textStyle = LocalTextStyle.current.copy(fontSize = 18.sp)
                )

                // 4. 记住账号 和 忘记密码
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                    ) {

                        CheckBox(
                            rememberMe,
                            "记住密码",
                            onCheckStateChange = { rememberMe = it },
                            colors = if (rememberMe) {
                                customSelectedCheckBoxColors()
                            } else {
                                CheckBoxDefaults.defaultCheckBoxColors()
                            }
                        )
                    }
                    ForgotPasswordDialog()
//                    TextButton(onClick = { /* TODO: 忘记密码逻辑 */ }) {
//                        Text("忘记密码?", color = HintColor, fontSize = 14.sp)
//                    }
                }
                Spacer(modifier = Modifier.height(4.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("HTTPS 安全访问", color = Colors.TextSecondaryColor, fontSize = 16.sp)
                    Switcher(
                        isHttps,
                        { isHttps = it },
                        styles = if (isHttps) {
                            selectedSwitcherStyle()
                        } else {
                            SwitcherDefaults.defaultSwitcherStyle()
                        },
                    )
                }

                // 5. 登录按钮
                Button(
                    onClick = {
                        handleLogin(
                            host = host,
                            port = port,
                            username = username,
                            password = password,
                            isHttps = isHttps,
                            toastManager = toastManager,
                            loginViewModel = loginViewModel,
                            rememberMe = rememberMe
                        )
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .pointerHoverIcon(PointerIcon.Hand),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = PrimaryBlue)
                ) {
                    Text("登录", fontSize = 16.sp)
                }

                // 6. NAS 登录按钮
//                Button(
//                    onClick = { /* TODO: NAS 登录逻辑 */ },
//                    modifier = Modifier
//                        .fillMaxWidth()
//                        .height(48.dp)
//                        .pointerHoverIcon(PointerIcon.Hand),
//                    shape = RoundedCornerShape(8.dp),
//                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3C3C4D))
//                ) {
//                    Text("使用 NAS 登录", fontSize = 16.sp)
//                }
            }
        }
        ToastHost(
            toastManager = toastManager,
            modifier = Modifier.fillMaxSize()
        )
        AnimatedVisibility(
            visible = showHistorySidebar,
            enter = slideInHorizontally(initialOffsetX = { -it }), // 从左侧滑入
            exit = slideOutHorizontally(targetOffsetX = { -it }),   // 向左侧滑出
            modifier = Modifier.align(Alignment.CenterStart) // 改为居左对齐
        ) {
            HistorySidebar(
                loginHistoryList = loginHistoryList,
                onDismiss = { showHistorySidebar = false },
                onDelete = { history ->
                    val updatedList = loginHistoryList.filterNot { it == history }
                    loginHistoryList = updatedList
                    val preferencesManager = PreferencesManager.getInstance()
                    preferencesManager.saveLoginHistory(updatedList)
                },
                onSelect = { history ->
                    host = history.host
                    port = history.port
                    username = history.username
                    isHttps = history.isHttps
                    password = history.password ?: ""
                    rememberMe = history.rememberMe
                    // 如果有密码，则直接登录
                    if (!history.password.isNullOrEmpty()) {
                        handleLogin(
                            host = history.host,
                            port = history.port,
                            username = history.username,
                            password = history.password,
                            isHttps = history.isHttps,
                            toastManager = toastManager,
                            loginViewModel = loginViewModel,
                            rememberMe = true
                        )
                    }
                    showHistorySidebar = false
                }
            )
        }
    }
}

@Composable
private fun getTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = PrimaryBlue,
    unfocusedBorderColor = Color.Gray,
    focusedLabelColor = PrimaryBlue,
    unfocusedLabelColor = HintColor,
    cursorColor = PrimaryBlue,
    focusedTextColor = Colors.TextSecondaryColor,
    unfocusedTextColor = Colors.TextSecondaryColor
)

@Composable
private fun HistorySidebar(
    loginHistoryList: List<LoginHistory>,
    onDismiss: () -> Unit,
    onDelete: (LoginHistory) -> Unit,
    onSelect: (LoginHistory) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxHeight()
            .width(300.dp)
            .background(CardBackgroundColor)
    ) {
        // 侧边栏内容
        Column(
            modifier = Modifier.fillMaxSize()
        ) {
            // 顶部带有返回箭头的标题栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 2.dp, end = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.End
            ) {
                val interactionSource = remember { MutableInteractionSource() }
                val isHovered by interactionSource.collectIsHoveredAsState()
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = DoubleArrowLeft,
                        contentDescription = "关闭历史记录",
                        tint = if (isHovered) Color.White else Color.White.copy(alpha = 0.7843f),
                        modifier = Modifier
                            .size(15.dp)
                            .hoverable(interactionSource)
                            .pointerHoverIcon(PointerIcon.Hand)
                    )
                }
            }
            val lazyListState = rememberLazyListState()
            ScrollbarContainer(
                adapter = rememberScrollbarAdapter(lazyListState)
            ) {
                LazyColumn(
                    state = lazyListState,
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                ) {
                    // 历史记录列表区域
                    if (loginHistoryList.isEmpty()) {
                        item {
                            Text(
                                text = "暂无历史记录",
                                color = HintColor,
                                modifier = Modifier
                                    .align(Alignment.CenterHorizontally)
                                    .padding(top = 32.dp)
                            )
                        }
                    } else {
                        items(loginHistoryList) { history ->
                            HistoryItem(
                                history = history,
                                onDelete = { onDelete(history) },
                                onSelect = { onSelect(history) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun HistoryItem(
    history: LoginHistory,
    onDelete: () -> Unit,
    onSelect: () -> Unit,
    modifier: Modifier = Modifier
) {
    var isHistoryItemHovered by remember { mutableStateOf(false) }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .background(
                if (isHistoryItemHovered) Color.White.copy(alpha = 0.1f) else Color(
                    0xFF2D313D
                ), shape = RoundedCornerShape(8.dp)
            )
            .padding(12.dp)
            .onPointerEvent(PointerEventType.Enter) { isHistoryItemHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHistoryItemHovered = false }
            .pointerHoverIcon(PointerIcon.Hand),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null, // 移除点击时的涟漪效果
                    onClick = { onSelect() }
                )
        ) {
            Text(
                text = history.username,
                color = Colors.TextSecondaryColor,
                fontSize = 16.sp
            )
            Text(
                text = history.getEndpoint(),
                color = HintColor,
                fontSize = 14.sp
            )
        }

        IconButton(
            onClick = onDelete,
            modifier = Modifier.size(24.dp)
        ) {
            Icon(
                imageVector = Delete,
                contentDescription = "删除记录",
                tint = HintColor,
                modifier = Modifier.size(16.dp)
            )
        }
    }
}
