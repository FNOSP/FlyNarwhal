package com.jankinwu.fntv.client.manager

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.utils.ExecutableDirectoryDetector
import java.io.File
import java.util.Locale

object ProxyManager {
    private var proxyProcess: Process? = null

    fun start() {
        if (proxyProcess != null && proxyProcess!!.isAlive) {
            return
        }

        val osName = System.getProperty("os.name").lowercase(Locale.getDefault())
        val osArch = System.getProperty("os.arch").lowercase(Locale.getDefault())

        val platformDir = getPlatformDir(osName, osArch)
        if (platformDir == null) {
            Logger.i("ProxyManager: Unsupported platform: $osName / $osArch")
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
                Logger.w("ProxyManager: Failed to get executable directory: ${e.message}")
            }
        }
        
        // Try to extract from classpath if not found
        if (!proxyDir.exists() || !File(proxyDir, "$platformDir/$executableName").exists()) {
            try {
                // Extract to the directory where the executable is located
                val exeDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
                val extractDir = File(exeDir, "app/resources/fntv-proxy")
                
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
                        Logger.i("ProxyManager: Extracting proxy to ${targetFile.absolutePath}")
                        targetFile.outputStream().use { output ->
                            resourceStream.copyTo(output)
                        }
                        if (!osName.contains("win")) {
                            targetFile.setExecutable(true)
                        }
                    }
                    proxyDir = extractDir
                } else {
                    Logger.i("ProxyManager: Resource not found in classpath: $resourcePath")
                }
            } catch (e: Exception) {
                Logger.e("ProxyManager: Failed to extract proxy: ${e.message}", e)
            }
        }

        val executableFile = File(proxyDir, "$platformDir/$executableName")
        
        if (!executableFile.exists()) {
            Logger.w("ProxyManager: Executable not found at ${executableFile.absolutePath}")
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
            Logger.i("ProxyManager: Started proxy at ${executableFile.absolutePath}")

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
                        Logger.e("ProxyManager Error: $it")
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
            Logger.e("ProxyManager: Failed to start proxy: ${e.message}", e)
        }
    }

    fun stop() {
        if (proxyProcess != null) {
            try {
                if (proxyProcess!!.isAlive) {
                    proxyProcess!!.destroy()
                    Logger.i("ProxyManager: Proxy stopped")
                }
            } catch (e: Exception) {
                Logger.e("ProxyManager: Failed to stop the proxy, case: ", e)
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
}
