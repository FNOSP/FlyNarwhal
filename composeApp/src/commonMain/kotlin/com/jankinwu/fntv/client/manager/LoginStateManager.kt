package com.jankinwu.fntv.client.manager

import com.jankinwu.fntv.client.components
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.data.store.UserInfoMemoryCache
import com.jankinwu.fntv.client.ui.component.common.ToastManager
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.viewmodel.LoginViewModel
import com.jankinwu.fntv.client.viewmodel.LogoutViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 登录状态管理单例类
 * 负责管理全局登录状态，并在状态改变时通知UI更新
 */
object LoginStateManager {
    private val _isLoggedIn = MutableStateFlow(AccountDataCache.isLoggedIn)
    val isLoggedIn = _isLoggedIn.asStateFlow()

    /**
     * 更新登录状态
     * @param loggedIn 新的登录状态
     */
    fun updateLoginStatus(loggedIn: Boolean) {
        _isLoggedIn.value = loggedIn
        AccountDataCache.isLoggedIn = loggedIn

        // 如果登录状态为false，清理用户信息
        if (!loggedIn) {
            AccountDataCache.authorization = ""
//            AccountDataCache.userName = ""
//            AccountDataCache.password = ""
//            AccountDataCache.cookieMap = mutableMapOf()
            AccountDataCache.clearCookie()
            UserInfoMemoryCache.clear()
            // 清理组件列表，确保切换用户后重新生成
            components.clear()
        }

        // 持久化登录状态
        PreferencesManager.getInstance().saveAllLoginInfo()
    }

    /**
     * 获取当前登录状态
     * @return 当前登录状态
     */
    /**
     * 登出操作
     */
    fun logout(
        logoutViewModel: LogoutViewModel
    ) {
        logoutViewModel.logout()
        updateLoginStatus(false)
    }

    /**
     * 获取当前登录状态
     * @return 当前登录状态
     */
    fun getLoginStatus(): Boolean {
        return _isLoggedIn.value
    }

    fun handleLogin(
        host: String,
        port: Int,
        username: String,
        password: String,
        isHttps: Boolean,
        toastManager: ToastManager,
        loginViewModel: LoginViewModel,
        rememberPassword: Boolean,
        onProbeRequired: ((String) -> Unit)? = null,
        isProbeFinished: Boolean = false
    ) {
//    val loginState by loginViewModel.uiState.collectAsState()
        if (host.isBlank() || username.isBlank() || password.isBlank()) {
            toastManager.showToast("请填写完整的登录信息", ToastType.Failed)
            return
        }

        if (!isProbeFinished) {
            AccountDataCache.isHttps = isHttps
//        val isValidDomainOrIP = DomainIpValidator.isValidDomainOrIP(host)
//        if (!isValidDomainOrIP) {
//            toastManager.showToast("请填写正确的ip地址或域名", ToastType.Failed)
//            return
//        }
            AccountDataCache.displayHost = host
            AccountDataCache.displayPort = port
            if (port != 0) {
                AccountDataCache.port = port
            } else {
                AccountDataCache.port = 0
            }

            // 如果使用 FN ID 或 FN 域名
            val normalizedHost = if (host.contains('.')) host else "$host.5ddd.com"
            if (normalizedHost.contains("5ddd.com")) {
                if (onProbeRequired != null) {
                    onProbeRequired("https://$normalizedHost")
                    return
                }
                AccountDataCache.isHttps = true
                AccountDataCache.insertCookie("mode" to "relay")
                AccountDataCache.port = 0
            } else {
                AccountDataCache.removeCookie("mode")
            }
            AccountDataCache.host = normalizedHost
        } else {
            if (AccountDataCache.host.contains("ddd.com")) {
                AccountDataCache.isHttps = true
                AccountDataCache.insertCookie("mode" to "relay")
                AccountDataCache.port = 0
            } else {
                AccountDataCache.removeCookie("mode")
            }
        }


        AccountDataCache.userName = username
        val preferencesManager = PreferencesManager.getInstance()
        // 如果选择了记住账号，则保存账号密码和token
        if (rememberPassword) {
            AccountDataCache.password = password
            AccountDataCache.rememberPassword = true
        } else {
            AccountDataCache.rememberPassword = false
            AccountDataCache.password = ""
            preferencesManager.clearLoginInfo()
        }
        preferencesManager.saveAllLoginInfo()
        // 执行登录逻辑
        loginViewModel.login(username, password)
    }
}
