import Foundation

/// File names for new captures (SC-401, SC-402). A name is never one that
/// exists, and existing files are never renamed.
public struct Namer: Sendable {
    public var style: NameStyle
    public var timeZone: TimeZone

    public init(
        style: NameStyle,
        timeZone: TimeZone = .current
    ) {
        self.style = style
        self.timeZone = timeZone
    }

    /// The next name in `caseID`, given the names already there; nil only
    /// when 26 captures fell in one second.
    public func name(
        at date: Date,
        caseID: String,
        existing: Set<String>
    ) -> String? {
        switch style {
        case .timestamp:
            let stem = "scap-" + stamp(date)
            // b after the bare name: `-1` would sort before it, a letter after
            for suffix in [""] + "bcdefghijklmnopqrstuvwxyz".map(String.init) {
                let name = "\(stem)\(suffix).png"
                if !existing.contains(name) {
                    return name
                }
            }
            return nil
        case .caseStep:
            let next = (Self.highestStep(caseID: caseID, in: existing) ?? 0) + 1
            return "\(caseID)-\(String(format: "%02d", next)).png"
        }
    }

    /// The highest `nn` of `<case-id>-<nn>.<ext>` among `names`.
    public static func highestStep(
        caseID: String,
        in names: Set<String>
    ) -> Int? {
        let prefix = caseID + "-"
        return names.compactMap { name -> Int? in
            guard name.hasPrefix(prefix) else {
                return nil
            }
            let stem = name.dropFirst(prefix.count).prefix { $0 != "." }
            guard !stem.isEmpty, stem.allSatisfy(\.isASCII), stem.allSatisfy(\.isNumber) else {
                return nil
            }
            return Int(stem)
        }
        .max()
    }

    func stamp(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(
            format: "%04d-%02d-%02d-%02d%02d%02d",
            c.year!,
            c.month!,
            c.day!,
            c.hour!,
            c.minute!,
            c.second!
        )
    }
}
