# sCapture

<img src="brand/scapture-1024.png" alt="sCapture icon" width="128">

sCapture is a macOS menu bar agent that captures a screenshot of a profiled window, at a fixed size and scale, into the active PoC case folder, and shows the step count. It does no editing (sNotate does) and no viewing (sView does); it is the first link of that chain. The Swift app will use Apple frameworks only and share code with its siblings through scommon.

## Part of sSuite

sSuite is a small family of macOS tools that turn work done on screen into step-by-step evidence and guides, one job per tool, published under the [uSuite](https://github.com/uSuite) organization. The organization page explains why the family exists.

| Tool | Job |
| --- | --- |
| **sCapture** (this one) | captures a window at a fixed size and scale into the active case folder (shell proof of concept today, Swift app next) |
| [sView](https://github.com/uSuite/sview) | views images and walks case folders from the keyboard |
| [sNotate](https://github.com/uSuite/snotate) | annotates a case folder as one story and exports one image per step |
| sWalk | planned: renders a notated case as an animated step-by-step clip |
| [scommon](https://github.com/uSuite/scommon) | the Swift package the tools share: folders, sorting, config and keymap |

sCapture is the first link: every capture of a procedure lands in its case folder at the same pixel size, named in capture order, so sView can flip through it and sNotate can annotate it as one story without resizing or moving a file.

## State

Phase 0, the shell proof of concept: `scripts/poc.sh` positions a window, captures it into the active case folder with a chronological name and prints the step count. The Swift app follows.

## Proof of concept

`scripts/poc.sh use <case-id>` makes a case under `~/Pictures/scapture` the active one (`SCAPTURE_ROOT` changes the root), `scripts/poc.sh shot [app] [title]` captures the app's window into it as `scap-YYYY-MM-DD-HHMMSS.png`, and `scripts/poc.sh` alone prints the active case and its count. `make poc ARGS="shot"` runs the same. Bound to a key with a Shortcuts "Run Shell Script" action it is a hotkey; the terminal or Shortcuts needs the Screen Recording and Accessibility permissions.

## Development

macOS 26 and Xcode 26 (Swift 6.2). The design lives in [docs/02-tech-stack.md](docs/02-tech-stack.md), the backlog in [docs/01-backlog.md](docs/01-backlog.md) and the decisions in [docs/DECISIONS.md](docs/DECISIONS.md).

## Licence

MIT, see [LICENSE](LICENSE).
