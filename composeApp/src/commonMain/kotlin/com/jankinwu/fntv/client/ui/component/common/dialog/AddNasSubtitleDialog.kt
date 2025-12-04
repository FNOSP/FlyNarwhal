package com.jankinwu.fntv.client.ui.component.common.dialog

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.response.AuthDir
import com.jankinwu.fntv.client.ui.component.common.FileTreePicker
import com.jankinwu.fntv.client.ui.component.common.SelectionMode
import com.jankinwu.fntv.client.ui.customAccentButtonColors
import com.jankinwu.fntv.client.ui.providable.LocalFileInfo
import com.jankinwu.fntv.client.viewmodel.AppAuthorizedDirViewModel
import com.jankinwu.fntv.client.viewmodel.ServerPathViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import io.github.composefluent.FluentTheme
import io.github.composefluent.LocalContentColor
import io.github.composefluent.LocalTextStyle
import io.github.composefluent.component.AccentButton
import io.github.composefluent.component.Button
import io.github.composefluent.component.ContentDialogButton
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FluentDialog
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.Text
import io.github.composefluent.component.rememberScrollbarAdapter
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun AddNasSubtitleDialog(
    title: String,
    visible: Boolean,
    primaryButtonText: String,
    secondaryButtonText: String? = null,
    closeButtonText: String? = null,
    onButtonClick: (ContentDialogButton, Set<String>?) -> Unit,
    size: DialogSize = DialogSize.Standard,
) {
    // 状态：用于保存文件选择器返回的路径 (此处仅用于演示，可以传递给其他组件)
    var selectedFilePaths by remember { mutableStateOf(emptySet<String>()) }
    FluentDialog(visible, size) {
        Column {
            Column(
                Modifier
                    .fillMaxWidth()
//                    .background(FluentTheme.colors.background.layer.alt)
                    .padding(top = 24.dp, bottom = 8.dp, start = 25.dp, end = 25.dp)
            ) {
                Text(
                    style = FluentTheme.typography.subtitle,
                    text = title,
                )
                Spacer(Modifier.height(12.dp))
                CompositionLocalProvider(
                    LocalTextStyle provides FluentTheme.typography.body,
                    LocalContentColor provides FluentTheme.colors.text.text.primary
                ) {
                    AddNasSubtitleBox(
                        onSelectionChanged = { selectedFilePaths = it },
                        onSelectedSidebarItemChanged = { selectedFilePaths = emptySet() } // 清空已选文件
                    )
                }
            }
            // Button Grid
            Box(
                Modifier
                    .height(50.dp)
                    .padding(horizontal = 25.dp, vertical = 8.dp),
                Alignment.CenterEnd
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AccentButton(
                        modifier = Modifier.weight(1f),
                        onClick = {
                            onButtonClick(ContentDialogButton.Primary, selectedFilePaths)
                        },
                        disabled = selectedFilePaths.isEmpty(),
                        buttonColors = customAccentButtonColors()
                    ) {
                        Text(primaryButtonText)
                    }
                    if (secondaryButtonText != null) Button(
                        modifier = Modifier.weight(1f),
                        onClick = { onButtonClick(ContentDialogButton.Secondary, null) }
                    ) {
                        Text(secondaryButtonText)
                    }
                    if (closeButtonText != null) Button(
                        modifier = Modifier.weight(1f),
                        onClick = { onButtonClick(ContentDialogButton.Close, null) }
                    ) {
                        Text(closeButtonText)
                    }
                }
            }
        }
    }
}

