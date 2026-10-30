# sCapture

macOS menu bar agent that captures a screenshot of a profiled window, at a fixed size and scale, into the active case folder, and shows the step count. No editing (sNotate, ../snotate), no viewing (sView, ../sview). Swift 6.2, Apple frameworks only, macOS 26, shared code from ../scommon. Read docs/02-tech-stack.md, docs/01-backlog.md (SC-xxx), docs/03-roadmap.md (releases), docs/DECISIONS.md (source of truth), and the local working notes docs/local/STATUS.md (where we are) and docs/local/03-plan-claude-code.md (phases); docs/local/ is ignored by git and never published.

## Commands

- `make test`      scommon's tests, then swift test on SCaptureCore and a syntax check of scripts/poc.sh
- `make coverage`  line coverage of SCaptureCore
- `make app`       SwiftPM build wrapped into build/sCapture.app by scripts/bundle.sh, signed with an Apple Development certificate when there is one
- `make run`       build and launch the agent
- `make smoke`     capture the app's test window with two profiles and both name styles, assert names and pixel sizes (needs Screen Recording)
- `make icon`      Resources/AppIcon.icns from the brand SVGs
- `make release`   universal ad hoc signed app and zip in build/release/
- `make poc`       run scripts/poc.sh (the shell proof of concept)

## Layers

Core (Sources/SCaptureCore: ActiveCase, Profile, Namer, Writer, Log, Commands; Capturer and Positioner as protocols) -> App (Sources/sCapture: NSStatusItem and menu, SCK capturer, window list and AX positioner, Carbon hotkeys, flash and toast panels, smoke mode; CLI from 0.2.0). Core has no ScreenCaptureKit or Accessibility import.

## Rules

- Plan, get approval, then implement. Shell PoC before Swift for anything new.
- One logical change per commit; the message says why. Default git identity, no trailers.
- make test before every commit; make app before App commits. Never commit red.
- Output pixel size is size x scale from the profile, never the display's. Files are written atomically. Existing files are never renamed or renumbered.
- No third-party packages; scommon is ours.
- Multi-line calls: one argument per line. No banner comment lines.
- Plain text, no em-dash character, no horizontal rules in markdown, one paragraph per line.
- Update docs/local/STATUS.md at the end of every session.
