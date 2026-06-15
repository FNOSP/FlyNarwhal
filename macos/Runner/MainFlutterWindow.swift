import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.titlebarAppearsTransparent = true
    self.styleMask.insert(.fullSizeContentView)

    self.standardWindowButton(.closeButton)?.isHidden = false
    self.standardWindowButton(.miniaturizeButton)?.isHidden = false
    self.standardWindowButton(.zoomButton)?.isHidden = false

    super.awakeFromNib()

    // Relayout traffic light buttons after window initialization
    DispatchQueue.main.async {
      self.relayoutWindowButtons()
    }
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
}
