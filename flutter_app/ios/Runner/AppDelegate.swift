import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    PlatformBridge.shared.connect(engineBridge.applicationRegistrar.messenger())
  }
}

final class PlatformBridge: NSObject, UIDocumentPickerDelegate {
  static let shared = PlatformBridge()
  private var channel: FlutterMethodChannel?
  private var pendingLink: String?
  private var ready = false
  private var documentResult: FlutterResult?
  private var exporting = false
  private var documentLimit = 0
  private var exportFile: URL?
  private let io = DispatchQueue(label: "setharbor.storage")
  private var stateURL: URL {
    get throws {
      let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
      return root.appendingPathComponent("training-flutter.json")
    }
  }
  private var presenter: UIViewController? {
    // Document providers can leave their own hosted key windows in this process.
    // Always present app UI from the Flutter window in the active app scene.
    var current = UIApplication.shared.connectedScenes
      .filter { $0.activationState == .foregroundActive }
      .compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
      .first { !$0.isHidden && $0.rootViewController is FlutterViewController }?.rootViewController
    while let presented = current?.presentedViewController, !presented.isBeingDismissed { current = presented }
    return current
  }
  func receive(_ url: URL) {
    if ready { channel?.invokeMethod("link", arguments: url.absoluteString) }
    else { pendingLink = url.absoluteString }
  }
  func connect(_ messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.william.treino/platform", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in self?.handle(call, result) }
  }
  private func handle(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    #if DEBUG
    NSLog("SetHarbor platform method: %@", call.method)
    #endif
    do {
      switch call.method {
      case "testEnvironment":
        #if targetEnvironment(simulator)
        result(true)
        #else
        result(false)
        #endif
      case "readState":
        let url = try stateURL
        result(FileManager.default.fileExists(atPath: url.path) ? try String(contentsOf: url, encoding: .utf8) : nil)
      case "readLegacy": result("{}")
      case "writeState":
        guard let text = call.arguments as? String, let bytes = text.data(using: .utf8) else { throw BridgeError.invalid }
        io.async {
          do { try bytes.write(to: self.stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]); DispatchQueue.main.async { result(nil) } }
          catch { DispatchQueue.main.async { result(FlutterError(code: "storage", message: "Falha ao gravar. Seu treino continua aberto.", details: nil)) } }
        }
      case "initialLink": ready = true; result(pendingLink); pendingLink = nil
      case "openUrl":
        guard let text = call.arguments as? String, let url = URL(string: text) else { throw BridgeError.invalid }
        UIApplication.shared.open(url) { success in result(success ? nil : FlutterError(code: "url", message: "Não foi possível abrir o link.", details: nil)) }
      case "linkSettings":
        guard let url = URL(string: UIApplication.openSettingsURLString) else { throw BridgeError.invalid }
        UIApplication.shared.open(url) { _ in result(nil) }
      case "share":
        guard let text = call.arguments as? String, let controller = presenter else { throw BridgeError.invalid }
        let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        sheet.popoverPresentationController?.sourceView = controller.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
        controller.present(sheet, animated: true); result(nil)
      case "pickDocument", "exportDocument":
        guard documentResult == nil, let controller = presenter else { throw BridgeError.invalid }
        exporting = call.method == "exportDocument"
        let picker: UIDocumentPickerViewController
        if exporting {
          guard let text = call.arguments as? String else { throw BridgeError.invalid }
          let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
          try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
          let file = directory.appendingPathComponent("meu-treino-backup.json")
          try text.write(to: file, atomically: true, encoding: .utf8)
          exportFile = file
          picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
        } else {
          guard let limit = call.arguments as? Int else { throw BridgeError.invalid }
          documentLimit = limit
          picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true)
        }
        // Files owns the user-selected backup location, including external
        // storage. Keep its location history rather than forcing our sandbox.
        documentResult = result
        picker.delegate = self; picker.allowsMultipleSelection = false
        controller.present(picker, animated: true)
      case "fetchPlan":
        guard let text = call.arguments as? String, let components = URLComponents(string: text), components.scheme == "https", components.host != nil, components.user == nil, let url = components.url else { throw BridgeError.invalid }
        PlanFetch.start(url) { response in result(response) }
      default: result(FlutterMethodNotImplemented)
      }
    } catch { result(FlutterError(code: "platform", message: "Não foi possível concluir a operação: \(error.localizedDescription)", details: nil)) }
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    documentResult?(exporting ? false : nil); clearPicker()
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    defer { clearPicker() }
    if exporting { documentResult?(true); return }
    guard let url = urls.first else { documentResult?(nil); return }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size <= documentLimit else { throw BridgeError.invalid }
      let data = try Data(contentsOf: url)
      guard data.count <= documentLimit, let text = String(data: data, encoding: .utf8) else { throw BridgeError.invalid }
      documentResult?(text)
    } catch { documentResult?(FlutterError(code: "document", message: "Arquivo inválido ou muito grande.", details: nil)) }
  }
  private func clearPicker() {
    documentResult = nil
    if let file = exportFile { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
    exportFile = nil
  }
}
private enum BridgeError: Error { case invalid }

/// Ephemeral fetch: no redirects, default TLS validation, strict 1 MB limit.
private final class PlanFetch: NSObject, URLSessionDataDelegate {
  private var bytes = Data()
  private var completion: ((Any?) -> Void)?
  private var valid = false
  static func start(_ url: URL, completion: @escaping (Any?) -> Void) {
    let fetch = PlanFetch(); fetch.completion = completion
    let config = URLSessionConfiguration.ephemeral
    config.timeoutIntervalForRequest = 10; config.timeoutIntervalForResource = 15
    URLSession(configuration: config, delegate: fetch, delegateQueue: nil).dataTask(with: url).resume()
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
    valid = (response as? HTTPURLResponse)?.statusCode == 200 && response.expectedContentLength <= 1024 * 1024
    completionHandler(valid ? .allow : .cancel)
  }
  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    if bytes.count + data.count > 1024 * 1024 { valid = false; dataTask.cancel() } else { bytes.append(data) }
  }
  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    let text = String(data: bytes, encoding: .utf8)
    let response: Any? = error == nil && valid && text != nil ? text : FlutterError(code: "network", message: "Não foi possível buscar a ficha. O treino offline continua disponível.", details: nil)
    let done = completion; completion = nil
    DispatchQueue.main.async { done?(response) }; session.finishTasksAndInvalidate()
  }
}
