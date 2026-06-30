// ABOUTME: Darwin (iOS + macOS) background uploader backed by a background
// ABOUTME: URLSession so transfers continue after the app is suspended.

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation

public class BackgroundUploaderPlugin: NSObject, FlutterPlugin {
  /// Identifier of the shared background session. Must be stable across
  /// launches so the OS can re-attach in-flight tasks after a relaunch.
  private static let sessionIdentifier = "co.openvine.background_uploader.session"

  private let channel: FlutterMethodChannel

  #if os(iOS)
  /// Held while the OS relaunches us in the background to drain session
  /// events; called once those events have been delivered. iOS-only — macOS
  /// apps are not relaunched to finish background sessions.
  private var backgroundCompletionHandler: (() -> Void)?

  /// Background-task assertions keyed by session id, so the app keeps running
  /// long enough to finish in-process publish steps (signing, relay broadcast)
  /// after the background URLSession upload completes while suspended.
  private var backgroundTasks: [String: UIBackgroundTaskIdentifier] = [:]
  #endif

  /// Response bodies accumulated per task identifier. URLSession delivers
  /// delegate callbacks for one session serially, so this needs no locking.
  private var responseData: [Int: Data] = [:]

  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(
      withIdentifier: BackgroundUploaderPlugin.sessionIdentifier
    )
    #if os(iOS)
    configuration.sessionSendsLaunchEvents = true
    #endif
    configuration.isDiscretionary = false
    return URLSession(
      configuration: configuration,
      delegate: self,
      delegateQueue: nil
    )
  }()

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    // Touch the lazy session so its delegate is connected immediately. This
    // lets tasks that completed while the app was dead deliver their terminal
    // events as soon as the engine attaches.
    _ = session
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #elseif os(macOS)
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "background_uploader",
      binaryMessenger: messenger
    )
    let instance = BackgroundUploaderPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
    #if os(iOS)
    registrar.addApplicationDelegate(instance)
    #endif
  }

  public func handle(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "isSupported":
      result(true)
    case "enqueue":
      enqueue(call.arguments, result: result)
    case "cancel":
      cancel(call.arguments, result: result)
    case "activeTaskIds":
      activeTaskIds(result: result)
    case "beginForegroundSession":
      beginForegroundSession(call.arguments, result: result)
    case "endForegroundSession":
      endForegroundSession(call.arguments, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Begins a background-task assertion on iOS so in-process work survives a
  /// brief suspension; a no-op on macOS, which does not background-restrict
  /// network the way iOS does.
  private func beginForegroundSession(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    #if os(iOS)
    guard
      let args = arguments as? [String: Any],
      let sessionId = args["sessionId"] as? String, !sessionId.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "beginForegroundSession requires a sessionId",
          details: nil
        )
      )
      return
    }
    endBackgroundTask(sessionId)
    let task = UIApplication.shared.beginBackgroundTask(
      withName: "co.openvine.background_uploader.\(sessionId)"
    ) { [weak self] in
      self?.endBackgroundTask(sessionId)
    }
    backgroundTasks[sessionId] = task
    #endif
    result(nil)
  }

  private func endForegroundSession(
    _ arguments: Any?,
    result: @escaping FlutterResult
  ) {
    #if os(iOS)
    if let args = arguments as? [String: Any],
      let sessionId = args["sessionId"] as? String {
      endBackgroundTask(sessionId)
    }
    #endif
    result(nil)
  }

  #if os(iOS)
  private func endBackgroundTask(_ sessionId: String) {
    guard let task = backgroundTasks.removeValue(forKey: sessionId),
      task != .invalid
    else { return }
    UIApplication.shared.endBackgroundTask(task)
  }
  #endif

  private func enqueue(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let taskId = args["taskId"] as? String, !taskId.isEmpty,
      let urlString = args["url"] as? String,
      let url = URL(string: urlString),
      let filePath = args["filePath"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "enqueue requires taskId, url, and filePath",
          details: nil
        )
      )
      return
    }

    let fileURL = URL(fileURLWithPath: filePath)
    guard FileManager.default.fileExists(atPath: filePath) else {
      result(
        FlutterError(
          code: "file_not_found",
          message: "No file at \(filePath)",
          details: nil
        )
      )
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = (args["method"] as? String) ?? "PUT"
    if let headers = args["headers"] as? [String: Any] {
      for (key, value) in headers {
        request.setValue(String(describing: value), forHTTPHeaderField: key)
      }
    }

    let task = session.uploadTask(with: request, fromFile: fileURL)
    task.taskDescription = taskId
    task.resume()
    result(nil)
  }

  private func cancel(_ arguments: Any?, result: @escaping FlutterResult) {
    guard
      let args = arguments as? [String: Any],
      let taskId = args["taskId"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "cancel requires a taskId",
          details: nil
        )
      )
      return
    }

    session.getAllTasks { tasks in
      for task in tasks where task.taskDescription == taskId {
        task.cancel()
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func activeTaskIds(result: @escaping FlutterResult) {
    session.getAllTasks { tasks in
      let ids = tasks.compactMap { $0.taskDescription }
      DispatchQueue.main.async { result(ids) }
    }
  }

  private func sendEvent(_ payload: [String: Any?]) {
    DispatchQueue.main.async {
      self.channel.invokeMethod("onUploadEvent", arguments: payload)
    }
  }
}

extension BackgroundUploaderPlugin: URLSessionDataDelegate {
  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    guard
      let taskId = task.taskDescription,
      totalBytesExpectedToSend > 0
    else { return }
    let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
    sendEvent([
      "taskId": taskId,
      "status": "running",
      "progress": min(max(progress, 0), 1),
    ])
  }

  public func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    responseData[dataTask.taskIdentifier, default: Data()].append(data)
  }

  public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    let taskId = task.taskDescription ?? ""
    let body = responseData.removeValue(forKey: task.taskIdentifier)
    let responseBody = body.flatMap { String(data: $0, encoding: .utf8) }

    if let error = error {
      let isCancelled = (error as NSError).code == NSURLErrorCancelled
      sendEvent([
        "taskId": taskId,
        "status": isCancelled ? "cancelled" : "failed",
        "progress": 0,
        "error": error.localizedDescription,
      ])
      return
    }

    let statusCode = (task.response as? HTTPURLResponse)?.statusCode
    let isSuccess = statusCode.map { (200..<300).contains($0) } ?? false
    sendEvent([
      "taskId": taskId,
      "status": isSuccess ? "completed" : "failed",
      "progress": isSuccess ? 1 : 0,
      "httpStatusCode": statusCode,
      "responseBody": responseBody,
    ])
  }
}

#if os(iOS)
extension BackgroundUploaderPlugin {
  public func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) -> Bool {
    guard identifier == BackgroundUploaderPlugin.sessionIdentifier else {
      return false
    }
    backgroundCompletionHandler = completionHandler
    // Ensure the session (and its delegate) exists to drain pending events.
    _ = session
    return true
  }

  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    DispatchQueue.main.async {
      let handler = self.backgroundCompletionHandler
      self.backgroundCompletionHandler = nil
      handler?()
    }
  }
}
#endif
