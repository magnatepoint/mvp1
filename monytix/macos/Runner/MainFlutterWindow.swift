import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    
    // Ensure window can become key and main for file picker dialogs
    self.isReleasedWhenClosed = false
    self.level = .normal

    super.awakeFromNib()
  }
  
  override func makeKeyAndOrderFront(_ sender: Any?) {
    super.makeKeyAndOrderFront(sender)
    NSApp.activate(ignoringOtherApps: true)
  }
  
  // Ensure window can receive focus for file dialogs
  override var canBecomeKey: Bool {
    return true
  }
  
  override var canBecomeMain: Bool {
    return true
  }
}
