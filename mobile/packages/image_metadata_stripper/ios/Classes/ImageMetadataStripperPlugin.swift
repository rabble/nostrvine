import CoreImage
import Flutter
import ImageIO
import MobileCoreServices
import UIKit

public class ImageMetadataStripperPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "image_metadata_stripper",
      binaryMessenger: registrar.messenger()
    )
    let instance = ImageMetadataStripperPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "stripImageMetadata":
      stripImageMetadata(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func stripImageMetadata(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard let args = call.arguments as? [String: Any],
          let inputPath = args["inputPath"] as? String,
          let outputPath = args["outputPath"] as? String else {
      result(FlutterError(
        code: "INVALID_ARGUMENT",
        message: "inputPath and outputPath are required",
        details: nil
      ))
      return
    }

    guard FileManager.default.fileExists(atPath: inputPath) else {
      result(FlutterError(
        code: "FILE_NOT_FOUND",
        message: "Input file does not exist: \(inputPath)",
        details: nil
      ))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      guard let imageData = FileManager.default.contents(atPath: inputPath),
            let imageSource = CGImageSourceCreateWithData(
              imageData as CFData, nil
            ),
            let srcImage = CGImageSourceCreateImageAtIndex(
              imageSource, 0, nil
            ) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "DECODE_FAILED",
            message: "Could not decode image: \(inputPath)",
            details: nil
          ))
        }
        return
      }

      // Read EXIF orientation from source image properties.
      let properties = CGImageSourceCopyPropertiesAtIndex(
        imageSource, 0, nil
      ) as? [CFString: Any]
      let orientation = properties?[kCGImagePropertyOrientation]
        as? UInt32 ?? 1

      // Bake the EXIF orientation into the pixel data via Core Image.
      // CIImage.oriented(forExifOrientation:) handles the transform
      // identically on iOS and macOS, avoiding the Y-axis pitfalls of
      // doing it manually with a Y-up CGContext (which produced
      // upside-down output before).
      let cleanImage: CGImage
      if orientation != 1 {
        let ciImage = CIImage(cgImage: srcImage)
          .oriented(forExifOrientation: Int32(orientation))
        let ciContext = CIContext(options: nil)
        guard let rendered = ciContext.createCGImage(
          ciImage, from: ciImage.extent
        ) else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "DECODE_FAILED",
              message: "Could not apply EXIF orientation",
              details: nil
            ))
          }
          return
        }
        cleanImage = rendered
      } else {
        cleanImage = srcImage
      }

      let isPng = inputPath.lowercased().hasSuffix(".png")
      let utType: CFString = isPng ? kUTTypePNG : kUTTypeJPEG
      let outputURL = URL(fileURLWithPath: outputPath)

      guard let destination = CGImageDestinationCreateWithURL(
        outputURL as CFURL, utType, 1, nil
      ) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "ENCODE_FAILED",
            message: "Could not create image destination",
            details: nil
          ))
        }
        return
      }

      // Pixels are already oriented; write with orientation = 1 so no
      // viewer applies a second rotation.
      var destProperties: [CFString: Any] = [
        kCGImagePropertyOrientation: 1,
      ]
      if !isPng {
        destProperties[kCGImageDestinationLossyCompressionQuality] =
          0.85
      }
      CGImageDestinationAddImage(
        destination, cleanImage, destProperties as CFDictionary
      )

      guard CGImageDestinationFinalize(destination) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "ENCODE_FAILED",
            message: "Could not re-encode image",
            details: nil
          ))
        }
        return
      }

      DispatchQueue.main.async {
        result(nil)
      }
    }
  }
}
