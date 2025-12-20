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

package com.jankinwu.fntv.client.utils

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.Platform
import com.jankinwu.fntv.client.currentPlatformDesktop
import kotlinx.coroutines.runBlocking
import java.io.File
import kotlin.io.path.createTempDirectory
import kotlin.system.exitProcess

interface DesktopUpdateInstaller : UpdateInstaller {
    override suspend fun openForManualInstallation(file: SystemPath, context: ContextMP?): Boolean {
        return DesktopFileRevealer.revealFile(file)
    }

    fun deleteOldUpdater()

    companion object {
        private val logger = Logger.withTag("DesktopUpdateInstaller")

        fun currentOS(): DesktopUpdateInstaller {
            return when (currentPlatformDesktop()) {
                is Platform.MacOS -> MacOSUpdateInstaller
                is Platform.Windows -> WindowsUpdateInstaller
                is Platform.Linux -> LinuxUpdateInstaller
            }
        }

        fun getPlatformDir(): String? {
            val osName = System.getProperty("os.name").lowercase()
            val osArch = System.getProperty("os.arch").lowercase()
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

        fun deleteProxyExecutable() {
            try {
                val osName = System.getProperty("os.name").lowercase()
                if (osName.contains("win")) return

                val userHome = System.getProperty("user.home")
                val appDataDir = if (osName.contains("mac")) {
                    File(userHome, "Library/Application Support/FnMedia")
                } else {
                    File(userHome, ".local/share/fn-media")
                }

                val proxyDir = File(appDataDir, "proxy")
                val platformDir = getPlatformDir() ?: return
                val executableName = "fntv-proxy"

                val targetFile = File(proxyDir, "$platformDir/$executableName")
                if (targetFile.exists()) {
                    logger.i { "Deleting old proxy executable: ${targetFile.absolutePath}" }
                    targetFile.delete()
                }
            } catch (e: Exception) {
                logger.w(e) { "Failed to delete old proxy executable" }
            }
        }
    }
}

object MacOSUpdateInstaller : DesktopUpdateInstaller {
    private val logger = Logger.withTag("MacOSUpdateInstaller")

    override fun install(file: SystemPath, context: ContextMP?): InstallationResult {
        logger.i { "Preparing to install update for macOS using external script." }

        DesktopUpdateInstaller.deleteProxyExecutable()

        val contentsDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
        logger.i { "contentsDir: $contentsDir" }

        val appDir = contentsDir.parentFile ?: return failed(
            "Cannot find .app dir",
            InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE,
        )

        if (!appDir.name.endsWith(".app", ignoreCase = true)) {
            return failed(
                "Current directory is not inside a .app bundle: $appDir",
                InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE,
            )
        }

        val updateFile = file.toFile()
        if (!updateFile.exists()) {
            return failed("Update file does not exist: ${updateFile.absolutePath}")
        }

        val extension = updateFile.extension.lowercase()
        if (extension != "dmg" && extension != "zip") {
            return failed("Unsupported update file format: $extension")
        }

        val tempDir = createTempDirectory(prefix = "ani-macos-update-").toFile()
        logger.i { "tempDir: ${tempDir.absolutePath}" }

        val scriptFile = File(tempDir, "macos-update.command")
        // We'll pass in essential parameters to the script.
        val oldPid = ProcessHandle.current().pid()
        val appName = appDir.name  // e.g. Ani.app
        val targetParentDir = appDir.parentFile.absolutePath

        // Generate the shell script content based on the extension
        val scriptContent = when (extension) {
            "dmg" -> {
                logger.i { "tempMountDir: ${tempDir.absolutePath}" }

                generateShellScriptForDmg(
                    oldPid = oldPid,
                    dmgFilePath = updateFile.absolutePath,
                    convertedDmgFilePath = tempDir.resolve("converted.dmg").absolutePath,
                    mountPath = tempDir.resolve("mount").absolutePath,
                    appName = appName,
                    targetParent = targetParentDir,
                )
            }

            "zip" -> generateShellScriptForZip(
                oldPid = oldPid,
                zipFilePath = updateFile.absolutePath,
                unzipPath = tempDir.resolve("unzip").absolutePath,
                appName = appName,
                targetParent = targetParentDir,
            )

            else -> return failed("Unsupported file format: $extension") // theoretically unreachable
        }

        // Write the script to disk and make it executable
        scriptFile.writeText(scriptContent)
        scriptFile.setExecutable(true)

        // Now run the script
        logger.i { "Launching update script: ${scriptFile.absolutePath}" }
        ProcessBuilder(scriptFile.absolutePath)
            .redirectOutput(File(tempDir, "update-output.log"))
            .redirectError(File(tempDir, "update-error.log"))
            .start()

        logger.i { "Exiting old instance." }
        Thread.sleep(1000)
        exitProcess(0)
    }