data class SidebarItem(val path: List<String>, val title: String)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddNasSubtitleBox(
    onSelectionChanged: (Set<String>) -> Unit,
    onSelectedSidebarItemChanged: () -> Unit = {}, // 添加回调参数
) {
    // 状态：用于跟踪侧边栏的当前选择
    var selectedSidebarItem: SidebarItem? by remember { mutableStateOf(null) }
    Box(
        modifier = Modifier
            .height(300.dp)
            .fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .border(1.dp, Color.Gray.copy(alpha = 0.5f), RoundedCornerShape(8.dp))
                .fillMaxSize()
        ) {
            // 1. 顶部标题栏
            TopBarBox(
                title = selectedSidebarItem?.title ?: "视频所在位置",
                contentColor = FluentTheme.colors.text.text.primary
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(Color.Gray.copy(alpha = 0.5f))
            )
            // 2. 主内容区域 (侧边栏 + 文件树)
            // 使用 weight(1f) 占据剩余空间
            Row(
                modifier = Modifier
                    .weight(
                        1f
                    )
            ) {

                // 2a. 侧边栏
                Sidebar(
                    selectedItem = selectedSidebarItem,
                    onItemSelected = {
                        selectedSidebarItem = it
                        onSelectedSidebarItemChanged() // 当侧边栏选项改变时调用回调
                    },
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(150.dp)
                )

                // 2b. 垂直分割线
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(1.dp)
                        .background(Color.Gray.copy(alpha = 0.5f))
                )

                // 2c. 主内容 (调用文件选择器)
                selectedSidebarItem?.let {
                    MainContent(
                        selectedSidebarItem = it,
                        onSelectionChanged = { paths ->
                            onSelectionChanged(paths)
                            // 调试：打印选中的路径
                            Logger.i("Selected Paths: $paths")
                        },
                        modifier = Modifier.fillMaxSize() // 占据剩余空间
                    )
                }
            }
        }
    }
}

@Composable
fun TopBarBox(title: String, contentColor: Color) {
    Row(
        modifier = Modifier
            .height(40.dp)
            .fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            modifier = Modifier
                .padding(start = 16.dp),
            color = contentColor
        )
        // TODO 所选文件/目录路径
    }
}

/**
 * 渲染左侧的侧边栏
 */
@Composable
fun Sidebar(
    selectedItem: SidebarItem?,
    onItemSelected: (SidebarItem) -> Unit,
    modifier: Modifier = Modifier
) {
    val fileInfo = LocalFileInfo.current
    val authorizedDirViewModel: AppAuthorizedDirViewModel =
        koinViewModel<AppAuthorizedDirViewModel>()
    val authorizedDirState by authorizedDirViewModel.uiState.collectAsState()
    var authDirList by remember { mutableStateOf<List<AuthDir>?>(null) }
    LaunchedEffect(Unit) {
        authorizedDirViewModel.loadAppAuthorizedDir()
    }
    LaunchedEffect(authorizedDirState) {
        when (authorizedDirState) {
            is UiState.Success -> {
                authDirList = (authorizedDirState as UiState.Success).data.authDirList
            }

            else -> {
                // 处理其他状态，如加载中、错误等
            }
        }
    }

    val currentDir = fileInfo?.path?.let { path ->
        // 提取文件所在目录路径
        if (path.contains("/")) {
            path.substringBeforeLast("/")
        } else {
            ""
        }
    } ?: ""
    val currentDirItem = SidebarItem(listOf(currentDir), "视频所在位置")

    // 从 authDirList 构建侧边栏项目列表
    val items = remember(authDirList) {
        val sidebarItems = mutableListOf<SidebarItem>()

        // 添加当前目录项
        sidebarItems.add(currentDirItem)

        // 遍历 authDirList 构建存储空间项
        authDirList?.forEach { authDir ->
            val path = authDir.path
            // 从路径中提取存储空间编号，例如 /vol2 -> 存储空间 2
            val storageTitle = FnDataConvertor.getVolumeCNName(path, hasSpace = true)
            // 检查是否已存在相同标题的项
            val existingItem = sidebarItems.find { it.title == storageTitle }
            if (existingItem != null) {
                // 如果存在，则添加路径到现有项
                sidebarItems.remove(existingItem)
                val updatedPaths = existingItem.path.toMutableList().apply { add(path) }
                sidebarItems.add(SidebarItem(updatedPaths.toList(), storageTitle))
            } else {
                // 如果不存在，则新建项
                sidebarItems.add(SidebarItem(listOf(path), storageTitle))
            }
        }
        sidebarItems
    }

    // 设置默认选中项为视频所在目录
    LaunchedEffect(items) {
        if (selectedItem == null && items.isNotEmpty()) {
            onItemSelected(currentDirItem)
        }
    }

    val lazyListState = rememberLazyListState()
    ScrollbarContainer(
        adapter = rememberScrollbarAdapter(lazyListState)
    ) {
        LazyColumn(
            state = lazyListState,
            modifier = modifier
                .padding(8.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp)
        ) {
            items(items) { item ->
                SidebarItem(
                    text = item.title,
                    isSelected = (item == selectedItem),
                    onClick = { onItemSelected(item) }
                )
            }
        }
    }
}

