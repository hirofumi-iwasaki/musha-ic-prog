import Cocoa
import FlutterMacOS

private final class FileDropHostView: NSView {
  var channel: FlutterMethodChannel?
  private var accessURLs: [String: URL] = [:]

  override var isFlipped: Bool { true }

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    registerForDraggedTypes([.fileURL, .URL])
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    registerForDraggedTypes([.fileURL, .URL])
  }

  private func urls(_ sender: NSDraggingInfo) -> [URL] {
    sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
  }

  private func point(_ sender: NSDraggingInfo) -> NSPoint {
    convert(sender.draggingLocation, from: nil)
  }

  override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
  override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

  override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let dropped = urls(sender)
    guard dropped.count == 1 else {
      channel?.invokeMethod("fileDropError", arguments: ["message": "Drop exactly one file at a time."])
      return false
    }
    let url = dropped[0]
    var isDirectory: ObjCBool = false
    guard url.isFileURL,
          FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          !isDirectory.boolValue else {
      channel?.invokeMethod("fileDropError", arguments: ["message": "The dropped item is not a readable file."])
      return false
    }
    var scopeToken: String?
    if url.startAccessingSecurityScopedResource() {
      let token = UUID().uuidString
      accessURLs[token] = url
      scopeToken = token
    }
    let location = point(sender)
    var arguments: [String: Any] = [
      "path": url.path,
      "x": location.x,
      "y": location.y,
    ]
    if let scopeToken { arguments["scopeToken"] = scopeToken }
    channel?.invokeMethod("fileDropped", arguments: arguments) { [weak self] _ in
      if let scopeToken { self?.releaseScope(scopeToken) }
    }
    return true
  }

  func releaseScope(_ token: String) {
    guard let url = accessURLs.removeValue(forKey: token) else { return }
    url.stopAccessingSecurityScopedResource()
  }

  deinit { for url in accessURLs.values { url.stopAccessingSecurityScopedResource() } }
}

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var closeApproved = false
  private var closePending = false

  func requestClose(_ completion: @escaping (Bool) -> Void) {
    guard let channel = dropChannel else { completion(false); return }
    channel.invokeMethod("closeRequested", arguments: nil) { result in
      completion((result as? Bool) == true)
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if closeApproved { return true }
    guard !closePending else { return false }
    closePending = true
    requestClose { [weak self] allowed in
      guard let self else { return }
      self.closePending = false
      if allowed { self.closeApproved = true; self.performClose(nil) }
    }
    return false
  }

  private var dropChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let host = FileDropHostView(frame: frame)
    let hostController = NSViewController()
    hostController.view = host
    hostController.addChild(flutterViewController)
    flutterViewController.view.frame = host.bounds
    flutterViewController.view.autoresizingMask = [.width, .height]
    host.addSubview(flutterViewController.view)
    self.contentViewController = hostController

    var windowFrame = self.frame
    self.minSize = NSSize(width: 1000, height: 700)
    windowFrame.size.width = max(windowFrame.size.width, 1180)
    windowFrame.size.height = max(windowFrame.size.height, 780)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    dropChannel = FlutterMethodChannel(
      name: "mushagaeshi/programmer_files",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    host.channel = dropChannel
    dropChannel?.setMethodCallHandler { [weak host] call, result in
      guard call.method == "releaseDropScope", let token = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      host?.releaseScope(token)
      result(nil)
    }
    super.awakeFromNib()
    self.delegate = self
  }
}
