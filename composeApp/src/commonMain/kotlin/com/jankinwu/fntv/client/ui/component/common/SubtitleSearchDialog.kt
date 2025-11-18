package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.viewmodel.SubtitleSearchViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FluentDialog
import io.github.composefluent.component.FlyoutPlacement
import io.github.composefluent.component.Icon
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.Text
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Dismiss
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun SubtitleSearchDialog(
    title: String,
    visible: Boolean,
    size: DialogSize = DialogSize.Max,
    mediaGuid: String,
    onDismissRequest: () -> Unit = {}
) {
    var language by remember { mutableStateOf("zh-CN") }
    val subtitleSearchViewModel: SubtitleSearchViewModel = koinViewModel()
    val subtitleSearchState by subtitleSearchViewModel.uiState.collectAsState()
    LaunchedEffect(language) {
        subtitleSearchViewModel.searchSubtitles(language, mediaGuid)
    }

    FluentDialog(visible, size) {
        Column {
            Column(
                Modifier
                    .fillMaxWidth()
//                    .background(FluentTheme.colors.background.layer.alt)
                    .padding(24.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        style = FluentTheme.typography.subtitle,
                        text = title,
                    )
                    Icon(
                        imageVector = Icons.Regular.Dismiss,
                        contentDescription = "",
                        tint = FluentTheme.colors.text.text.primary,
                        modifier = Modifier
                            .clickable(
                                onClick = {
                                    onDismissRequest()
                                }
                            )
                            .size(16.dp)
                    )
                }
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(
                        style = LocalTypography.current.subtitle,
                        text = "",
                    )
                    LanguageSwitchFlyout(onLanguageSelected = { language = it })
                }
                Text(
                    style = LocalTypography.current.body,
                    text = "按相关度排序：",
                )
            }
        }
    }
}

@Composable
private fun LanguageSwitchFlyout(
    onLanguageSelected: (String) -> Unit,
) {
    var buttonName by remember { mutableStateOf("中文") }
    MenuFlyoutContainer(
        flyout = {
            languageList.forEach { language ->
                MenuFlyoutItem(
                    text = {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = language.name,
                                color = FluentTheme.colors.text.text.secondary,
                                fontWeight = FontWeight.Normal,
                                fontSize = 14.sp,
                                modifier = Modifier
                                    .width(120.dp)
                            )
                        }
                    },
                    onClick = {
                        isFlyoutVisible = false
                        buttonName = language.buttonName
                        onLanguageSelected(language.code)
                    },
                    modifier = Modifier
                        .pointerHoverIcon(PointerIcon.Hand)
                )
            }
        },
        content = {
            FlyoutButton(
                isSelected = isFlyoutVisible,
                onClick = {
                    isFlyoutVisible = !isFlyoutVisible
                },
                buttonText = buttonName,
            )
        },
        placement = FlyoutPlacement.BottomAlignedEnd,
        modifier = Modifier.offset(x = 16.dp)
    )
}

private data class Language(
    val name: String,
    val code: String,
    val buttonName: String
)

private val languageList = listOf(
    Language("简体中文", "zh-CN", "中文"),
    Language("英文", "en", "英文")
)