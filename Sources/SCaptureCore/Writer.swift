import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// PNG files for captures (SC-206): sRGB, the DPI that matches the scale
/// (72 or 144), no other metadata, written under a hidden temporary name and
/// renamed into place without ever replacing a file.
public enum Writer {
    public enum WriteError: Error, Equatable, CustomStringConvertible {
        case exists(String)
        case encode(String)
        case io(String, Int32)

        public var description: String {
            switch self {
            case .exists(let name):
                return "\(name) exists already"
            case .encode(let name):
                return "could not encode \(name) as PNG"
            case .io(let name, let code):
                return "could not write \(name): \(String(cString: strerror(code)))"
            }
        }
    }

    /// The PNG data of `image`, converted to sRGB when it is not.
    public static func png(
        _ image: CGImage,
        scale: Int
    ) -> Data? {
        guard let srgb = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        var source = image
        if image.colorSpace?.name != CGColorSpace.sRGB {
            guard let context = CGContext(
                data: nil,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: srgb,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return nil
            }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let converted = context.makeImage() else {
                return nil
            }
            source = converted
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        let dpi = 72 * scale
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: dpi,
            kCGImagePropertyDPIHeight: dpi,
        ]
        CGImageDestinationAddImage(destination, source, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }

    /// Writes `data` as `folder/name`; throws `.exists` rather than replace.
    public static func write(
        _ data: Data,
        to folder: URL,
        name: String
    ) throws(WriteError) {
        let temporary = folder.appendingPathComponent(".scap-\(UUID().uuidString).png")
        let target = folder.appendingPathComponent(name)
        do {
            try data.write(to: temporary)
        } catch {
            throw .io(name, Int32((error as NSError).code))
        }
        let result = temporary.path.withCString { from in
            target.path.withCString { to in
                renamex_np(from, to, UInt32(RENAME_EXCL))
            }
        }
        guard result == 0 else {
            let code = errno
            try? FileManager.default.removeItem(at: temporary)
            throw code == EEXIST ? .exists(name) : .io(name, code)
        }
    }
}
