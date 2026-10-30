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

## 2026-10-30 Revised plan for a public repository: 0.1.0 ships window capture first

Supersedes the four-phase plan to `v0.1.0` (the local session plan). Why: the repository is public and the Swift app should be installable early; window capture into the active case is the one job nothing else does. 0.1.0 is the core library, ScreenCaptureKit window capture, Accessibility placement, the menu bar item and its menu as the case picker, global keys, flash, toast and log; the picker panel, area, display and timed capture and the CLI move to 0.2.0, display-relative origins and the browser content rect to 0.3.0. The public plan is `docs/03-roadmap.md`. The shell PoC week with a Shortcuts hotkey was skipped by choice. Rules out: holding the first release for the whole backlog.

## 2026-10-30 A case is any lower-case hyphenated folder under the root

Supersedes the `^poc-...` validation of SC-101 to SC-103. Why: the evidence procedure is one use of sCapture; a public user documents any procedure. A case id is lower-case letters and digits joined by hyphens (`^[a-z0-9]+(-[a-z0-9]+)*$`), `poc-` stays the recommended prefix for evidence. Consequence: scommon needs no new case validator; `FolderScanner` lists the folders and `PocCase` stays sNotate's. Rules out: spaces, capitals and underscores in case ids.

## 2026-10-30 AppKit status item instead of SwiftUI MenuBarExtra

Supersedes the `MenuBarExtra` row of the stack. Why: the item shows text (case, count, profile in a lighter colour) next to a template icon, the menu is rebuilt each time it opens from the live folder list, and `ctrl-shift-space` opens it through `performClick`; an `NSStatusItem` does all three directly, and sPaste made the same choice the same day. Rules out: a SwiftUI `App` scene for the agent.

## 2026-10-30 The app bundle is built from SwiftPM, no Xcode project

Supersedes `make gen` and the XcodeGen project of the stack entry. Why: `scripts/bundle.sh` wraps the `swift build` product into `build/sCapture.app` on any machine with the Command Line Tools, as sPaste does; one Package.swift, no generated project to keep in step. Rules out: `project.yml`.

## 2026-10-30 Local builds keep their permissions, releases are ad hoc

Why: macOS ties the Screen Recording and Accessibility grants to the signature, and an ad hoc signature changes with every build, so every `make app` would ask again. `make app` signs with the first Apple Development certificate in the keychain when there is one (`SIGN_IDENTITY` overrides it); `make release` always signs ad hoc, and the README tells users to grant both permissions again after each update until releases are notarised.

## 2026-10-30 Profile keys are ctrl-alt-1 to ctrl-alt-9

Supersedes `ctrl-shift-1..9` of SC-304. Why: the backlog also gives `ctrl-shift-3` to display capture and `ctrl-shift-4` to area capture; the profile keys move to `ctrl-alt-` so the two sets never collide. `ctrl-shift-space` opens the menu until the picker panel exists.

## 2026-10-30 case-step numbers start at 01

Why: the toast says `step 07` for the seventh capture, and a human counts from one; SC-402 said only "highest existing number plus one". An evidence script that numbers from 00 keeps doing so in its own rename; sCapture never renumbers.

## 2026-10-30 A Settings window, as sPaste's

Why: Sam asked for it after 0.1.0 shipped; editing a text file is fine for keys and profiles, less so for a folder or a yes or no, and the permission state is easier to read in a window than in menu rows. It follows sPaste's: an `@Observable` model, each control writes one line through `ConfigPaths.persist` with the text `Config.text(for:)` gives, so the config file stays the truth and keeps its comments; the window refreshes when it becomes key, so a grant made in System Settings shows on return. Profiles and the keymap stay text files, opened from the window. Rules out: settings that live only in the app (`UserDefaults`).

## 2026-10-31 A Profiles window that writes the profiles file block by block

Why: Sam asked for a dialog to edit profiles and try them before use; a text file is fine for a few keys, less so for a frame in points and an inset that must be measured. As with Settings, the file stays the truth: `Profiles.replacing` rewrites only the edited block (header, key lines in place, comments and unknown lines kept), and `Profiles.check` parses the result and refuses a change that brings a new issue, so the form and the file never disagree on what is valid. Use Current Window and Place go through the same resolver and positioner as the keys; Test Capture is `CaptureService.test`, the capture path without naming, writing, logging or setting the repeat window. A profile of the front app is tried on the app that was in front before the window, not sCapture. Rules out: profiles kept in the app's own store, or a whole-file rewrite that loses the comments.

## 2026-10-31 A hidden Edit menu

Why: AppKit sends cmd-X, cmd-C, cmd-V, cmd-A and cmd-Z to a text field through the main menu's key equivalents, and an agent (`LSUIElement`) had no main menu, so New Case… took no paste, not even from sPaste, which sends cmd-V. `EditMenu.install()` sets a main menu with an Edit menu that is never shown.

