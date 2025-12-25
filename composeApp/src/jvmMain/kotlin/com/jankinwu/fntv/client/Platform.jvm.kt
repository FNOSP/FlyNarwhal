/*
 * Copyright (C) 2024-2025 OpenAni and contributors.
 *
 * 此源代码的使用受 GNU AFFERO GENERAL PUBLIC LICENSE version 3 许可证的约束, 可以在以下链接找到该许可证.
 * Use of this source code is governed by the GNU AGPLv3 license, which can be found at the following link.
 *
 * https://github.com/open-ani/ani/blob/main/LICENSE
 */
/*
 * Copyright (C) 2025 FNOSP and contributors.
 *
 * This file has been modified from its original version.
 * The modifications are also licensed under the AGPLv3.
 */
package com.jankinwu.fntv.client

import com.jankinwu.fntv.client.utils.ExecutableDirectoryDetector
import co.touchlab.kermit.Logger
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

private var externalPlayerProcess: Process? = null
private const val PLAYER_PORT = 47920

internal actual fun currentPlatformImpl(): Platform {
    val os = System.getProperty("os.name")?.lowercase() ?: error("Cannot determine platform, 'os.name' is null.")
    val arch = getArch()
    return when {
        "mac" in os || "os x" in os || "darwin" in os -> Platform.MacOS(arch)
        "windows" in os -> Platform.Windows(arch)
//        "linux" in os || "redhat" in os || "debian" in os || "ubuntu" in os -> Platform.Linux(arch)
        "linux" in os -> Platform.Linux(arch)
        else -> throw UnsupportedOperationException("Unsupported platform: $os")
    }
}

private fun getArch() = System.getProperty("os.arch").lowercase().let {
    when {
        "x86" in it || "x64" in it || "amd64" in it -> Arch.X86_64
        "arm" in it || "aarch" in it -> Arch.AARCH64
        else -> Arch.X86_64
    }
}

fun currentPlatformDesktop(): Platform.Desktop {
    val platform = currentPlatform()
    check(platform is Platform.Desktop)
    return platform
}

actual fun launchExternalPlayer(url: String, title: String, startPos: Long) {
    val platform = currentPlatformDesktop()
    val logger = Logger.withTag("ExternalPlayer")

    // Try to send to existing player first
    if (sendToExistingPlayer(url, title, startPos)) {
        logger.i { "Successfully sent play request to existing external player." }
        return
    }

    val executableDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
    val candidates = buildExternalPlayerCandidates(platform, executableDir)
    val playerExe = candidates.firstOrNull { it.exists() }
        ?: throw IllegalStateException(
            "External player executable not found. Tried: ${candidates.joinToString { it.absolutePath }}"
        )

    logger.i { "Launching new external player instance: $url, title: $title, startPos: $startPos ms" }
    try {
        // Kill previous process if it exists (safety)
        externalPlayerProcess?.destroy()

        // Keep working directory next to the executable so Flutter can find "data/" and native libs.
        val process = ProcessBuilder(playerExe.absolutePath, url, title, startPos.toString())
            .directory(playerExe.parentFile)
            .start()
        
        externalPlayerProcess = process

        // Ensure subprocess is killed when main app exits
        Runtime.getRuntime().addShutdownHook(Thread {
            process.destroy()
        })
    } catch (e: Exception) {
        logger.e(e) { "Failed to start external player process." }
        throw e
    }
}

private fun sendToExistingPlayer(url: String, title: String, startPos: Long): Boolean {
    return try {
        val connection = URL("http://127.0.0.1:$PLAYER_PORT/play").openConnection() as HttpURLConnection
        connection.requestMethod = "POST"
        connection.doOutput = true
        connection.setRequestProperty("Content-Type", "application/json")
        connection.connectTimeout = 500 // Short timeout
        connection.readTimeout = 1000

        val json = """
            {
                "url": "$url",
                "title": "$title",
                "startPos": $startPos
            }
        """.trimIndent()

        connection.outputStream.use { it.write(json.toByteArray()) }
        val responseCode = connection.responseCode
        responseCode == 200
    } catch (e: Exception) {
        // If connection fails, player probably not running
        false
    }
}

private fun buildExternalPlayerCandidates(
    platform: Platform.Desktop,
    executableDir: File
): List<File> {
    val exeName = when (platform) {
        is Platform.Windows -> "flutter_player.exe"
        is Platform.MacOS -> "flutter_player.app/Contents/MacOS/flutter_player"
        is Platform.Linux -> "flutter_player"
    }

    val packagedResources = File(File(executableDir, "app"), "resources")
    val packagedExe = File(packagedResources, exeName)

    val userDir = File(System.getProperty("user.dir") ?: ".").absoluteFile
    val projectRoot = findProjectRoot(userDir)

    val devBuildExe = projectRoot?.let { root ->
        when (platform) {
            is Platform.Windows -> listOf(
                File(root, "flutter_player/build/windows/x64/runner/Release/flutter_player.exe"),
                File(root, "flutter_player/build/windows/runner/Release/flutter_player.exe"),
            )
            is Platform.MacOS -> listOf(
                File(root, "flutter_player/build/macos/Build/Products/Release/flutter_player.app/Contents/MacOS/flutter_player"),
            )
            is Platform.Linux -> listOf(
                File(root, "flutter_player/build/linux/x64/release/bundle/flutter_player"),
            )
        }
    }.orEmpty()

    val bundledExe = projectRoot?.let { root ->
        listOf(
            File(root, "composeApp/build/compose/all-app-resources/$exeName"),
            File(root, "composeApp/build/compose/all-app-resources/${exeName.replace(".exe", "")}"),
        )
    }.orEmpty()

    return listOf(packagedExe) + bundledExe + devBuildExe
}

private fun findProjectRoot(startDir: File): File? {
    var current: File? = startDir
    repeat(8) {
        val dir = current ?: return null
        if (File(dir, "flutter_player").exists()) return dir
        current = dir.parentFile
    }
    return null
}
