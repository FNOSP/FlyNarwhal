package com.jankinwu.fntv.client.utils

// Best-effort IME toggle used by password fields on desktop.
internal expect fun setWindowImeDisabled(windowHandle: Long, disabled: Boolean)
