package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.border
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.ArrowDropUp
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.interaction.collectIsHoveredAsState

/**
 * 一个数字输入框，带有增加和减少按钮。
 *
 * @param value 当前的数值。
 * @param onValueChange 当数值改变时调用的回调函数。
 * @param modifier 应用于此组件的 Modifier。
 * @param minValue 允许的最小值。
 * @param maxValue 允许的最大值。
 * @param placeholder 输入框的占位符文本，默认为空字符串
 * @param label 输入框上方显示的标签文本，默认为空字符串
 */
@Composable
fun NumberInput(
    value: Int,
    onValueChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
    minValue: Int = Int.MIN_VALUE,
    maxValue: Int = Int.MAX_VALUE,
    placeholder: String = "",
    label: String = "",
    textColor: Color = Color.White,
    defaultValue: Int = 0
) {
    Column(
        modifier = modifier
    ) {
        // 显示标签
        if (label.isNotEmpty()) {
            Text(
                text = label,
                style = LocalTextStyle.current.copy(
                    fontSize = 14.sp,
                    color = Color.Gray
                ),
                modifier = Modifier
                    .padding(bottom = 4.dp)
                    .fillMaxWidth()
            )
        }

        // 使用 derivedStateOf 来确保 text 状态只在 value 真正从外部改变时才更新
        // 这可以防止在内部编辑时，光标跳到末尾的问题
        var text by remember { mutableStateOf(value.toString()) }
        val interactionSource = remember { MutableInteractionSource() }
        val isFocused by interactionSource.collectIsFocusedAsState()
        val borderColor = if (isFocused) Color(0xFF3A7BFF) else Color.Gray
        
        LaunchedEffect(value) {
            if (value.toString() != text) {
                text = value.toString()
            }
        }

        Row(
            modifier = Modifier
                .border(if (isFocused) 2.dp else 1.dp, borderColor, RoundedCornerShape(4.dp))
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 文本输入框
            BasicTextField(
                value = text,
                onValueChange = { newText ->
                    // 只允许输入数字
                    val filteredText = newText.filter { it.isDigit() }
                    text = filteredText

                    val newInt = filteredText.toIntOrNull()
                    if (newInt != null) {
                        // 将合法数字通过回调传出去，并限制在最大最小值范围内
                        onValueChange(newInt.coerceIn(minValue, maxValue))
                    } else if (filteredText.isEmpty()) {
                        // 如果输入框为空，使用默认值
                        onValueChange(defaultValue)
                    }
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.weight(1f),
                singleLine = true,
                textStyle = LocalTextStyle.current.copy(textAlign = TextAlign.Center, fontSize = 18.sp, color = textColor),
                visualTransformation = if (text.isEmpty() && placeholder.isNotEmpty()) VisualTransformation.None else VisualTransformation.None,
                decorationBox = { innerTextField ->
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        if (text.isEmpty() && placeholder.isNotEmpty()) {
                            Text(
                                text = placeholder,
                                style = LocalTextStyle.current.copy(
                                    textAlign = TextAlign.Center,
                                    fontSize = 18.sp,
                                    color = Color.Gray.copy(alpha = 0.5f)
                                )
                            )
                        }
                        innerTextField()
                    }
                },
                interactionSource = interactionSource
            )

            // 加减按钮列
            Column {
                // 增加按钮
                IconButton(
                    onClick = {
                        val newValue = (value + 1).coerceIn(minValue, maxValue)
                        onValueChange(newValue)
                    },
                    modifier = Modifier.size(24.dp)
                ) {
                    val interactionSource = remember { MutableInteractionSource() }
                    val isHovered by interactionSource.collectIsHoveredAsState()
                    Icon(
                        imageVector = Icons.Default.ArrowDropUp,
                        contentDescription = "增加",
                        modifier = Modifier
                            .size(32.dp)
                            .hoverable(interactionSource),
                        tint = if (isHovered) Color.White else Color.Gray
                    )
                }
                // 减少按钮
                IconButton(
                    onClick = {
                        val newValue = (value - 1).coerceIn(minValue, maxValue)
                        onValueChange(newValue)
                    },
                    modifier = Modifier.size(24.dp)
                ) {
                    val interactionSource = remember { MutableInteractionSource() }
                    val isHovered by interactionSource.collectIsHoveredAsState()
                    Icon(
                        imageVector = Icons.Default.ArrowDropDown,
                        contentDescription = "减少",
                        modifier = Modifier
                            .size(32.dp)
                            .hoverable(interactionSource),
                        tint = if (isHovered) Color.White else Color.Gray
                    )
                }
            }
        }
    }
}