    /**
     * Generates a shell script that handles .dmg files:
     * 1) Waits for the old process to exit
     * 2) Converts + mounts the DMG
     * 3) Copies the .app into place
     * 4) Removes the quarantine attribute
     * 5) Detaches the DMG
     * 6) Cleans up
     * 7) Launches the new app
     */
    private fun generateShellScriptForDmg(
        oldPid: Long,
        dmgFilePath: String,
        convertedDmgFilePath: String,
        mountPath: String,
        appName: String,
        targetParent: String,
    ): String {
        return $$"""
            #!/usr/bin/env bash
            set -euo pipefail

            OLD_PID=$$oldPid
            DMG_FILE="$$dmgFilePath"
            MOUNT_DIR="$$mountPath"
            APP_NAME="$$appName"
            TARGET_PARENT="$$targetParent"
            NEW_DMG_FILE="$$convertedDmgFilePath"

            echo "Update script for DMG started."
            echo "Will wait for process PID=$$oldPid to exit."

            # 1) Wait for the old process to fully exit.
            while kill -0 "$OLD_PID" 2>/dev/null; do
              echo "Waiting for old app process $OLD_PID to exit..."
              sleep 1
            done

            # 2) Convert the DMG to a CDR (UDTO format)
            echo "Converting DMG into CDR..."
            hdiutil convert "$DMG_FILE" -format UDTO -o "$NEW_DMG_FILE"

            # 3) Mount the converted DMG
            echo "Mounting the DMG at $MOUNT_DIR ..."
            hdiutil attach "${NEW_DMG_FILE}.cdr" -nobrowse -noverify -noautoopen -mountpoint "$MOUNT_DIR"

            # 4) Copy the updated .app from the DMG to the parent of the current .app
            echo "Copying updated app to $TARGET_PARENT ..."
            cp -R "$MOUNT_DIR/$APP_NAME" "$TARGET_PARENT"

            # 5) Detach the DMG
            echo "Detaching the DMG..."
            hdiutil detach "$MOUNT_DIR" || echo "Warning: failed to detach DMG."

            # 6) Remove the com.apple.quarantine attribute
            echo "Removing quarantine..."
            xattr -r -d com.apple.quarantine "$TARGET_PARENT/$APP_NAME" || true

            echo "Cleaning up temporary mount directory..."
            rm -rf "$MOUNT_DIR"

            # 7) Launch the newly copied app
            echo "Launching updated app: $TARGET_PARENT/$APP_NAME"
            open "$TARGET_PARENT/$APP_NAME"
            
            echo "Deleting update package..."
            rm "$DMG_FILE"

            echo "Update script for DMG finished."
        """.trimIndent()
    }

