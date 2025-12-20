package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.awt.ComposePanel
import androidx.compose.ui.awt.SwingPanel
import androidx.compose.ui.graphics.Color
import com.jankinwu.fntv.client.player.CustomVlcMediampPlayer
import com.jankinwu.fntv.client.ui.providable.LocalFrameWindowScope
import com.jankinwu.fntv.client.ui.providable.LocalIsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.ui.providable.LocalWindowState
import com.jankinwu.fntv.client.ui.providable.LocalFileInfo
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.window.findComponent
import org.openani.mediamp.MediampPlayer
import org.jetbrains.skiko.SkiaLayer
import java.awt.Component
import java.awt.Container
import java.awt.IllegalComponentStateException
import java.awt.Frame
import java.awt.Window
import java.awt.event.ComponentAdapter
import java.awt.event.ComponentEvent
import java.awt.event.ContainerAdapter
import java.awt.event.ContainerEvent
import java.awt.event.MouseAdapter
import java.awt.event.MouseEvent
import java.awt.event.MouseMotionAdapter
import java.awt.event.WindowStateListener
import javax.swing.JComponent
import javax.swing.JWindow
import javax.swing.SwingUtilities

@Composable
actual fun EmbeddedPlayerSurface(
    mediampPlayer: MediampPlayer,
    modifier: Modifier,
    content: @Composable () -> Unit
) {
    if (mediampPlayer !is CustomVlcMediampPlayer || mediampPlayer.mode != CustomVlcMediampPlayer.VlcRenderMode.EMBEDDED) {
        return
    }

    val vlcComponent = mediampPlayer.component ?: return
    val playerManager = LocalPlayerManager.current
    val notifyMouseActivity = rememberUpdatedState(newValue = { playerManager.notifyMouseActivity() })
    val overlayContent = rememberUpdatedState(newValue = content)
    val ownerWindow = LocalFrameWindowScope.current.window as? Window
    val isoTagData = LocalIsoTagData.current
    val toastManager = LocalToastManager.current
    val fileInfo = LocalFileInfo.current
    val typography = LocalTypography.current
    val windowState = LocalWindowState.current

    DisposableEffect(vlcComponent) {
        val mouseMotionListener = object : MouseMotionAdapter() {
            override fun mouseMoved(e: MouseEvent) {
                notifyMouseActivity.value.invoke()
            }

            override fun mouseDragged(e: MouseEvent) {
                notifyMouseActivity.value.invoke()
            }
        }

        val mouseListener = object : MouseAdapter() {
            override fun mouseEntered(e: MouseEvent) {
                notifyMouseActivity.value.invoke()
            }

            override fun mousePressed(e: MouseEvent) {
                notifyMouseActivity.value.invoke()
            }

            override fun mouseReleased(e: MouseEvent) {
                notifyMouseActivity.value.invoke()
            }
        }

        lateinit var attachRecursive: (Component) -> Unit
        lateinit var detachRecursive: (Component) -> Unit

        val containerListener = object : ContainerAdapter() {
            override fun componentAdded(e: ContainerEvent) {
                attachRecursive(e.child)
            }

            override fun componentRemoved(e: ContainerEvent) {
                detachRecursive(e.child)
            }
        }

        attachRecursive = { component ->
            component.addMouseMotionListener(mouseMotionListener)
            component.addMouseListener(mouseListener)
            if (component is Container) {
                component.addContainerListener(containerListener)
                component.components.forEach { child -> attachRecursive(child) }
            }
        }

        detachRecursive = { component ->
            component.removeMouseMotionListener(mouseMotionListener)
            component.removeMouseListener(mouseListener)
            if (component is Container) {
                component.removeContainerListener(containerListener)
                component.components.forEach { child -> detachRecursive(child) }
            }
        }

        attachRecursive(vlcComponent)

        onDispose {
            detachRecursive(vlcComponent)
        }
    }

    DisposableEffect(vlcComponent, ownerWindow) {
        if (ownerWindow == null) {
            return@DisposableEffect onDispose {}
        }

        val composePanel = ComposePanel().apply {
            isOpaque = false
            background = java.awt.Color(0, 0, 0, 0)
            setContent {
                CompositionLocalProvider(
                    LocalIsoTagData provides isoTagData,
                    LocalToastManager provides toastManager,
                    LocalFileInfo provides fileInfo,
                    LocalTypography provides typography,
                    LocalWindowState provides windowState,
                    LocalPlayerManager provides playerManager
                ) {
                    overlayContent.value.invoke()
                }
            }
        }

        val overlayWindow = JWindow(ownerWindow).apply {
            isAlwaysOnTop = true
            focusableWindowState = false
            background = java.awt.Color(0, 0, 0, 0)
            (contentPane as? JComponent)?.let { pane ->
                pane.isOpaque = false
                pane.background = java.awt.Color(0, 0, 0, 0)
            }
            contentPane = composePanel
        }

        // Ensure the SkiaLayer inside ComposePanel supports per-pixel transparency, otherwise it paints a solid background.
        SwingUtilities.invokeLater {
            composePanel.findComponent<SkiaLayer>()?.transparency = true
        }

        fun updateOverlayBounds() {
            val ownerFrame = ownerWindow as? Frame
            val isOwnerIconified = ownerFrame?.let { (it.extendedState and Frame.ICONIFIED) != 0 } == true
            if (!vlcComponent.isShowing || !ownerWindow.isShowing || isOwnerIconified) {
                if (overlayWindow.isVisible) {
                    overlayWindow.isVisible = false
                }
                return
            }

            val location = try {
                vlcComponent.locationOnScreen
            } catch (_: IllegalComponentStateException) {
                null
            } ?: return

            val width = vlcComponent.width
            val height = vlcComponent.height
            if (width <= 0 || height <= 0) {
                return
            }

            overlayWindow.setBounds(location.x, location.y, width, height)
            if (!overlayWindow.isVisible) {
                overlayWindow.isVisible = true
            }
            overlayWindow.toFront()
        }

        val componentListener = object : ComponentAdapter() {
            override fun componentShown(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }

            override fun componentHidden(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }

            override fun componentMoved(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }

            override fun componentResized(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }
        }

        val windowListener = object : ComponentAdapter() {
            override fun componentMoved(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }

            override fun componentResized(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }

            override fun componentShown(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }

            override fun componentHidden(e: ComponentEvent) {
                SwingUtilities.invokeLater { updateOverlayBounds() }
            }
        }

        val windowStateListener = WindowStateListener {
            SwingUtilities.invokeLater { updateOverlayBounds() }
        }

        vlcComponent.addComponentListener(componentListener)
        ownerWindow.addComponentListener(windowListener)
        (ownerWindow as? Frame)?.addWindowStateListener(windowStateListener)

        SwingUtilities.invokeLater { updateOverlayBounds() }

        onDispose {
            vlcComponent.removeComponentListener(componentListener)
            ownerWindow.removeComponentListener(windowListener)
            (ownerWindow as? Frame)?.removeWindowStateListener(windowStateListener)
            composePanel.setContent { }
            overlayWindow.isVisible = false
            overlayWindow.dispose()
        }
    }

    SwingPanel(
        background = Color.Black,
        modifier = modifier,
        factory = {
            vlcComponent
        },
        update = { container ->
        }
    )
}
