package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

class ToastManager {
    private val _toasts = mutableStateListOf<ToastMessage>()
    val toasts: SnapshotStateList<ToastMessage> = _toasts

    fun showToast(message: String, isSuccess: Boolean = true, duration: Long = 2000L) {
        val toast = ToastMessage(
            message = message,
            isSuccess = isSuccess,
            duration = duration
        )
        _toasts.add(toast)
    }

    fun removeToast(id: String) {
        _toasts.removeAll { it.id == id }
    }
}

@Composable
fun rememberToastManager(): ToastManager {
    return remember { ToastManager() }
}

@Composable
fun ToastHost(
    toastManager: ToastManager,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.Top),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            toastManager.toasts.forEach { toast ->
                Toast(
                    message = toast.message,
                    isSuccess = toast.isSuccess,
                    duration = toast.duration
                ) {
                    toastManager.removeToast(toast.id)
                }
            }
        }
    }
}