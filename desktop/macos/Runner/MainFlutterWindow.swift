import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    skipFontPanelUpdates()

    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // The layout is drawn for 1336 x 1000 points, the size of the design mockups.
    self.setContentSize(NSSize(width: 1336, height: 1000))
    self.contentMinSize = NSSize(width: 1180, height: 860)
    self.center()
    self.title = "Invoice agent"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// Flutter types into a hidden NSTextView. When it gets focus, AppKit updates the font panel,
  /// and on some macOS installs (older Macs running a patched system) loading the font panel
  /// favourites crashes the app. The app never shows the font panel, so the update is skipped.
  private func skipFontPanelUpdates() {
    let selector = NSSelectorFromString("updateFontPanel")
    guard let method = class_getInstanceMethod(NSTextView.self, selector) else { return }
    let skip: @convention(block) (AnyObject) -> Void = { _ in }
    method_setImplementation(method, imp_implementationWithBlock(skip))
  }
}
