package com.jankinwu.fntv.client.utils

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.data.store.AppSettingsStore

import co.touchlab.kermit.Severity
import dev.datlag.kcef.KCEF
import dev.datlag.kcef.KCEFBuilder
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.awt.EventQueue
import java.io.File
import java.io.RandomAccessFile
import java.nio.file.FileSystems
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.jar.JarFile
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.Continuation
import kotlin.coroutines.intrinsics.COROUTINE_SUSPENDED
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlin.coroutines.suspendCoroutine
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

        val currentVersion = BuildConfig.VERSION_NAME

        var isKcefInitialized = AppSettingsStore.kcefInitialized &&
            AppSettingsStore.kcefInitializedVersion == currentVersion

        if (AppSettingsStore.kcefInitialized && AppSettingsStore.kcefInitializedVersion != currentVersion) {
            AppSettingsStore.kcefInitialized = false
            isKcefInitialized = false
        }

        if (isKcefInitialized && !installDir.exists()) {
            AppSettingsStore.kcefInitialized = false
            isKcefInitialized = false
        }

        if (isKcefInitialized) {
            val installEmpty = installDir.listFiles()?.isEmpty() != false
            val cacheEmpty = cacheDir.listFiles()?.isEmpty() != false
            if (installDir.exists() && installEmpty) {
                logger.w { "KCEF installDir is empty but marked initialized, forcing reinitialize: ${installDir.absolutePath}" }
                AppSettingsStore.kcefInitialized = false
                isKcefInitialized = false
                installDir.deleteRecursively()
            }
            if (cacheDir.exists() && cacheEmpty) {
                cacheDir.deleteRecursively()
            }
        }

        if (!isKcefInitialized) {
            val installEmpty = installDir.listFiles()?.isEmpty() != false
            val cacheEmpty = cacheDir.listFiles()?.isEmpty() != false

            if (installDir.exists() && installEmpty) {
                installDir.deleteRecursively()
            }
            if (cacheDir.exists() && cacheEmpty) {
                cacheDir.deleteRecursively()
            }
        }

        // Create a custom HttpClient with Trust-All SSL configuration for KCEF download
        val kcefClient = HttpClient(OkHttp) {
            engine {
                config {
                    val trustAllCerts = arrayOf<TrustManager>(@Suppress("CustomX509TrustManager")
                    object : X509TrustManager {
                        override fun getAcceptedIssuers(): Array<X509Certificate> = arrayOf()
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

        try {
            File(cacheDir, "kcef.log").delete()
            val kcefLog = File(cacheDir, "kcef.log").apply { deleteOnExit() }

            scope.launch {
                tailKcefLog(kcefLog)
            }

            val preflightError = withContext(Dispatchers.IO) {
                runCatching {
                    installDir.parentFile?.mkdirs()
                    if (!cacheDir.exists()) cacheDir.mkdirs()

                    if (!isKcefInstallComplete(installDir)) {
                        runCatching { extractBundledKcef(installDir) }
                    }

                    if (!isKcefInstallComplete(installDir)) {
                        installDir.deleteRecursively()
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

                        withTimeout(30L * 60L * 1000L) {
                            installKcef(builder)
                        }
                    }

                    if (!isKcefInstallComplete(installDir)) {
                        error("KCEF install directory is incomplete: ${installDir.absolutePath}")
                    }
                }.exceptionOrNull()
            }

            if (preflightError != null) {
                initError.value = preflightError
                return
            }

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
                                    AppSettingsStore.kcefInitializedVersion = currentVersion
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
                return
            }
        } catch (t: Throwable) {
            initError.value = t
        } finally {
            runCatching { kcefClient.close() }
        }
    }

    suspend fun retry() {
        if (lastInstallDir == null || lastCacheDir == null || lastLogDir == null) return
        initError.value = null
        started.set(false)
        start(lastInstallDir!!, lastCacheDir!!, lastLogDir!!)
    }

    private fun extractBundledKcef(targetInstallDir: File) {
        if (!targetInstallDir.exists()) targetInstallDir.mkdirs()

        if (extractBundledKcefFromResourcesDir(targetInstallDir)) return
        if (extractBundledKcefFromClasspathJar(targetInstallDir)) return

        logger.w { "Bundled KCEF directory not found in resources dir or classpath, skipping extraction" }
    }

    private fun extractBundledKcefFromResourcesDir(targetInstallDir: File): Boolean {
        val resourcesDirPath = System.getProperty("compose.application.resources.dir") ?: return false
        val resourcesDir = File(resourcesDirPath)
        val bundledDir = File(resourcesDir, "kcef-bundle")
        if (!bundledDir.exists() || !bundledDir.isDirectory) return false

        logger.i { "Extracting bundled KCEF from resources dir: ${bundledDir.absolutePath} -> ${targetInstallDir.absolutePath}" }

        val supportsPosix = FileSystems.getDefault().supportedFileAttributeViews().contains("posix")
        var fileCount = 0

        bundledDir.walkTopDown().forEach { src ->
            val relPath = src.relativeTo(bundledDir).path
            val dest = File(targetInstallDir, relPath)
            if (src.isDirectory) {
                dest.mkdirs()
            } else {
                dest.parentFile?.mkdirs()
                val srcPath = src.toPath()
                val destPath = dest.toPath()
                Files.copy(
                    srcPath,
                    destPath,
                    StandardCopyOption.REPLACE_EXISTING,
                    StandardCopyOption.COPY_ATTRIBUTES
                )
                if (supportsPosix) {
                    runCatching { Files.setPosixFilePermissions(destPath, Files.getPosixFilePermissions(srcPath)) }
                }
                fileCount++
            }
        }

        logger.i { "Extracted $fileCount files to ${targetInstallDir.absolutePath}" }
        return fileCount > 0
    }

    private fun extractBundledKcefFromClasspathJar(targetInstallDir: File): Boolean {
        val jarPath = runCatching {
            val uri = WebViewBootstrap::class.java.protectionDomain.codeSource.location.toURI()
            File(uri)
        }.getOrNull()?.takeIf { it.isFile && it.extension.equals("jar", ignoreCase = true) }
            ?: return false

        logger.i { "Extracting bundled KCEF from classpath jar: ${jarPath.absolutePath} -> ${targetInstallDir.absolutePath}" }

        var fileCount = 0
        JarFile(jarPath).use { jar ->
            val entries = jar.entries()
            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                val name = entry.name
                if (!name.startsWith("kcef-bundle/")) continue
                if (entry.isDirectory) continue

                val relPath = name.removePrefix("kcef-bundle/")
                if (relPath.isBlank()) continue

                val dest = File(targetInstallDir, relPath)
                dest.parentFile?.mkdirs()

                jar.getInputStream(entry).use { input ->
                    Files.copy(input, dest.toPath(), StandardCopyOption.REPLACE_EXISTING)
                }
                fileCount++
            }
        }

        logger.i { "Extracted $fileCount files to ${targetInstallDir.absolutePath}" }
        return fileCount > 0
    }

    private fun isKcefInstallComplete(installDir: File): Boolean {
        val localesDir = File(installDir, "locales")
        val hasLocales = localesDir.isDirectory && localesDir.listFiles()?.any { it.isFile && it.name.endsWith(".pak") } == true
        val hasIcu = File(installDir, "icudtl.dat").isFile
        return hasLocales && hasIcu
    }

    private suspend fun installKcef(builder: KCEFBuilder): KCEFBuilder {
        val method = KCEFBuilder::class.java.getDeclaredMethod("install\$kcef", Continuation::class.java)
        method.isAccessible = true

        @Suppress("UNCHECKED_CAST")
        return suspendCoroutine { cont ->
            runCatching { method.invoke(builder, cont) }
                .onSuccess { result ->
                    if (result != COROUTINE_SUSPENDED) {
                        cont.resume(result as KCEFBuilder)
                    }
                }
                .onFailure { e ->
                    cont.resumeWithException(e)
                }
        }
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
