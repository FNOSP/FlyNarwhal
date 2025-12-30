package com.jankinwu.fntv.client.manager

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.utils.ExecutableDirectoryDetector
import java.io.File
import java.util.Locale

object ProxyManager {
    private val logger = Logger.withTag("ProxyManager")
    private var proxyProcess: Process? = null

    fun start() {
        if (proxyProcess != null && proxyProcess!!.isAlive) {
            return
        }
        
        // Try to kill existing proxy process to avoid port conflict (especially in dev mode)
        killExistingProxy()

        val osName = System.getProperty("os.name").lowercase(Locale.getDefault())
        val osArch = System.getProperty("os.arch").lowercase(Locale.getDefault())

        val platformDir = getPlatformDir(osName, osArch)
        if (platformDir == null) {
            logger.i("Unsupported platform: $osName / $osArch")
            return
        }

        val executableName = if (osName.contains("win")) "fntv-proxy.exe" else "fntv-proxy"
        
        // Locate fntv-proxy directory
        // Assume it's in the project root or working directory
        val workingDir = File(System.getProperty("user.dir"))
        var proxyDir = File(workingDir, "fntv-proxy")
        
        // If not found in current working directory, try parent directory
        // (This handles cases where the app is run from a submodule directory)
        if (!proxyDir.exists()) {
            val parentDir = workingDir.parentFile
            if (parentDir != null) {
                val parentProxyDir = File(parentDir, "fntv-proxy")
                if (parentProxyDir.exists()) {
                    proxyDir = parentProxyDir
                }
            }
        }

        // Check resources dir (for packaged app)
        if (!proxyDir.exists()) {
            val resourcesPath = System.getProperty("compose.application.resources.dir")
            if (resourcesPath != null) {
                val resourcesDir = File(resourcesPath)
                val resourcesProxyDir = File(resourcesDir, "fntv-proxy")
                if (resourcesProxyDir.exists()) {
                    proxyDir = resourcesProxyDir
                }
            }
        }

        // Check the executable directory as well, just in case it was already extracted there
        if (!proxyDir.exists()) {
            try {
                val exeDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
                val appResourcesProxyDir = File(exeDir, "app/resources/fntv-proxy")
                val exeProxyDir = File(exeDir, "fntv-proxy")

                if (appResourcesProxyDir.exists()) {
                    proxyDir = appResourcesProxyDir
                } else if (exeProxyDir.exists()) {
                    proxyDir = exeProxyDir
                }
            } catch (e: Exception) {
                logger.w("Failed to get executable directory: ${e.message}")
            }
        }
        
        // Try to extract from classpath if not found
        if (!proxyDir.exists() || !File(proxyDir, "$platformDir/$executableName").exists()) {
            try {
                // Extract to a user-writable directory (for Linux/macOS) or keep relative (for Windows)
                val userHome = System.getProperty("user.home")
                val extractDir = if (osName.contains("win")) {
                    val exeDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
                    File(exeDir, "app/resources/fntv-proxy")
                } else {
                    val appDataDir = when {
                        osName.contains("mac") -> File(userHome, "Library/Application Support/fly-narwhal")
                        else -> File(userHome, ".local/share/fly-narwhal") // Linux/Unix
                    }
                    File(appDataDir, "proxy")
                }
                
                if (!extractDir.exists()) {
                    extractDir.mkdirs()
                }
                
                val resourcePath = "/fntv-proxy/$platformDir/$executableName"
                val resourceStream = ProxyManager::class.java.getResourceAsStream(resourcePath)
                
                if (resourceStream != null) {
                    val targetFile = File(extractDir, "$platformDir/$executableName")
                    if (!targetFile.parentFile.exists()) {
                        targetFile.parentFile.mkdirs()
                    }
                    
                    // Copy if not exists or size differs (simple check)
                    // Ideally check version or hash, but here we just ensure it exists
                    if (!targetFile.exists()) {
                        logger.i("Extracting proxy to ${targetFile.absolutePath}")
                        targetFile.outputStream().use { output ->
                            resourceStream.copyTo(output)
                        }
                        if (!osName.contains("win")) {
                            targetFile.setExecutable(true)
                        }
                    }
                    proxyDir = extractDir
                } else {
                    logger.i("Resource not found in classpath: $resourcePath")
                }
            } catch (e: Exception) {
                logger.e("Failed to extract proxy: ${e.message}", e)
            }
        }

        val executableFile = File(proxyDir, "$platformDir/$executableName")
        
        if (!executableFile.exists()) {
            logger.w("Executable not found at ${executableFile.absolutePath}")
            return
        }

        if (!osName.contains("win")) {
            executableFile.setExecutable(true)
        }

        try {
            val pb = ProcessBuilder(executableFile.absolutePath)
            pb.directory(executableFile.parentFile)
            
            // Start process
            proxyProcess = pb.start()
            logger.i("Started proxy at ${executableFile.absolutePath}")

            // Consume output streams to prevent blocking
            Thread {
                try {
                    proxyProcess?.inputStream?.bufferedReader()?.forEachLine { 
                    }
                } catch (_: Exception) {
                    // Ignore stream close errors
                }
            }.apply { 
                isDaemon = true 
                start()
            }
            
            Thread {
                try {
                    proxyProcess?.errorStream?.bufferedReader()?.forEachLine {
                        logger.e("Proxy Error: $it")
                    }
                } catch (_: Exception) {
                     // Ignore stream close errors
                }
            }.apply { 
                isDaemon = true 
                start()
            }
            
            // Add shutdown hook as a safety net
            Runtime.getRuntime().addShutdownHook(Thread {
                stop()
            })

        } catch (e: Exception) {
            logger.e("Failed to start proxy: ${e.message}", e)
        }
    }

    fun stop() {
        if (proxyProcess != null) {
            try {
                if (proxyProcess!!.isAlive) {
                    proxyProcess!!.destroy()
                    logger.i("Proxy stopped")
                }
            } catch (e: Exception) {
                logger.e("Failed to stop the proxy, case: ", e)
            } finally {
                proxyProcess = null
            }
        }
    }

    private fun getPlatformDir(osName: String, osArch: String): String? {
        return when {
            osName.contains("win") -> {
                when {
                    osArch.contains("aarch64") || osArch.contains("arm64") -> "windows_aarch64"
                    osArch.contains("amd64") -> "windows_amd64"
                    else -> "windows_386"
                }
            }
            osName.contains("mac") -> {
                if (osArch.contains("aarch64") || osArch.contains("arm")) "darwin_aarch64" else "darwin_amd64"
            }
            osName.contains("nix") || osName.contains("nux") -> {
                if (osArch.contains("aarch64") || osArch.contains("arm")) "linux_aarch64" else "linux_amd64"
            }
            else -> null
        }
    }

    private fun killExistingProxy() {
        try {
            val osName = System.getProperty("os.name").lowercase(Locale.getDefault())
            if (osName.contains("win")) {
                Runtime.getRuntime().exec("taskkill /F /IM fntv-proxy.exe").waitFor()
            } else {
                Runtime.getRuntime().exec(arrayOf("pkill", "-f", "fntv-proxy")).waitFor()
            }
        } catch (e: Exception) {
            // Ignore errors (e.g. process not found)
            logger.w("Failed to kill existing proxy: ${e.message}")
        }
    }
}
