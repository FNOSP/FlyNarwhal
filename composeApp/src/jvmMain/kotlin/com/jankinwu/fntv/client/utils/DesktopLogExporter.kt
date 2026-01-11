package com.jankinwu.fntv.client.utils

import io.github.vinceglb.filekit.path
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.awt.Desktop
import java.io.File
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.regex.Pattern

class DesktopLogExporter(private val logsDir: File) : LogExporter {
    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val timestampPattern = Pattern.compile("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}\\.\\d{3}")

    override fun getAvailableLogDates(): List<String> {
        val today = LocalDate.now()
        return (0..2).map { today.minusDays(it.toLong()).format(dateFormatter) }
    }

    override fun exportErrorLogs(
        date: String,
        onStart: () -> Unit,
        onComplete: () -> Unit,
        onError: (String) -> Unit
    ) {
        val logFile = File(logsDir, "FlyNarwhal-$date.log")
        if (!logFile.exists()) {
            onError("日志文件不存在: ${logFile.name}")
            return
        }

        CoroutineScope(Dispatchers.Main).launch {
            // Use modern FileKit-based FileUtil
            val platformFile = withContext(Dispatchers.IO) {
                FileUtil.saveFile(
                    suggestedName = "FlyNarwhal-Error-$date",
                    extension = "log"
                    // title = "选择保存位置" // Title not supported in FileKit 0.12.0 saver
                )
            }

            if (platformFile == null) return@launch

            val targetFile = File(platformFile.path)
            
            onStart()

            withContext(Dispatchers.IO) {
                try {
                    processAndExport(logFile, targetFile)
                    withContext(Dispatchers.Main) {
                        onComplete()
                        revealFile(targetFile)
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        onError("导出失败: ${e.message}")
                    }
                }
            }
        }
    }

    private fun processAndExport(source: File, target: File) {
        val lines = source.readLines()
        val entries = mutableListOf<String>()
        var currentEntry = StringBuilder()

        for (line in lines) {
            if (timestampPattern.matcher(line).find()) {
                if (currentEntry.isNotEmpty()) {
                    entries.add(currentEntry.toString())
                }
                currentEntry = StringBuilder(line)
            } else {
                currentEntry.append("\n").append(line)
            }
        }
        if (currentEntry.isNotEmpty()) {
            entries.add(currentEntry.toString())
        }

        val errorIndices = entries.indices.filter {
            val entry = entries[it]
            entry.contains("[ERROR]", ignoreCase = true) ||
                    (entry.contains("[KCEF]") && (entry.contains(":ERROR:", ignoreCase = true) || entry.contains(":FATAL:", ignoreCase = true)))
        }
        val selectedIndices = mutableSetOf<Int>()

        for (errorIdx in errorIndices) {
            val start = (errorIdx - 50).coerceAtLeast(0)
            val end = (errorIdx + 50).coerceAtMost(entries.size - 1)
            for (i in start..end) {
                selectedIndices.add(i)
            }
        }

        val sortedIndices = selectedIndices.sorted()
        target.bufferedWriter().use { writer ->
            for (idx in sortedIndices) {
                writer.write(entries[idx])
                writer.newLine()
            }
        }
    }

    private fun revealFile(file: File) {
        try {
            val os = System.getProperty("os.name").lowercase()
            when {
                os.contains("win") -> {
                    Runtime.getRuntime().exec(arrayOf("explorer.exe", "/select,", file.absolutePath))
                }
                os.contains("mac") -> {
                    Runtime.getRuntime().exec(arrayOf("open", "-R", file.absolutePath))
                }
                else -> {
                    // For Linux or others, just open the parent directory
                    if (Desktop.isDesktopSupported()) {
                        Desktop.getDesktop().open(file.parentFile)
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
