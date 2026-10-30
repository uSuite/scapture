# sCapture

macOS menu bar agent that captures a screenshot of a profiled window, at a fixed size and scale, into the active PoC case folder, and shows the step count. No editing (sNotate, ../snotate), no viewing (sView, ../sview). Swift 6.2, Apple frameworks only, macOS 26, shared code from ../scommon. Read docs/02-tech-stack.md, docs/01-backlog.md (SC-xxx), docs/DECISIONS.md (source of truth), and the local working notes docs/local/STATUS.md (where we are) and docs/local/03-plan-claude-code.md (phases); docs/local/ is ignored by git and never published.

## Commands

- `make gen`    regenerate sCapture.xcodeproj from project.yml
- `make test`   swift test on SCaptureCore
- `make app`    xcodebuild Debug sCapture.app into build/
- `make run`    build and launch the agent
- `make smoke`  capture a test window with two profiles, assert names and pixel sizes
- `make poc`    run scripts/poc.sh (the shell proof of concept)

## Layers

Core (Sources/SCaptureCore: ActiveCase, Profile, Namer, Writer, Log, Commands; Capturer and Positioner as protocols) -> App (Sources/sCapture: MenuBarExtra, SCK capturer, AX positioner, Carbon hotkeys, panels, CLI). Core has no ScreenCaptureKit or Accessibility import.

## Rules

- Plan, get approval, then implement. Shell PoC before Swift for anything new.
- One logical change per commit; the message says why. Default git identity, no trailers.
- make test before every commit; make app before App commits. Never commit red.
- Output pixel size is size x scale from the profile, never the display's. Files are written atomically. Existing files are never renamed or renumbered.
- No third-party packages; scommon is ours.
- Multi-line calls: one argument per line. No banner comment lines.
- Plain text, no em-dash character, no horizontal rules in markdown, one paragraph per line.
- Update docs/local/STATUS.md at the end of every session.
