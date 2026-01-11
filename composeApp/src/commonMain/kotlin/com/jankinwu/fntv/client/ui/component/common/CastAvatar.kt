package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.person_placeholder
import io.github.composefluent.FluentTheme

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun CastAvatar(
    modifier: Modifier = Modifier,
    imageUrl: String? = null,
    onClick: () -> Unit = {},
    castName: String = "",
    role: String? = "",
) {
    val store = LocalStore.current
    var isPosterHovered by remember { mutableStateOf(false) }
    val interactionSource = remember { MutableInteractionSource() }
    Column(
        modifier = modifier
            .width(80.dp)
            .onPointerEvent(PointerEventType.Enter) { isPosterHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isPosterHovered = false }
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = {
                    /* TODO: Handle click event */
                }
            )
            .pointerHoverIcon(PointerIcon.Hand),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Top
    ) {
        Box(
            modifier = Modifier
                .size(64.dp)
                .aspectRatio(1f)
                .border(1.dp, Color.Gray.copy(alpha = 0.5f), CircleShape)
                .clip(CircleShape)
        ) {
            if (imageUrl != null) {
                SubcomposeAsyncImage(
                    model = ImageRequest.Builder(PlatformContext.INSTANCE)
                        .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img$imageUrl${Constants.FN_IMG_URL_PARAM}")
                        .httpHeaders(store.fnImgHeaders)
                        .crossfade(true)
                        .build(),
                    contentDescription = "",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop,
                    loading = {
                        ImgLoadingProgressRing()
                    },
                    error = {
                        ImgLoadingError(resource = Res.drawable.person_placeholder, fraction = 0.7f)
                    },
                )
            } else {
                ImgNotMapped()
            }
            // 半透明遮罩层
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color(0xFF1C1C1C).copy(alpha = if (isPosterHovered) 0.5f else 0f))
                    .alpha(if (isPosterHovered) 1f else 0f)
            )
        }
        // 图片下方的间距
        Spacer(Modifier.height(8.dp))
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth()
        ) {
            // 电影标题
            Text(
                text = castName,
                style = LocalTypography.current.caption,
                fontWeight = FontWeight.Normal,
                fontSize = 12.sp,
                textAlign = TextAlign.Center,
                color = if (isPosterHovered) Color(0xFF2073DF) else FluentTheme.colors.text.text.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(4.dp))
            // 副标题/描述
            role?.let {
                Text(
                    text = it,
                    style = LocalTypography.current.subtitle,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center,
                    color = FluentTheme.colors.text.text.tertiary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.fillMaxWidth()
                )
            }
        }
    }
}