import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Opaque native window; Flutter paints the shell canvas and chrome.
    self.isOpaque = true
    self.backgroundColor = NSColor.windowBackgroundColor
    flutterViewController.backgroundColor = NSColor.windowBackgroundColor
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