/**
 * 渲染侧边栏中的单个项目
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun SidebarItem(
    text: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    // 根据是否选中，切换背景和文字颜色
    val textColor = if (isSelected) FluentTheme.colors.text.text.primary else FluentTheme.colors.text.text.secondary
    var isHovered by remember { mutableStateOf(false) }
    val backgroundColor = if (isSelected || isHovered) FluentTheme.colors.stroke.control.default else Color.Transparent
    Text(
        text = text,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            )
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .pointerHoverIcon(PointerIcon.Hand)
            .background(backgroundColor, RoundedCornerShape(4.dp))
            .padding(12.dp),
        color = textColor,
        fontSize = 14.sp
    )
}

/**
 * 渲染右侧的主内容区域，这里是**调用**文件选择器的地方
 */
@Composable
fun MainContent(
    selectedSidebarItem: SidebarItem,
    onSelectionChanged: (Set<String>) -> Unit,
    modifier: Modifier = Modifier
) {
    val serverPathViewModel: ServerPathViewModel = koinViewModel()
    val serverPathUiState by serverPathViewModel.uiState.collectAsState()

    // 当选中的侧边栏项改变时，加载对应的文件列表
    LaunchedEffect(selectedSidebarItem) {
        if (selectedSidebarItem.title == "视频所在位置" && selectedSidebarItem.path.isNotEmpty()) {
            serverPathViewModel.loadFilesByServerPath(selectedSidebarItem.path.first())
        }
    }

    Box(
        modifier = modifier
//            .background(Color(0xFF2B2B2B)) // 主内容区域背景
    ) {
        if (selectedSidebarItem.title == "视频所在位置") {
            // 对于"视频所在位置"，使用ServerPathViewModel获取的数据
            when (serverPathUiState) {
                is UiState.Loading -> {
                }

                is UiState.Success -> {
                    FileTreePicker(
                        rootPaths = selectedSidebarItem.path,
                        selectionMode = SelectionMode.FilesOnly,
                        allowedExtensions = listOf("ass", "srt", "vtt", "sub", "ssa"),
                        onSelectionChanged = onSelectionChanged,
                        hideRoot = true // 隐藏根目录
                    )
                }

                is UiState.Error -> {
                    Text(
                        text = "Error: ${(serverPathUiState as UiState.Error).message}",
                        color = Color.Red,
                        modifier = Modifier.padding(16.dp)
                    )
                }

                else -> {
                    FileTreePicker(
                        rootPaths = selectedSidebarItem.path,
                        selectionMode = SelectionMode.FilesOnly,
                        allowedExtensions = listOf("ass", "srt", "vtt", "sub", "ssa"),
                        onSelectionChanged = onSelectionChanged,
                        hideRoot = true // 隐藏根目录
                    )
                }
            }
        } else {
            // 对于其他存储空间，显示所有根目录，但采用懒加载方式
            FileTreePicker(
                rootPaths = selectedSidebarItem.path,
                selectionMode = SelectionMode.FilesOnly,
                allowedExtensions = listOf("ass", "srt", "vtt", "sub", "ssa"),
                onSelectionChanged = onSelectionChanged,
                hideRoot = false // 不隐藏根目录
            )
        }
    }
}
