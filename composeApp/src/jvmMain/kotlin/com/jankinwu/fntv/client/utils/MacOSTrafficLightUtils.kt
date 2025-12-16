package com.jankinwu.fntv.client.utils

import com.sun.jna.Library
import com.sun.jna.Native
import com.sun.jna.Pointer
import java.awt.Window

object MacOSTrafficLightUtils {
    private interface ObjC : Library {
        fun objc_getClass(className: String): Pointer
        fun sel_registerName(name: String): Pointer
        fun objc_msgSend(receiver: Pointer, selector: Pointer, arg1: Long): Pointer
        fun objc_msgSend(receiver: Pointer, selector: Pointer, arg1: Boolean)
    }

    private val libObjC: ObjC? = try {
        Native.load("objc", ObjC::class.java)
    } catch (e: Throwable) {
        null
    }

    private val selStandardWindowButton by lazy { libObjC?.sel_registerName("standardWindowButton:") }
    private val selSetHidden by lazy { libObjC?.sel_registerName("setHidden:") }

    // Button types (NSWindowButton)
    private const val NSWindowCloseButton = 0L
    private const val NSWindowMiniaturizeButton = 1L
    private const val NSWindowZoomButton = 2L

    fun setTrafficLightButtonsVisible(window: Window, visible: Boolean) {
        val objc = libObjC ?: return
        val setHidden = selSetHidden ?: return
        val standardWindowButton = selStandardWindowButton ?: return

        try {
            val nsWindowPtr = Native.getWindowPointer(window)
            if (nsWindowPtr == null) return

            val buttons = listOf(NSWindowCloseButton, NSWindowMiniaturizeButton, NSWindowZoomButton)
            for (btnType in buttons) {
                val buttonPtr = objc.objc_msgSend(nsWindowPtr, standardWindowButton, btnType)
                if (buttonPtr != Pointer.NULL) {
                    objc.objc_msgSend(buttonPtr, setHidden, !visible)
                }
            }
        } catch (e: Throwable) {
            // Ignore errors to prevent crashes on non-macOS or if something goes wrong
            e.printStackTrace()
        }
    }
}
