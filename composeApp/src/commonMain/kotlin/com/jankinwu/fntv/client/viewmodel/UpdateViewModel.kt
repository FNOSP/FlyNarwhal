package com.jankinwu.fntv.client.viewmodel

import androidx.lifecycle.viewModelScope
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.manager.UpdateInfo
import com.jankinwu.fntv.client.manager.UpdateManager
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import org.koin.java.KoinJavaComponent.inject
import kotlin.time.ExperimentalTime

class UpdateViewModel : BaseViewModel() {
    private val updateManager: UpdateManager by inject(UpdateManager::class.java)
    val status = updateManager.status
    val latestVersion = updateManager.latestVersion
    private val logger = Logger.withTag("UpdateViewModel")

    private var lastCheckTime = 0L
    private var scheduledCheckJob: Job? = null
    private val checkInterval = 5 * 60 * 1000L // 5 minutes (for prerelease toggle)
    private val periodicCheckInterval = 4 * 60 * 60 * 1000L // 4 hours

    init {
        startPeriodicCheck()
    }

    private fun startPeriodicCheck() {
        viewModelScope.launch {
            while (true) {
                // Check every 4 hours
                delay(periodicCheckInterval)
                
                // If not checked today, trigger an automatic check
                if (!isCheckedToday()) {
                    checkUpdate(isManual = false)
                }
            }
        }
    }

    @OptIn(ExperimentalTime::class)
    private fun isCheckedToday(): Boolean {
        logger.i("Checking if checked today...")
        val lastCheck = AppSettingsStore.lastUpdateCheckTime
        if (lastCheck == 0L) return false

        val currentInstant = kotlin.time.Clock.System.now()
        val lastCheckInstant = kotlin.time.Instant.fromEpochMilliseconds(lastCheck)
        
        val timeZone = TimeZone.currentSystemDefault()
        val currentDateTime = currentInstant.toLocalDateTime(timeZone)
        val lastCheckDateTime = lastCheckInstant.toLocalDateTime(timeZone)

        return currentDateTime.date == lastCheckDateTime.date
    }

    @OptIn(ExperimentalTime::class)
    fun checkUpdate(isManual: Boolean = true) {
        logger.i("Checking for updates...")
        val currentTime = kotlin.time.Clock.System.now().toEpochMilliseconds()
        lastCheckTime = currentTime
        AppSettingsStore.lastUpdateCheckTime = currentTime
        
        val proxyUrl = AppSettingsStore.githubResourceProxyUrl
        val includePrerelease = AppSettingsStore.includePrerelease
        val autoDownload = AppSettingsStore.autoDownloadUpdates
        updateManager.checkUpdate(proxyUrl, includePrerelease, isManual, autoDownload)
    }

    @OptIn(ExperimentalTime::class)
    fun onIncludePrereleaseChanged() {
        val currentTime = kotlin.time.Clock.System.now().toEpochMilliseconds()
        if (currentTime - lastCheckTime >= checkInterval) {
            // No restriction, check immediately
            checkUpdate(isManual = false)
            scheduledCheckJob?.cancel()
        } else {
            // Restricted, schedule a check if not already scheduled
            if (scheduledCheckJob?.isActive != true) {
                val delayTime = checkInterval - (currentTime - lastCheckTime)
                scheduledCheckJob = viewModelScope.launch {
                    delay(delayTime)
                    // Double check if we still need to run (in case a manual check happened)
                    if (kotlin.time.Clock.System.now().toEpochMilliseconds() - lastCheckTime >= checkInterval) {
                        checkUpdate(isManual = false)
                    }
                }
            }
        }
    }

    fun downloadUpdate(info: UpdateInfo) {
        val proxyUrl = AppSettingsStore.githubResourceProxyUrl
        updateManager.downloadUpdate(proxyUrl, info)
    }
    
    fun installUpdate(info: UpdateInfo) {
        updateManager.installUpdate(info)
    }

    fun cancelDownload() {
        updateManager.cancelDownload()
    }
    
    fun clearStatus() {
        updateManager.clearStatus()
    }
}
