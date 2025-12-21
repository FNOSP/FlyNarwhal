package com.jankinwu.fntv.client.utils

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.platform.win32.WinDef.HWND
import com.sun.jna.win32.W32APIOptions
import org.jetbrains.skiko.hostOs
import java.awt.im.InputContext
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap

internal actual fun setWindowImeDisabled(windowHandle: Long, disabled: Boolean) {
    when {
        hostOs.isWindows -> setWindowsImeDisabled(windowHandle, disabled)
        hostOs.isMacOS -> setMacOsImeDisabled(windowHandle, disabled)
        hostOs.isLinux -> setLinuxImeDisabled(windowHandle, disabled)
    }
}

// Windows: detach and restore IME context for the window (prevents IME composition in password fields).
private fun setWindowsImeDisabled(windowHandle: Long, disabled: Boolean) {
    val imm32 = Imm32Extend.instance ?: return
    val hwnd = HWND(Pointer(windowHandle))
    if (disabled) {
        val previous = imm32.ImmAssociateContext(hwnd, Pointer.NULL) ?: Pointer.NULL
        savedImeContextByHwnd.putIfAbsent(windowHandle, previous)
    } else {
        val previous = savedImeContextByHwnd.remove(windowHandle) ?: return
        imm32.ImmAssociateContext(hwnd, previous)
    }
}

// macOS: best-effort switch input method to an English locale while focused.
private fun setMacOsImeDisabled(windowHandle: Long, disabled: Boolean) {
    if (disabled) {
        val inputContext = InputContext.getInstance()
        savedInputLocaleByToken.putIfAbsent(windowHandle, inputContext.locale)
        inputContext.endComposition()
        inputContext.selectInputMethod(Locale.ENGLISH)
    } else {
        val previous = savedInputLocaleByToken.remove(windowHandle) ?: return
        InputContext.getInstance().selectInputMethod(previous)
    }
}

// Linux: best-effort support for ibus/fcitx; fallback to AWT InputContext locale selection.
private fun setLinuxImeDisabled(windowHandle: Long, disabled: Boolean) {
    if (disabled) {
        if (savedLinuxImeStateByToken.containsKey(windowHandle)) return
        val ibusEngine = runProcessForOutput(listOf("ibus", "engine"))
        if (!ibusEngine.isNullOrBlank()) {
            savedLinuxImeStateByToken[windowHandle] = LinuxImeRestoreState.Ibus(ibusEngine.trim())
            runProcessForOutput(listOf("ibus", "engine", "xkb:us::eng"))
            InputContext.getInstance().endComposition()
            InputContext.getInstance().selectInputMethod(Locale.ENGLISH)
            return
        }

        val fcitxState = runProcessForOutput(listOf("fcitx5-remote"))
            ?: runProcessForOutput(listOf("fcitx-remote"))
        val isActive = fcitxState?.trim() == "1"
        if (fcitxState != null && fcitxState.trim() != "2") {
            savedLinuxImeStateByToken[windowHandle] = LinuxImeRestoreState.Fcitx(wasActive = isActive)
            if (isActive) {
                runProcessForOutput(listOf("fcitx5-remote", "-c"))
                runProcessForOutput(listOf("fcitx-remote", "-c"))
            }
            InputContext.getInstance().endComposition()
            InputContext.getInstance().selectInputMethod(Locale.ENGLISH)
            return
        }

        savedLinuxImeStateByToken[windowHandle] = LinuxImeRestoreState.InputContext(InputContext.getInstance().locale)
        InputContext.getInstance().endComposition()
        InputContext.getInstance().selectInputMethod(Locale.ENGLISH)
    } else {
        when (val restore = savedLinuxImeStateByToken.remove(windowHandle) ?: return) {
            is LinuxImeRestoreState.Ibus -> runProcessForOutput(listOf("ibus", "engine", restore.previousEngine))
            is LinuxImeRestoreState.Fcitx -> if (restore.wasActive) {
                runProcessForOutput(listOf("fcitx5-remote", "-o"))
                runProcessForOutput(listOf("fcitx-remote", "-o"))
            }
            is LinuxImeRestoreState.InputContext -> InputContext.getInstance().selectInputMethod(restore.previousLocale)
            LinuxImeRestoreState.None -> Unit
        }
    }
}

private fun runProcessForOutput(command: List<String>): String? {
    return runCatching {
        val process = ProcessBuilder(command)
            .redirectErrorStream(true)
            .start()
        BufferedReader(InputStreamReader(process.inputStream)).use { it.readText() }.also { process.waitFor() }
    }.getOrNull()
}

private val savedImeContextByHwnd = ConcurrentHashMap<Long, Pointer>()
private val savedInputLocaleByToken = ConcurrentHashMap<Long, Locale?>()
private val savedLinuxImeStateByToken = ConcurrentHashMap<Long, LinuxImeRestoreState>()

private sealed interface LinuxImeRestoreState {
    data object None : LinuxImeRestoreState
    data class Ibus(val previousEngine: String) : LinuxImeRestoreState
    data class Fcitx(val wasActive: Boolean) : LinuxImeRestoreState
    data class InputContext(val previousLocale: Locale?) : LinuxImeRestoreState
}

@Suppress("FunctionName")
private interface Imm32Extend : Library {
    fun ImmAssociateContext(hWnd: HWND, hIMC: Pointer?): Pointer?

    companion object {
        val instance: Imm32Extend? by lazy {
            runCatching {
                Native.load(
                    "imm32",
                    Imm32Extend::class.java,
                    W32APIOptions.DEFAULT_OPTIONS
                )
            }.getOrNull()
        }
    }
}
