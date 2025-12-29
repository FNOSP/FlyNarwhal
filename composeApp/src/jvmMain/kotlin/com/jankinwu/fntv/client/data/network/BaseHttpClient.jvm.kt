package com.jankinwu.fntv.client.data.network

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import com.jankinwu.fntv.client.data.network.impl.ProxyApiImpl
import com.jankinwu.fntv.client.data.store.AccountDataCache
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.header
import io.ktor.http.HttpHeaders
import io.ktor.serialization.jackson.jackson
import org.koin.dsl.module
import com.jankinwu.fntv.client.manager.DesktopUpdateManager
import com.jankinwu.fntv.client.manager.UpdateManager

import com.jankinwu.fntv.client.utils.Mp4Parser

actual val fnOfficialClient = HttpClient(OkHttp) {
    expectSuccess = true
    // 启用自动重定向跟随
    followRedirects = true
    // 允许POST等非GET方法重定向
//    followRedirectsForNonGetMethods = true
//    engine {
//        val trustAllCerts = arrayOf<TrustManager>(@Suppress("CustomX509TrustManager")
//        object : X509TrustManager {
//            @Suppress("TrustAllX509TrustManager")
//            override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
//            @Suppress("TrustAllX509TrustManager")
//            override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {
//            }
//            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
//        })
//
//        val sslContext = SSLContext.getInstance("SSL")
//        sslContext.init(null, trustAllCerts, java.security.SecureRandom())
//
//        config {
//            sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
//            hostnameVerifier(HostnameVerifier { hostname, session ->
//                true
//            })
//        }
//    }
    
    install(HttpTimeout) {
        val timeout = 10000L
        connectTimeoutMillis = timeout
        requestTimeoutMillis = timeout
        socketTimeoutMillis = timeout
    }
    install(ContentNegotiation) {
        // Jackson 的 ObjectMapper 的自定义配置
        jackson {
            // 禁止格式化输出 JSON
            disable(SerializationFeature.INDENT_OUTPUT)
            // 将日期序列化为 ISO 字符串而不是时间戳
            disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            // 忽略未知属性
            disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            // 不序列化null值
            disable(SerializationFeature.WRITE_NULL_MAP_VALUES)
//            setSerializationInclusion(com.fasterxml.jackson.annotation.JsonInclude.Include.NON_NULL)
        }
    }
    // 添加公共请求头
    defaultRequest {
        header(HttpHeaders.Authorization, AccountDataCache.authorization)
        header(HttpHeaders.Accept, "application/json")
        if (AccountDataCache.cookieState.isNotBlank()) {
            header(HttpHeaders.Cookie, AccountDataCache.cookieState)
        }
        header(HttpHeaders.UserAgent, "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36")
    }
}

actual val apiModule = module {
    single { FnOfficialApiImpl() }
    single { ProxyApiImpl() }
    single { Mp4Parser(fnOfficialClient) }
    single<UpdateManager> { DesktopUpdateManager() }
}