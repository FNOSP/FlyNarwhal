package com.jankinwu.fntv.client.utils

import androidx.compose.runtime.ProvidableCompositionLocal
import androidx.compose.runtime.staticCompositionLocalOf

interface LogExporter {
    /**
     * Export error logs for the given date.
     * @param date The date in "yyyy-MM-dd" format.
     */
    fun exportErrorLogs(date: String, onStart: () -> Unit, onComplete: () -> Unit, onError: (String) -> Unit)
    
    /**
     * Get available log dates (last 3 days).
     * @return List of dates in "yyyy-MM-dd" format.
     */
    fun getAvailableLogDates(): List<String>
}

val LocalLogExporter: ProvidableCompositionLocal<LogExporter> = staticCompositionLocalOf {
    error("No LogExporter provided")
}
