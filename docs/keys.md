# sCapture: keys

sCapture has no window to type into; its keys are global, registered with macOS so they work whichever app is in front, and need no permission. Every binding can be changed in `~/.config/scapture/keymap`, one `<key> <command>` per line, applied over these defaults; `<key> nop` removes one. A key that another app holds is listed in the menu.

| Key | Command | What |
| --- | --- | --- |
| `ctrl-shift-5` | `capture-window` | place the active profile's window and capture it into the active case |
| `ctrl-shift-r` | `capture-repeat` | capture the window captured last again, without looking it up |
| `ctrl-shift-p` | `position` | place the profile's window at its frame without capturing |
| `ctrl-shift-space` | `open-menu` | open the menu: cases, profiles, new case |
| `ctrl-shift-o` | `open-case` | show the active case folder in Finder |
| `ctrl-alt-1` to `ctrl-alt-9` | `profile 1` to `profile 9` | make the first to ninth profile of the profiles file active |

`ctrl-shift-3` and `ctrl-shift-4` are kept free for display and area capture in 0.2.0. The macOS screenshot keys (`cmd-shift-3`, `cmd-shift-4`, `cmd-shift-5`) can be bound, but then both sCapture and macOS answer; the menu warns about it.
