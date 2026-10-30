# sCapture: landscape

sCapture is the third sibling and the first link of the chain: it puts screenshots into a PoC case folder with repeatable geometry, so that sNotate can annotate them as one story and sView can flip through them. Shottr is the reference for speed and feel (see `docs/00-landscape.md` in the sNotate repository for the five-line summary); this page covers what matters for capture only. Written 2026-10-25.

## What exists

- macOS `screencapture` (built in, CLI): `-R x,y,w,h` captures a rect, `-l <windowid>` a window, `-x` silences the sound, `-o` drops the shadow, `-T n` delays, `-t png` sets the format. It cannot find a window id by app name on its own and knows nothing about scale, but a 20-line shell script around it is a complete proof of the workflow and is sCapture's Phase 0.
- The Guide-Shot AppleScripts (`Guide-Shot-BMP.scpt`, `Guide-Shot-BMP-Screen.scpt`, `postitioning-window.scpt`, `Google-Chrome.scpt` in the Script Editor iCloud folder): Sam's current capture path; they position a window and shoot. They are the requirements document for sCapture and get decompiled (`osadecompile`) and read in Phase 0 before any Swift is written.
- Shottr (free, native, 2.4 MB): 17 ms grab, 165 ms to display, area, window, any-window, fullscreen, scrolling, delayed and repeat-last-area capture, editor opens at once, saves to a chosen folder with Cmd+S; no notion of a destination that changes per task, no fixed-scale output, no sequence counter.
- CleanShot X (paid): capture history, overlay, all-in-one multi-screen capture, recording; same gap, the destination is one folder.
- Scribe, Tango, StepGrab: capture a step on every click while a task is recorded; the right trigger for procedure documentation, delivered as SaaS with its own storage. sCapture parks the click trigger as a later item (SC-701) and keeps the folder.

## The three things none of them do, and sCapture does

1. Destination is the active case folder, switched from the keyboard, with the step count shown in the menu bar; a capture never has to be moved afterwards.
2. Geometry is a profile: the target window is placed at a fixed position and size in points and captured at a fixed scale (1x or 2x), so every capture of a PoC has the same pixel dimensions. Without it, one PoC ends up holding the same window at 1518 x 892 and at 3036 x 1784, two scales; sCapture makes that impossible.
3. File names follow the evidence procedure: chronological capture names by default so an evidence script can rename them after the author has deleted the wrong ones, or `<case-id>-<nn>` directly when the author wants no second step.

## Sources

- [Shottr](https://shottr.cc/)
- [CleanShot vs Shottr](https://thesweetbits.com/cleanshot-vs-shottr/)
- [StepGrab announcement](https://forums.macrumors.com/threads/stepgrab-record-a-task-once-get-an-annotated-step-by-step-guide-menu-bar-app.2485533/)
- `man screencapture` on any Mac
