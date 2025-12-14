package com.jankinwu.fntv.client.ui.screen

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.BuildConfig
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.icons.Logout
import com.jankinwu.fntv.client.icons.VersionInfo
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.ui.component.common.ComponentItem
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.component.common.dialog.UpdateDialog
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.viewmodel.LogoutViewModel
import com.jankinwu.fntv.client.viewmodel.UpdateViewModel
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.github_logo
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Button
import io.github.composefluent.component.CardExpanderItem
import io.github.composefluent.component.DropDownButton
import io.github.composefluent.component.Expander
import io.github.composefluent.component.Icon
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.NavigationDisplayMode
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.Switcher
import io.github.composefluent.component.Text
import io.github.composefluent.component.TextField
import io.github.composefluent.component.rememberScrollbarAdapter
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.ArrowUpRight
import io.github.composefluent.icons.regular.Blur
import io.github.composefluent.icons.regular.Color
import io.github.composefluent.icons.regular.Globe
import io.github.composefluent.icons.regular.List
import io.github.composefluent.icons.regular.Navigation
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun SettingsScreen(componentNavigator: ComponentNavigator) {
    val logoutViewModel: LogoutViewModel = koinViewModel()
    val updateViewModel: UpdateViewModel = koinViewModel()
    val updateStatus by updateViewModel.status.collectAsState()
    val latestVersion by updateViewModel.latestVersion.collectAsState()
    var proxyUrl by remember { mutableStateOf(AppSettingsStore.githubResourceProxyUrl) }
    val scrollState = rememberScrollState()
    val uriHandler = LocalUriHandler.current
    val focusManager = LocalFocusManager.current
    var showUpdateDialog by remember { mutableStateOf(false) }

    UpdateDialog(
        status = updateStatus,
        showDialog = showUpdateDialog,
        onDownload = { info -> updateViewModel.downloadUpdate(info) },
        onInstall = { info -> updateViewModel.installUpdate(info) },
        onDismiss = {
            updateViewModel.cancelDownload()
            showUpdateDialog = false
            // 不再清除全局状态，以保留更新提示标签
            // updateViewModel.clearStatus()
        }
    )

    Column(
        modifier = Modifier
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) {
                focusManager.clearFocus()
            }
    ) {
        Text(
            text = "Settings",
            style = FluentTheme.typography.titleLarge,
            modifier = Modifier.alignHorizontalSpace()
                .padding(top = 36.dp)
        )
        ScrollbarContainer(
            adapter = rememberScrollbarAdapter(scrollState)
        ) {
            val store = LocalStore.current
            Column(
                verticalArrangement = Arrangement.spacedBy(4.dp),
                modifier = Modifier
                    .verticalScroll(scrollState)
                    .alignHorizontalSpace()
                    .padding(top = 8.dp)
                    .padding(bottom = 24.dp)
            ) {
                Header("Appearance & behavior")
                val followSystemTheme = store.isFollowingSystemTheme

                CardExpanderItem(
                    heading = {
                        Text("主题模式")
                    },
                    icon = {
                        Icon(Icons.Regular.Color, contentDescription = null)
                    },
                    caption = {
                        Text("是否跟随系统主题")
                    },
                    trailing = {
                        Switcher(
                            checked = followSystemTheme,
                            text = if (followSystemTheme) "跟随系统" else "手动设置",
                            textBefore = true,
                            onCheckStateChange = {
                                store.isFollowingSystemTheme = it
                                AppSettingsStore.isFollowingSystemTheme = it
                            }
                        )
                    }
                )
                AnimatedVisibility(
                    visible = !followSystemTheme,
                    enter = fadeIn() + expandVertically(expandFrom = Alignment.Top),
                    exit = fadeOut() + shrinkVertically(shrinkTowards = Alignment.Top)
                ) {
                    CardExpanderItem(
                        heading = {
                            Text("深色模式")
                        },
                        icon = {
                            Icon(Icons.Regular.Color, contentDescription = null)
                        },
                        caption = {
                            Text("请选择是否使用深色模式")
                        },
                        trailing = {
                            Switcher(
                                checked = store.darkMode,
                                text = if (store.darkMode) "是" else "否",
                                textBefore = true,
                                onCheckStateChange = {
                                    store.darkMode = it
                                    AppSettingsStore.darkMode = it
                                }
                            )
                        }
                    )
                }

                CardExpanderItem(
                    heading = {
                        Text("Acrylic Flyout")
                    },
                    icon = {
                        Icon(
                            imageVector = Icons.Regular.Blur,
                            contentDescription = "Blur"
                        )
                    },
                    caption = {
                        Text("Enable Acrylic effect on Flyout")
                    },
                    trailing = {
                        Switcher(
                            checked = store.enabledAcrylicPopup,
                            text = if (store.enabledAcrylicPopup) "On" else "Off",
                            textBefore = true,
                            onCheckStateChange = { store.enabledAcrylicPopup = it }
                        )
                    }
                )
                CardExpanderItem(
                    heading = {
                        Text("Compact Mode")
                    },
                    icon = {
                        Icon(
                            imageVector = Icons.Regular.List,
                            contentDescription = "List"
                        )
                    },
                    caption = {
                        Text("Adjust ListItem height")
                    },
                    trailing = {
                        Switcher(
                            checked = store.compactMode,
                            text = if (store.compactMode) "Compact" else "Standard",
                            textBefore = true,
                            onCheckStateChange = { store.compactMode = it }
                        )
                    }
                )
                CardExpanderItem(
                    heading = {
                        Text("Navigation Style")
                    },
                    icon = {
                        Icon(
                            imageVector = Icons.Regular.Navigation,
                            contentDescription = "List"
                        )
                    },
                    caption = {
                        Text("Choose the Navigation View Layout")
                    },
                    trailing = {
                        MenuFlyoutContainer(
                            flyout = {
                                NavigationDisplayMode.entries.forEach { item ->
                                    MenuFlyoutItem(
                                        selected = item == store.navigationDisplayMode,
                                        onSelectedChanged = {
                                            store.navigationDisplayMode = item
                                            isFlyoutVisible = false
                                        },
                                        text = {
                                            Text(item.name)
                                        }
                                    )
                                }
                            },
                            content = {
                                DropDownButton(
                                    onClick = {
                                        isFlyoutVisible = true
                                    },
                                    content = {
                                        Text(store.navigationDisplayMode.name)
                                    }
                                )
                            }
                        )
                    }
                )

                // Hide this test component if gallery is release version.
//                if (!BuildKonfig.CURRENT_BRANCH.equals("master", false)) {
//                    Header("Test")
//                    CardExpanderItem(
//                        heading = {
//                            Text("Test Component")
//                        },
//                        caption = {
//                            Text("Test Component with some settings like scale fraction and dark theme")
//                        },
//                        onClick = {
//                            componentNavigator.navigate(testComponent)
//                        },
//                        icon = {
//                            Icon(Icons.Regular.Bug, contentDescription = null)
//                        },
//                        dropdown = {
//                            Icon(Icons.Regular.ChevronRight, null)
//                        }
//                    )
//                }
                Header("About")
                CardExpanderItem(
                    heading = {
                        Text("Fntv Client Multiplatform")
                    },
                    icon = {
                        Image(
                            painter = painterResource(Res.drawable.github_logo),
                            contentDescription = null,
                            modifier = Modifier
                                .size(18.dp)
                        )
                    },
                    caption = {
                        Text(Constants.PROJECT_URL)
                    },
                    trailing = {
                        Button(
                            onClick = {
                                uriHandler.openUri(Constants.PROJECT_URL)
                            },
                            modifier = Modifier
                                .pointerHoverIcon(PointerIcon.Hand)
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text("访问仓库")
                                Icon(
                                    imageVector = Icons.Regular.ArrowUpRight,
                                    contentDescription = "访问仓库",
                                    modifier = Modifier
                                        .padding(start = 4.dp)
                                        .size(12.dp)
                                )
                            }
                        }
                    },
                )

                // Update Settings
                Header("Update")
                CardExpanderItem(
                    heading = { Text("Proxy") },
                    caption = { Text("Proxy URL for downloading updates (e.g. https://ghfast.top/)") },
                    icon = { Icon(Icons.Regular.Globe, null, modifier = Modifier.size(18.dp)) },
                    trailing = {
                        TextField(
                            value = proxyUrl,
                            onValueChange = {
                                proxyUrl = it
                                AppSettingsStore.githubResourceProxyUrl = it
                            },
                            modifier = Modifier.width(200.dp),
                            singleLine = true,
                            placeholder = { Text("Proxy URL") },
                        )
                    }
                )

                CardExpanderItem(
                    heading = { Text("当前版本") },
                    caption = { Text(BuildConfig.VERSION_NAME) },
                    icon = {
                        Icon(
                            VersionInfo,
                            "版本升级", modifier = Modifier.size(18.dp)
                        )
                    },
                    trailing = {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (latestVersion != null) {
                                Row(
                                    modifier = Modifier
                                        .padding(start = 8.dp)
                                        .background(
                                            Colors.AccentColorDefault,
                                            RoundedCornerShape(50)
                                        )
//                                        .border(1.dp, Colors.AccentColorDefault, RoundedCornerShape(50))
                                        .padding(horizontal = 8.dp, vertical = 1.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
//                                    Icon(
//                                        UpdateNoBorder,
//                                        "版本升级", modifier = Modifier.size(10.dp),
//                                        tint = Color.White
//                                    )
                                    latestVersion?.let {
                                        Text(
                                            text = it.version,
                                            style = FluentTheme.typography.bodyStrong,
                                            color = Color.White,
                                            modifier = Modifier
                                                .padding(start = 2.dp)
                                        )
                                    }

                                }
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Button(
                                modifier = Modifier
                                    .pointerHoverIcon(PointerIcon.Hand),
                                onClick = {
                                    updateViewModel.checkUpdate()
                                    showUpdateDialog = true
                                }) {
                                Text("检查更新")
                            }
                        }
                    }
                )

                // 添加登出按钮
                Header("Account")
                CardExpanderItem(
                    icon = {
                        Icon(
                            imageVector = Logout,
                            contentDescription = "访问仓库",
                            modifier = Modifier
                                .size(18.dp)
                        )
                    },
                    heading = {
                        Text("Log out")
                    },
                    caption = {
                        Text("Sign out of your account")
                    },
                    onClick = {
                        LoginStateManager.logout(logoutViewModel)
                    }
                )
            }
        }
    }
}

