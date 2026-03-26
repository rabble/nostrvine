import Cocoa
import FlutterMacOS
import ImageIO
import UniformTypeIdentifiers

public class ImageMetadataStripperPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "image_metadata_stripper",
      binaryMessenger: registrar.messenger
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

      // Read EXIF orientation from source image properties
      let properties = CGImageSourceCopyPropertiesAtIndex(
        imageSource, 0, nil
      ) as? [CFString: Any]
      let orientation = properties?[kCGImagePropertyOrientation]
        as? UInt32 ?? 1

      let srcWidth = srcImage.width
      let srcHeight = srcImage.height

      // Orientations 5-8 swap width/height
      let swapsWidthHeight = orientation >= 5 && orientation <= 8
      let outWidth = swapsWidthHeight ? srcHeight : srcWidth
      let outHeight = swapsWidthHeight ? srcWidth : srcHeight

      let colorSpace = srcImage.colorSpace ?? CGColorSpaceCreateDeviceRGB()
      guard let ctx = CGContext(
        data: nil,
        width: outWidth,
        height: outHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ) else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "DECODE_FAILED",
            message: "Could not create bitmap context",
            details: nil
          ))
        }
        return
      }

      // Apply EXIF orientation transform
      Self.applyOrientation(
        ctx, orientation: orientation,
        width: outWidth, height: outHeight
      )
      ctx.draw(
        srcImage,
        in: CGRect(x: 0, y: 0, width: srcWidth, height: srcHeight)
      )
      guard let cleanImage = ctx.makeImage() else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "DECODE_FAILED",
            message: "Could not create clean image from context",
            details: nil
          ))
        }
        return
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

      var destProperties: [CFString: Any] = [:]
      if !isPng {
        destProperties[kCGImageDestinationLossyCompressionQuality] = 0.85
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

  /// Applies an EXIF orientation transform to a CGContext.
  /// The context must already be sized for the output dimensions.
  private static func applyOrientation(
    _ ctx: CGContext,
    orientation: UInt32,
    width: Int,
    height: Int
  ) {
    let w = CGFloat(width)
    let h = CGFloat(height)
    switch orientation {
    case 1: break // Normal
    case 2: // Horizontal flip
      ctx.translateBy(x: w, y: 0)
      ctx.scaleBy(x: -1, y: 1)
    case 3: // 180°
      ctx.translateBy(x: w, y: h)
      ctx.rotate(by: .pi)
    case 4: // Vertical flip
      ctx.translateBy(x: 0, y: h)
      ctx.scaleBy(x: 1, y: -1)
    case 5: // Transpose (flip + 90° CW)
      ctx.translateBy(x: 0, y: h)
      ctx.rotate(by: -.pi / 2)
      ctx.scaleBy(x: -1, y: 1)
    case 6: // 90° CW
      ctx.translateBy(x: w, y: 0)
      ctx.rotate(by: .pi / 2)
    case 7: // Transverse (flip + 90° CCW)
      ctx.translateBy(x: w, y: 0)
      ctx.rotate(by: .pi / 2)
      ctx.scaleBy(x: -1, y: 1)
    case 8: // 90° CCW
      ctx.translateBy(x: 0, y: h)
      ctx.rotate(by: -.pi / 2)
    default: break
    }
  }
}
