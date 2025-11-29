package com.jankinwu.fntv.client.data.network

import com.jankinwu.fntv.client.data.model.request.ProxyInfoRequest

interface ProxyApi {

    suspend fun setProxyInfo(request: ProxyInfoRequest): Boolean
}