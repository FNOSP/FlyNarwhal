package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.Image
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.icons.Logout
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.ui.component.common.ComponentItem
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.viewmodel.LogoutViewModel
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
import io.github.composefluent.component.rememberScrollbarAdapter
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.ArrowUpRight
import io.github.composefluent.icons.regular.Blur
import io.github.composefluent.icons.regular.Color
import io.github.composefluent.icons.regular.List
import io.github.composefluent.icons.regular.Navigation
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun SettingsScreen(componentNavigator: ComponentNavigator) {
    val logoutViewModel: LogoutViewModel = koinViewModel()
    val scrollState = rememberScrollState()
    val uriHandler = LocalUriHandler.current
    Column {
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
                CardExpanderItem(
                    heading = {
                        Text("App Theme")
                    },
                    icon = {
                        Icon(Icons.Regular.Color, contentDescription = null)
                    },
                    caption = {
                        Text("Select which app theme to display")
                    },
                    trailing = {
                        Switcher(
                            checked = store.darkMode,
                            text = if (store.darkMode) "Dark" else "Light",
                            textBefore = true,
                            onCheckStateChange = { store.darkMode = it }
                        )
                    }
                )
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
//                    onClick = {
//                        uriHandler.openUri(Constants.ProjectUrl)
//                    }
//                    expandContent = {
//                        CardExpanderItem(
//                            icon = {},
//                            heading = {
//                                Text("To clone this repository")
//                            },
//                            trailing = {
//                                SelectionContainer {
//                                    val interactionSource = remember { MutableInteractionSource() }
//                                    val isHovered by interactionSource.collectIsHoveredAsState()
//                                    Box(
//                                        modifier = Modifier
////                                            .clickable(
////                                                interactionSource = interactionSource,
////                                                indication = null,
////                                                onClick = {
////                                                    uriHandler.openUri(Constants.ProjectUrl)
////                                                }
////                                            )
//                                            .hoverable(interactionSource)
//                                            .pointerHoverIcon(PointerIcon.Hand),
//                                    ) {
//                                        Text("git clone ${Constants.ProjectUrl}.git")
//                                    }
//                                }
//                            },
//                            onClick =  {
//                                uriHandler.openUri(Constants.ProjectUrl)
//                            }
//                        )
//
//                        ExpanderItemSeparator()
//
//                        ExpanderItem(
//                            heading = {
//                                Text("Compose Fluent Design")
//                            },
//                            trailing = {
//                                Text("v0.1.0")
//                            }
//                        )
//                        ExpanderItemSeparator()
//                        ExpanderItem(
//                            heading = {
//                                Text("Kotlin")
//                            },
//                            trailing = {
//                                Text("2.2.20")
//                            }
//                        )
//                        ExpanderItemSeparator()
//                        ExpanderItem(
//                            heading = {
//                                Text("Compose Multiplatform")
//                            },
//                            trailing = {
//                                Text("1.9.0")
//                            }
//                        )
//                        ExpanderItemSeparator()
//                        ExpanderItem(
//                            heading = {
//                                Text("Haze")
//                            },
//                            trailing = {
////                                Text(BuildKonfig.HAZE_VERSION)
//                            },
//                        )
//                    }
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