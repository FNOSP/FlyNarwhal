/*
 * Copyright (C) 2024-2025 OpenAni and contributors.
 *
 * 此源代码的使用受 GNU AFFERO GENERAL PUBLIC LICENSE version 3 许可证的约束, 可以在以下链接找到该许可证.
 * Use of this source code is governed by the GNU AGPLv3 license, which can be found at the following link.
 *
 * https://github.com/open-ani/ani/blob/main/LICENSE
 */
/*
 * Copyright (C) 2025 FNOSP and contributors.
 *
 * This file has been modified from its original version.
 * The modifications are also licensed under the AGPLv3.
 */

@file:Suppress("NOTHING_TO_INLINE", "KotlinRedundantDiagnosticSuppress")

package com.jankinwu.fntv.client.utils

import androidx.compose.runtime.ProvidableCompositionLocal

expect val LocalContext: ProvidableCompositionLocal<Context>

expect abstract class Context

typealias ContextMP = Context // compose bug, use this in common

val Context.files: ContextFiles get() = filesImpl
internal expect val Context.filesImpl: ContextFiles

interface ContextFiles {
    val cacheDir: SystemPath

    /**
     * filesDir on Android.
     */
    val dataDir: SystemPath

    /**
     * Base directory of media cache downloads.
     *
     * * Android: external private storage or internal private if external is unavailable.
     * * Desktop: [dataDir]`/media-downloads` by default, can be changed by settings.
     * * iOS: [dataDir]
     */
    val defaultBaseMediaCacheDir: SystemPath
}
