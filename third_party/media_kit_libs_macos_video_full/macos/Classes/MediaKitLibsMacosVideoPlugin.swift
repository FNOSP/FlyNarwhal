import Cocoa
import FlutterMacOS

// No-op placeholder for the vendored media_kit_libs_macos_video override.
// The package only ships prebuilt XCFrameworks via CocoaPods, so the Swift
// class exists solely so Flutter's macOS plugin discovery can register the
// module. Behavior is identical to upstream media_kit_libs_macos_video 1.1.4.
public class MediaKitLibsMacosVideoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
  }
}
