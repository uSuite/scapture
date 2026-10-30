# sCapture: backlog

One thing: a hotkey puts a screenshot of the right window, at the right size and scale, into the active case folder, and tells you the step number. Nothing is edited here; sNotate does that.

Input and output are fixed by the evidence procedure: the case folder `<root>/<case-id>/`, capture names that sort chronologically, `.png`. Priorities: P0 first usable release, P1 complete workflow, P2 comfort, P3 parked. IDs SC-xxx.

## Non-goals

- No editor, no annotation, no clipboard history, no cloud, no recording, no GIF, no OCR.
- No scrolling capture in v1 (console pages that need it are rare in the PoC set; parked as SC-703).
- No Dock icon, no main window; a menu bar item and a few panels.
- Free and open source (MIT), built for step-by-step evidence and guides; not a general screenshot tool.

## E1 Active case (P0)

- SC-101 One active case at a time: a folder under a configured root (`root ~/Pictures/scapture`). The menu bar item shows `<case-id>  n` where n is the number of captures in the folder; the item shows a neutral icon when no case is active, and every capture is refused until one is.
- SC-102 Case picker (`hotkey_case`, default `ctrl-shift-space`): a floating panel with fuzzy search over all case folders under the root, `j`/`k` or arrows to move, `Enter` to pick, `Esc` to cancel; most recent cases first.
- SC-103 New case from the picker: typing an id that does not exist and pressing `cmd-Enter` creates the folder after validating `^[a-z0-9]+(-[a-z0-9]+)*$` (lower-case letters and digits joined by hyphens; `poc-` is the evidence procedure's prefix, recommended, not required); the memo is not created, that is the evidence script's job.
- SC-104 The active case, the last used profile and the last area are persisted in `state.json` and restored on launch.
- SC-105 Open the active case in Finder, sView or sNotate from the menu (`o`, `v`, `n` in the menu's key column); the step count refreshes through a folder watch when files are deleted or renamed by the script.

## E2 Capture (P0)

- SC-201 Window capture of the profile's target window with ScreenCaptureKit, shadow excluded, cursor excluded by default, menu bar excluded; under 50 ms from hotkey to file on Apple Silicon.
- SC-202 Area capture (`hotkey_area`, default `ctrl-shift-4`): crosshair selection with size shown in points and pixels, `Esc` cancels, `Enter` or release captures; the area is remembered per profile.
- SC-203 Repeat last area (`hotkey_repeat`, default `ctrl-shift-r`) and repeat last window (`hotkey_window`, default `ctrl-shift-5`) without any UI, for the fifteen captures of one procedure.
- SC-204 Display capture (`ctrl-shift-3`) of the display under the cursor, for dashboards that fill the screen.
- SC-205 Timed capture (`ctrl-shift-t`, delay from config, default 3 s) with a countdown in the menu bar item, for menus and hover states that close when the hotkey is pressed.
- SC-206 Output is PNG, written atomically (temp name then rename) so a watcher never sees a half file; sRGB tagged, DPI metadata consistent with the profile's scale (72 or 144), no other metadata.

## E3 Geometry profiles (P0/P1)

The reason sCapture exists. A profile is a block in `~/.config/scapture/profiles`.

- SC-301 (P0) Profile fields: `app` (bundle id or name of the target, or `frontmost` for whatever app is in front, as `postitioning-window` does), `window` (title substring, optional, else frontmost of that app), `origin` and `size` of the window in points, `inset` (top left bottom right in points cut off the window, default none), `scale` 1 or 2, `name` pattern, `post` command (optional). Example `profile console-chrome`, Guide-Shot-BMP's geometry: `app com.google.Chrome`, `origin 200 50`, `size 1520 980`, `inset 87 1 1 1` (title bar, tabs and address bar; the window border), `scale 2`, which writes 3036 x 1784.
- SC-302 (P0) Position the target window to the profile's origin and size before capturing (`hotkey_position`, default `ctrl-shift-p`, and automatically before a window capture when `auto_position true`), through the Accessibility API; if the app refuses (fixed-size window), the capture proceeds and the toast says so.
- SC-303 (P0) Fixed scale: the capture is rendered at `(size - inset) x scale` pixels regardless of the display's backing scale, so 1x and 2x displays produce identical files; a warning is logged when upsampling from a 1x display to scale 2.
- SC-304 (P1) Profile switch from the menu or `ctrl-alt-1..9` (`ctrl-shift-3` and `ctrl-shift-4` belong to display and area capture); the active profile name shows next to the case id in the menu bar.
- SC-305 (P1) Per-case profile memory: the first capture of a case records the profile in `state.json`, and switching back to that case restores it, so a case never mixes geometries.
- SC-306 (P2) Guard: if a capture's pixel size differs from the other files in the case folder, the toast shows a warning and the file name gets no special mark (the files stay honest; the author decides).
- SC-307 (P1) Origin relative to a display: `display main|external|<name>` in a profile makes `origin` relative to that display's top-left, so one profile works on the laptop display alone and with an external display beside or above it. The Guide-Shot scripts carry the same geometry at a separate global origin for each display arrangement.
- SC-308 (P2) Content rect from the page: for a browser, take the rect of the web area (`AXWebArea`) instead of a fixed inset, so a restore banner, an info bar or the bookmarks bar never ends up in the capture. With the fixed inset of Guide-Shot and the PoC, Chrome's "Continue where you left off" bar was captured as the top 56 points of the page.

## E4 Naming and feedback (P0/P1)

- SC-401 (P0) Default name `scap-YYYY-MM-DD-HHMMSS.png` (same shape as the Guide-Shot captures, so an evidence script renames them unchanged); a second capture in the same second gets `b`, `c` appended (`scap-2026-10-28-093435b.png`), because `-1` sorts before the first capture both in a plain sort and in Finder's order (scommon's natural sort), which would put the steps out of order.
- SC-402 (P0) Alternative `name case-step`: write `<case-id>-<nn>.png` directly, nn being the highest existing number plus one, for authors who do not want the rename step; never renumbers existing files.
- SC-403 (P0) Feedback: a 150 ms screen flash on the captured rect and a small toast in the corner with the thumbnail, `<case-id>  step 07  3036x1784`, which fades after 2 s; clicking it opens the file in sNotate (or sView when sNotate is absent). No sound.
- SC-404 (P1) `post` command per profile, run after the file is written with `$FILE`, `$CASE`, `$STEP` substituted (open in sNotate, run the evidence script in dry-run, `git add`).
- SC-405 (P1) Capture log `~/.config/scapture/log` with one line per capture (time, case, profile, file, pixel size), plain text, for the day a report asks when a step was taken.

## E5 Shell, keys, CLI (P0/P1)

- SC-501 (P0) Menu bar only app (`LSUIElement`), launches at login optionally, quits from the menu; menu lists case, profile, last capture, the hotkeys, Open config folder, Quit.
- SC-502 (P0) Global hotkeys from `~/.config/scapture/keymap`, same grammar as sView and sNotate (`ctrl-shift-4 capture-area`), registered without the Accessibility permission (Carbon hotkey API); conflicts with the system screenshot keys are detected and reported on launch.
- SC-503 (P0) `scapture` CLI: `scapture --case <folder> --profile <name>` captures once from a script or Makefile; `scapture --area x,y,w,h`, `scapture --position <profile>`, `scapture --list` (profiles, cases). The CLI talks to the running menu bar app when present and works standalone otherwise. This is the replacement for the Guide-Shot AppleScripts.
- SC-504 (P0) Permissions handled once with a plain explanation: Screen Recording (capture) and Accessibility (window positioning); the app works for area capture without Accessibility.
- SC-505 (P1) Config as plain text in `~/.config/scapture/` (`config`, `keymap`, `profiles`, `state.json`, `log`), hot-reloaded, exportable as a zip; all paths lower-case, no white space.

## E6 Quality (P1)

- SC-601 Unit tests on the core: case id validation, name generation (collisions, `case-step` numbering), profile parsing, geometry maths (points to pixels per scale), log format.
- SC-602 Integration test on the Mac: `make smoke` creates a temporary case, captures a known window (a test window the smoke script opens) with two profiles, asserts pixel sizes and file names.
- SC-603 Idle CPU zero, memory under 30 MB resident, launch under 200 ms.
- SC-604 Hostile cases: root folder missing, case folder read-only, target app not running, window on another display or Space, display scale changes mid-session.

## E7 Later (P2/P3)

- SC-701 (P2) Click-to-step: while armed, every click inside the target window captures a step just before the click lands (needs an event tap, Input Monitoring permission); the Scribe idea without Scribe.
- SC-702 (P2) Capture the same profile on two windows side by side (console and terminal) into one PNG.
- SC-703 (P3) Scrolling capture of a window's content.
- SC-704 (P3) Hide a configured list of windows (chat, mail) before a capture and restore them after.
