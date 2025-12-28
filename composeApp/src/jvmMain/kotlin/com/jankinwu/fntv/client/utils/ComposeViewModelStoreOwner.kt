package com.jankinwu.fntv.client.utils

import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner

class ComposeViewModelStoreOwner : ViewModelStoreOwner {
    override val viewModelStore: ViewModelStore = ViewModelStore()

    fun dispose() {
        viewModelStore.clear()
    }
}
