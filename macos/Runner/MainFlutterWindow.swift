import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    var windowFrame = self.frame
    self.minSize = NSSize(width: 1000, height: 700)
    windowFrame.size.width = max(windowFrame.size.width, 1180)
    windowFrame.size.height = max(windowFrame.size.height, 780)
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
