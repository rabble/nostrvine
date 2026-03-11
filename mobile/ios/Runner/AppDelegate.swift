import Flutter
import UIKit
import AVFoundation
import LibProofMode
import ZendeskCoreSDK
import SupportSDK
import SupportProvidersSDK

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Set up ProofMode platform channel
    setupProofModeChannel()

    // Set up Zendesk platform channel
    setupZendeskChannel()

    // Set up Camera Zoom Detector platform channel
    setupCameraZoomDetectorChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Force portrait orientation for entire app (including camera preview)
  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return .portrait
  }

  private func setupProofModeChannel() {

    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("❌ ProofMode: Could not get FlutterViewController")
      return
    }

    let channel = FlutterMethodChannel(
      name: "org.openvine/proofmode",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "generateProof":
        guard let args = call.arguments as? [String: Any],
              let mediaPath = args["mediaPath"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Media path is required",
            details: nil
          ))
          return
        }

        NSLog("🔐 ProofMode: Generating proof for: \(mediaPath)")

        do {
          // Create MediaItem from file URL
          let fileURL = URL(fileURLWithPath: mediaPath)
          guard FileManager.default.fileExists(atPath: mediaPath) else {
            NSLog("🔐 ProofMode: FILE NOT FOUND: \(mediaPath)")
            result(FlutterError(
              code: "FILE_NOT_FOUND",
              message: "Media file does not exist: \(mediaPath)",
              details: nil
            ))
            return
          }

          let mediaItem = MediaItem(mediaUrl: fileURL)

          // Configure proof generation options
          // Include device ID, location (if available), and network info
          let options = ProofGenerationOptions(
            showDeviceIds: false,
            showLocation: false,
            showMobileNetwork: false,
            notarizationProviders: []
          )

		Proof.shared.process(mediaItem: mediaItem, options: options, whenDone: { mediaItem in
                    if let proofHash = mediaItem.mediaItemHash {
          		NSLog("🔐 ProofMode: Proof generated successfully: \(proofHash)")
          		result(proofHash)
                    } else {
            		NSLog("❌ ProofMode: Proof generation did not produce hash")
            		result(FlutterError(
              		code: "PROOF_HASH_MISSING",
              		message: "LibProofMode did not generate video hash",
              		details: nil
            		))
            		return
                    }
                })



        } catch {
          NSLog("❌ ProofMode: Proof generation failed: \(error.localizedDescription)")
          result(FlutterError(
            code: "PROOF_GENERATION_FAILED",
            message: error.localizedDescription,
            details: nil
          ))
        }

      case "getProofDir":
        guard let args = call.arguments as? [String: Any],
              let proofHash = args["proofHash"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "Proof hash is required",
            details: nil
          ))
          return
        }

        NSLog("🔐 ProofMode: Getting proof directory for hash: \(proofHash)")

        // ProofMode stores proof in documents directory under hash subfolder
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let proofDirPath = (documentsPath as NSString).appendingPathComponent(proofHash)

        if FileManager.default.fileExists(atPath: proofDirPath) {
          NSLog("🔐 ProofMode: Proof directory found: \(proofDirPath)")
          result(proofDirPath)
        } else {
          NSLog("⚠️ ProofMode: Proof directory not found for hash: \(proofHash)")
          result(nil)
        }

      case "isAvailable":
        // iOS ProofMode library is now available
        NSLog("🔐 ProofMode: isAvailable check - true (LibProofMode installed)")
        result(true)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ ProofMode: Platform channel registered with LibProofMode")
  }

  private func setupZendeskChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("❌ Zendesk: Could not get FlutterViewController")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.openvine/zendesk_support",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call, result) in
      guard let self = self,
            let controller = self.window?.rootViewController as? FlutterViewController else {
        result(FlutterError(code: "NO_CONTROLLER", message: "FlutterViewController not available", details: nil))
        return
      }

      switch call.method {
      case "initialize":
        guard let args = call.arguments as? [String: Any],
              let appId = args["appId"] as? String,
              let clientId = args["clientId"] as? String,
              let zendeskUrl = args["zendeskUrl"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "appId, clientId, and zendeskUrl are required",
            details: nil
          ))
          return
        }

        NSLog("🎫 Zendesk: Initializing with URL: \(zendeskUrl)")

        // Initialize Zendesk Core SDK
        Zendesk.initialize(appId: appId, clientId: clientId, zendeskUrl: zendeskUrl)

        // Initialize Support SDK
        Support.initialize(withZendesk: Zendesk.instance)

        // No identity set at init — JWT identity will be set when the user
        // accesses support. Setting anonymous here would lock the SDK into
        // anonymous auth mode and prevent switching to JWT later.

        NSLog("✅ Zendesk: Initialized (identity deferred to JWT)")
        result(true)

      case "showNewTicket":
        let args = call.arguments as? [String: Any]
        let subject = args?["subject"] as? String ?? ""
        let tags = args?["tags"] as? [String] ?? []
        // Note: description parameter not supported by Zendesk iOS SDK RequestUiConfiguration

        NSLog("🎫 Zendesk: Showing new ticket screen")

        // Configure request UI
        let config = RequestUiConfiguration()
        config.subject = subject
        config.tags = tags

        // Build request screen
        let requestScreen = RequestUi.buildRequestUi(with: [config])

        // Present modally
        controller.present(requestScreen, animated: true) {
          NSLog("✅ Zendesk: Ticket screen presented")
        }

        result(true)

      case "showTicketList":
        NSLog("🎫 Zendesk: Showing ticket list screen")

        // Build request list screen
        let requestListScreen = RequestUi.buildRequestList()

        // CRITICAL: Zendesk RequestUi requires UINavigationController for ticket navigation
        // Without this, tapping tickets won't open the conversation view
        let navigationController = UINavigationController(rootViewController: requestListScreen)

        // Present modally with navigation controller
        controller.present(navigationController, animated: true) {
          NSLog("✅ Zendesk: Ticket list presented in navigation controller")
        }

        result(true)

      case "setUserIdentity":
        guard let args = call.arguments as? [String: Any],
              let name = args["name"] as? String,
              let email = args["email"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "name and email are required",
            details: nil
          ))
          return
        }

        NSLog("🎫 Zendesk: Setting user identity")

        // Create anonymous identity with name and email identifiers
        let identity = Identity.createAnonymous(name: name, email: email)
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: User identity set successfully")
        result(true)

      case "clearUserIdentity":
        NSLog("🎫 Zendesk: Clearing user identity")

        // Reset to plain anonymous identity
        let identity = Identity.createAnonymous()
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: User identity cleared")
        result(true)

      case "setJwtIdentity":
        guard let args = call.arguments as? [String: Any],
              let userToken = args["userToken"] as? String else {
          result(FlutterError(
            code: "INVALID_ARGUMENT",
            message: "userToken is required",
            details: nil
          ))
          return
        }

        NSLog("🎫 Zendesk: Setting JWT identity with user token")

        // Pass user token (npub) to SDK - Zendesk will call our JWT endpoint to get the actual JWT
        let identity = Identity.createJwt(token: userToken)
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: JWT identity set - Zendesk will callback to get JWT")
        result(true)

      case "setAnonymousIdentity":
        NSLog("🎫 Zendesk: Setting anonymous identity")

        // Set plain anonymous identity (for non-logged-in users)
        let identity = Identity.createAnonymous()
        Zendesk.instance?.setIdentity(identity)

        NSLog("✅ Zendesk: Anonymous identity set")
        result(true)

      case "createTicket":
        NSLog("🎫 Zendesk: Creating ticket programmatically (no UI)")

        // Extract parameters
        guard let args = call.arguments as? [String: Any],
              let subject = args["subject"] as? String,
              let description = args["description"] as? String else {
          NSLog("❌ Zendesk: Missing required parameters for createTicket")
          result(FlutterError(code: "INVALID_ARGS",
                            message: "Missing subject or description",
                            details: nil))
          return
        }

        let tags = args["tags"] as? [String] ?? []
        let ticketFormId = args["ticketFormId"] as? NSNumber
        let customFieldsData = args["customFields"] as? [[String: Any]] ?? []

        // Build create request object using ZDK API
        let createRequest = ZDKCreateRequest()
        createRequest.subject = subject
        createRequest.requestDescription = description
        createRequest.tags = tags

        // Set ticket form ID if provided
        if let formId = ticketFormId {
          createRequest.ticketFormId = formId
          NSLog("🎫 Zendesk: Using ticket form ID: \(formId)")
        }

        // Set custom fields if provided
        if !customFieldsData.isEmpty {
          var customFields: [CustomField] = []
          for fieldData in customFieldsData {
            if let fieldId = fieldData["id"] as? NSNumber,
               let fieldValue = fieldData["value"] {
              // CustomField uses dictionary-based initializer in modern SDK
              let customField = CustomField(dictionary: ["id": fieldId, "value": fieldValue])
              customFields.append(customField)
              NSLog("🎫 Zendesk: Custom field \(fieldId) = \(fieldValue)")
            }
          }
          createRequest.customFields = customFields
        }

        NSLog("🎫 Zendesk: Submitting ticket - subject: '\(subject)', tags: \(tags)")

        // Submit ticket asynchronously using ZDKRequestProvider
        ZDKRequestProvider().createRequest(createRequest) { (request, error) in
          DispatchQueue.main.async {
            if let error = error {
              NSLog("❌ Zendesk: Failed to create ticket - \(error.localizedDescription)")
              result(FlutterError(code: "CREATE_FAILED",
                                message: error.localizedDescription,
                                details: nil))
            } else if let request = request as? ZDKRequest {
              NSLog("✅ Zendesk: Ticket created successfully - ID: \(request.requestId)")
              result(true)
            } else {
              // No error means the ticket was created — the response type may differ
              // under JWT auth vs anonymous auth. Treat as success to avoid duplicate
              // ticket creation via REST API fallback.
              NSLog("✅ Zendesk: Ticket created (no error, response type: \(type(of: request)))")
              result(true)
            }
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ Zendesk: Platform channel registered")
  }

  private func setupCameraZoomDetectorChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      NSLog("❌ CameraZoomDetector: Could not get FlutterViewController")
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.openvine/camera_zoom_detector",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "getPhysicalCameras":
        NSLog("📷 CameraZoomDetector: Getting physical cameras...")

        guard #available(iOS 10.0, *) else {
          result([])
          return
        }

        // Query back cameras
        let backDiscoverySession = AVCaptureDevice.DiscoverySession(
          deviceTypes: [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera
          ].compactMap { $0 },
          mediaType: .video,
          position: .back
        )

        // Query front cameras
        let frontDiscoverySession = AVCaptureDevice.DiscoverySession(
          deviceTypes: [
            .builtInWideAngleCamera
          ].compactMap { $0 },
          mediaType: .video,
          position: .front
        )

        // First, get the multi-camera virtual device to query zoom switchover points
        var telephotoZoomFactor: Double = 2.0  // Default fallback

        if #available(iOS 13.0, *) {
          // Query multi-camera device to get actual zoom switchover factors
          let multiCamSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera].compactMap { $0 },
            mediaType: .video,
            position: .back
          )

          if let multiCamDevice = multiCamSession.devices.first {
            let switchFactors = multiCamDevice.virtualDeviceSwitchOverVideoZoomFactors.map { $0.doubleValue }
            NSLog("📷 Multi-camera device internal switchover factors: \(switchFactors)")

            // CRITICAL: Apple uses ultra-wide as baseline (internal factor 1 = 0.5x display)
            // iPhone 13 Pro Max returns [2, 6] which means:
            //   - Factor 2 = Wide camera (1x display) = 2 / 2 = 1.0x
            //   - Factor 6 = Telephoto camera (3x display) = 6 / 2 = 3.0x
            // Conversion: Display zoom = Internal factor / 2
            if let maxInternalZoom = switchFactors.max(), maxInternalZoom > 1.0 {
              telephotoZoomFactor = maxInternalZoom / 2.0
              NSLog("📷 Telephoto display zoom factor: \(telephotoZoomFactor)x (from internal \(maxInternalZoom))")
            }
          }
        }

        var cameras: [[String: Any]] = []

        // Process back cameras
        for device in backDiscoverySession.devices {
          // Determine camera type based on device type
          var cameraType = "wide"
          if device.deviceType == .builtInUltraWideCamera {
            cameraType = "ultrawide"
          } else if device.deviceType == .builtInTelephotoCamera {
            cameraType = "telephoto"
          }

          // Get zoom factor relative to wide camera (1.0x baseline)
          let zoomFactor: Double
          if device.deviceType == .builtInUltraWideCamera {
            // Ultrawide is typically 0.5x on all iPhones (13mm vs 26mm)
            zoomFactor = 0.5
          } else if device.deviceType == .builtInTelephotoCamera {
            // Use the zoom factor from multi-camera switchover points
            zoomFactor = telephotoZoomFactor
          } else {
            // Wide angle camera is the baseline (1.0x)
            zoomFactor = 1.0
          }

          cameras.append([
            "type": cameraType,
            "zoomFactor": zoomFactor,
            "deviceId": device.uniqueID,
            "displayName": device.localizedName
          ])

          NSLog("📷 Found back camera: \(device.localizedName) - \(cameraType) - \(zoomFactor)x")
        }

        // Process front cameras
        for device in frontDiscoverySession.devices {
          cameras.append([
            "type": "front",
            "zoomFactor": 1.0,  // Front cameras are always 1.0x
            "deviceId": device.uniqueID,
            "displayName": device.localizedName
          ])

          NSLog("📷 Found front camera: \(device.localizedName) - front - 1.0x")
        }

        NSLog("📷 CameraZoomDetector: Found \(cameras.count) cameras total")
        result(cameras)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    NSLog("✅ CameraZoomDetector: Platform channel registered")
  }
}
