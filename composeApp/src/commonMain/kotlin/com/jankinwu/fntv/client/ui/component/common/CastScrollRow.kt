package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.LocalTypography
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import io.github.composefluent.FluentTheme

@Composable
fun CastScrollRow(
    modifier: Modifier = Modifier,
    scrollRowItemList: List<ScrollRowItemData> = emptyList(),
) {
    if (scrollRowItemList.isNotEmpty()) {
        Column(
            modifier = modifier
                .height(140.dp),
            verticalArrangement = Arrangement.SpaceBetween
        ) {
            // 媒体库标题行
            Row(
                modifier = Modifier
                    .padding(start = 32.dp, bottom = 12.dp)
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null,
                        onClick = {
                            // 在组件内部实现导航逻辑
//                        val targetComponent = components
//                            .firstOrNull { it.name == "媒体库" }
//                            ?.items
//                            ?.firstOrNull { it.guid == guid }

//                        targetComponent?.let {
//                            navigator.navigate(it)
//                        }
                        }
                    )
                    .pointerHoverIcon(PointerIcon.Hand),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "演职人员",
                    style = LocalTypography.current.title.copy(
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold
                    ),
                    color = FluentTheme.colors.text.text.primary
                )
            }

            ScrollRow(scrollRowItemList) { _, movie, modifier, _ ->
                CastAvatar(
                    modifier = modifier,
                    imageUrl = movie.posterImg,
                    castName = movie.title,
                    role = movie.subtitle
                )
            }
        }
    }
}