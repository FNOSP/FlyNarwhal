package com.jankinwu.fntv.client.manager

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import co.touchlab.kermit.Logger
import fntv_client_multiplatform.composeapp.generated.resources.Res
import io.github.alexzhirkevich.compottie.LottieCompositionSpec
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

object PlayerResourceManager {
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    var fullScreenSpec by mutableStateOf<LottieCompositionSpec?>(null)
        private set
    var quitFullScreenSpec by mutableStateOf<LottieCompositionSpec?>(null)
        private set
    var volumeHighSpec by mutableStateOf<LottieCompositionSpec?>(null)
        private set
    var volumeLowSpec by mutableStateOf<LottieCompositionSpec?>(null)
        private set
    var volumeOffSpec by mutableStateOf<LottieCompositionSpec?>(null)
        private set
    var settingsSpec by mutableStateOf<LottieCompositionSpec?>(null)
        private set

    fun preload() {
        if (fullScreenSpec != null) return // Already loaded or loading

        scope.launch {
            try {
                // Load concurrently if possible, but sequential is fine for now as it's just reading bytes
                fullScreenSpec = loadLottie("files/full_screen_lottie.json")
                quitFullScreenSpec = loadLottie("files/quit_full_screen_lottie.json")
                volumeHighSpec = loadLottie("files/volume_high_lottie.json")
                volumeLowSpec = loadLottie("files/volume_low_lottie.json")
                volumeOffSpec = loadLottie("files/volume_off_lottie.json")
                settingsSpec = loadLottie("files/settings_lottie.json")
                Logger.i("Player resources preloaded successfully")
            } catch (e: Exception) {
                Logger.e("Failed to preload player resources", e)
            }
        }
    }

    private suspend fun loadLottie(path: String): LottieCompositionSpec {
        val bytes = Res.readBytes(path)
        return LottieCompositionSpec.JsonString(bytes.decodeToString())
    }
}
