/// How the Settings window writes the config file: one line per control,
/// through the same text `set` reads, so the file stays the truth and its
/// comments and layout survive.
extension Config {
    /// Every key, in the order the default file lists them.
    public static let keys = [
        "root",
        "name",
        "auto_position",
        "settle_ms",
        "flash",
        "toast",
    ]

    /// The value of `key` as the config file writes it, so `set(key, text)`
    /// gives this config's value back; nil for a key not in `keys`.
    public func text(for key: String) -> String? {
        switch key {
        case "root":
            return root
        case "name":
            return name.rawValue
        case "auto_position":
            return autoPosition ? "yes" : "no"
        case "settle_ms":
            return String(settleMilliseconds)
        case "flash":
            return flash ? "yes" : "no"
        case "toast":
            return String(toastSeconds)
        default:
            return nil
        }
    }
}
