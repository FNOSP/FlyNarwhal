package com.jankinwu.fntv.client.utils

import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.currentPlatform
import com.jankinwu.fntv.client.isMacOS
import com.jankinwu.fntv.client.isWindows
import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import com.sun.jna.platform.win32.Kernel32
import com.sun.jna.ptr.IntByReference

internal object WindowsDisplaySleepBlocker {
    private const val ES_SYSTEM_REQUIRED = 0x00000001
    private const val ES_DISPLAY_REQUIRED = 0x00000002
    private const val ES_CONTINUOUS = 0x80000000.toInt()

    private val logger = Logger.withTag("WindowsDisplaySleepBlocker")

    fun setEnabled(enabled: Boolean) {
        if (!currentPlatform().isWindows()) return
        try {
            val flags = if (enabled) {
                ES_CONTINUOUS or ES_SYSTEM_REQUIRED or ES_DISPLAY_REQUIRED
            } else {
                ES_CONTINUOUS
            }
            val previous = Kernel32.INSTANCE.SetThreadExecutionState(flags)
            if (previous == 0) {
                logger.w { "SetThreadExecutionState returned 0 (failed), enabled=$enabled" }
            }
        } catch (t: Throwable) {
            logger.w(t) { "Failed to set execution state, enabled=$enabled" }
        }
    }
}

internal object MacDisplaySleepBlocker {
    private const val IOPM_ASSERTION_LEVEL_ON = 255
    private const val K_IO_PM_ASSERTION_SUCCESS = 0

    private val logger = Logger.withTag("MacDisplaySleepBlocker")

    private interface IOKit : Library {
        fun IOPMAssertionCreateWithName(
            assertionType: Pointer,
            assertionLevel: Int,
            assertionName: Pointer,
            assertionID: IntByReference
        ): Int

        fun IOPMAssertionRelease(assertionID: Int): Int
    }

    private interface ObjC : Library {
        fun objc_getClass(className: String): Pointer
        fun sel_registerName(name: String): Pointer
        fun objc_msgSend(receiver: Pointer, selector: Pointer, arg1: String): Pointer
    }

    private val ioKit: IOKit = Native.load("IOKit", IOKit::class.java)
    private val objC: ObjC = Native.load("objc", ObjC::class.java)
    private var assertionId: Int? = null

    fun setEnabled(enabled: Boolean) {
        if (!currentPlatform().isMacOS()) return
        if (enabled) {
            if (assertionId != null) return
            val assertionIdRef = IntByReference()
            try {
                val nsStringClass = objC.objc_getClass("NSString")
                val stringWithUtf8 = objC.sel_registerName("stringWithUTF8String:")
                val assertionType = objC.objc_msgSend(
                    nsStringClass,
                    stringWithUtf8,
                    "PreventUserIdleDisplaySleep"
                )
                val assertionName = objC.objc_msgSend(
                    nsStringClass,
                    stringWithUtf8,
                    "FlyNarwhal Playback"
                )
                val result = ioKit.IOPMAssertionCreateWithName(
                    assertionType,
                    IOPM_ASSERTION_LEVEL_ON,
                    assertionName,
                    assertionIdRef
                )
                if (result == K_IO_PM_ASSERTION_SUCCESS) {
                    assertionId = assertionIdRef.value
                } else {
                    logger.w { "IOPMAssertionCreateWithName failed, result=$result" }
                }
            } catch (t: Throwable) {
                logger.w(t) { "Failed to create IOPM assertion" }
            }
        } else {
            val id = assertionId ?: return
            assertionId = null
            try {
                val result = ioKit.IOPMAssertionRelease(id)
                if (result != K_IO_PM_ASSERTION_SUCCESS) {
                    logger.w { "IOPMAssertionRelease failed, result=$result" }
                }
            } catch (t: Throwable) {
                logger.w(t) { "Failed to release IOPM assertion" }
            }
        }
    }
}
