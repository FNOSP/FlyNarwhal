import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  // Presented as a standalone floating panel instead of a window sheet: the
  // sheet slide-in/out animation runs as a blocking animation loop on the main
  // thread, and media_kit waits on the main thread for every video frame
  // (DispatchQueue.main.sync in VideoOutput), so sheets freeze the picture.
  // The panel instance is created once and reused: creating an NSOpenPanel
  // costs a synchronous XPC round trip to the out-of-process open/save panel
  // service on the main thread (~145ms warm, ~570ms cold), which also freezes
  // the merged UI/platform thread. preWarmSubtitlePicker() pays that cost at
  // startup behind an invisible, click-through panel so the first real open
  // is cheap.
  private var subtitlePickerPanel: NSOpenPanel?
  private var subtitlePickerResult: FlutterResult?
  private var didPreWarmSubtitlePicker = false
  private var isPreWarmingPicker = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerLocalSubtitlePickerChannel(messenger: flutterViewController.engine.binaryMessenger)
    registerTopEdgeColorChannel(messenger: flutterViewController.engine.binaryMessenger)
    registerDisplayEnumerationChannel(messenger: flutterViewController.engine.binaryMessenger)
    preWarmSubtitlePicker()

    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    installTopEdgeCover()

    self.standardWindowButton(.closeButton)?.isHidden = false
    self.standardWindowButton(.miniaturizeButton)?.isHidden = false
    self.standardWindowButton(.zoomButton)?.isHidden = false

    super.awakeFromNib()

    // Relayout traffic light buttons after window initialization
    DispatchQueue.main.async {
      self.relayoutWindowButtons()
      self.installTopEdgeCover()
    }

    // window_manager / flutter_acrylic can recreate or reorder the titlebar
    // container during startup and on style changes, which orphans the top
    // edge cover. Re-assert it (idempotently) whenever the window updates.
    for name in [NSWindow.didBecomeKeyNotification,
                 NSWindow.didResizeNotification,
                 NSWindow.didUpdateNotification] {
      NotificationCenter.default.addObserver(
        forName: name, object: self, queue: .main) { [weak self] _ in
        self?.installTopEdgeCover()
      }
    }

    // Fix: retarget Edit ▸ Paste once the menu bar is loaded. Deferred so the
    // xib menu is fully instantiated before we walk it.
    DispatchQueue.main.async { [weak self] in
      self?.rewirePasteMenuItem()
    }
  }

  // MARK: - Paste fix
  //
  // The default template wires Edit ▸ Paste to the responder chain (`paste:`),
  // but Flutter's macOS responders (FlutterViewController / FlutterTextInputPlugin)
  // do not implement `paste:`. A physical Cmd+V still works because the engine
  // intercepts it in `performKeyEquivalent` and forwards it to the framework, but
  // a Cmd+V *synthesized* by a clipboard manager is routed through the menu
  // key-equivalent path, which dispatches `paste:` and finds no responder — so
  // nothing is inserted. Retarget the menu item here and insert the clipboard text
  // through the active NSTextInputClient (the focused Flutter text field).
  private func rewirePasteMenuItem() {
    guard let topItems = NSApp.mainMenu?.items else { return }
    for top in topItems {
      guard let submenu = top.submenu else { continue }
      for item in submenu.items where item.action == #selector(NSText.paste(_:)) {
        item.target = self
        item.action = #selector(MainFlutterWindow.flutterPaste(_:))
      }
    }
  }

  @objc private func flutterPaste(_ sender: Any?) {
    let text = NSPasteboard.general.string(forType: .string) ?? ""
    guard !text.isEmpty else { return }
    var responder: NSResponder? = firstResponder
    while let current = responder {
      if let client = current as? NSTextInputClient {
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: 0))
        return
      }
      responder = current.nextResponder
    }
  }

  private func registerLocalSubtitlePickerChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "fly_narwhal/local_subtitle_picker",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      guard call.method == "openLocalSubtitles" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let initialDirectory = (call.arguments as? [String: Any])?["initialDirectory"] as? String
      self.openLocalSubtitlePicker(initialDirectory: initialDirectory, result: result)
    }
  }

  private func openLocalSubtitlePicker(initialDirectory: String?, result: @escaping FlutterResult) {
    if isPreWarmingPicker {
      // The user clicked while the invisible warm-up panel was up: end the
      // warm-up early and fall through to a real presentation.
      endSubtitlePickerPreWarm()
    } else if let existingPanel = subtitlePickerPanel, existingPanel.isVisible {
      existingPanel.makeKeyAndOrderFront(nil)
      result(["paths": [], "directory": NSNull()])
      return
    }

    let panel = makeSubtitlePickerPanel()
    // Resume at the directory resolved on the Dart side (last used → nearest
    // existing ancestor → user home). Setting directoryURL does not affect
    // the view style / sort / grouping the panel restores from the app's
    // defaults on a per-directory basis.
    if let initialDirectory, !initialDirectory.isEmpty {
      panel.directoryURL = URL(fileURLWithPath: initialDirectory, isDirectory: true)
    }
    subtitlePickerResult = result
    panel.begin { [weak self] response in
      guard let self = self, let pendingResult = self.subtitlePickerResult else {
        return
      }
      self.subtitlePickerResult = nil
      let paths = response == .OK ? panel.urls.map { $0.path } : []
      // Report the folder shown when the panel closed — including after the
      // user browsed somewhere and cancelled — so the Dart side can resume
      // there next time.
      pendingResult([
        "paths": paths,
        "directory": panel.directoryURL?.path as Any,
      ])
    }
  }

  private func makeSubtitlePickerPanel() -> NSOpenPanel {
    if let panel = subtitlePickerPanel {
      return panel
    }

    let panel = NSOpenPanel()
    panel.prompt = "选择"
    panel.allowsMultipleSelection = true
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.canCreateDirectories = false
    let subtitleExtensions = ["ass", "srt", "vtt", "sub", "ssa", "sup"]
    if #available(macOS 11.0, *) {
      let allowedTypes = subtitleExtensions.compactMap { UTType(filenameExtension: $0) }
      if !allowedTypes.isEmpty {
        panel.allowedContentTypes = allowedTypes
      }
    } else {
      panel.allowedFileTypes = subtitleExtensions
    }
    // Keep the panel above the player window (including fullscreen spaces)
    // since it is not attached as a sheet.
    panel.level = .modalPanel
    panel.collectionBehavior.insert(.fullScreenAuxiliary)
    panel.isReleasedWhenClosed = false
    subtitlePickerPanel = panel
    return panel
  }

  /// Spins up the out-of-process open/save panel service at startup so the
  /// first real picker open doesn't stall the main thread for ~0.5s. The
  /// panel is invisible and click-through while it warms up.
  private func preWarmSubtitlePicker() {
    guard !didPreWarmSubtitlePicker else { return }
    didPreWarmSubtitlePicker = true

    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
      guard let self = self,
            self.subtitlePickerResult == nil,
            self.subtitlePickerPanel?.isVisible != true else { return }
      let panel = self.makeSubtitlePickerPanel()
      self.isPreWarmingPicker = true
      panel.alphaValue = 0
      panel.ignoresMouseEvents = true
      panel.begin { _ in }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
        guard let self = self, self.isPreWarmingPicker else { return }
        self.endSubtitlePickerPreWarm()
      }
    }
  }

  private func endSubtitlePickerPreWarm() {
    isPreWarmingPicker = false
    guard let panel = subtitlePickerPanel else { return }
    panel.cancel(nil)
    panel.alphaValue = 1
    panel.ignoresMouseEvents = false
  }

  private func relayoutWindowButtons() {
    guard let closeButton = standardWindowButton(.closeButton),
          let minButton = standardWindowButton(.miniaturizeButton),
          let zoomButton = standardWindowButton(.zoomButton) else {
      return
    }

    // Get the titlebar view (parent of traffic light buttons)
    guard let titlebarView = closeButton.superview else {
      return
    }

    // Top padding to vertically center the buttons
    let topPadding: CGFloat = 18.0
    // Left padding for the first button
    let leftPadding: CGFloat = 16.0
    // Spacing between buttons
    let buttonSpacing: CGFloat = 8.0
    // Button width (standard macOS traffic light button size)
    let buttonWidth: CGFloat = 12.0

    // Disable autoresizing mask translation for all buttons
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    minButton.translatesAutoresizingMaskIntoConstraints = false
    zoomButton.translatesAutoresizingMaskIntoConstraints = false

    // Remove existing constraints
    titlebarView.removeConstraints(titlebarView.constraints)

    // Add constraints for close button
    titlebarView.addConstraints([
      NSLayoutConstraint(item: closeButton, attribute: .top, relatedBy: .equal, toItem: titlebarView, attribute: .top, multiplier: 1, constant: topPadding),
      NSLayoutConstraint(item: closeButton, attribute: .left, relatedBy: .equal, toItem: titlebarView, attribute: .left, multiplier: 1, constant: leftPadding)
    ])

    // Add constraints for minimize button
    titlebarView.addConstraints([
      NSLayoutConstraint(item: minButton, attribute: .top, relatedBy: .equal, toItem: titlebarView, attribute: .top, multiplier: 1, constant: topPadding),
      NSLayoutConstraint(item: minButton, attribute: .left, relatedBy: .equal, toItem: titlebarView, attribute: .left, multiplier: 1, constant: leftPadding + buttonWidth + buttonSpacing)
    ])

    // Add constraints for zoom button
    titlebarView.addConstraints([
      NSLayoutConstraint(item: zoomButton, attribute: .top, relatedBy: .equal, toItem: titlebarView, attribute: .top, multiplier: 1, constant: topPadding),
      NSLayoutConstraint(item: zoomButton, attribute: .left, relatedBy: .equal, toItem: titlebarView, attribute: .left, multiplier: 1, constant: leftPadding + (buttonWidth + buttonSpacing) * 2)
    ])
  }

  // MARK: - Top edge cover
  //
  // macOS draws a ~1px highlight along the very top edge of a titled window
  // (brightest when the window is key), which shows up as a light hairline
  // above the dark custom caption. It is painted above the content view, so
  // it cannot be covered from Flutter. Overlay it with a 2pt strip pinned to
  // the top of the titlebar container view — that view is kept above the
  // other frame subviews by AppKit (acrylic/window_manager reorder the frame
  // view's subviews during startup, which buries overlays added there).
  private var topEdgeCover: TopEdgeCoverView?
  // Last color pushed from the Dart side, so a cover recreated after a
  // titlebar-container rebuild immediately uses the app-theme color instead
  // of waiting for the next Dart push.
  private var topEdgeColor: NSColor = .windowBackgroundColor

  private func installTopEdgeCover() {
    guard let closeButton = standardWindowButton(.closeButton),
          let container = closeButton.superview?.superview else { return }
    // The container can be recreated after startup (e.g. when window_manager
    // inserts .fullSizeContentView), and AppKit re-adds its decoration view
    // (which paints the top-edge highlight) above the cover, so only skip
    // when the cover is attached to the current container AND on top.
    if let cover = topEdgeCover,
       cover.superview === container,
       container.subviews.last === cover {
      return
    }
    let cover = topEdgeCover ?? TopEdgeCoverView()
    cover.removeFromSuperview()
    cover.fillColor = topEdgeColor
    cover.frame = NSRect(x: 0,
                         y: container.bounds.height - 2,
                         width: container.bounds.width,
                         height: 2)
    cover.autoresizingMask = [.width, .minYMargin]
    container.addSubview(cover)
    topEdgeCover = cover
  }

  /// Method channel letting the Dart side push the current caption background
  /// color, so the cover matches the app theme (which follows app settings,
  /// not the system appearance).
  private func registerTopEdgeColorChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "fly_narwhal/window",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "setTopEdgeColor",
            let args = call.arguments as? [String: Any],
            let r = args["r"] as? Int,
            let g = args["g"] as? Int,
            let b = args["b"] as? Int else {
        result(FlutterMethodNotImplemented)
        return
      }
      let a = (args["a"] as? Int) ?? 255
      let color = NSColor(srgbRed: CGFloat(r) / 255,
                          green: CGFloat(g) / 255,
                          blue: CGFloat(b) / 255,
                          alpha: CGFloat(a) / 255)
      DispatchQueue.main.async {
        self?.topEdgeColor = color
        self?.topEdgeCover?.fillColor = color
      }
      result(nil)
    }
  }

  // MARK: - Display enumeration
  //
  // Mirrors the Windows `getAllDisplays` channel so Dart can validate window
  // geometry against every connected screen (restore on the display the
  // window was closed on, fall back to primary when that display is gone,
  // follow the main window's display when opening the player).
  private func registerDisplayEnumerationChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "fly_narwhal/window_display_frame",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "getAllDisplays" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(MainFlutterWindow.buildAllDisplays())
    }
  }

  /// All connected screens in the same top-left-origin coordinate space that
  /// window_manager uses for getBounds/setBounds: NSScreen frames are
  /// bottom-left-origin, flipped against `NSScreen.screens[0].frame.height`
  /// (the exact baseline window_manager's NSRect.topLeft conversion uses).
  private static func buildAllDisplays() -> [[String: Any]] {
    let screens = NSScreen.screens
    guard let baselineScreen = screens.first else { return [] }
    let baselineHeight = baselineScreen.frame.height

    func toTopLeftRect(_ rect: NSRect) -> [String: Any] {
      return [
        "x": Double(rect.origin.x),
        "y": Double(baselineHeight - (rect.origin.y + rect.height)),
        "width": Double(rect.width),
        "height": Double(rect.height),
      ]
    }

    return screens.map { screen in
      let screenNumber =
          (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
              as? NSNumber)?.uint32Value ?? 0
      return [
        "id": "macos-display-\(screenNumber)",
        "monitorBounds": toTopLeftRect(screen.frame),
        "workArea": toTopLeftRect(screen.visibleFrame),
        // screens.first is the screen carrying the menu bar (the designated
        // primary display); NSScreen.main follows the focused window and
        // must not be used here.
        "isPrimary": screen === baselineScreen,
        "scaleFactor": Double(screen.backingScaleFactor),
      ]
    }
  }
}

/// Covers the window's top-edge highlight with the caption background color.
final class TopEdgeCoverView: NSView {
  var fillColor: NSColor = .windowBackgroundColor {
    didSet { needsDisplay = true }
  }

  override func draw(_ dirtyRect: NSRect) {
    fillColor.setFill()
    bounds.fill()
  }
}
