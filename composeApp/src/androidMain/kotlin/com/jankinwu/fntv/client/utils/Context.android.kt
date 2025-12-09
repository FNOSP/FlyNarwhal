package com.jankinwu.fntv.client.utils

import androidx.compose.runtime.ProvidableCompositionLocal

actual abstract class Context

actual val LocalContext: ProvidableCompositionLocal<Context>
    get() = TODO("Not yet implemented")
internal actual val Context.filesImpl: ContextFiles
    get() = TODO("Not yet implemented")