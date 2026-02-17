package com.jankinwu.fntv.client.data.network

import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.jankinwu.fntv.client.data.network.impl.FlyNarwhalApiImpl
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import com.jankinwu.fntv.client.data.network.impl.ProxyApiImpl
import com.jankinwu.fntv.client.data.store.AccountDataCache
import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
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
import java.security.cert.X509Certificate
import javax.net.ssl.HostnameVerifier
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

actual val fnOfficialClient = createFnOfficialClient(insecure = false)
actual val fnOfficialInsecureClient = createFnOfficialClient(insecure = true)

private fun createFnOfficialClient(insecure: Boolean): HttpClient {
    return HttpClient(OkHttp) {
        expectSuccess = true
        followRedirects = true
        if (insecure) {
            engine {
                val trustAllCerts = arrayOf<TrustManager>(@Suppress("CustomX509TrustManager")
                object : X509TrustManager {
                    @Suppress("TrustAllX509TrustManager")
                    override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    @Suppress("TrustAllX509TrustManager")
                    override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
                    override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                })

                val sslContext = SSLContext.getInstance("SSL")
                sslContext.init(null, trustAllCerts, java.security.SecureRandom())

                config {
                    sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
                    hostnameVerifier(HostnameVerifier { _, _ -> true })
                }
            }
        }
        applyCommonHttpConfig(this)
    }
}

private fun applyCommonHttpConfig(config: HttpClientConfig<*>) {
    config.install(HttpTimeout) {
        val timeout = 10000L
        connectTimeoutMillis = timeout
        requestTimeoutMillis = timeout
        socketTimeoutMillis = timeout
    }
    config.install(ContentNegotiation) {
        jackson {
            disable(SerializationFeature.INDENT_OUTPUT)
            disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
            disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
            disable(SerializationFeature.WRITE_NULL_MAP_VALUES)
        }
    }
    config.defaultRequest {
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
    single<FlyNarwhalApi> { FlyNarwhalApiImpl() }
    single { Mp4Parser(fnOfficialClient) }
    single<UpdateManager> { DesktopUpdateManager() }
}
