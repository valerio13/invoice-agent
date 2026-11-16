import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
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
}
