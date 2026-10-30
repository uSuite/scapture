import Foundation

/// What survives a restart (SC-104, SC-305), in `state.json`. Disposable: a
/// missing or broken file is an empty state.
public struct State: Codable, Sendable, Equatable {
    public var activeCase: String?
    public var profile: String?
    /// The profile each case was captured with first, restored when the case
    /// is picked again so a case never mixes geometries.
    public var caseProfiles: [String: String] = [:]

    public init(
        activeCase: String? = nil,
        profile: String? = nil
    ) {
        self.activeCase = activeCase
        self.profile = profile
    }

    public static func load(_ url: URL) -> State {
        guard let data = try? Data(contentsOf: url),
            let state = try? JSONDecoder().decode(State.self, from: data)
        else {
            return State()
        }
        return state
    }

    public func save(_ url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(self).write(to: url, options: .atomic)
    }

    /// Makes `id` active and brings back the profile it was captured with.
    public mutating func pick(_ id: String) {
        activeCase = id
        if let remembered = caseProfiles[id] {
            profile = remembered
        }
    }

    /// Records the first profile a case is captured with.
    public mutating func captured(
        _ id: String,
        with profile: String
    ) {
        if caseProfiles[id] == nil {
            caseProfiles[id] = profile
        }
    }
}
