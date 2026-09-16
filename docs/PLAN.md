# FileStack — Local File Shelf for macOS

> Original design plan from before implementation started. Kept as historical
> record — a few details changed along the way (see note at the bottom).

## Context

The `filestack` repo started empty. Goal: a fully local Mac app that replaces
BoringNotch's file-shelf feature. Motivation: no trust in a third-party tool
having file access — so the app must contain **no network code at all**, all
data stays under `~/Library/Application Support/FileStack/`.

Scope:
- Drag files into a temporary shelf, drag them back out later.
- Two display modes: a menu bar icon (like WireGuard) **or** a notch panel
  with an expand animation.
- Two drop-in zones: **Move** (removes the original at its source) and
  **Copy** (leaves the original in place).
- Dragging an item back out always removes it from the shelf.

Decisions (confirmed by the user):
| Topic | Decision |
|---|---|
| Storage | Real copy under Application Support, not just a reference |
| Drop-in | Two zones: Move (original gone) / Copy (original stays) |
| Drag-out | Entry leaves the shelf as soon as the receiver has accepted the file |
| Toolchain | Swift Package Manager, no Xcode (Command Line Tools only) |
| Notch fallback | Falls back to menu bar mode automatically without a hardware notch |

## Technical Framework

- macOS 26.6, Swift 6.4, SwiftUI + AppKit. No Xcode → SPM executable + shell
  script that assembles the `.app` bundle.
- No sandbox (no convenient entitlement handling without Xcode) → "moving"
  the original works with plain `FileManager`. In exchange, the OS asks for
  Full Disk Access / per-folder TCC permission (Desktop/Documents/Downloads)
  on first access.
- No external dependencies.

## File Structure

```
Package.swift
build.sh                       # swift build -c release + assemble the .app bundle
Resources/Info.plist           # LSUIElement=1 (no Dock icon), bundle ID, version
PLAN.md                        # copy of this plan into the project root (step 0)
Sources/FileStack/
  FileStackApp.swift           # @main, AppDelegate, mode switching
  StashStore.swift             # model + disk operations
  StashItem.swift              # struct: id, url, name, size, addedAt, lazy NSImage icon
  DropZonesView.swift          # two drop targets: move / copy
  StashListView.swift          # list, drag-out, delete, Quick Look
  FilePromise.swift            # NSFilePromiseProvider + delegate (drag-out)
  NotchPanel.swift             # NSPanel, notch geometry, expand/collapse
  SettingsView.swift           # mode picker, autostart, clear shelf
```

## Core Building Blocks

### 1. Storage (`StashStore.swift`)

On-disk layout — the directory itself **is** the database, no separate index
file:

```
~/Library/Application Support/FileStack/Stash/<uuid>/<original filename>
```

One UUID subfolder per entry avoids name collisions and preserves the
original filename. On launch the folder is enumerated once
(`FileManager.contentsOfDirectory`), sorted by `creationDate`, into the
`[StashItem]` list — persistence and restoring state come for free.

API:
- `add(url: URL, mode: .move | .copy)` — create the destination folder,
  `copyItem`, then for `.move` follow up with `removeItem(at: url)` at the
  source. Copy-then-delete is deliberate so a failure never loses the file.
  `moveItem` isn't used because it's unreliable across volume boundaries and
  with Downloads-folder TCC prompts.
- `remove(_ item:)` — delete the subfolder.
- `removeAll()`.
- Watching the folder with `DispatchSource.makeFileSystemObjectSource`
  (stdlib) is optional; with only one writer (the app itself), directly
  updating the published list is enough.

### 2. Drop-in: Two Zones (`DropZonesView.swift`)

Two side-by-side `.onDrop(of: [.fileURL], isTargeted:)` regions, clearly
labeled ("Move — removes the original" / "Copy — original stays"), with a
hover highlight and distinct icons (`arrow.right.doc.on.clipboard` /
`doc.on.doc`). Both call the same `store.add(url:mode:)` with a different
mode. Multi-selection is supported (multiple providers per drop).

Folders are treated like files (`copyItem` copies recursively).

### 3. Drag-out with Guaranteed Removal (`FilePromise.swift`)

A plain `.onDrag { NSItemProvider(contentsOf: url) }` doesn't reliably report
whether the drop was accepted. Using `NSFilePromiseProvider` instead:

- An `NSViewRepresentable` wrapper around a small `NSView` that starts the
  drag.
- `NSFilePromiseProviderDelegate.filePromiseProvider(_:writePromiseTo:completionHandler:)`
  copies the file to the destination; **only inside the completion handler**
  is `store.remove(item)` called.
- If the user cancels or the target rejects it, the entry stays.
- Additionally `draggingSession(_:endedAt:operation:)` as a safety net for
  targets that don't support promises (falls back to `operation != []`).

### 4. Menu Bar Mode

SwiftUI `MenuBarExtra("FileStack", systemImage: …) { StashPanelView() }` with
`.menuBarExtraStyle(.window)`. No manual `NSStatusItem` needed. The badge
shows the item count. Important: drops directly onto the menu bar icon don't
work — the popover has to be open first. So the icon symbol reflects the
fill state, and the drop zones live inside the popover.

