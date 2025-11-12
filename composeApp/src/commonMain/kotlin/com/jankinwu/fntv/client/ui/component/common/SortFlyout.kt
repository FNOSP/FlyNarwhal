package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Arrangement.spacedBy
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.icons.ArrowUp
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.FlyoutPlacement
import io.github.composefluent.component.Icon
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.MenuFlyoutSeparator
import io.github.composefluent.component.Text
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark

data class SortItem(
    val label: String,
    val value: String
)

@Composable
fun SortFlyout(
    onSortTypeSelected: (String) -> Unit = {},
    onSortOrderSelected: (String) -> Unit = {},
) {
    val sortTypeList: List<SortItem> = listOf(
        SortItem("标题", "sort_title"),
        SortItem("评分", "vote_average"),
        SortItem("发行年份", "release_date"),
        SortItem("添加日期", "create_time")
    )
    val sortOrder: List<SortItem> = listOf(
        SortItem("升序", "ASC"),
        SortItem("降序", "DESC")
    )
    var selectedSortType by remember { mutableStateOf(sortTypeList[3]) }
    var selectedSortOrder by remember { mutableStateOf(sortOrder[1]) }
    MenuFlyoutContainer(
        flyout = {
            sortTypeList.forEach { sortItem ->
                MenuFlyoutItem(
                    text = {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = sortItem.label,
                                color = if (sortItem == selectedSortType) FluentTheme.colors.text.text.primary else FluentTheme.colors.text.text.secondary,
                                fontWeight = FontWeight.Normal,
                                fontSize = 14.sp,
                                modifier = Modifier
                                    .width(120.dp)
                            )
                            if (sortItem == selectedSortType) {
                                Icon(
                                    imageVector = Icons.Regular.Checkmark,
                                    contentDescription = "",
                                    tint = FluentTheme.colors.text.text.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    },
                    onClick = {
                        selectedSortType = sortItem
                        isFlyoutVisible = false
                        onSortTypeSelected(sortItem.value)
                    }
                )
            }
            MenuFlyoutSeparator(modifier = Modifier.padding(horizontal = 1.dp))
            sortOrder.forEach { sortItem ->
                MenuFlyoutItem(
                    text = {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = sortItem.label,
                                color = if (sortItem == selectedSortOrder) FluentTheme.colors.text.text.primary else FluentTheme.colors.text.text.secondary,
                                fontWeight = FontWeight.Normal,
                                fontSize = 14.sp
                            )
                            if (sortItem == selectedSortOrder) {
                                Icon(
                                    imageVector = Icons.Regular.Checkmark,
                                    contentDescription = "",
                                    tint = FluentTheme.colors.text.text.primary,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    },
                    onClick = {
                        selectedSortOrder = sortItem
                        isFlyoutVisible = false
                        onSortOrderSelected(sortItem.value)
                    }
                )
            }
        },
        content = {
            SortButton(
                isSelected = isFlyoutVisible,
                onClick = {
                    isFlyoutVisible = !isFlyoutVisible
                },
                buttonText = selectedSortType.label
            )
        },
        placement = FlyoutPlacement.BottomAlignedStart,
    )
}

@Composable
fun SortButton(
    isSelected: Boolean,
    onClick: () -> Unit,
    buttonText: String,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isHovered by interactionSource.collectIsHoveredAsState()
    val backgroundColor by animateColorAsState(
        targetValue = if (isHovered || isSelected) FluentTheme.colors.stroke.control.default else Color.Transparent
    )

    // 根据isSelected状态计算目标旋转角度
    val targetRotation = if (isSelected) -180f else 0f
    val animatedRotation by animateFloatAsState(targetValue = targetRotation)
    val isAsc by remember { mutableStateOf(true) }
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .border(1.dp, Color.Gray.copy(alpha = 0.4f), CircleShape)
            .background(backgroundColor)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick
            )
            .hoverable(interactionSource)
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .pointerHoverIcon(PointerIcon.Hand),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = spacedBy(4.dp, Alignment.CenterHorizontally)
    ) {
        Text(
            text = buttonText,
            color = FluentTheme.colors.text.text.primary,
            fontSize = 14.sp
        )
        Spacer(modifier = Modifier.width(4.dp))
//        Column(
//            horizontalAlignment = Alignment.CenterHorizontally,
//            verticalArrangement = Arrangement.Center,
//        ) {
//            Box(
//                modifier = Modifier.size(12.dp),
//                contentAlignment = Alignment.BottomCenter
//            ) {
//                Icon(
//                    TriangleUpFill,
//                    tint = if (isAsc) FluentTheme.colors.text.text.tertiary else FluentTheme.colors.text.text.disabled,
//                    contentDescription = "升序",
//                    modifier = Modifier.size(16.dp)
//                )
//            }
//            Box(
//                modifier = Modifier.size(12.dp),
//                contentAlignment = Alignment.TopCenter
//            ) {
//                Icon(
//                    TriangleDownFill,
//                    tint = if (isAsc) FluentTheme.colors.text.text.tertiary else FluentTheme.colors.text.text.disabled,
//                    contentDescription = "降序",
//                    modifier = Modifier.size(16.dp)
//                )
//            }
//
//        }
        Icon(
            imageVector = ArrowUp,
            contentDescription = "下拉图标",
            tint = FluentTheme.colors.text.text.primary,
            modifier = Modifier
                .size(16.dp)
                .rotate(animatedRotation)
        )

    }

}