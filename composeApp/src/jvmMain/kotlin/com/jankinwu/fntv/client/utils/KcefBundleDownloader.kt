package com.jankinwu.fntv.client.utils

import dev.datlag.kcef.KCEFBuilder
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.ContentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json
import java.io.File
import java.security.SecureRandom
import java.security.cert.X509Certificate
import kotlin.coroutines.Continuation
import kotlin.coroutines.intrinsics.COROUTINE_SUSPENDED
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager

object KcefBundleDownloader {
    @JvmStatic
    fun main(args: Array<String>) {
        val osName = System.getProperty("os.name").orEmpty().lowercase()
        if (!osName.contains("win")) {
            println("Skipping KCEF download on os.name=$osName")
            return
        }
        val installDir = args.getOrNull(0)?.let(::File) ?: error("Missing installDir")
        val cacheDir = args.getOrNull(1)?.let(::File) ?: error("Missing cacheDir")
        val logDir = args.getOrNull(2)?.let(::File) ?: error("Missing logDir")
        val timeoutSeconds = args.getOrNull(3)?.toLongOrNull() ?: 1800L

        println("KCEF download installDir=${installDir.absolutePath}")
        println("KCEF download cacheDir=${cacheDir.absolutePath}")
        println("KCEF download logDir=${logDir.absolutePath}")

        installDir.mkdirs()
        cacheDir.mkdirs()
        logDir.mkdirs()

        val kcefLog = File(logDir, "kcef-download.log").apply { parentFile?.mkdirs() }

        val kcefClient = HttpClient(OkHttp) {
            engine {
                config {
                    val trustAllCerts = arrayOf<TrustManager>(
                        @Suppress("CustomX509TrustManager")
                        object : X509TrustManager {
                            override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
                            @Suppress("TrustAllX509TrustManager")
                            override fun checkClientTrusted(certs: Array<X509Certificate>, authType: String) {}
                            @Suppress("TrustAllX509TrustManager")
                            override fun checkServerTrusted(certs: Array<X509Certificate>, authType: String) {}
                        }
                    )
                    val sslContext = SSLContext.getInstance("SSL")
                    sslContext.init(null, trustAllCerts, SecureRandom())
                    sslSocketFactory(sslContext.socketFactory, trustAllCerts[0] as X509TrustManager)
                    hostnameVerifier { _, _ -> true }
                }
            }
            install(ContentNegotiation) {
                val jsonConfig = Json { ignoreUnknownKeys = true }
                json(jsonConfig)
                json(jsonConfig, ContentType("application", "vnd.github+json"))
            }
        }

        runBlocking {
            val builder = KCEFBuilder()
                .installDir(installDir)
                .settings {
                    cachePath = cacheDir.absolutePath
                    logFile = kcefLog.absolutePath
                }
                .download {
                    github()
                    client(kcefClient)
                }

            withTimeout(timeoutSeconds * 1000) {
                installKcef(builder)
            }
        }

        val installEntries = installDir.listFiles()?.map { it.name }.orEmpty()
        println("KCEF download installDir entries count=${installEntries.size}")
        if (installEntries.isEmpty()) {
            error("KCEF bundle directory is empty: ${installDir.absolutePath}")
        }
    }

    private suspend fun installKcef(builder: KCEFBuilder): KCEFBuilder {
        @Suppress("UNCHECKED_CAST")
        return suspendCoroutine { cont ->
            val run = runCatching {
                val builderClass = KCEFBuilder::class.java
                val candidates = listOf("install\$kcef", "install")
                val builderMethod = candidates.firstNotNullOfOrNull { name ->
                    runCatching { builderClass.getDeclaredMethod(name, Continuation::class.java) }.getOrNull()
                }
                if (builderMethod != null) {
                    builderMethod.isAccessible = true
                    return@runCatching builderMethod.invoke(builder, cont)
                }

                val cClass = Class.forName("dev.datlag.kcef.c")
                val staticMethod = candidates.firstNotNullOfOrNull { name ->
                    runCatching { cClass.getDeclaredMethod(name, KCEFBuilder::class.java, Continuation::class.java) }.getOrNull()
                } ?: error("No compatible KCEF install method found")

                staticMethod.isAccessible = true
                staticMethod.invoke(null, builder, cont)
            }

            run.onSuccess { result ->
                if (result != COROUTINE_SUSPENDED) {
                    cont.resume(result as KCEFBuilder)
                }
            }.onFailure { e ->
                cont.resumeWithException(e)
            }
        }
    }
}
