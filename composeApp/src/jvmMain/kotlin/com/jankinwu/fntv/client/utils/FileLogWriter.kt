package com.jankinwu.fntv.client.utils

import co.touchlab.kermit.LogWriter
import co.touchlab.kermit.Severity
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.io.PrintWriter
import java.nio.charset.StandardCharsets
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit

class FileLogWriter(private val logDir: File) : LogWriter() {
    private val logFile: File
    private val writer: PrintWriter
    private val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    private val timeFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS")
    private var currentLogDate: String = ""

    init {
        if (!logDir.exists()) {
            logDir.mkdirs()
        }
        
        cleanOldLogs()

        currentLogDate = LocalDateTime.now().format(dateFormatter)
        logFile = File(logDir, "fntv-client-$currentLogDate.log")
        writer = PrintWriter(OutputStreamWriter(FileOutputStream(logFile, true), StandardCharsets.UTF_8), true)
    }

    private fun cleanOldLogs() {
        try {
            val files = logDir.listFiles { _, name ->
                name.startsWith("fntv-client-") && name.endsWith(".log")
            } ?: return

            val today = LocalDate.now()
            val retentionDays = 3L

            files.forEach { file ->
                val datePart = file.name.removePrefix("fntv-client-").removeSuffix(".log")
                try {
                    val fileDate = LocalDate.parse(datePart, dateFormatter)
                    val daysBetween = ChronoUnit.DAYS.between(fileDate, today)
                    
                    if (daysBetween >= retentionDays) {
                        file.delete()
                    }
                } catch (_: DateTimeParseException) {
                    // Ignore files with invalid date format
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun log(severity: Severity, message: String, tag: String, throwable: Throwable?) {
        synchronized(this) {
            // Check if date changed, though for simplicity we might skip rotation logic for now 
            // or just append to the file created at start. 
            // Implementing proper rotation requires checking date on every log or using a timer.
            // For now, let's stick to the file created at initialization.
            
            val timestamp = LocalDateTime.now().format(timeFormatter)
            val logMessage = "$timestamp [${severity.name}] [$tag] $message"
            writer.println(logMessage)
            throwable?.printStackTrace(writer)
            writer.flush()
        }
    }
    
    fun close() {
        writer.close()
    }
}
