package com.jankinwu.fntv.client.ui.component.detail

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.model.response.ItemResponse
import com.jankinwu.fntv.client.ui.providable.LocalIsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.ui.screen.Separator
import com.jankinwu.fntv.client.viewmodel.GenresViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import io.github.composefluent.FluentTheme
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun DetailPlayButton(
    text: String = "",
    playMedia: () -> Unit
) {
    Button(
        onClick = {
            playMedia()
        },
        colors = ButtonDefaults.buttonColors(containerColor = Colors.AccentColorDefault), // 蓝色背景
        shape = CircleShape, // 圆角
        modifier = Modifier
            .height(56.dp)
            .widthIn(min = 160.dp)
//            .width(160.dp)
            .pointerHoverIcon(PointerIcon.Hand)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)
        ) {
            Text(
                "▶",
                style = LocalTypography.current.title,
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text,
                style = LocalTypography.current.title,
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold
            )
        }
    }
}

@Composable
fun DetailTags(
    itemData: ItemResponse,
    formatedTotalDuration: String? = "",
) {
    val isoTagData = LocalIsoTagData.current
    FlowRow(
        modifier = Modifier, // 占据右侧约 60% 宽度
        horizontalArrangement = Arrangement.spacedBy(
            8.dp,
            Alignment.End
        ),
        verticalArrangement = Arrangement.Center
    ) {
        val voteAverage = itemData.voteAverage.toDoubleOrNull()?.let {
            "%.1f".format(it)
        } ?: ""
        if (voteAverage.isNotEmpty() && voteAverage != "0.0") {
            Text(
                "$voteAverage 分",
                color = Color(0xFFFACC15),
                fontWeight = FontWeight.Normal,
                fontSize = 14.sp,
//                        modifier = Modifier.offset(y = (-3).dp)
            )
            Separator()
        }
        val contentRatings = itemData.contentRatings ?: ""
        if (contentRatings.isNotEmpty()) {
            Text(
                contentRatings,
                color = FluentTheme.colors.text.text.secondary,
                fontSize = 14.sp
            )
            Separator()
        }
        val year = itemData.airDate?.take(4) ?: ""
        if (year.isNotEmpty()) {
            Text(
                year,
                color = FluentTheme.colors.text.text.secondary,
                fontSize = 14.sp
            )
            Separator()
        }
        val genresViewModel: GenresViewModel = koinViewModel<GenresViewModel>()
        val genresUiState = genresViewModel.uiState.collectAsState().value
        LaunchedEffect(genresUiState) {
            if (genresUiState !is UiState.Success) {
                genresViewModel.loadGenres()
            }
        }
        if (genresUiState is UiState.Success) {
            val genresMap = genresUiState.data.associateBy { it.id }
            val genresText = itemData.genres?.joinToString(" ") { genreId ->
                genresMap[genreId]?.value ?: ""
            }
            if (!genresText.isNullOrBlank()) {
                Text(
                    genresText,
                    color = FluentTheme.colors.text.text.secondary,
                    fontSize = 14.sp
                )
            }
            Separator()
        }
        if (isoTagData.iso3166Map.isNotEmpty()) {
            val countriesText = itemData.productionCountries?.joinToString(" ") { locate ->
                isoTagData.iso3166Map[locate]?.value ?: locate
            }
            if (!countriesText.isNullOrBlank()) {
                Text(
                    countriesText,
                    color = FluentTheme.colors.text.text.secondary,
                    fontSize = 14.sp
                )
            }
            Separator()
        }
        if (!formatedTotalDuration.isNullOrBlank()) {
            Text(
                formatedTotalDuration,
                color = FluentTheme.colors.text.text.secondary,
                fontSize = 14.sp
            )
            Separator()
        }
        Text(
            itemData.ancestorName,
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 14.sp
        )

    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun ImdbLink(
    imdbLink: String,
    modifier: Modifier = Modifier
) {
    val uriHandler = LocalUriHandler.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
    ) {
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "链接:  ",
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 14.sp
        )
        var isImdbHovered by remember { mutableStateOf(false) }
        Text(
            text = "IMDB链接",
            color = FluentTheme.colors.text.text.primary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            modifier = Modifier
                .onPointerEvent(PointerEventType.Enter) { isImdbHovered = true }
                .onPointerEvent(PointerEventType.Exit) { isImdbHovered = false }
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null
                ) {
                    uriHandler.openUri(imdbLink)
                }
                .pointerHoverIcon(PointerIcon.Hand),
            style = if (isImdbHovered) {
                TextStyle(textDecoration = TextDecoration.Underline) // 悬停时添加下划线
            } else {
                LocalTextStyle.current
            }
        )
    }
}