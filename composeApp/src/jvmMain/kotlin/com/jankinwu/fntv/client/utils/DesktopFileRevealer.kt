package com.jankinwu.fntv.client.utils

import com.jankinwu.fntv.client.Platform
import com.jankinwu.fntv.client.currentPlatformDesktop
import java.awt.Desktop
import java.io.IOException

object DesktopFileRevealer {
    fun revealFile(file: SystemPath): Boolean {
        val ioFile = file.toFile()
        if (!ioFile.exists()) return false

        return try {
            when (currentPlatformDesktop()) {
                is Platform.Windows -> {
                    ProcessBuilder("explorer.exe", "/select,", ioFile.absolutePath).start()
                    true
                }
                is Platform.MacOS -> {
                    ProcessBuilder("open", "-R", ioFile.absolutePath).start()
                    true
                }
                is Platform.Linux -> {
                    // Try generic xdg-open on parent
                    if (Desktop.isDesktopSupported() && Desktop.getDesktop().isSupported(Desktop.Action.OPEN)) {
                         Desktop.getDesktop().open(ioFile.parentFile)
                         true
                    } else {
                        // Fallback
                         ProcessBuilder("xdg-open", ioFile.parent).start()
                         true
                    }
                }
            }
        } catch (e: IOException) {
            e.printStackTrace()
            false
        }
    }
}
