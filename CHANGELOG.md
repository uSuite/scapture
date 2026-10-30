# Changelog

Versions follow semver. Each release lists what a user notices; docs/DECISIONS.md has the reasoning.

## 0.1.2 (2026-10-31)

- Edit Profiles… in the menu, and in Settings, opens a Profiles window: the profiles as a list with + and −, and a form for the app (pick a running one), the window title, place and size, inset and scale, with the output size in pixels. Each change rewrites only that profile's block of `~/.config/scapture/profiles`, keeping its comments; a change the file would not accept is shown and not written.
- In the same window, Use Current Window takes the origin and size from where the window is now, Place moves and resizes it to the profile, and Test Capture shows what the capture key would take, at its pixel size, without saving it.
- A profile finds its window in any running copy of its app, not only the first.
- Paste works in New Case… and in the Settings fields, with cmd-V or from another app such as sPaste: the app now has the hidden Edit menu that carries cut, copy, paste, select all and undo.
- The Settings window's permissions note says to reset both entries with `tccutil reset` after an update, then allow them again; removing and adding sCapture in System Settings did not always replace the old entry.

## 0.1.1 (2026-10-31)

- Settings… in the menu (cmd-,) opens a Settings window: the root folder with a folder picker, the file name style, placing the window before a capture and the wait after a move, the flash, the toast, launch at login. Each control writes one line of `~/.config/scapture/config`, so the file stays the truth.
- The same window shows whether Screen Recording and Accessibility are allowed, with a button to each System Settings pane, lists the problems in the config files, and opens the profiles, the keymap and the config folder.

## 0.1.0 (2026-10-30)

- The Swift menu bar app. The menu bar shows the active case, its capture count and the active profile.
- `ctrl-shift-5` captures the profile's window into the active case at exactly `(size - inset) x scale` pixels, whatever the display's scale; the window is placed at the profile's frame first (`auto_position`). `ctrl-shift-r` captures the same window again, `ctrl-shift-p` only places it.
- Profiles in `~/.config/scapture/profiles`: app by bundle id, name or `frontmost`, optional window title, origin, size, inset and scale. `front-window` and `console-chrome` ship as examples; `ctrl-alt-1` to `ctrl-alt-9` switch, and a case remembers the profile it was first captured with.
- Cases are the lower-case folders under the root (`~/Pictures/scapture`); the menu lists them, makes new ones and opens the active one in Finder, sView or sNotate.
- Names `scap-YYYY-MM-DD-HHMMSS.png` (a letter for a second capture in the same second) or `<case-id>-<nn>.png` with `name case-step`. PNG in sRGB at 72 or 144 dpi, written under a temporary name and renamed into place; no file is ever replaced.
- A flash on the captured rect and a toast with the thumbnail, step and pixel size; a click opens the capture in sNotate or sView. Warnings say when a window kept another size or was upsampled from a 1x display.
- Global keys from `~/.config/scapture/keymap`, without any permission. Config, keymap and profiles reload when they change; problems and missing permissions show in the menu. Every capture is a line in `~/.config/scapture/log`.
- Launch at login from the menu.

## 0.0.3 (2026-10-30)

- The icon: the family s on green with a reticle.

## 0.0.2 (2026-10-30)

- The tree made fit to publish: the proof of concept's root defaults to `~/Pictures/scapture`, neutral examples, `make test`.

## 0.0.1 (2026-10-28)

- `scripts/poc.sh`, the shell proof of concept: `use <case-id>`, `shot [app] [title]`, and the active case with its count.
