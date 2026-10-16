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
  private func localFilesRoot() {
    let root = app.navigationBars.descendants(matching: .any).matching(NSPredicate(format: "identifier != %@ AND (label == %@ OR label BEGINSWITH %@)", "BackButton", "On My iPhone", "On My iPhone,")).firstMatch
    let back = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@", "BackButton", "On My iPhone")).firstMatch
    let local = app.cells.containing(.staticText, identifier: "On My iPhone").firstMatch
    // Files publishes its toolbar before the location/back controls on a cold
    // provider. Wait for a usable navigation state before deciding what to tap.
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      (root.exists && root.isHittable) || (back.exists && back.isHittable) || (local.exists && local.isHittable)
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed, app.debugDescription)
    if root.exists && root.isHittable { return }
    if back.exists && back.isHittable { back.tap() } else { local.tap() }
    XCTAssertTrue(root.waitForExistence(timeout: 15), app.debugDescription)
  }
  private func createBackupFolder(_ name: String) {
    let more = app.buttons["More"].firstMatch
    XCTAssertTrue(more.waitForExistence(timeout: 15), app.debugDescription)
    localFilesRoot()
    let root = app.navigationBars.descendants(matching: .any).matching(NSPredicate(format: "identifier != %@ AND (label == %@ OR label BEGINSWITH %@)", "BackButton", "On My iPhone", "On My iPhone,")).firstMatch
    XCTAssertTrue(root.waitForExistence(timeout: 15), app.debugDescription)
    more.tap()
    let newFolder = item("New Folder")
    XCTAssertTrue(newFolder.waitForExistence(timeout: 15), app.debugDescription)
    newFolder.tap()
    let inline = app.descendants(matching: .any).matching(identifier: "DOC.inlineRenameField").firstMatch
    let alertField = app.alerts.textFields.firstMatch
    let naming = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      inline.exists || alertField.exists
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [naming], timeout: 15), .completed, app.debugDescription)
    let field = inline.exists ? inline : alertField
    if let value = field.value as? String {
      field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
    }
    field.typeText(name)
    if inline.exists {
      // The Files text view treats injected newlines differently across SDKs.
      // Commit through its real keyboard action, as a user would.
      let done = app.keyboards.buttons["Done"].firstMatch
      XCTAssertTrue(done.waitForExistence(timeout: 15), app.debugDescription)
      done.tap()
    } else {
      let create = app.alerts.buttons["Create"].firstMatch
      if create.exists { create.tap() } else { app.alerts.buttons["Done"].firstMatch.tap() }
    }
    let title = app.navigationBars.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    // Files enters the new folder asynchronously after committing its name.
    // Wait for that navigation instead of racing it with another folder tap.
    XCTAssertTrue(title.waitForExistence(timeout: 15), app.debugDescription)
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
    let originalTitle = "iOS native link " + String(UUID().uuidString.prefix(8))
    let plan: [String: Any] = [
      "format":"meu-treino-plan", "schemaVersion":1, "revision":100,
      "title":originalTitle, "days":[["id":"ios-a", "name":"A", "focus":"Teste iOS", "exercises":[["id":"ios-slot", "catalogId":"barbell-bench-press", "name":"Supino reto barra", "sets":2, "reps":"8–12"]]]]
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
    XCTAssertTrue(item(originalTitle).waitForExistence(timeout: 15))
    screenshot("cold-link-applied")
    let folderName = "SetHarbor-E2E-" + String(UUID().uuidString.prefix(8))
    tapScrolled("Exportar backup")
    createBackupFolder(folderName)
    let save = app.buttons["Save"].firstMatch
    XCTAssertTrue(save.waitForExistence(timeout: 15), app.debugDescription)
    // Export pickers differ by OS/linked SDK: the filename editor is optional.
    // Verify the actual file roundtrip using a unique plan payload instead.
    let backupName = "meu-treino-backup"
    let saveEnabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
    XCTAssertEqual(XCTWaiter.wait(for: [saveEnabled], timeout: 15), .completed, app.debugDescription)
    screenshot("native-export-picker"); save.tap()
    let replace = app.buttons["Replace"].firstMatch
    if replace.waitForExistence(timeout: 2) { replace.tap() }
    XCTAssertTrue(item("Backup exportado.").waitForExistence(timeout: 15), app.debugDescription)
    var replacement = plan
    let replacementTitle = "Replacement " + originalTitle
    replacement["title"] = replacementTitle
    replacement["revision"] = 101
    let replacementData = try JSONSerialization.data(withJSONObject: replacement)
    let replacementEncoded = replacementData.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    XCUIDevice.shared.system.open(try XCTUnwrap(URL(string: "setharbor://workout#v1.\(replacementEncoded)")))
    XCTAssertTrue(item("Aplicar treino do link?").waitForExistence(timeout: 15))
    item("Aplicar treino").tap()
    XCTAssertTrue(item(replacementTitle).waitForExistence(timeout: 15))
    tapScrolled("Restaurar backup")
    let file = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR label == %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@", backupName, backupName + ".json", backupName + ",", backupName + ".json,")).firstMatch
    let currentFolder = app.navigationBars.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", folderName)).firstMatch
    XCTAssertTrue(app.buttons["More"].firstMatch.waitForExistence(timeout: 15), app.debugDescription)
    if !currentFolder.exists {
      localFilesRoot()
      let folder = app.cells.containing(.staticText, identifier: folderName).firstMatch
      XCTAssertTrue(folder.waitForExistence(timeout: 15), app.debugDescription)
      folder.tap()
    }
    XCTAssertTrue(file.waitForExistence(timeout: 15), app.debugDescription)
    screenshot("native-import-picker"); file.tap()
    XCTAssertTrue(item("Restaurar backup?").waitForExistence(timeout: 15), app.debugDescription)
    item("Restaurar").tap()
    XCTAssertTrue(item("Backup restaurado.").waitForExistence(timeout: 15))
    XCTAssertTrue(item(originalTitle).waitForExistence(timeout: 15), app.debugDescription)
    let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: item("Backup restaurado."))
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 8), .completed)
    tapScrolled("Planejar com ChatGPT")
    XCTAssertTrue(item("Copy").waitForExistence(timeout: 15), app.debugDescription)
    screenshot("native-share-sheet")
  }
}
