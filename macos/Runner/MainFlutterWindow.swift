import Cocoa
import FlutterMacOS
import UniformTypeIdentifiers

class MainFlutterWindow: NSWindow {
  // AppKit consults the window's contentView (not the deepest hit-tested
  // view) when deciding whether a mouse-down in the native title bar strip
  // may drag the window. Plugins (acrylic / window utils / window_manager)
  // can replace the contentView with their own wrapper at any time, so
  // re-install the opt-out override on every contentView change after the
  // window is awake. See disableNativeTitleBarDrag.
  private var isAwakeForDragOptOut = false
  override var contentView: NSView? {
    didSet {
      guard isAwakeForDragOptOut, let contentView else { return }
      Self.disableNativeTitleBarDrag(for: contentView)
    }
  }

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
    registerTopEdgeDimmerChannel(messenger: flutterViewController.engine.binaryMessenger)
    preWarmSubtitlePicker()

    Self.disableNativeTitleBarDrag(for: flutterViewController.view)
    if let contentView = self.contentView {
      Self.disableNativeTitleBarDrag(for: contentView)
    }
    // From now on, patch any contentView installed later (e.g. by
    // flutter_acrylic / macos_window_utils wrappers) via the didSet hook.
    isAwakeForDragOptOut = true

    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)
    installTopEdgeDimmer()

    self.standardWindowButton(.closeButton)?.isHidden = false
    self.standardWindowButton(.miniaturizeButton)?.isHidden = false
    self.standardWindowButton(.zoomButton)?.isHidden = false

    super.awakeFromNib()

    // Relayout traffic light buttons after window initialization
    DispatchQueue.main.async {
      self.relayoutWindowButtons()
      self.installTopEdgeDimmer()
    }

    // window_manager / flutter_acrylic can recreate or reorder the titlebar
    // container during startup and on style changes, which orphans the top
    // edge dimmer. Re-assert it (idempotently) whenever the window updates.
    for name in [NSWindow.didBecomeKeyNotification,
                 NSWindow.didResizeNotification,
                 NSWindow.didUpdateNotification] {
      NotificationCenter.default.addObserver(
        forName: name, object: self, queue: .main) { [weak self] _ in
        self?.installTopEdgeDimmer()
      }
    }

    // Failsafe for the hover-driven isMovable toggle (caption search box):
    // if the window loses key state while the pointer is over the capsule
    // and the exit event is swallowed, never leave the window immovable.
    NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification, object: self, queue: .main) { [weak self] _ in
      self?.isMovable = true
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

  // MARK: - Native title bar drag opt-out
  //
  // The engine's FlutterView does not implement mouseDown: itself (the
  // FlutterViewController handles mouse events), so it inherits NSView's
  // default mouseDownCanMoveWindow == true. With TitleBarStyle.hidden
  // (titlebarAppearsTransparent + .fullSizeContentView) AppKit keeps the
  // native ~28px title bar drag strip active: any mouse-down + move there
  // starts a native window drag — even though the events are also
  // forwarded to Flutter. Widgets that overlap the strip (e.g. the caption
  // search box) then see a pointer that never moves relative to the
  // window, so drag-to-select text silently turns into moving the window.
  // Window dragging is already handled on the Flutter side by
  // DragToMoveArea (windowManager.startDragging) across the whole 48px
  // caption, so teach FlutterView to opt out of the native behavior.
  // Applied at class level, so it also covers views created later (e.g.
  // the PiP window).
  private static func disableNativeTitleBarDrag(for view: NSView) {
    let flutterViewClass: AnyClass = type(of: view)
    // Never patch NSView itself (the nib installs a plain NSView placeholder
    // as contentView during -[NSWindow _initContent:...], before the window
    // is fully initialized); that would change behavior app-wide and touch
    // views during window construction.
    guard flutterViewClass != NSView.self else { return }
    let selector = NSSelectorFromString("mouseDownCanMoveWindow")
    // Only install the override when the class does not implement the
    // method itself (a future engine may handle this natively).
    guard
      let inherited = class_getInstanceMethod(NSView.self, selector),
      let current = class_getInstanceMethod(flutterViewClass, selector),
      inherited == current
    else { return }
    // The block MUST be @convention(block): passing a plain Swift closure to
    // imp_implementationWithBlock hands a thick function pointer to
    // Block_copy and segfaults.
    let block: @convention(block) (NSView) -> Bool = { _ in false }
    class_addMethod(flutterViewClass, selector, imp_implementationWithBlock(block),
                    method_getTypeEncoding(inherited))
  }

  // MARK: - Top edge dimmer
  //
  // macOS paints a ~1px highlight along the very top edge of a titled window
  // (brightest while key), which reads as a light hairline above the dark
  // custom caption. It is drawn above the content view, so Flutter cannot
  // touch it. Rather than hiding the hairline, soften it: overlay a 2pt strip
  // of the caption color at partial alpha. Over the caption the strip blends
  // the caption color into itself (invisible), while over the highlight it
  // pulls the bright line toward the caption color, keeping the edge visible
  // but much quieter. Pinned to the top of the titlebar container view —
  // AppKit keeps that view above the other frame subviews (acrylic /
  // window_manager reorder the frame view's subviews during startup, which
  // buries overlays added there).
  private var topEdgeDimmer: TopEdgeDimmerView?
  // Last color pushed from the Dart side, so a dimmer recreated after a
  // titlebar-container rebuild immediately uses the app-theme color instead
  // of waiting for the next Dart push.
  private var topEdgeDimColor: NSColor = .windowBackgroundColor

  private func installTopEdgeDimmer() {
    guard let closeButton = standardWindowButton(.closeButton),
          let container = closeButton.superview?.superview else { return }
    // The container can be recreated after startup (e.g. when window_manager
    // inserts .fullSizeContentView), and AppKit re-adds its decoration view
    // (which paints the top-edge highlight) above the dimmer, so only skip
    // when the dimmer is attached to the current container AND on top.
    if let dimmer = topEdgeDimmer,
       dimmer.superview === container,
       container.subviews.last === dimmer {
      return
    }
    let dimmer = topEdgeDimmer ?? TopEdgeDimmerView()
    dimmer.removeFromSuperview()
    dimmer.fillColor = topEdgeDimColor
    dimmer.frame = NSRect(x: 0,
                          y: container.bounds.height - 2,
                          width: container.bounds.width,
                          height: 2)
    dimmer.autoresizingMask = [.width, .minYMargin]
    container.addSubview(dimmer)
    topEdgeDimmer = dimmer
  }

  /// Method channel letting the Dart side push the current caption background
  /// color, so the dimmer matches the app theme (which follows app settings,
  /// not the system appearance).
  private func registerTopEdgeDimmerChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "fly_narwhal/window",
      binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setWindowMovable":
        // Toggled from Dart while the pointer hovers/leaves the caption
        // search box: macOS keeps the native title bar drag strip active
        // over the capsule (and on macOS 26 drags the window even when the
        // hit view reports mouseDownCanMoveWindow == false), which turns
        // drag-to-select text into moving the window. Marking the window
        // immovable while the capsule is hovered suppresses the native
        // drag; DragToMoveArea (windowManager.startDragging) still moves
        // the window from the rest of the caption because
        // performDrag(with:) is programmatic and ignores isMovable.
        let movable = (call.arguments as? [String: Any])?["movable"] as? Bool ?? true
        DispatchQueue.main.async {
          self?.isMovable = movable
        }
        result(nil)
      case "setTopEdgeDimColor":
        guard let args = call.arguments as? [String: Any],
              let r = args["r"] as? Int,
              let g = args["g"] as? Int,
              let b = args["b"] as? Int else {
          result(FlutterMethodNotImplemented)
          return
        }
        let a = (args["a"] as? Int) ?? 128
        let color = NSColor(srgbRed: CGFloat(r) / 255,
                            green: CGFloat(g) / 255,
                            blue: CGFloat(b) / 255,
                            alpha: CGFloat(a) / 255)
        DispatchQueue.main.async {
          self?.topEdgeDimColor = color
          self?.topEdgeDimmer?.fillColor = color
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Softens the window's top-edge highlight by blending the caption background
/// color over it at partial alpha.
final class TopEdgeDimmerView: NSView {
  var fillColor: NSColor = .windowBackgroundColor {
    didSet { needsDisplay = true }
  }

  override func draw(_ dirtyRect: NSRect) {
    fillColor.setFill()
    bounds.fill()
  }
}
