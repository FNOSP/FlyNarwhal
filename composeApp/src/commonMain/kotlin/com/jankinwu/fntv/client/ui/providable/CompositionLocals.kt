package com.jankinwu.fntv.client.ui.providable

import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.platform.Font
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.FrameWindowScope
import androidx.compose.ui.window.WindowState
import com.jankinwu.fntv.client.RefreshState
import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.model.response.FileInfo
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import com.jankinwu.fntv.client.data.model.response.VideoStream
import com.jankinwu.fntv.client.data.store.Store
import com.jankinwu.fntv.client.ui.component.common.ToastManager
import com.jankinwu.fntv.client.ui.screen.PlayerManager
import io.github.composefluent.Typography
import org.jetbrains.skiko.hostOs
import org.openani.mediamp.MediampPlayer

// from HomePageScreen.kt
val LocalUserInfo = staticCompositionLocalOf<UserInfoResponse> {
    error("UserInfo not provided")
}

// from PlayerScreen.kt
val LocalPlayerManager = staticCompositionLocalOf<PlayerManager> {
    error("PlayerManager not provided")
}

// from PlayerScreen.kt
val LocalMediaPlayer = staticCompositionLocalOf<MediampPlayer> {
    error("No MediaPlayer provided")
}

// from MovieDetailScreen.kt
val LocalFileInfo = staticCompositionLocalOf<FileInfo?> {
    error("No FileInfo provided")
}

data class CurrentStreamData(
    val fileInfo: FileInfo?,
    val videoStream: VideoStream?,
    val audioStreamList: List<AudioStream>,
    val subtitleStreamList: List<SubtitleStream>
)

data class IsoTagData(
    val iso6391Map: Map<String, QueryTagResponse>,
    val iso6392Map: Map<String, QueryTagResponse>,
    val iso3166Map: Map<String, QueryTagResponse>
)
// from MovieDetailScreen.kt
val LocalIsoTagData = staticCompositionLocalOf<IsoTagData> {
    error("No IsoTagData provided")
}

// from MovieDetailScreen.kt
val LocalToastManager = staticCompositionLocalOf<ToastManager> {
    error("No ToastManager provided")
}

val defaultVariableFamily = FontFamily(
    if (hostOs.isWindows) {
        Font("Microsoft YaHei")
    } else if (hostOs.isMacOS) {
        Font("PingFang SC")
    } else {
        Font("font/SourceHanSansSC-VF.otf")
    }
)

// from AppTheme.kt
internal val LocalTypography = staticCompositionLocalOf {
    Typography(
        caption = TextStyle(
            fontWeight = FontWeight.Normal,
            fontSize = 12.sp, lineHeight = 16.sp,
            fontFamily = defaultVariableFamily
        ),
        body = TextStyle(
            fontWeight = FontWeight.Normal,
            fontSize = 14.sp, lineHeight = 20.sp,
            fontFamily = defaultVariableFamily
        ),
        bodyStrong = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp, lineHeight = 20.sp,
            fontFamily = defaultVariableFamily
        ),
        bodyLarge = TextStyle(
            fontWeight = FontWeight.Normal,
            fontSize = 18.sp, lineHeight = 24.sp,
            fontFamily = defaultVariableFamily
        ),
        subtitle = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 20.sp, lineHeight = 28.sp,
            fontFamily = defaultVariableFamily
        ),
        title = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 28.sp, lineHeight = 36.sp,
            fontFamily = defaultVariableFamily
        ),
        titleLarge = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 40.sp, lineHeight = 52.sp,
            fontFamily = defaultVariableFamily
        ),
        display = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 68.sp, lineHeight = 92.sp,
            fontFamily = defaultVariableFamily
        )
    )
}

// from AppTheme.kt
val LocalFrameWindowScope = staticCompositionLocalOf<FrameWindowScope> {
    error("FrameWindowScope not provided")
}

// from App.kt
val LocalRefreshState = staticCompositionLocalOf<RefreshState> {
    error("RefreshState not provided")
}

val LocalWindowState = compositionLocalOf<WindowState> { error("WindowState not provided") }

val LocalWindowHandle = compositionLocalOf<Long?> { null }

val LocalStore = compositionLocalOf<Store> { error("Not provided") }