    /**
     * Generates a shell script that handles .zip files:
     * 1) Waits for the old process to exit
     * 2) Unzips to a temp directory
     * 3) Finds the .app inside the unzipped folder
     * 4) Copies the .app into place
     * 5) Removes the quarantine attribute
     * 6) Cleans up
     * 7) Launches the new app
     */
    private fun generateShellScriptForZip(
        oldPid: Long,
        zipFilePath: String,
        unzipPath: String,
        appName: String,
        targetParent: String,
    ): String {
        return $$"""
            #!/usr/bin/env bash
            set -euo pipefail

            OLD_PID=$$oldPid
            ZIP_FILE="$$zipFilePath"
            UNZIP_DIR="$$unzipPath"
            APP_NAME="$$appName"
            TARGET_PARENT="$$targetParent"

            echo "Update script for ZIP started."
            echo "Will wait for process PID=$$oldPid to exit."

            # 1) Wait for the old process to fully exit.
            while kill -0 "$OLD_PID" 2>/dev/null; do
              echo "Waiting for old app process $OLD_PID to exit..."
              sleep 1
            done

            # 2) Unzip the ZIP file into a temporary directory
            echo "Unzipping update file into $UNZIP_DIR ..."
            mkdir -p "$UNZIP_DIR"
            unzip -q "$ZIP_FILE" -d "$UNZIP_DIR"

            # 3) Within the unzipped folder, locate the .app folder
            #    We'll assume the unzipped folder contains the correct .app we need, matching $APP_NAME
            #    If the .zip file is structured differently, you'd adapt accordingly.
            echo "Looking for $APP_NAME inside $UNZIP_DIR ..."
            if [ ! -d "$UNZIP_DIR/$APP_NAME" ]; then
              echo "Error: Could not find $APP_NAME in the extracted zip."
              exit 1
            fi

            # 4) Copy the updated .app to the parent of the current .app
            echo "Copying updated app to $TARGET_PARENT ..."
            cp -R "$UNZIP_DIR/$APP_NAME" "$TARGET_PARENT"

            # 5) Remove the com.apple.quarantine attribute
            echo "Removing quarantine..."
            xattr -r -d com.apple.quarantine "$TARGET_PARENT/$APP_NAME" || true

            # 6) Clean up the unzipped folder
            echo "Cleaning up temporary unzip directory..."
            rm -rf "$UNZIP_DIR"

            # 7) Launch the newly copied app
            echo "Launching updated app: $TARGET_PARENT/$APP_NAME"
            open "$TARGET_PARENT/$APP_NAME"

            echo "Deleting update package..."
            rm "$ZIP_FILE"

            echo "Update script for ZIP finished."
        """.trimIndent()
    }

    override fun deleteOldUpdater() {
        // Noop or your custom implementation
    }

    private fun failed(
        message: String,
        reason: InstallationFailureReason? = InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE
    ): InstallationResult.Failed {
        logger.i { message }
        return InstallationResult.Failed(reason ?: InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE, message)
    }
}

object LinuxUpdateInstaller : DesktopUpdateInstaller {
    private val logger = Logger.withTag("LinuxUpdateInstaller")

    override fun deleteOldUpdater() {
        // no-op
    }

    override fun install(file: SystemPath, context: ContextMP?): InstallationResult {
        DesktopUpdateInstaller.deleteProxyExecutable()

        val updateFile = file.toFile()
        if (!updateFile.exists()) {
            return failed("Update file does not exist: ${updateFile.absolutePath}")
        }

        val extension = updateFile.extension.lowercase()
        val installCommand = when (extension) {
            "deb" -> "pkexec dpkg -i"
            "rpm" -> "pkexec rpm -Uvh"
            "pkg" -> "pkexec pacman -U --noconfirm"
            else -> {
                runBlocking {
                    DesktopFileRevealer.revealFile(file)
                }
                return InstallationResult.Succeed
            }
        }

        val tempDir = createTempDirectory(prefix = "ani-linux-update-").toFile()
        val scriptFile = File(tempDir, "linux-update.sh")
        val oldPid = ProcessHandle.current().pid()

        val scriptContent = generateShellScriptForLinux(
            oldPid = oldPid,
            filePath = updateFile.absolutePath,
            installCommand = installCommand
        )

        scriptFile.writeText(scriptContent)
        scriptFile.setExecutable(true)

        logger.i { "Launching update script: ${scriptFile.absolutePath}" }
        try {
            ProcessBuilder(scriptFile.absolutePath)
                .start()
            logger.i { "Exiting old instance." }
            Thread.sleep(1000)
            exitProcess(0)
        } catch (e: Exception) {
            return failed("Failed to launch installer: ${e.message}", InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE)
        }
    }

