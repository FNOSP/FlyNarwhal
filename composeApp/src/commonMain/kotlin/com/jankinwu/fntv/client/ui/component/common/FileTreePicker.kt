package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.TooltipArea
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.network.impl.FnOfficialApiImpl
import com.jankinwu.fntv.client.ui.component.common.DirectoryContentFetcher.fetchDirectoryContents
import com.jankinwu.fntv.client.ui.customSelectedCheckBoxColors
import com.jankinwu.fntv.client.utils.DisabledPointerIcon
import flynarwhal.composeapp.generated.resources.Res
import flynarwhal.composeapp.generated.resources.empty_folder
import flynarwhal.composeapp.generated.resources.folder
import flynarwhal.composeapp.generated.resources.text
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.CheckBox
import io.github.composefluent.component.CheckBoxDefaults
import io.github.composefluent.component.Icon
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.Text
import io.github.composefluent.component.rememberScrollbarAdapter
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.painterResource
import org.koin.core.component.KoinComponent
import org.koin.core.component.inject

// --- 1. 数据模型 ---

/**
 * 模拟从 API 接收到的文件/目录项
 */
data class ApiFileItem(
    val filename: String,
    val isDir: Boolean
    // 其他字段 (trim_name, trim_id) 在此示例中未使用
)

/**
 * 选择模式：只选文件、只选文件夹、或两者皆可
 */
enum class SelectionMode {
    FilesOnly,
    FoldersOnly,
    FilesAndFolders
}

/**
 * 内部用于UI状态的树节点模型
 * @param path 节点的完整路径，用作唯一ID
 * @param children 首次加载后，目录的子节点列表；null 表示尚未加载
 * @param isExpanded 目录是否已展开
 * @param isLoading 目录是否正在加载子节点
 * @param isRoot 是否是根节点
 */
data class TreeNode(
    val name: String,
    val path: String,
    val isDirectory: Boolean,
    val children: List<TreeNode>? = null,
    val isExpanded: Boolean = false,
    val isLoading: Boolean = false,
    val isRoot: Boolean = false
)

/**
 * 通过API获取指定路径下的文件和目录列表
 */
object DirectoryContentFetcher : KoinComponent {
    private val fnOfficialApi: FnOfficialApiImpl by inject()

    suspend fun fetchDirectoryContents(path: String): List<ApiFileItem> {
        return try {
            // 使用 withContext 确保在正确的上下文中执行
            val serverPathResponses = with(kotlinx.coroutines.Dispatchers.IO) {
                fnOfficialApi.getFilesByServerPath(path)
            }

            // 将 ServerPathResponse 转换为 ApiFileItem
            serverPathResponses.map { response ->
                ApiFileItem(
                    filename = response.filename,
                    isDir = response.isDir
                )
            }
        } catch (e: kotlinx.coroutines.CancellationException) {
            // 正常处理协程取消
            throw e
        } catch (_: Exception) {
            // 处理其他异常
            emptyList()
        }
    }
}

// --- 3. 核心 Composable：文件树选择器 ---

/**
 * 文件树选择器的主 Composable (支持多选)
 *
 * @param rootPaths 启动时加载的根路径列表
 * @param selectionMode 允许选择的类型 (文件 / 文件夹 / 两者)
 * @param allowedExtensions 允许显示的文件后缀名列表 (小写)。如果为空，则显示所有文件。
 * @param onSelectionChanged 当选择项发生变化时调用的回调，返回一个包含所有选中路径的 Set
 * @param hideRoot 是否隐藏根目录（对于"视频所在位置"使用）
 */
