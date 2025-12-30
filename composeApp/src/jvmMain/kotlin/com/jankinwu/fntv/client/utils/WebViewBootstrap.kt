package com.jankinwu.fntv.client.utils

import co.touchlab.kermit.Logger
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

object WebViewBootstrap {
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
                                // logSeverity = KCEFBuilder.Settings.LogSeverity.INFO
                            }
                            progress {
                                onInitialized {
                                    initialized.value = true
                                }
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
                            Logger.log(severity, "KCEF", null, line)
                        }
                        line = reader.readLine()
                    }
                    filePointer = reader.filePointer
                }
                delay(1000)
            }
            reader.close()
        } catch (e: Exception) {
            Logger.withTag("KCEF").e(e) { "Error tailing log file" }
        }
    }
}
