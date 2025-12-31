package com.jankinwu.fntv.client.utils

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.store.AppSettingsStore

import co.touchlab.kermit.Severity
import dev.datlag.kcef.KCEF
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.awt.EventQueue
import java.io.File
import java.io.RandomAccessFile
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.CoroutineContext
import io.ktor.client.HttpClient
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import io.ktor.http.ContentType
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import java.security.SecureRandom
import java.security.cert.X509Certificate

object WebViewBootstrap {
    private val logger = Logger.withTag("WebViewBootstrap")
    private val started = AtomicBoolean(false)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val awtDispatcher = object : kotlinx.coroutines.CoroutineDispatcher() {
        override fun dispatch(context: CoroutineContext, block: Runnable) {
            if (EventQueue.isDispatchThread()) {
                block.run()
            } else {
                EventQueue.invokeLater(block)
            }
        }
    }

    val initialized = MutableStateFlow(false)
    val restartRequired = MutableStateFlow(false)
    val initError = MutableStateFlow<Throwable?>(null)

    private var lastInstallDir: File? = null
    private var lastCacheDir: File? = null
    private var lastLogDir: File? = null

    suspend fun start(installDir: File, cacheDir: File, logDir: File) {
        lastInstallDir = installDir
        lastCacheDir = cacheDir
        lastLogDir = logDir

        if (!started.compareAndSet(false, true)) return

        // Check if KCEF was successfully initialized before AND the installation directory exists
        var isKcefInitialized = AppSettingsStore.kcefInitialized
        if (isKcefInitialized && !installDir.exists()) {
            AppSettingsStore.kcefInitialized = false
            isKcefInitialized = false
        }

        if (!isKcefInitialized) {
            // If not initialized successfully before or directory missing, clean up to force a fresh download
            if (installDir.exists()) {
                installDir.deleteRecursively()
            }
        }

        // Create a custom HttpClient with Trust-All SSL configuration for KCEF download
        val kcefClient = HttpClient(OkHttp) {
            engine {
                config {
                    val trustAllCerts = arrayOf<TrustManager>(@Suppress("CustomX509TrustManager")
                    object : X509TrustManager {
                        override fun getAcceptedIssuers(): Array<X509Certificate>? = null
                        @Suppress("TrustAllX509TrustManager")
                        override fun checkClientTrusted(certs: Array<X509Certificate>, authType: String) {}
                        @Suppress("TrustAllX509TrustManager")
                        override fun checkServerTrusted(certs: Array<X509Certificate>, authType: String) {}
                    })
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

        // Clean up legacy kcef.log in logDir if it exists
        File(cacheDir, "kcef.log").delete()

        // Use cacheDir for the raw KCEF log to avoid polluting the logs directory
        val kcefLog = File(cacheDir, "kcef.log")
        kcefLog.deleteOnExit()

        withContext(Dispatchers.IO) {
            try {
                if (!installDir.exists()) installDir.mkdirs()
                if (!cacheDir.exists()) cacheDir.mkdirs()
            } catch (e: Exception) {
                initError.value = e
                return@withContext
            }
        }

        try {
            val initFailure = runCatching {
                withContext(awtDispatcher) {
                    KCEF.init(
                        builder = {
                            installDir(installDir)
                            settings {
                                cachePath = cacheDir.absolutePath
                                logFile = kcefLog.absolutePath
                            }
                            progress {
                                onInitialized {
                                    initialized.value = true
                                    AppSettingsStore.kcefInitialized = true
                                }
                            }
                            download {
                                github()
                                client(kcefClient)
                            }
                        },
                        onError = { throwable ->
                            initError.value = throwable
                        },
                        onRestartRequired = {
                            restartRequired.value = true
                        }
                    )
                }
            }.exceptionOrNull()

            if (initFailure != null) {
                initError.value = initFailure
            }
        } catch (t: Throwable) {
            initError.value = t
        }

        scope.launch {
            tailKcefLog(kcefLog)
        }
    }

    suspend fun retry() {
        if (lastInstallDir == null || lastCacheDir == null || lastLogDir == null) return
        initError.value = null
        started.set(false)
        start(lastInstallDir!!, lastCacheDir!!, lastLogDir!!)
    }

    private suspend fun tailKcefLog(file: File) {
        var retries = 0
        while (!file.exists() && retries < 30) {
            delay(1000)
            retries++
        }
        if (!file.exists()) return

        try {
            val reader = RandomAccessFile(file, "r")
            var filePointer = 0L

            while (scope.isActive) {
                val length = file.length()
                if (length < filePointer) {
                    filePointer = 0
                    reader.seek(0)
                }

                if (length > filePointer) {
                    reader.seek(filePointer)
                    var line = reader.readLine()
                    while (line != null) {
                        if (line.isNotEmpty()) {
                            val severity = when {
                                line.contains(":ERROR:", ignoreCase = true) || line.contains(":FATAL:", ignoreCase = true) -> Severity.Error
                                line.contains(":WARNING:", ignoreCase = true) -> Severity.Warn
                                line.contains(":VERBOSE:", ignoreCase = true) -> Severity.Verbose
                                else -> Severity.Info
                            }
                            logger.log(severity, "KCEF", null, line)
                        }
                        line = reader.readLine()
                    }
                    filePointer = reader.filePointer
                }
                delay(1000)
            }
            reader.close()
        } catch (e: Exception) {
            logger.e(e) { "Error tailing log file" }
        }
    }
}
