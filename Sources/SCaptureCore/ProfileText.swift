import CoreGraphics
import SCommon

/// How the Profiles window writes the profiles file: one block at a time,
/// through the same lines `Profiles.parse` reads, so the file stays the truth
/// and its comments and layout survive (SC-309).
extension Profile {
    static let keys = ["app", "window", "origin", "size", "inset", "scale"]

    /// The block's key lines as the file writes them, without the header.
    public var lines: [String] {
        var lines = ["app \(app)"]
        if let window {
            lines.append("window \(window)")
        }
        if let origin {
            lines.append("origin \(Self.number(origin.x)) \(Self.number(origin.y))")
        }
        if let size {
            lines.append("size \(Self.number(size.width)) \(Self.number(size.height))")
        }
        if inset != .zero {
            lines.append("inset \([inset.top, inset.left, inset.bottom, inset.right].map(Self.number).joined(separator: " "))")
        }
        lines.append("scale \(scale)")
        return lines
    }

    /// This profile placed where a window is now, in whole points.
    public func fitted(to frame: CGRect) -> Profile {
        var fitted = self
        fitted.origin = CGPoint(x: frame.minX.rounded(), y: frame.minY.rounded())
        fitted.size = CGSize(width: frame.width.rounded(), height: frame.height.rounded())
        return fitted
    }

    static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e9 ? String(Int(value)) : String(value)
    }
}

extension Profiles {
    /// `text` with the block of `name` rewritten for `profile`: the header
    /// renamed, each key line changed in place, a key now unset dropped, a new
    /// key put after the keys that come before it in the usual order (`app`,
    /// `window`, `origin`, `size`, `inset`, `scale`). Comments, blank lines
    /// and unknown lines stay; other blocks are untouched. Unchanged when no
    /// block has that name.
    public static func replacing(
        _ name: String,
        with profile: Profile,
        in text: String
    ) -> String {
        var file = Lines(text)
        guard let block = file.block(name) else {
            return text
        }
        var wanted: [String: String] = [:]
        for line in profile.lines {
            wanted[key(line)!] = line
        }
        var body: [String] = []
        var used: Set<String> = []
        for line in file.lines[(block.header + 1)..<block.end] {
            guard let key = key(line), Profile.keys.contains(key) else {
                body.append(line)
                continue
            }
            if let replacement = wanted[key], !used.contains(key) {
                used.insert(key)
                body.append(replacement)
            }
        }
        for line in profile.lines where !used.contains(key(line)!) {
            body.insert(line, at: place(of: key(line)!, in: body))
        }
        file.lines = Array(file.lines[..<block.header]) + ["profile \(profile.name)"] + body + Array(file.lines[block.end...])
        return file.text
    }

    /// Where a new `key` line goes in a block's body: after the last known
    /// key that comes before it, else above the first that comes after it and
    /// its comment, else after the body's last key line.
    private static func place(
        of key: String,
        in body: [String]
    ) -> Int {
        let rank = Profile.keys.firstIndex(of: key)!
        let ranks = body.map { line in
            Self.key(line).flatMap { Profile.keys.firstIndex(of: $0) }
        }
        if let before = ranks.lastIndex(where: { $0 != nil && $0! < rank }) {
            return before + 1
        }
        if var after = ranks.firstIndex(where: { $0 != nil && $0! > rank }) {
            // above the comment that belongs to that key, not between them
            while after > 0, body[after - 1].trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                after -= 1
            }
            return after
        }
        return (body.lastIndex { Self.key($0) != nil } ?? -1) + 1
    }

    private static func key(_ line: String) -> String? {
        KeyValueParser.parse(line).first?.key
    }

    /// `text` with a new block for `profile` at the end, after a blank line.
    public static func adding(
        _ profile: Profile,
        to text: String
    ) -> String {
        var file = Lines(text)
        while let last = file.lines.last, Lines.blank(last) {
            file.lines.removeLast()
        }
        if !file.lines.isEmpty {
            file.lines.append("")
        }
        file.lines += ["profile \(profile.name)"] + profile.lines
        return file.text
    }

    /// `text` without the block of `name` and the comment lines right above
    /// its header; a blank line left doubled is dropped.
    public static func removing(
        _ name: String,
        from text: String
    ) -> String {
        var file = Lines(text)
        guard let block = file.block(name) else {
            return text
        }
        var start = block.header
        while start > 0, file.lines[start - 1].trimmingCharacters(in: .whitespaces).hasPrefix("#") {
            start -= 1
        }
        var end = block.header + 1
        for index in (block.header + 1)..<block.end where KeyValueParser.parse(file.lines[index]).first != nil {
            end = index + 1
        }
        file.lines.removeSubrange(start..<end)
        while start > 0, Lines.blank(file.lines[start - 1]), start == file.lines.count || Lines.blank(file.lines[start]) {
            file.lines.remove(at: start - 1)
            start -= 1
        }
        return file.text
    }

    /// The problems a change brings: `text` with `profile` in place of the
    /// block `name` (or added, when `name` is nil) is parsed, and the issues
    /// it did not have before are returned. The parser is the only judge.
    public static func check(
        _ profile: Profile,
        replacing name: String?,
        in text: String
    ) -> [String] {
        let changed = name.map { replacing($0, with: profile, in: text) } ?? adding(profile, to: text)
        var before = parse(text).issues.map(\.message)
        var added: [String] = []
        for message in parse(changed).issues.map(\.message) {
            if let index = before.firstIndex(of: message) {
                before.remove(at: index)
            } else {
                added.append(message)
            }
        }
        return added
    }
}

/// A text file as lines, with its trailing newline remembered.
private struct Lines {
    var lines: [String]
    let trailingNewline: Bool

    init(_ text: String) {
        trailingNewline = text.hasSuffix("\n")
        lines = text.isEmpty ? [] : text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if trailingNewline {
            lines.removeLast()
        }
    }

    var text: String {
        lines.joined(separator: "\n") + (trailingNewline && !lines.isEmpty ? "\n" : "")
    }

    /// The index of the block's header and the index after its last line
    /// (the next header, or the end).
    func block(_ name: String) -> (header: Int, end: Int)? {
        let headers = lines.indices.filter { index in
            KeyValueParser.parse(lines[index]).first?.key == "profile"
        }
        guard let header = headers.first(where: { KeyValueParser.parse(lines[$0]).first?.value == name }) else {
            return nil
        }
        return (header, headers.first { $0 > header } ?? lines.count)
    }

    static func blank(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
