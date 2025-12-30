package com.jankinwu.fntv.client.utils

import io.github.vinceglb.filekit.FileKit
import io.github.vinceglb.filekit.PlatformFile
import io.github.vinceglb.filekit.dialogs.FileKitType
import io.github.vinceglb.filekit.dialogs.openFilePicker
import io.github.vinceglb.filekit.dialogs.openFileSaver

/**
 * Modern KMP File picker utility using FileKit
 */
object FileUtil {
    /**
     * Opens a file picker and returns the selected file.
     * This is a suspend function and can be called from any coroutine.
     */
    suspend fun pickFile(
        fileExtensions: List<String> = emptyList(),
        title: String? = null
    ): PlatformFile? {
        val type = if (fileExtensions.isEmpty()) {
            FileKitType.File()
        } else {
            FileKitType.File(extensions = fileExtensions)
        }

        return FileKit.openFilePicker(
            type = type,
            title = title
        )
    }

    /**
     * Opens a file saver and returns the selected file location.
     */
    suspend fun saveFile(
        suggestedName: String = "file",
        extension: String = "",
        title: String? = null
    ): PlatformFile? {
        return FileKit.openFileSaver(
            suggestedName = suggestedName,
            extension = extension,
            // title parameter is not supported in openFileSaver in this version
        )
    }
}