@Composable
fun FileTreePicker(
    rootPaths: List<String>,
    selectionMode: SelectionMode,
    allowedExtensions: List<String>,
    onSelectionChanged: (selectedPaths: Set<String>) -> Unit,
    hideRoot: Boolean = false
) {
    // 树的根节点状态 - 支持多个根节点
    var roots by remember(rootPaths) {
        mutableStateOf(
            rootPaths.map { rootPath ->
                TreeNode(
                    name = rootPath.substringAfterLast("/", rootPath),
                    path = rootPath,
                    isDirectory = true,
                    isExpanded = false, // 默认折叠根目录
                    isLoading = false, // 初始不加载
                    children = null, // 初始为 null，表示未加载
                    isRoot = true // 标记为根节点
                )
            }
        )
    }

    // 当前选择的项的路径集合 (Set)
    var selectedPaths by remember { mutableStateOf(emptySet<String>()) }

    // 用于执行异步加载的协程作用域
    val scope = rememberCoroutineScope()

    // 初始加载所有根节点的内容（针对hideRoot情况）
    LaunchedEffect(rootPaths) {
        if (hideRoot) {
            roots.forEach { root ->
                if (root.children == null && !root.isLoading) {
                    scope.launch {
                        val apiChildren = fetchDirectoryContents(root.path)
                        val newChildren = apiChildren.map {
                            TreeNode(
                                name = it.filename,
                                path = "${root.path}/${it.filename}",
                                isDirectory = it.isDir,
                                children = if (it.isDir) null else emptyList()
                            )
                        }
                        roots = roots.map {
                            if (it.path == root.path) {
                                it.copy(
                                    isLoading = false,
                                    children = newChildren,
                                    isExpanded = true
                                )
                            } else {
                                it
                            }
                        }
                    }
                }
            }
        }
    }

    // --- 状态更新辅助函数 ---

    /**
     * 递归更新树状态的辅助函数（保持不可变性）
     */
    fun TreeNode.updateNode(targetPath: String, action: (TreeNode) -> TreeNode): TreeNode {
        if (this.path == targetPath) {
            return action(this)
        }
        return this.copy(
            children = this.children?.map { it.updateNode(targetPath, action) }
        )
    }

    /**
     * 更新所有根节点中的指定节点
     */
    fun updateNodeInRoots(targetPath: String, action: (TreeNode) -> TreeNode): List<TreeNode> {
        return roots.map { root ->
            root.updateNode(targetPath, action)
        }
    }

    /**
     * 当一个目录节点被点击时触发
     */
    fun onDirectoryClick(node: TreeNode) {
        val targetPath = node.path

        if (node.isExpanded) {
            // 如果已展开 -> 折叠
            roots = updateNodeInRoots(targetPath) { it.copy(isExpanded = false) }
        } else {
            // 如果已折叠 -> 展开
            if (node.children == null) {
                // 1. 未加载 -> 加载数据
                roots = updateNodeInRoots(targetPath) { it.copy(isLoading = true) }

                scope.launch {
                    val apiChildren = fetchDirectoryContents(targetPath)
                    val newChildren = apiChildren.map {
                        TreeNode(
                            name = it.filename,
                            path = "$targetPath/${it.filename}",
                            isDirectory = it.isDir,
                            children = if (it.isDir) null else emptyList()
                        )
                    }
                    roots = updateNodeInRoots(targetPath) {
                        it.copy(
                            isLoading = false,
                            isExpanded = true,
                            children = newChildren
                        )
                    }
                }
            } else {
                // 2. 已加载 -> 直接展开
                roots = updateNodeInRoots(targetPath) { it.copy(isExpanded = true) }
            }
        }
    }

    // 处理选择状态切换的逻辑
    val onToggleSelection = { path: String ->
        val newPaths = if (path in selectedPaths) {
            selectedPaths - path // 从 Set 中移除
        } else {
            selectedPaths + path // 添加到 Set 中
        }
        selectedPaths = newPaths // 更新内部状态
        onSelectionChanged(newPaths) // 调用外部回调
    }
    var isEmpty by remember(rootPaths) { mutableStateOf(false) }
    if (isEmpty) {
        EmptyFolder(modifier = Modifier.fillMaxSize(), "空空如也")
    }
    // --- UI 渲染 ---
    val lazyListState = rememberLazyListState()
    ScrollbarContainer(
        adapter = rememberScrollbarAdapter(lazyListState)
    ) {
        LazyColumn(
            state = lazyListState,
            modifier = Modifier
                .fillMaxSize()
//            .background(Color(0xFF2B2B2B))
        ) {
            // 启动递归渲染
            if (roots.any { it.children == null && !it.isLoading && hideRoot }) {
                // 根目录的初始加载
                item {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
//                        CircularProgressIndicator(modifier = Modifier.size(20.dp))
//                        Spacer(Modifier.width(8.dp))
//                        Text("Loading root...", color = Color.White)
                    }
                }
            } else {
                // 递归渲染所有根节点下的文件树项
                roots.forEach { root ->
                    if (hideRoot) {
                        // 如果隐藏根目录，直接渲染其子项
                        if (root.children != null) {
                            // 过滤出符合 allowedExtensions 条件的节点
                            val filteredNodes = root.children.filter { node ->
                                val extension =
                                    if (!node.isDirectory) node.name.substringAfterLast('.', "")
                                        .lowercase() else ""
                                when {
                                    node.isDirectory -> true
                                    allowedExtensions.isEmpty() -> true
                                    extension in allowedExtensions.map { it.lowercase() } -> true
                                    else -> false
                                }
                            }

                            if (filteredNodes.isEmpty()) {
                                isEmpty = true
                            } else {
                                fileTreeItems(
                                    nodes = root.children,
                                    depth = 0,
                                    selectionMode = selectionMode,
                                    allowedExtensions = allowedExtensions.map { it.lowercase() },
                                    selectedPaths = selectedPaths,
                                    onDirectoryClick = { onDirectoryClick(it) },
                                    onToggleSelection = onToggleSelection
                                )
                            }
                        } else if (root.isLoading) {
                            // 显示加载状态
                            item {
                                Row(
                                    modifier = Modifier.padding(16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    CircularProgressIndicator(modifier = Modifier.size(20.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Loading ${root.name}...", color = Color.White)
                                }
                            }
                        } else {
                            // 显示空目录
                            item {
                                EmptyFolder(modifier = Modifier.fillMaxSize(), "空空如也")
                            }
                        }
                    } else {
                        // 显示根节点（作为普通目录节点显示）
                        item {
                            FileNodeItem(
                                node = root.copy(isDirectory = true), // 确保根节点显示为目录图标
                                depth = 0,
                                isSelectable = false,
                                isSelected = false,
                                onNodeClick = {
                                    onDirectoryClick(root)
                                },
                                onCheckboxChange = {}
                            )
                        }

                        // 递归渲染文件树项（仅在展开时）
                        if (root.isExpanded && root.children != null) {
                            fileTreeItems(
                                nodes = root.children,
                                depth = 1, // 根目录本身占一层深度
                                selectionMode = selectionMode,
                                allowedExtensions = allowedExtensions.map { it.lowercase() },
                                selectedPaths = selectedPaths,
                                onDirectoryClick = { onDirectoryClick(it) },
                                onToggleSelection = onToggleSelection
                            )
                        } else if (root.isLoading) {
                            // 显示单个根节点的加载状态
                            item {
                                Row(
                                    modifier = Modifier.padding(16.dp, 0.dp, 16.dp, 16.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Spacer(Modifier.width(24.dp)) // 缩进根节点的子级
                                    CircularProgressIndicator(modifier = Modifier.size(20.dp))
                                    Spacer(Modifier.width(8.dp))
                                    Text("Loading ${root.name}...", color = Color.White)
                                }
                            }
                        } else if (!root.isExpanded && root.children == null) {
                            // 根节点未展开且未加载子项时，不显示任何内容
                            // 这样就实现了懒加载的效果
                        }
                    }
                }
            }
        }
    }
}

/**
 * `LazyListScope` 扩展函数，递归构建列表项
 */
private fun LazyListScope.fileTreeItems(
    nodes: List<TreeNode>,
    depth: Int,
    selectionMode: SelectionMode,
    allowedExtensions: List<String>,
    selectedPaths: Set<String>, // **[修改点]** 接收 Set
    onDirectoryClick: (TreeNode) -> Unit,
    onToggleSelection: (String) -> Unit // **[修改点]** 接收 toggle 处理器
) {
    nodes.forEach { node ->
        // --- 过滤逻辑 ---
        val extension = if (!node.isDirectory) node.name.substringAfterLast('.', "") else ""
        val isAllowed = when {
            node.isDirectory -> true
            allowedExtensions.isEmpty() -> true
            extension in allowedExtensions -> true
            else -> false
        }

        // --- 可选择逻辑 ---
        val isSelectable = when (selectionMode) {
            SelectionMode.FilesOnly -> !node.isDirectory
            SelectionMode.FoldersOnly -> node.isDirectory
            SelectionMode.FilesAndFolders -> true
        }

        if (isAllowed) {
            // 1. 渲染当前节点
            item {
                FileNodeItem(
                    node = node,
                    depth = depth,
                    isSelectable = isSelectable,
                    isSelected = node.path in selectedPaths, // **[修改点]** 检查 Set 中是否存在
                    onNodeClick = {
                        if (node.isDirectory) {
                            onDirectoryClick(node)
                        } else if (isSelectable) {
                            // 点击文件行也触发 toggle
                            onToggleSelection(node.path)
                        }
                    },
                    onCheckboxChange = {
                        // 点击复选框触发 toggle
                        onToggleSelection(node.path)
                    }
                )
            }

            // 2. 递归渲染子节点
            if (node.isExpanded && node.children != null) {
                fileTreeItems(
                    nodes = node.children,
                    depth = depth + 1,
                    selectionMode = selectionMode,
                    allowedExtensions = allowedExtensions,
                    selectedPaths = selectedPaths, // **[修改点]** 向下传递 Set
                    onDirectoryClick = onDirectoryClick,
                    onToggleSelection = onToggleSelection // **[修改点]** 向下传递处理器
                )
            }
        }
    }
}

/**
 * 渲染单个文件/目录行
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FileNodeItem(
    node: TreeNode,
    depth: Int,
    isSelectable: Boolean,
    isSelected: Boolean,
    onNodeClick: () -> Unit,
    onCheckboxChange: () -> Unit
) {
    TooltipArea(
        tooltip = {
            Surface(
                modifier = Modifier.padding(4.dp),
                color = FluentTheme.colors.background.smoke.default.copy(alpha = 0.8f),
                shape = RoundedCornerShape(4.dp),
                border = BorderStroke(1.dp, FluentTheme.colors.text.text.primary),
            ) {
                Text(
                    text = node.path,
                    modifier = Modifier
                        .padding(8.dp)
                        .width(500.dp),
                    color = FluentTheme.colors.text.text.primary,
                    style = FluentTheme.typography.caption
                )
            }
        },
        delayMillis = 800,
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onNodeClick
                )
                .padding(vertical = 4.dp)
                .padding(start = (depth * 24 + 8).dp),
            verticalAlignment = Alignment.CenterVertically
        ) {

            // 1. 展开/折叠箭头 (或加载指示器)
            Box(modifier = Modifier.size(20.dp), contentAlignment = Alignment.Center) {
                if (node.isDirectory) {
                    if (node.isLoading) {
//                        CircularProgressIndicator(modifier = Modifier.size(16.dp))
                    } else {
                        val arrowIcon =
                            if (node.isExpanded) Icons.Default.KeyboardArrowDown else Icons.AutoMirrored.Filled.KeyboardArrowRight
                        Icon(
                            imageVector = arrowIcon,
                            contentDescription = "Expand",
                            tint = Color.LightGray
                        )
                    }
                }
            }

//        Spacer(Modifier.width(8.dp))

            // 2. 复选框
            Box(modifier = Modifier.size(20.dp), contentAlignment = Alignment.Center) {
                CheckBox(
                    isSelected && isSelectable,
                    enabled = isSelectable,
                    onCheckStateChange = {
                        if (isSelectable) {
                            onCheckboxChange()
                        }
                    },
                    colors = if (isSelected && isSelectable) {
                        customSelectedCheckBoxColors()
                    } else {
                        CheckBoxDefaults.defaultCheckBoxColors()
                    },
                    modifier = Modifier
                        .pointerHoverIcon(if (isSelectable) PointerIcon.Hand else DisabledPointerIcon)
                        .size(15.dp)
                )
            }

            Spacer(Modifier.width(8.dp))

            // 3. 文件/目录图标
            Image(
                painterResource(if (node.isDirectory) Res.drawable.folder else Res.drawable.text),
                contentDescription = "文件夹 logo",
                modifier = Modifier
                    .size(24.dp)
            )

            Spacer(Modifier.width(8.dp))

            // 4. 文件名
            Text(
                text = node.name,
                color = FluentTheme.colors.text.text.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@Composable
fun EmptyFolder(modifier: Modifier, text: String) {
    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Image(
                painter = painterResource(Res.drawable.empty_folder),
                contentDescription = null,
                modifier = Modifier
                    .size(110.dp)
                    .padding(bottom = 24.dp)
            )
            Text(
                text,
                fontSize = 14.sp,
                color = FluentTheme.colors.text.text.primary
            )
        }
    }
}

