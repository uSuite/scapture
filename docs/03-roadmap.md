# sCapture: roadmap

Where sCapture is going, release by release, with the backlog ids (SC-xxx) from `docs/01-backlog.md`. The reasoning behind each choice is in `docs/DECISIONS.md`; what each release changed for a user is in `CHANGELOG.md`. Revised 2026-10-30, when the repository went public.

## 0.0.x: the shell proof of concept (done)

`scripts/poc.sh` places a window, captures its kept rect into the active case at a fixed scale and prints the step count. It proved the workflow, gave the timing baseline (about 280 ms a shot) and found the naming rule for same-second captures. It stays in the tree until the `scapture` CLI replaces it.

## 0.1.0: window capture from the menu bar (done)

The smallest app worth installing: one key puts the profile's window, at its size and scale, into the active case.

- Core library, test first: config, keymap, profiles and their pixel maths, cases, names, PNG writing, state, log (SC-601).
- Window capture with ScreenCaptureKit at exactly `(size - inset) x scale` pixels, sRGB, written atomically (SC-201, SC-206, SC-301, SC-303).
- Window placement through Accessibility, before every capture when `auto_position yes` (SC-302).
- Menu bar item with case, count and profile; the menu lists cases and profiles, makes new cases and opens the case in Finder, sView or sNotate (SC-101, SC-103, SC-104, SC-105, SC-304, SC-305, SC-501).
- Global keys from the keymap file, no permission needed; repeat last window (SC-203, window half; SC-502).
- Flash and thumbnail toast, capture log, permissions asked once (SC-403, SC-405, SC-504).
- Config, keymap and profiles as plain text, reloaded on change (SC-505, without export).
- `make smoke` on the app's own test window (SC-602); universal ad hoc zip on GitHub Releases.

## 0.1.1: Settings window (this release)

- Settings… (cmd-,): every config option as a control writing one line of config, the two permissions with a button to each pane, the problems in the files, and the profiles, keymap and config folder (SC-505).

## 0.2.0: picker, area and CLI

- Case picker panel with fuzzy search, `j`/`k` and new case from the keyboard (SC-102).
- Area capture with a crosshair, repeat last area (SC-202, SC-203), display capture (SC-204), timed capture (SC-205).
- `scapture` command line: talks to the running app, works standalone otherwise (SC-503). `scripts/poc.sh` goes.
- `post` command per profile (SC-404), the size guard (SC-306), config export as a zip (SC-505).

## 0.3.0: geometry that follows the displays

- Origins relative to a display, so one profile works on a laptop alone and with an external display (SC-307).
- Content rect read from the page for browsers, instead of a fixed inset (SC-308).
- Hostile cases and budgets: missing root, read-only case, window on another Space, display changes, idle CPU and launch time (SC-603, SC-604).

## Later

- Click-to-step, two windows in one PNG, scrolling capture, hiding windows (SC-701 to SC-704), each only when real use asks for it.
- Notarised downloads and a Homebrew cask, once the project has an Apple Developer ID; until then every update asks for the permissions again.
