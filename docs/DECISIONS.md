# sCapture: decisions

Single source of truth for choices that shape the code. Newest at the bottom. Supersede, never rewrite.

## 2026-10-25 Name: sCapture

Why: lower-case s plus a verb, like sView and sNotate; `scapture` as binary and config directory.

## 2026-10-25 Scope: capture into PoC case folders, nothing else

Why: the chain is sCapture (screen to folder), sNotate (folder to notated story), sView (folder to eyes); each does one thing. Rules out: editing, viewing, clipboard history, cloud, recording, OCR. sNotate's capture items were withdrawn the same day.

## 2026-10-25 Menu bar agent, no window, no Dock icon

Why: capture is a background job triggered by a hotkey; the only state worth seeing is the active case and the step count, which fit in the menu bar. Panels (picker, toast, area selector) are non-activating so the target app stays frontmost.

## 2026-10-25 Fixed output geometry per profile

Why: one PoC held the same window at 1518 x 892 and 3036 x 1784; mixed scales break annotation reuse in sNotate and make reports uneven. A profile fixes origin and size in points and the scale (1 or 2); the output is always `size x scale` pixels. Rules out: capturing at whatever the display's backing scale is.

## 2026-10-25 Default file names are chronological, like the Guide-Shot captures

Why: the evidence procedure renames captures to `<case-id>-<nn>` only after the author has deleted the wrong ones, so numbering gaps never appear. sCapture writes `scap-YYYY-MM-DD-HHMMSS.png` by default and offers `name case-step` for authors who skip that step. Rules out: numbering at capture time by default, renumbering ever.

## 2026-10-25 ScreenCaptureKit for capture, Accessibility for positioning, Carbon for hotkeys

Why: SCK is the supported capture API with per-capture pixel size and shadow and cursor control; AX is the only way to move another app's window; Carbon `RegisterEventHotKey` is the only global hotkey path that does not need the Accessibility permission. Each sits behind a protocol or in one file so the core stays testable and a replacement is local.

## 2026-10-25 Stack and config as the siblings

Swift 6.2, Apple frameworks only, macOS 26, Xcode 26, XcodeGen, Makefile, `~/.config/scapture/` with `config`, `keymap`, `profiles`, `state.json`, `log`; lower-case paths, no white space, exportable as a zip.

## 2026-10-25 Shared code from the `scommon` package

Why: sCapture is the third sibling; folder scan, natural sort, `poc-` parsing, config and keymap parsers and the config-directory logic move from `SViewCore` to the scommon repository after sView Phase 2, and sCapture is its first consumer with nothing to copy. Local path dependency `../scommon`, no version pinning, one person edits all repos.

## 2026-10-25 Branding follows the s-family note

The s means super-fast and swift, never expanded in the product; sCapture's icon is the shared s mark on green with a reticle as the accent, from SVG layers and an Icon Composer `.icon` in `brand/`; the menu bar item is a monochrome template image of the same s and reticle at 18 pt. Source of truth: `docs/04-branding.md` in the sView repository until it moves to `brand/` in the scommon repository.

## 2026-10-25 Shell proof of concept before Swift

Why: `screencapture` plus `osascript` can prove the hotkey-to-case-folder workflow in 30 lines; the Swift app must earn its place with fixed scale, sub-50 ms capture and feedback. The Guide-Shot AppleScripts are decompiled into `scripts/legacy/` as the requirements record.

## 2026-10-28 A profile captures the window minus an inset

Why: the Guide-Shot scripts, which made all of today's evidence, never capture the whole window; they place Chrome at `200 50 1520 980` and crop 87 points of title bar, tabs and address bar and the 1-point border, which is where 1518 x 892 comes from. A profile therefore has `inset` beside `origin` and `size`, and the output is `(size - inset) x scale` pixels. Rules out: whole-window capture as the only mode. A content rect read from the page (SC-308) may replace the fixed inset later.

## 2026-10-28 Same-second captures get a letter, not a number

Supersedes the `-1`, `-2` of SC-401. Why: `scap-...-093435-1.png` sorts before `scap-...-093435.png` in a plain sort, as the evidence script uses, and in Finder's order, so the rename would number the second capture before the first; `scap-...-093435b.png` sorts after it in both. Found by the PoC on 2026-10-28.

## 2026-10-28 The Chrome profile is fixed at 2x

Sam's choice: the profile writes 3036 x 1784 (1518 x 892 points at scale 2), and so does the PoC by default. Why: both of Sam's displays are 2x, so the capture needs no resampling (the PoC's 1x default ran `sips` on every shot), and the SC-301 example already said 2. Rules out: 1x as the default. Older captures at 1518 x 892 stay as they are; SC-306 warns when a case mixes scales.

## 2026-10-30 The published tree holds no private paths or work material

Supersedes the example root, case id and profile name used so far, and the `scripts/legacy/` record of the shell proof of concept entry. Why: sCapture is published as open source with its siblings. The default PoC root is `~/Pictures/scapture` (`SCAPTURE_ROOT` overrides it in the PoC, `root` in the config), the examples are `poc-demo-vm-stop` and `console-chrome`, and sibling repositories are named, not given as paths. The decompiled Guide-Shot scripts, `STATUS.md` and the session plan stay as local notes in `docs/local/`, which git ignores. Earlier entries were reworded to match; their decisions are unchanged. Rules out: work folders, work display layouts and home paths in tracked files.

## 2026-10-30 sCapture's icon layers are in brand/

Why: the family rules (scommon's `brand/README.md`) give sCapture green `#1fbf75` to `#15895a` with a reticle on the s's upper terminal; the layers are drawn now so the Swift phase starts with its icon. The reticle is deep green `#0b5c3a`, not white, so it does not cut the white s apart. `brand/scapture-1024.png` is rendered by scommon's `brand/render.swift`; the menu bar template image comes with the menu bar app.
