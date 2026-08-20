import Cocoa
import FlutterMacOS
import CoreVideo

class VideoTexture: NSObject, FlutterTexture {
    private var pixelBuffer: CVPixelBuffer?
    private let lock = NSLock()

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        lock.lock()
        defer { lock.unlock() }
        if let buffer = pixelBuffer {
            return Unmanaged.passRetained(buffer)
        }
        return nil
    }

    func updatePixelBuffer(_ buffer: CVPixelBuffer) {
        lock.lock()
        pixelBuffer = buffer
        lock.unlock()
    }
}

public class VideoTexturePlugin: NSObject {
    private let textures: FlutterTextureRegistry
    private var textureMap: [Int64: VideoTexture] = [:]

    init(textures: FlutterTextureRegistry) {
        self.textures = textures
        super.init()
    }

    public static func register(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.matrix.video_texture",
            binaryMessenger: controller.engine.binaryMessenger
        )
        if let registry = controller as? FlutterTextureRegistry {
            let instance = VideoTexturePlugin(textures: registry)
            channel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) in
                instance.handle(call, result: result)
            })
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "createTexture":
            let texture = VideoTexture()
            let textureId = textures.register(texture)
            textureMap[textureId] = texture
            result(textureId)

        case "updateFrame":
            guard let args = call.arguments as? [String: Any],
                  let textureId = args["textureId"] as? Int64,
                  let texture = textureMap[textureId],
                  let flutterData = args["data"] as? FlutterStandardTypedData,
                  let width = args["width"] as? Int,
                  let height = args["height"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid frame data", details: nil))
                return
            }

            let data = flutterData.data
            var pixelBufferOut: CVPixelBuffer?
            let options: [CFString: Any] = [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true,
                kCVPixelBufferMetalCompatibilityKey: true,
                kCVPixelBufferOpenGLCompatibilityKey: true
            ]

            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                options as CFDictionary,
                &pixelBufferOut
            )

            if status == kCVReturnSuccess, let pixelBuffer = pixelBufferOut {
                CVPixelBufferLockBaseAddress(pixelBuffer, [])
                let dest = CVPixelBufferGetBaseAddress(pixelBuffer)
                data.withUnsafeBytes { rawBuffer in
                    if let baseAddress = rawBuffer.baseAddress, let dest = dest {
                        memcpy(dest, baseAddress, min(data.count, width * height * 4))
                    }
                }
                CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
                texture.updatePixelBuffer(pixelBuffer)
                textures.textureFrameAvailable(textureId)
                result(true)
            } else {
                result(false)
            }

        case "disposeTexture":
            guard let args = call.arguments as? [String: Any],
                  let textureId = args["textureId"] as? Int64 else {
                result(nil)
                return
            }
            textures.unregisterTexture(textureId)
            textureMap.removeValue(forKey: textureId)
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    VideoTexturePlugin.register(with: flutterViewController)

    super.awakeFromNib()
  }
}
