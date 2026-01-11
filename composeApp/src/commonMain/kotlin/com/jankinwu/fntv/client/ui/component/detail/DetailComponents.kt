package com.jankinwu.fntv.client.ui.component.detail

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.text.style.TextOverflow
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
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FluentDialog
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
    smartAnalysisStatusText: String? = null,
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
            if (genresUiState is UiState.Initial) {
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
                Separator()
            }
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
                Separator()
            }
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
        if (!smartAnalysisStatusText.isNullOrBlank()) {
            Separator()
            Text(
                "智能片头/片尾检测状态：$smartAnalysisStatusText",
                color = FluentTheme.colors.text.text.secondary,
                fontSize = 14.sp
            )
        }

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

@Composable
fun MediaDescriptionDialog(
    title: String,
    content: String,
    onDismiss: () -> Unit
) {
    FluentDialog(
        visible = true,
        size = DialogSize.Standard,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
        ) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = title,
                    style = LocalTypography.current.title,
                    color = FluentTheme.colors.text.text.primary,
                    fontSize = 20.sp,
                    fontWeight = FontWeight.SemiBold
                )
                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = "Close",
                        tint = FluentTheme.colors.text.text.primary,
                        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand)
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Content
            Box(modifier = Modifier.weight(1f, fill = false)) {
                val scrollState = rememberScrollState()
                Text(
                    text = content,
                    style = LocalTypography.current.body,
                    color = FluentTheme.colors.text.text.secondary,
                    fontSize = 15.sp,
                    lineHeight = 24.sp,
                    modifier = Modifier.verticalScroll(scrollState)
                )
            }
        }
    }
}

@Composable
fun MediaDescription(
    modifier: Modifier = Modifier,
    itemData: ItemResponse?,
    isSeason: Boolean? = false,
    onClick: (() -> Unit)? = null
) {
    val processedOverview = itemData?.overview?.replace("\n\n", "\n") ?: ""
//    var showDialog by remember { mutableStateOf(false) }
    var isOverflowing by remember { mutableStateOf(false) }
    val maxLines = if (isSeason == true) 2 else 4

    // Listen to windowWidthState change to trigger recomposition
//    val windowWidth = LocalStore.current.windowWidthState

    Box(modifier = modifier.fillMaxWidth()) {
        Text(
            text = processedOverview,
            style = LocalTypography.current.body,
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 15.sp,
            lineHeight = 20.sp,
            modifier = Modifier.fillMaxWidth(),
            maxLines = maxLines,
            overflow = TextOverflow.Clip,
            onTextLayout = { textLayoutResult ->
                isOverflowing = textLayoutResult.hasVisualOverflow
            }
        )

        if (isOverflowing) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .offset(x = 30.dp)
            ) {
                Text(
                    text = "  更多",
                    style = LocalTypography.current.body,
                    color = Colors.AccentColorDefault,
                    fontSize = 15.sp,
                    lineHeight = 20.sp,
                    modifier = Modifier
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                        ) {
//                            showDialog = true
                            onClick?.invoke()
                        }
                        .pointerHoverIcon(PointerIcon.Hand)
                )
            }
        }
    }

//    if (showDialog) {
//        MediaDescriptionDialog(
//            title = "电影简介",
//            content = processedOverview,
//            onDismiss = { showDialog = false }
//        )
//    }
}
