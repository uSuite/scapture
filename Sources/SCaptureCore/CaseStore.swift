import Foundation
import SCommon

/// One case: a folder under the root that captures go into.
public struct CaseFolder: Sendable, Hashable {
    public let id: String
    public let url: URL
    public let modified: Date
}

/// The cases under the configured root (SC-101, SC-103). A case is any
/// visible sub-folder whose name is lower-case words joined by hyphens;
/// `poc-` is the evidence procedure's prefix, not a requirement.
public struct CaseStore: Sendable {
    public let root: URL

    public init(root: URL) {
        self.root = root
    }

    public enum CaseError: Error, Equatable, CustomStringConvertible {
        case invalidID(String)
        case exists(String)
        case noRoot(String)

        public var description: String {
            switch self {
            case .invalidID(let id):
                return "'\(id)' is not a case id: use lower-case letters and digits joined by hyphens, such as poc-demo-vm-stop"
            case .exists(let id):
                return "case '\(id)' exists already"
            case .noRoot(let path):
                return "the root folder \(path) does not exist"
            }
        }
    }

    public static func isValidID(_ id: String) -> Bool {
        id.wholeMatch(of: /[a-z0-9]+(-[a-z0-9]+)*/) != nil
    }

    /// Cases, most recently changed first; empty when the root is missing.
    public func cases() -> [CaseFolder] {
        guard let folders = try? FolderScanner.subfolders(of: root) else {
            return []
        }
        return folders
            .filter { Self.isValidID($0.lastPathComponent) }
            .map { url in
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                return CaseFolder(
                    id: url.lastPathComponent,
                    url: url,
                    modified: modified ?? .distantPast
                )
            }
            .sorted { $0.modified != $1.modified ? $0.modified > $1.modified : $0.id < $1.id }
    }

    public func url(of id: String) -> URL {
        root.appendingPathComponent(id, isDirectory: true)
    }

    public func exists(_ id: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url(of: id).path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    /// Makes the case folder, and the root when it is missing; nothing else.
    @discardableResult
    public func create(_ id: String) throws -> URL {
        guard Self.isValidID(id) else {
            throw CaseError.invalidID(id)
        }
        guard !exists(id) else {
            throw CaseError.exists(id)
        }
        let url = url(of: id)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    /// Images in the case: the step count in the menu bar.
    public func count(_ id: String) -> Int {
        (try? FolderScanner.images(in: url(of: id)).count) ?? 0
    }

    /// File names in the case, hidden ones left out.
    public func names(_ id: String) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url(of: id).path)) ?? []
        return Set(names.filter { !$0.hasPrefix(".") })
    }
}
