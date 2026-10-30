import AppKit

/// The main menu an agent never shows. AppKit sends cmd-X, cmd-C, cmd-V, cmd-A and
/// cmd-Z to a text field through the main menu's key equivalents, so without this
/// menu the New Case field and the Settings fields take no paste, not even one
/// another app sends as cmd-V.
enum EditMenu {
    @MainActor
    static func install() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(item("Undo", Selector(("undo:")), "z"))
        edit.addItem(item("Redo", Selector(("redo:")), "Z"))
        edit.addItem(.separator())
        edit.addItem(item("Cut", #selector(NSText.cut(_:)), "x"))
        edit.addItem(item("Copy", #selector(NSText.copy(_:)), "c"))
        edit.addItem(item("Paste", #selector(NSText.paste(_:)), "v"))
        edit.addItem(item("Select All", #selector(NSText.selectAll(_:)), "a"))
        let editItem = NSMenuItem()
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(NSMenuItem())
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    private static func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: key
        )
    }
}
