package com.jankinwu.fntv.client.viewmodel

import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.manager.UpdateInfo
import com.jankinwu.fntv.client.manager.UpdateManager
import org.koin.java.KoinJavaComponent.inject

class UpdateViewModel : BaseViewModel() {
    private val updateManager: UpdateManager by inject(UpdateManager::class.java)
    val status = updateManager.status
    val latestVersion = updateManager.latestVersion

    fun checkUpdate() {
        val proxyUrl = AppSettingsStore.githubResourceProxyUrl
        updateManager.checkUpdate(proxyUrl)
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
