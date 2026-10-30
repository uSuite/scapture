# sCapture: technology stack

Same foundation as its siblings: Swift 6.2, Apple frameworks only, macOS 26 Tahoe, Xcode 26, a Makefile that wraps the SwiftPM build into the app bundle (`scripts/bundle.sh`), config in `~/.config/scapture/`, shared code from `../scommon`. sCapture is the smallest of the three: a menu bar agent, a capture pipeline and a CLI. Status: proposed 2026-10-25, 0.1.0 built 2026-10-30 without the picker panel, area capture and CLI (see `03-roadmap.md`); decisions in `DECISIONS.md`.

## What it looks like

Nothing, most of the time. A menu bar item reading `poc-demo-vm-stop  7` (case id, capture count) and, when a profile is active, `console-chrome` in a lighter weight after it. Press the hotkey: the Chrome window snaps to the profile's frame if it is not there already, the screen flashes on that rectangle for 150 ms, a thumbnail toast slides in at the corner with `step 08  3036x1784` and fades. Press `ctrl-shift-space`: in 0.1.0 the menu opens with the cases and profiles; from 0.2.0 a Shottr-sized floating panel with a text field and a list of case folders, fuzzy filtered as you type, `j`/`k`, `Enter`. That is the whole UI. The feel borrows from Shottr (instant, silent, no window), the keys from sView and sNotate (same keymap grammar, same `j`/`k` in lists), the folder discipline from the evidence procedure.

## Frameworks

| Need | Framework | Notes |
| --- | --- | --- |
| Capture | ScreenCaptureKit: `SCShareableContent` to find displays and windows, `SCContentFilter` for one window or a display rect, `SCStreamConfiguration` for pixel size and options, `SCScreenshotManager.captureImage` | One-shot capture, no stream kept open. Width and height set to `size x scale` so output pixels never depend on the display. Shadow, cursor and menu bar off through the configuration. |
| Window geometry | Accessibility API (`AXUIElement`, `kAXPositionAttribute`, `kAXSizeAttribute`) | Needs the Accessibility permission; the only part that does. Area and display capture work without it. |
| Window identity | `CGWindowListCopyWindowInfo` and `NSRunningApplication` | Match the profile's app bundle id and optional title substring; pick the frontmost window of that app. |
| Hotkeys | Carbon `RegisterEventHotKey` | Works without Accessibility, which `NSEvent` global monitors need. Deprecated for years but present in 26; wrapped in one file so a replacement is a local change. |
| Menu bar | AppKit `NSStatusItem` with an `NSMenu` rebuilt each time it opens, `LSUIElement` true | Text next to a template icon; items run Commands and show their global keys. `MenuBarExtra` was the first plan (DECISIONS). |
| Picker and toast | `NSPanel` (non-activating, floating) hosting SwiftUI views | A non-activating panel keeps the target app frontmost, which matters for the capture that follows. |
| Flash | A borderless transparent `NSWindow` over the captured rect, faded with Core Animation | 150 ms, no sound. |
| PNG | ImageIO `CGImageDestination` | sRGB, DPI from scale, no other metadata, atomic write (temp file then `rename`). |
| Folder watch | `DispatchSource` on the active case folder | Keeps the count in the menu bar honest when the evidence script renames or the author deletes. |
| CLI | The same binary with arguments; talks to the running agent over a Unix socket in `~/.config/scapture/`, falls back to capturing directly | One code path for the capture itself. |
| Tests | Swift Testing on `SCaptureCore`; `make smoke` on the Mac | Core is pure (names, profiles, geometry, log). |

## Architecture

```
App     main.swift, AppDelegate (NSStatusItem and menu), permissions, hotkey registration; CLI entry and socket from 0.2.0
UI      CasePicker (NSPanel + SwiftUI), Toast, Flash, AreaSelector (crosshair overlay)
Core    SCaptureCore library:
          ActiveCase       root scan (scommon), validation, counts, state
          Profile          parse profiles file, resolve target window, pixel size maths
          Namer            scap-timestamp and case-step naming, collision rules
          Capturer         protocol: capture(filter, pixelSize) -> CGImage; SCK implementation in App
          Positioner       protocol: place(window, frame); AX implementation in App
          Writer           PNG encode and atomic write
          Log              one line per capture
          Commands         every action as a Command; Dispatcher
          Keymap, Config   from scommon
```

Core depends on Foundation, CoreGraphics and ImageIO; ScreenCaptureKit and Accessibility sit behind protocols implemented in the App layer so the core tests run headless and the smoke test swaps in a fake capturer when no permission is granted on a CI machine.

## Configuration

`~/.config/scapture/`: `config` (`root ~/Pictures/scapture`, `name timestamp|case-step`, `auto_position yes`, `settle_ms 150`, `flash yes`, `toast 2`; `delay 3` from 0.2.0), `keymap` (`ctrl-shift-5 capture-window`, `ctrl-shift-r capture-repeat`, `ctrl-shift-p position`, `ctrl-shift-space open-menu`, `ctrl-shift-o open-case`, `ctrl-alt-1 profile 1`; `ctrl-shift-4 capture-area` from 0.2.0), `profiles` (blocks: `profile console-chrome`, `app com.google.Chrome`, `origin 200 50`, `size 1520 980`, `inset 87 1 1 1`, `scale 2`; `post open -a sNotate "$FILE"` from 0.2.0), `state.json` (disposable), `log` (append only, tab-separated).

## Phase 0 proof of concept, before any Swift

`scripts/poc.sh`, about 30 lines of shell: read a case folder and a window title from arguments, find the window id with `osascript` or `GetWindowID`, position it with `osascript` (System Events), capture with `screencapture -x -o -l <id> <case>/scap-$(date +%F-%H%M%S).png`, print the step count. If this script, bound to a hotkey through Shortcuts or skhd, already removes the pain for one PoC week, the Swift app earns its place only by the fixed-scale output, the sub-50 ms capture and the toast; if it does not, the backlog is wrong and should be fixed first. The Guide-Shot AppleScripts are decompiled and read in the same phase; whatever they do that the backlog misses goes into it.

## Alternatives considered

| Option | Verdict |
| --- | --- |
| Keep the AppleScripts and add a hotkey | The Phase 0 PoC in effect; it cannot fix the scale or give feedback, and AppleScript is slow (hundreds of ms) and brittle across Chrome versions. Baseline, not the product. |
| `screencapture` CLI inside the Swift app | Simpler than SCK but no fixed scale, no shadow control without flags that change per version, no sub-50 ms. SCK is the Apple-supported path. |
| Shottr with its URL scheme and a folder per case | Destination switching and naming are not scriptable enough, no scale control, closed source. No. |
| A mode inside sNotate | Needs Screen Recording and Accessibility permissions in an app that otherwise needs none, and a menu bar agent lifecycle unlike an editor's. Separate app. |
| `NSEvent.addGlobalMonitorForEvents` for hotkeys | Requires Accessibility for key events; Carbon hotkeys do not. Carbon, wrapped. |
| CGWindowList-based legacy capture (`CGWindowListCreateImage`) | Deprecated since 14 and removed from new code paths; SCK only. |

## Risks

- Carbon hotkey API removal in a future macOS: wrapped in one file; the fallback is the CLI bound through Shortcuts.
- Accessibility positioning fails for some apps (Electron windows with minimum sizes, Chrome with a sidebar): the capture still happens and the toast says the size differs; SC-306 flags it.
- Screen Recording permission resets after reinstall or re-sign: detect and show the system dialog once, never loop.
- Two displays with different scales: the profile's scale decides the output; the flash and selector overlay still follow the display's backing scale.
