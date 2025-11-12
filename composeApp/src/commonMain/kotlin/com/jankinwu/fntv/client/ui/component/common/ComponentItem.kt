package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.vector.ImageVector

class ComponentItem(
    val name: String = "",
    val group: String,
    val description: String,
    val items: List<ComponentItem>? = null,
    val icon: ImageVector? = null,
    val guid: String? = null,
    val type: List<String>? = listOf(),
    val content: (@Composable ComponentItem.(navigator: ComponentNavigator) -> Unit)?,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ComponentItem) return false
        // 使用 name 和 group 作为相等性判断依据
        return  guid == other.guid
    }

    override fun hashCode(): Int {
        // 根据 name、group 和 guid 计算哈希值
        return guid?.hashCode() ?: 0
    }
}