### 5. Notch Mode (`NotchPanel.swift`)

- Availability check: `NSScreen.main?.safeAreaInsets.top ?? 0 > 0` (or
  `auxiliaryTopLeftArea`). If it's 0, the mode picker automatically switches
  to menu bar mode and shows an explanatory note.
- A borderless `NSPanel` (`styleMask: [.borderless, .nonactivatingPanel]`,
  `level: .statusBar + 1`, `collectionBehavior: [.canJoinAllSpaces,
  .fullScreenAuxiliary]`, `isOpaque = false`), positioned centered at the top
  edge, sized to the notch while collapsed.
- Collapsed: invisible, exactly covers the notch area, and is registered as a
  drag destination.
- `draggingEntered` or `onHover` → the panel grows animated
  (`NSAnimationContext`, size + SwiftUI `.transition`) into the full shelf
  panel with rounded bottom corners, visually growing out of the notch.
  Leaving → collapses after a short delay (~0.4s) so the path to the panel
  doesn't break.
- Display/resolution change: `NSApplication.didChangeScreenParametersNotification`
  → reposition.

### 6. Settings (`SettingsView.swift`)

- Mode: menu bar / notch (notch disabled when unavailable) — `@AppStorage`.
- Autostart: `SMAppService.mainApp.register()` / `.unregister()`.
- Show storage used + "Clear shelf".
- Optional (later): auto-delete entries older than N days.

### 7. Build (`build.sh`)

```
swift build -c release
mkdir -p FileStack.app/Contents/{MacOS,Resources}
cp .build/release/FileStack FileStack.app/Contents/MacOS/
cp Resources/Info.plist FileStack.app/Contents/
codesign --force --deep --sign - FileStack.app     # ad-hoc, keeps TCC grants stable
```

Ad-hoc signing matters: without a stable signature, macOS re-asks for
file-access permissions after every rebuild.

## Implementation Order

1. Write `PLAN.md` into the project root (copy of this document).
2. `Package.swift`, `Info.plist`, `build.sh` → an empty app that starts as a
   menu bar icon (rung 1).
3. `StashStore` + `StashItem` + directory enumeration, with a self-check.
4. Menu bar popover: list + two drop zones. The app is usable from here on.
5. Drag-out via `NSFilePromiseProvider`, including removal only after a
   confirmed drop.
6. Settings (mode, autostart, clear).
7. Notch panel with animation + automatic fallback.
8. Polish: icons via `NSWorkspace.shared.icon(forFile:)`, Quick Look via
   `QLPreviewPanel`, context menu (reveal in Finder / remove).

## Verification

Built-in self-check: a `demo()` function or `Tests/StashStoreTests.swift`
with assertion checks for `add(.copy)` (original still exists), `add(.move)`
(original gone, copy present), `remove` (folder gone) — against a temporary
directory, no UI involved.

Manual, after building (`./build.sh && open FileStack.app`):
1. Drag a file from Finder onto the **Copy** zone → appears in the list,
   original still there.
2. Same file onto the **Move** zone → appears in the list, original is gone.
3. `ls ~/Library/Application\ Support/FileStack/Stash/` → one UUID folder per
   entry.
4. Drag an entry onto the Desktop → the file lands there, the entry
   disappears from the list.
5. Cancel a drag (Escape / drop nowhere) → the entry stays.
6. Quit and relaunch the app → list is identical.
7. Switch mode to Notch → the panel expands on hover and on drag-hover; on an
   external display without a notch the app falls back to menu bar mode.
8. Drop a folder and a multi-selection.
9. `grep -rE "URLSession|Network|http" Sources/` → no matches (privacy claim).

## Deliberately Left Out

- iCloud sync, encryption, a history database — local and flat is enough.
- A custom icon cache layer — `NSWorkspace` already provides icons.
- Sandbox entitlements — would make "move the original" unnecessarily
  complicated without Xcode.

---

**What changed during implementation:** the self-check ended up as a plain
`SelfTest.swift` with `precondition()` (run via `--selftest`) instead of an
XCTest target — Swift Testing's bundled framework didn't build against the
pinned older SDK this toolchain needs (see `build.sh`'s comment). Autostart
was skipped as YAGNI (nobody asked for it yet). The menu bar mode ended up as
a custom `NSStatusItem` + borderless `NSPanel` (`StatusBarController.swift`)
rather than `MenuBarExtra`, because dragging a file needs to open the panel
on hover, which `MenuBarExtra` can't do. An English/German UI language
toggle was added later (`Localization.swift`), not part of the original
plan.

**Notch mode was removed.** Section 5 above and the "two display modes"
framing throughout this document describe the original design, including a
`NotchPanel.swift` that expanded a panel out of the hardware notch. It shipped
and worked, but the user later decided to drop it and keep only the menu bar
icon — simpler surface, one thing to maintain. `NotchPanel.swift` and the
`AppSettings`/`DisplayMode` mode-switching it needed are gone from the
codebase; this document is left as-is otherwise since it's a historical
record of the original design, not current documentation (see `README.md`
for that).
