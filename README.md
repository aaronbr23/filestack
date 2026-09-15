# FileStack

![FileStack](docs/assets/banner.png)

A local-only macOS shelf for files: drag files in, drag them back out later.
No cloud, no sync, no network access at all — everything lives in
`~/Library/Application Support/FileStack`.

Inspired by BoringNotch's file-shelf feature, built as a standalone app for
anyone who doesn't want a third-party menu bar tool touching their files.

## Features

- **Two display modes** — a plain menu bar icon (à la WireGuard), or a
  BoringNotch-style panel that expands out of the notch. Falls back to the
  menu bar automatically on displays without a notch.
- **Drag in, two ways** — a "Move" zone (removes the original) and a "Copy"
  zone (keeps it) side by side.
- **Drag out** — drop a stashed file anywhere (Finder, another app); it's
  removed from the shelf only once the drop actually succeeds.
- **Open on hover** — the icon/panel expands on mouse hover or while dragging
  a file over it, not just on click.
- **100% local** — no network code anywhere in the source. Verify yourself:
  `grep -rE "URLSession|Network|http" Sources/`

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (full Xcode is **not** required)

## Installation

FileStack isn't notarized or distributed as a signed release yet, so it's
build-from-source for now:

```bash
git clone https://github.com/<your-username>/filestack.git
cd filestack
./build.sh
open FileStack.app
```

`build.sh` compiles a release build with Swift Package Manager and assembles
`FileStack.app`, ad-hoc signed so macOS doesn't re-ask for file-access
permissions on every rebuild.

To have it launch automatically, drag `FileStack.app` into `/Applications`
and add it in **System Settings → General → Login Items**.

## Usage

1. Click (or hover) the menu bar icon to open the shelf.
2. Drag a file onto **Move** (removes it from its original location) or
   **Copy** (leaves the original in place).
3. Drag a stashed file out to Finder, another app, or the Desktop — it
   disappears from the shelf once the drop lands.
4. Right-click an item to reveal it in Finder or remove it directly.
5. Open **Settings** from the shelf's footer to switch between menu bar and
   notch mode, or clear the shelf entirely.

## Development

```bash
swift build                          # debug build
.build/debug/FileStack --selftest    # runs the built-in self-check
./build.sh                           # release build + .app bundle
```

There's no Xcode project — this is a plain Swift Package. See
[`docs/PLAN.md`](docs/PLAN.md) for the original design notes.

## Privacy

FileStack never makes a network request. Files you stash are copied into
`~/Library/Application Support/FileStack/Stash/`, one folder per item, and
deleted from there the moment you drag them back out (or clear the shelf
from Settings).
