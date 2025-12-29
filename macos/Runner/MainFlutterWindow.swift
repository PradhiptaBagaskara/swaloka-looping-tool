import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Configure window
    self.minSize = NSSize(width: 1280, height: 800)
    self.title = "Swaloka Looping Tool"

    // Disable window auto-save to prevent getting stuck with a tiny window from a previous session
    self.setFrameAutosaveName("")
  }
}
