import Foundation

/// The capture log, `~/.config/scapture/log` (SC-405): one tab-separated line
/// per capture, appended, never rewritten.
public enum Log {
    public static func line(
        date: Date,
        caseID: String,
        profile: String,
        file: String,
        size: PixelSize,
        milliseconds: Int
    ) -> String {
        let time = date.formatted(.iso8601)
        return [time, caseID, profile, file, size.description, "\(milliseconds)ms"].joined(separator: "\t")
    }

    public static func append(
        _ line: String,
        to url: URL
    ) throws {
        let data = Data((line + "\n").utf8)
        guard let handle = try? FileHandle(forWritingTo: url) else {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url)
            return
        }
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }
}
