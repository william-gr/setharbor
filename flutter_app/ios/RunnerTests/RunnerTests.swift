import XCTest

/// Native OS flows supplement Flutter integration tests; simulator only in CI.
@MainActor
final class RunnerTests: XCTestCase {
  override func setUpWithError() throws {
    #if !targetEnvironment(simulator)
    throw NSError(domain: "SetHarborTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "UI tests require an iOS simulator; no personal device data may be changed."])
    #endif
  }
  private let app = XCUIApplication(bundleIdentifier: "com.william.treino")
  private func item(_ label: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
  }
  private func tapScrolled(_ label: String) {
    let element = item(label)
    for _ in 0..<25 {
      if element.exists && element.isHittable {
        // Flutter scroll physics do not participate in XCTest's UIKit idle check.
        // Require a stable accessibility frame before synthesizing the touch.
        var previous = CGRect.null
        var changedAt = Date()
        let stable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
          guard element.exists && element.isHittable else { return false }
          let frame = element.frame
          if frame != previous { previous = frame; changedAt = Date(); return false }
          return Date().timeIntervalSince(changedAt) >= 0.5
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [stable], timeout: 5), .completed)
        element.tap(); return
      }
      app.swipeUp()
    }
    XCTFail("Missing visible control: \(label)\n\(app.debugDescription)")
  }
  private func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
  }
  func test01NativeSharing() throws {
    continueAfterFailure = false
    app.launch()
    XCTAssertTrue(item("SetHarbor").waitForExistence(timeout: 30))
    tapScrolled("Planejar com ChatGPT")
    XCTAssertTrue(item("Copy").waitForExistence(timeout: 15), app.debugDescription)
    screenshot("fresh-native-share-sheet")
  }
  func testNativeLinksDocumentsAndSharing() throws {
    continueAfterFailure = false
    app.launch()
    XCTAssertTrue(item("SetHarbor").waitForExistence(timeout: 30))
    let plan: [String: Any] = [
      "format":"meu-treino-plan", "schemaVersion":1, "revision":100,
      "title":"iOS native link", "days":[["id":"ios-a", "name":"A", "focus":"Teste iOS", "exercises":[["id":"ios-slot", "catalogId":"barbell-bench-press", "name":"Supino reto barra", "sets":2, "reps":"8–12"]]]]
    ]
    let bytes = try JSONSerialization.data(withJSONObject: plan)
    let encoded = bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    let url = try XCTUnwrap(URL(string: "setharbor://workout#v1.\(encoded)"))
    XCUIDevice.shared.system.open(url)
    XCTAssertTrue(item("Aplicar treino do link?").waitForExistence(timeout: 15))
    screenshot("warm-link-preview")
    item("Cancelar").tap()
    app.terminate()
    XCUIDevice.shared.system.open(url)
    XCTAssertTrue(item("Aplicar treino do link?").waitForExistence(timeout: 30))
    item("Aplicar treino").tap()
    XCTAssertTrue(item("iOS native link").waitForExistence(timeout: 15))
    screenshot("cold-link-applied")
    tapScrolled("Exportar backup")
    let save = app.buttons["Save"].firstMatch
    XCTAssertTrue(save.waitForExistence(timeout: 15), app.debugDescription)
    let filename = app.textFields["DOCPicker.filenameTextField"]
    XCTAssertTrue(filename.exists)
    filename.tap(); filename.typeText("-" + String(UUID().uuidString.prefix(8)))
    let backupName = try XCTUnwrap(filename.value as? String)
    screenshot("native-export-picker"); save.tap()
    XCTAssertTrue(item("Backup exportado.").waitForExistence(timeout: 15), app.debugDescription)
    tapScrolled("Restaurar backup")
    let file = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", backupName)).firstMatch
    XCTAssertTrue(file.waitForExistence(timeout: 15), app.debugDescription)
    screenshot("native-import-picker"); file.tap()
    XCTAssertTrue(item("Restaurar backup?").waitForExistence(timeout: 15), app.debugDescription)
    item("Restaurar").tap()
    XCTAssertTrue(item("Backup restaurado.").waitForExistence(timeout: 15))
    let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: item("Backup restaurado."))
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed)
    tapScrolled("Planejar com ChatGPT")
    XCTAssertTrue(item("Copy").waitForExistence(timeout: 15), app.debugDescription)
    screenshot("native-share-sheet")
  }
}
