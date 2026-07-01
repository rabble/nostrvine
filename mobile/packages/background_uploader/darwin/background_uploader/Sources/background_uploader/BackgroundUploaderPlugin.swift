// ABOUTME: Darwin (iOS + macOS) background uploader backed by a background
// ABOUTME: URLSession so transfers continue after the app is suspended.

#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import FlutterMacOS
#endif
import Foundation

/// Owns the process-wide background `URLSession` and fans its delegate events
/// out to every attached Flutter engine's method channel.
///
/// A process can host more than one Flutter engine (e.g. the Firebase-messaging
/// background engine), and each one registers this plugin. iOS forbids creating
/// two `URLSession`s that share one background identifier — doing so is
/// undefined behavior and historically crashes — so the session must be a
/// single process-wide instance rather than one per plugin. Events are
/// delivered to every attached channel; only the engine whose Dart isolate set
/// an `onUploadEvent` handler acts on it, the rest ignore it (mirroring the
/// Android multi-engine handling).
private final class BackgroundUploadCoordinator: NSObject {
  static let shared = BackgroundUploadCoordinator()

  /// Identifier of the shared background session. Must be stable across
  /// launches so the OS can re-attach in-flight tasks after a relaunch.
  fileprivate static let sessionIdentifier =
    "co.openvine.background_uploader.session"

  /// Channels for every attached engine. Mutated and read only on the main
  /// queue.
  private var channels: [FlutterMethodChannel] = []

  /// Response bodies accumulated per task identifier. URLSession delivers
  /// delegate callbacks for one session serially, so this needs no locking.
  private var responseData: [Int: Data] = [:]

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

  private lazy var session: URLSession = {
    let configuration = URLSessionConfiguration.background(
      withIdentifier: BackgroundUploadCoordinator.sessionIdentifier
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

  func attach(_ channel: FlutterMethodChannel) {
    channels.append(channel)
    // Touch the lazy session so its delegate is connected immediately. This
    // lets tasks that completed while the app was dead deliver their terminal
    // events as soon as an engine attaches.
    _ = session
  }

  func detach(_ channel: FlutterMethodChannel) {
    channels.removeAll { $0 === channel }
  }

  func enqueue(
    taskId: String,
    request: URLRequest,
    fileURL: URL,
    completion: @escaping () -> Void
  ) {
    // Dedupe: a retry/timeout can re-enqueue the same taskId while the first
    // transfer is still in flight (or was restored by the OS after a
    // relaunch). Skip starting a second parallel upload of the same file.
    session.getAllTasks { tasks in
      let alreadyRunning = tasks.contains { $0.taskDescription == taskId }
      if !alreadyRunning {
        let task = self.session.uploadTask(with: request, fromFile: fileURL)
        task.taskDescription = taskId
        task.resume()
      }
      DispatchQueue.main.async { completion() }
    }
  }

  func cancel(taskId: String, completion: @escaping () -> Void) {
    session.getAllTasks { tasks in
      for task in tasks where task.taskDescription == taskId {
        task.cancel()
      }
      DispatchQueue.main.async { completion() }
    }
  }

  func activeTaskIds(completion: @escaping ([String]) -> Void) {
    session.getAllTasks { tasks in
      let ids = tasks.compactMap { $0.taskDescription }
      DispatchQueue.main.async { completion(ids) }
    }
  }

  #if os(iOS)
  func beginForegroundSession(_ sessionId: String) {
    endForegroundSession(sessionId)
    let task = UIApplication.shared.beginBackgroundTask(
      withName: "co.openvine.background_uploader.\(sessionId)"
    ) { [weak self] in
      self?.endForegroundSession(sessionId)
    }
    backgroundTasks[sessionId] = task
  }

  func endForegroundSession(_ sessionId: String) {
    guard let task = backgroundTasks.removeValue(forKey: sessionId),
      task != .invalid
    else { return }
    UIApplication.shared.endBackgroundTask(task)
  }

  func handleBackgroundEvents(completionHandler: @escaping () -> Void) {
    backgroundCompletionHandler = completionHandler
    // Ensure the session (and its delegate) exists to drain pending events.
    _ = session
  }
  #endif

  private func sendEvent(_ payload: [String: Any?]) {
    DispatchQueue.main.async {
      for channel in self.channels {
        channel.invokeMethod("onUploadEvent", arguments: payload)
      }
    }
  }
}

extension BackgroundUploadCoordinator: URLSessionDataDelegate {
  func urlSession(
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

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive data: Data
  ) {
    responseData[dataTask.taskIdentifier, default: Data()].append(data)
  }

  func urlSession(
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

  #if os(iOS)
  func urlSessionDidFinishEvents(
    forBackgroundURLSession session: URLSession
  ) {
    DispatchQueue.main.async {
      let handler = self.backgroundCompletionHandler
      self.backgroundCompletionHandler = nil
      handler?()
    }
  }
  #endif
}

public class BackgroundUploaderPlugin: NSObject, FlutterPlugin {
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    super.init()
    BackgroundUploadCoordinator.shared.attach(channel)
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

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    BackgroundUploadCoordinator.shared.detach(channel)
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
    BackgroundUploadCoordinator.shared.beginForegroundSession(sessionId)
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
      BackgroundUploadCoordinator.shared.endForegroundSession(sessionId)
    }
    #endif
    result(nil)
  }

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

    BackgroundUploadCoordinator.shared.enqueue(
      taskId: taskId,
      request: request,
      fileURL: fileURL
    ) {
      result(nil)
    }
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

    BackgroundUploadCoordinator.shared.cancel(taskId: taskId) {
      result(nil)
    }
  }

  private func activeTaskIds(result: @escaping FlutterResult) {
    BackgroundUploadCoordinator.shared.activeTaskIds { ids in
      result(ids)
    }
  }
}

#if os(iOS)
extension BackgroundUploaderPlugin {
  public func application(
    _ application: UIApplication,
    handleEventsForBackgroundURLSession identifier: String,
    completionHandler: @escaping () -> Void
  ) -> Bool {
    guard identifier == BackgroundUploadCoordinator.sessionIdentifier else {
      return false
    }
    BackgroundUploadCoordinator.shared.handleBackgroundEvents(
      completionHandler: completionHandler
    )
    return true
  }
}
#endif
