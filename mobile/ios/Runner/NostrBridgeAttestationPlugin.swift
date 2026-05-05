import Flutter
import WebKit
import webview_flutter_wkwebview

/// Thin native plugin that replaces the pigeon-managed WKScriptMessageHandler
/// for `divineSandboxBridge` with one that includes WKScriptMessage.frameInfo,
/// and streams attested messages (with isMainFrame + securityOrigin) back to
/// Dart via an EventChannel.
///
/// The pigeon layer exposes WKScriptMessage.name and .body only; .frameInfo is
/// absent from the pigeon definition, so this plugin is required to surface it.
///
/// Dart drives lifecycle via two calls:
///   attach(webViewId)  — replaces the handler for the given WebView
///   detach(webViewId)  — removes the handler
///
/// The EventChannel delivers maps:
///   { "message": String, "isMainFrame": Bool, "host": String,
///     "port": Int, "scheme": String }
final class NostrBridgeAttestationPlugin: NSObject, FlutterStreamHandler {
  static let methodChannelName = "co.openvine/nostr_bridge_attestation"
  static let eventChannelName = "co.openvine/nostr_bridge_attestation/events"
  private static let bridgeChannelName = "divineSandboxBridge"

  // Retained for the lifetime of the engine.
  private static var shared: NostrBridgeAttestationPlugin?

  private let pluginRegistry: FlutterPluginRegistry
  private var handlers: [Int64: FrameAttestingScriptMessageHandler] = [:]
  private var eventSink: FlutterEventSink?

  private init(pluginRegistry: FlutterPluginRegistry) {
    self.pluginRegistry = pluginRegistry
  }

  // MARK: - Registration (called from AppDelegate)

  static func setup(
    messenger: FlutterBinaryMessenger,
    pluginRegistry: FlutterPluginRegistry
  ) {
    let plugin = NostrBridgeAttestationPlugin(pluginRegistry: pluginRegistry)
    shared = plugin

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    methodChannel.setMethodCallHandler { [weak plugin] call, result in
      plugin?.handle(call, result: result)
    }

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: messenger
    )
    eventChannel.setStreamHandler(plugin)
  }

  // MARK: - Method channel handler

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard
      let args = call.arguments as? [String: Any],
      let webViewId = args["webViewId"] as? Int64
    else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "webViewId (Int64) required",
        details: nil
      ))
      return
    }

    switch call.method {
    case "attach":
      attachHandler(webViewId: webViewId, result: result)
    case "detach":
      detachHandler(webViewId: webViewId)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - FlutterStreamHandler

  func onListen(
    withArguments _: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments _: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  // MARK: - Private

  private func attachHandler(webViewId: Int64, result: FlutterResult) {
    guard let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
      forIdentifier: webViewId,
      withPluginRegistry: pluginRegistry
    ) else {
      result(FlutterError(
        code: "WEBVIEW_NOT_FOUND",
        message: "No WKWebView found for identifier \(webViewId)",
        details: nil
      ))
      return
    }

    let contentController = webView.configuration.userContentController

    // Remove the pigeon-managed handler installed by addJavaScriptChannel.
    // The WKUserScript that creates window.divineSandboxBridge as an alias
    // for webkit.messageHandlers.divineSandboxBridge remains intact and
    // continues to route postMessage() calls to whichever handler owns the
    // name — now ours.
    contentController.removeScriptMessageHandler(
      forName: NostrBridgeAttestationPlugin.bridgeChannelName
    )

    let handler = FrameAttestingScriptMessageHandler { [weak self] event in
      self?.eventSink?(event)
    }
    contentController.add(
      handler,
      name: NostrBridgeAttestationPlugin.bridgeChannelName
    )
    handlers[webViewId] = handler

    result(nil)
  }

  private func detachHandler(webViewId: Int64) {
    guard let webView = FWFWebViewFlutterWKWebViewExternalAPI.webView(
      forIdentifier: webViewId,
      withPluginRegistry: pluginRegistry
    ) else { return }

    webView.configuration.userContentController
      .removeScriptMessageHandler(forName: NostrBridgeAttestationPlugin.bridgeChannelName)
    handlers.removeValue(forKey: webViewId)
  }
}

// MARK: - FrameAttestingScriptMessageHandler

final class FrameAttestingScriptMessageHandler: NSObject, WKScriptMessageHandler {
  private let deliver: ([String: Any]) -> Void

  init(deliver: @escaping ([String: Any]) -> Void) {
    self.deliver = deliver
  }

  func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    let frame = message.frameInfo
    let origin = frame.securityOrigin
    deliver([
      "message": message.body as? String ?? "",
      "isMainFrame": frame.isMainFrame,
      "host": origin.host,
      "port": origin.port,
      "scheme": origin.protocol,
    ])
  }
}
