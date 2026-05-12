import XCTest
import WebKit
@testable import Runner

/// Native coverage for the Nostr bridge frame-attestation plugin. The plugin's
/// security guarantees rest on two pieces of native logic that the Dart-side
/// mocks cannot cover:
///
///   1. The single-instance attach/detach state machine that decides whether
///      a second sandbox WebView is allowed to overwrite an existing
///      attestation handler. If this lets a second attach silently win, the
///      previous sandbox stops receiving attested events and degrades to
///      nonce-only enforcement without any signal — exactly the failure mode
///      the structural fix in this PR is meant to prevent.
///
///   2. The WKScriptMessage → Dart event translation that determines what
///      isMainFrame value reaches Dart. If the dictionary shape regresses or
///      starts including unintended fields, downstream callers may grow
///      reliance on data the contract no longer guarantees.
///
/// Both are pure logic, extracted so they can be exercised here without a
/// real WKWebView, FlutterEngine, or Dart channel. The
/// WKUserContentController integration test below additionally proves the
/// WebKit APIs the plugin depends on (script handler add/remove + document-
/// start user script with main-frame-only) actually behave as expected on
/// the iOS version this app targets.

final class NostrBridgeAttestationPolicyTests: XCTestCase {
  func testInitialStateNoAttachment() {
    let policy = NostrBridgeAttestationPolicy()
    XCTAssertNil(policy.attachedWebViewId)
  }

  func testAttachReturnsOkWhenNothingAttached() {
    let policy = NostrBridgeAttestationPolicy()
    XCTAssertEqual(policy.attach(webViewId: 1), .ok)
    XCTAssertEqual(policy.attachedWebViewId, 1)
  }

  func testAttachIsIdempotentForSameWebViewId() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 7)
    XCTAssertEqual(policy.attach(webViewId: 7), .noOp)
    XCTAssertEqual(policy.attachedWebViewId, 7)
  }

  func testAttachRefusesDifferentWebViewIdWhileOneIsAttached() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 1)
    XCTAssertEqual(policy.attach(webViewId: 2), .alreadyAttached(existing: 1))
    XCTAssertEqual(
      policy.attachedWebViewId, 1,
      "second attach must not overwrite the existing attachment"
    )
  }

  func testDetachClearsMatchingAttachment() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 9)
    XCTAssertTrue(policy.detach(webViewId: 9))
    XCTAssertNil(policy.attachedWebViewId)
  }

  func testDetachIsNoOpForUnattachedWebViewId() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 1)
    XCTAssertFalse(policy.detach(webViewId: 2))
    XCTAssertEqual(
      policy.attachedWebViewId, 1,
      "stale detach call must not clear the live attachment"
    )
  }

  func testDetachIsNoOpWhenNothingAttached() {
    let policy = NostrBridgeAttestationPolicy()
    XCTAssertFalse(policy.detach(webViewId: 1))
    XCTAssertNil(policy.attachedWebViewId)
  }

  func testReAttachAfterDetachSucceeds() {
    let policy = NostrBridgeAttestationPolicy()
    _ = policy.attach(webViewId: 1)
    _ = policy.detach(webViewId: 1)
    XCTAssertEqual(policy.attach(webViewId: 2), .ok)
    XCTAssertEqual(policy.attachedWebViewId, 2)
  }
}

final class FrameAttestingScriptMessageHandlerTests: XCTestCase {
  func testEventPayloadIncludesMessageBody() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "hello",
      isMainFrame: true
    )
    XCTAssertEqual(payload["message"] as? String, "hello")
  }

  func testEventPayloadIncludesIsMainFrameTrue() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "x",
      isMainFrame: true
    )
    XCTAssertEqual(payload["isMainFrame"] as? Bool, true)
  }

  func testEventPayloadIncludesIsMainFrameFalse() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "x",
      isMainFrame: false
    )
    XCTAssertEqual(payload["isMainFrame"] as? Bool, false)
  }

  func testEventPayloadHasOnlyMessageAndIsMainFrame() {
    let payload = FrameAttestingScriptMessageHandler.eventPayload(
      messageBody: "x",
      isMainFrame: true
    )
    XCTAssertEqual(
      Set(payload.keys), ["message", "isMainFrame"],
      "payload must not leak host/port/scheme or any other origin fields — Dart only consumes message + isMainFrame"
    )
  }
}

/// Smoke test for the WebKit APIs the plugin depends on. If a future iOS SDK
/// change deprecates or alters the behaviour of `removeScriptMessageHandler`
/// or `addUserScript(_:atDocumentStart:forMainFrameOnly:)` this fails loudly.
final class WebKitContentControllerIntegrationTests: XCTestCase {
  func testHandlerSwapAndDocumentStartUserScriptInstallation() {
    let webView = WKWebView()
    let contentController = webView.configuration.userContentController
    let bridgeName = NostrBridgeAttestationPlugin.bridgeChannelName

    // Simulate the pigeon-managed handler that addJavaScriptChannel installs.
    let pigeonStub = FrameAttestingScriptMessageHandler { _ in }
    contentController.add(pigeonStub, name: bridgeName)

    // The plugin's attach path swaps it for the attesting handler.
    contentController.removeScriptMessageHandler(forName: bridgeName)
    let attesting = FrameAttestingScriptMessageHandler { _ in }
    contentController.add(attesting, name: bridgeName)

    // And installs the bootstrap script at document start, main-frame only.
    XCTAssertEqual(contentController.userScripts.count, 0)
    let userScript = WKUserScript(
      source: "void(0);",
      injectionTime: .atDocumentStart,
      forMainFrameOnly: true
    )
    contentController.addUserScript(userScript)

    XCTAssertEqual(contentController.userScripts.count, 1)
    let installed = contentController.userScripts.first
    XCTAssertEqual(installed?.injectionTime, .atDocumentStart)
    XCTAssertTrue(installed?.isForMainFrameOnly ?? false)
  }
}