    private fun generateShellScriptForLinux(
        oldPid: Long,
        filePath: String,
        installCommand: String
    ): String {
        return $$"""
            #!/usr/bin/env bash
            set -e

            OLD_PID=$$oldPid
            UPDATE_FILE="$$filePath"

            # Wait for the old process to fully exit.
            while kill -0 "$OLD_PID" 2>/dev/null; do
              sleep 1
            done

            # Run the install command
            $installCommand "$UPDATE_FILE"

            echo "Deleting update package..."
            rm "$UPDATE_FILE"
        """.trimIndent()
    }

    private fun failed(
        message: String,
        reason: InstallationFailureReason? = InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE
    ): InstallationResult.Failed {
        logger.i { message }
        return InstallationResult.Failed(reason ?: InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE, message)
    }
}

object WindowsUpdateInstaller : DesktopUpdateInstaller {
    private val logger = Logger.withTag("WindowsUpdateInstaller")

    override fun install(file: SystemPath, context: ContextMP?): InstallationResult {
        logger.i { "Installing update for Windows" }
        val appDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
        logger.i { "Current app dir: ${appDir.absolutePath}" }

        val platformDir = DesktopUpdateInstaller.getPlatformDir() ?: return InstallationResult.Failed(
            InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE,
            "Unsupported platform"
        )

        // Target updater path
        val targetUpdater = File(appDir, "fntv-updater.exe")

        // Extract updater
        try {
            // If exists, try to delete it first to ensure we use the new one
            if (targetUpdater.exists()) {
                if (!targetUpdater.delete()) {
                    logger.w { "Failed to delete old updater: ${targetUpdater.absolutePath}, trying to overwrite." }
                }
            }

            var found = false

            // 1. Try to find in resources dir (packaged app)
            val resourcesPath = System.getProperty("compose.application.resources.dir")
            if (resourcesPath != null) {
                val resourcesDir = File(resourcesPath)
                val sourceUpdater = File(resourcesDir, "fntv-updater/$platformDir/fntv-updater.exe")
                if (sourceUpdater.exists()) {
                    sourceUpdater.copyTo(targetUpdater, overwrite = true)
                    found = true
                }
            }

            // 2. If not found, try classpath (dev mode)
            if (!found) {
                val resourcePath = "/fntv-updater/$platformDir/fntv-updater.exe"
                val stream = WindowsUpdateInstaller::class.java.getResourceAsStream(resourcePath)
                if (stream != null) {
                    stream.use { input ->
                        targetUpdater.outputStream().use { output ->
                            input.copyTo(output)
                        }
                    }
                    found = true
                }
            }

            if (!found) {
                return InstallationResult.Failed(
                    InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE,
                    "Updater executable not found in resources"
                )
            }

            if (!targetUpdater.exists()) {
                return InstallationResult.Failed(
                    InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE,
                    "Updater executable extraction failed"
                )
            }

        } catch (e: Exception) {
            logger.e(e) { "Failed to extract updater" }
            return InstallationResult.Failed(
                InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE,
                "Failed to extract updater: ${e.message}"
            )
        }

        // Run updater
        try {
            logger.i { "Launching updater: ${targetUpdater.absolutePath}" }
            ProcessBuilder(
                targetUpdater.absolutePath,
                file.absolutePath, // Installer path
                appDir.absolutePath // Install dir
            )
                .directory(appDir)
                .start()

            logger.i { "Updater started, exiting app..." }
            exitProcess(0)
        } catch (e: Exception) {
            logger.e(e) { "Failed to start updater" }
            return InstallationResult.Failed(
                InstallationFailureReason.UNSUPPORTED_FILE_STRUCTURE,
                "Failed to start updater: ${e.message}"
            )
        }
    }

    override fun deleteOldUpdater() {
        val appDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
        val updateExecutable = appDir.resolve("fntv-updater.exe")
        if (updateExecutable.exists()) {
            try {
                updateExecutable.delete()
            } catch (e: Exception) {
                logger.w(e) { "Failed to delete old updater" }
            }
        }
    }


}