fun Modifier.alignHorizontalSpace() = then(
    Modifier
        .fillMaxWidth()
        .wrapContentWidth(align = Alignment.CenterHorizontally)
        .padding(horizontal = 32.dp)
        .widthIn(max = 1000.dp)
        .fillMaxWidth()
)

@Composable
private fun Header(text: String) {
    Text(
        text = text,
        style = FluentTheme.typography.bodyStrong,
        modifier = Modifier.padding(top = 16.dp, bottom = 4.dp)
    )
}

@Composable
private fun Expander(
    heading: @Composable () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    interactionSource: MutableInteractionSource? = null,
    shape: Shape = FluentTheme.shapes.control,
    icon: (@Composable () -> Unit)? = {},
    caption: @Composable () -> Unit = {},
    trailing: @Composable () -> Unit = {},
    expandContent: (@Composable ColumnScope.() -> Unit) = {},
) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    Expander(
        expanded = expanded,
        onExpandedChanged = { expanded = it },
        heading = heading,
        modifier = modifier,
        enabled = enabled,
        interactionSource = interactionSource,
        shape = shape,
        icon = icon,
        caption = caption,
        trailing = trailing,
        expandContent = expandContent
    )
}

private val testComponent = ComponentItem(
    name = "Test Component",
    description = "Test Component with some settings like scale fraction and dark theme",
    group = "settings",
    content = {
//        TestComponentScreen()
    }
)