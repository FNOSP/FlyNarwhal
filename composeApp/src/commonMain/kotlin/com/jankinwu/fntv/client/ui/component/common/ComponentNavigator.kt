package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember

interface ComponentNavigator {

    fun navigate(componentItem: ComponentItem)

    fun navigateUp()

    val currentBackstack: List<ComponentItem>

    val latestBackEntry: ComponentItem?

    val canNavigateUp: Boolean

    fun addStartItem(componentItem: ComponentItem);

}

@Composable
fun rememberComponentNavigator(): ComponentNavigator {
    return remember { ComponentNavigatorImpl() }
}

private class ComponentNavigatorImpl() : ComponentNavigator {

    companion object {
        private val NOT_ADD_ITEM_NAME_LIST = listOf("9e63fc61-eb41-0e19-6d09-73f92969fc95", "62fbfbba-3808-85b8-a09d-3c7766a289b8")
    }

    private val backstack = mutableStateListOf<ComponentItem>()

    override fun navigate(componentItem: ComponentItem) {
        if (!NOT_ADD_ITEM_NAME_LIST.contains(componentItem.guid)) {
            backstack.add(componentItem)
        }
        if (backstack.size > 20) {
            backstack.removeAt(0)
        }
    }

    override fun navigateUp() {
        if (backstack.isNotEmpty()) {
            do {
                backstack.removeAt(backstack.lastIndex)
            } while (backstack.lastOrNull().let { it != null && it.content == null })
        }
    }

    override val canNavigateUp: Boolean by derivedStateOf {
        backstack.count { it.content != null } > 1
    }

    override fun addStartItem(componentItem: ComponentItem) {
        backstack.add(componentItem)
    }

    override val currentBackstack: List<ComponentItem>
        get() = backstack

    override val latestBackEntry: ComponentItem?
        get() = backstack.lastOrNull()
}