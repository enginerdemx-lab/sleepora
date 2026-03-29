import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    
    // Sabit telefon boyutu (Örn: iPhone 14 Pro Max oranlarına yakın, 400x800)
    let windowFrame = NSRect(x: 0, y: 0, width: 400, height: 800)
    
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    
    // Pencerenin boyutunu ortalayarak sabitle
    self.center()
    
    // İsteğe bağlı minimum/maksimum boyut (kullanıcı boyutunu değiştirmesin dersen)
    // self.minSize = NSSize(width: 400, height: 800)
    // self.maxSize = NSSize(width: 400, height: 800)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
