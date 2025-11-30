package com.jankinwu.fntv.client.manager

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
            println("ProxyManager: Unsupported platform: $osName / $osArch")
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
        
        val executableFile = File(proxyDir, "$platformDir/$executableName")
        
        if (!executableFile.exists()) {
            println("ProxyManager: Executable not found at ${executableFile.absolutePath}")
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
            println("ProxyManager: Started proxy at ${executableFile.absolutePath}")

            // Consume output streams to prevent blocking
            Thread {
                try {
                    proxyProcess?.inputStream?.bufferedReader()?.forEachLine { 
                        // println("Proxy: $it") 
                    }
                } catch (e: Exception) {
                    // Ignore stream close errors
                }
            }.apply { 
                isDaemon = true 
                start()
            }
            
            Thread {
                try {
                    proxyProcess?.errorStream?.bufferedReader()?.forEachLine {
                        System.err.println("ProxyManager Error: $it")
                    }
                } catch (e: Exception) {
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
            println("ProxyManager: Failed to start proxy: ${e.message}")
            e.printStackTrace()
        }
    }

    fun stop() {
        if (proxyProcess != null) {
            try {
                if (proxyProcess!!.isAlive) {
                    proxyProcess!!.destroy()
                    println("ProxyManager: Proxy stopped")
                }
            } catch (e: Exception) {
                e.printStackTrace()
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
