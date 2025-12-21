  package com.jankinwu.fntv.client.data.store

import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object UserInfoMemoryCache {
    private val _userInfo = MutableStateFlow<UserInfoResponse?>(null)
    val userInfo: StateFlow<UserInfoResponse?> = _userInfo.asStateFlow()

    val guid: String?
        get() = _userInfo.value?.guid?.takeIf { it.isNotBlank() }

    fun setUserInfo(userInfo: UserInfoResponse) {
        _userInfo.value = userInfo
    }

    fun clear() {
        _userInfo.value = null
    }
}

