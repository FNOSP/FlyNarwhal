package com.jankinwu.fntv.client.utils

import androidx.compose.ui.window.FrameWindowScope
import java.io.File
import javax.swing.JFileChooser
import javax.swing.filechooser.FileNameExtensionFilter

fun chooseFile(
    scope: FrameWindowScope,
    fileExtensions: Array<String>,
    description: String
): File? {
    return scope.selectFile(fileExtensions, description)
}


fun FrameWindowScope.selectFile(
    fileExtensions: Array<String> = arrayOf("*"),
    description: String = "选择文件"
): File? {
    val fileChooser = JFileChooser().apply {
        fileFilter = FileNameExtensionFilter(description, *fileExtensions)
        isMultiSelectionEnabled = false
    }

    val result = fileChooser.showOpenDialog(this.window)
    return if (result == JFileChooser.APPROVE_OPTION) {
        fileChooser.selectedFile
    } else {
        null
    }
}
