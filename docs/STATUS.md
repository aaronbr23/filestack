# FileStack — Project Status

> Context primer for a fresh chat session picking up this project. Written
> 2026-09-18. Update this file whenever the architecture, toolchain
> workarounds, or scope change — it goes stale otherwise.

## What this is

A local-only macOS menu bar app: drag files into a shelf, drag them back out
later. No network code, no cloud, no third parties — everything lives under
`~/Library/Application Support/FileStack/`. Menu bar icon only (a notch-panel
mode existed and was deliberately removed, see below).

Working, buildable, in daily use by the user. Two remotes, both up to date:
`origin` = Gitea (`git.rau-bach.com/aaron/filestack`, the primary clone
source), `github` = `github.com/aaronbr23/filestack` (mirror, pushed to
explicitly on request, not the default upstream).

## Toolchain — read this before touching build config

This machine has **Command Line Tools only, no Xcode**. That single fact
drives several non-obvious decisions:

- **`build.sh` pins an older SDK** (`MacOSX14.5.sdk`, auto-detected — see the
  script). The newest CLT SDK implements SwiftUI's `@State` as a compiler
  macro whose plugin only ships inside full Xcode; plain `swift build`
  against the default SDK fails with "plugin for module 'SwiftUIMacros' not
  found". Always build via `./build.sh`, or `export SDKROOT=...` manually
  before `swift build`/`swift run` — see the script for the exact path logic.
- **`@Observable` was tried and rejected** for the same reason, a different
  symptom: its macro expansion doesn't match the `Observation` runtime
  shipped in that pinned older SDK (confirmed with a standalone spike, not
  just theorized). State management stays on `ObservableObject`/`@Published`/
  Combine. Don't re-attempt `@Observable` without first re-testing on
  whatever SDK is pinned at the time.
- **No SPM test target.** `swift test`'s auto-injected Swift Testing
  framework doesn't build against the pinned SDK either (`no macro named
  'isolation'`). Verification instead lives in `SelfTest.swift`, a plain enum
  with `precondition()` checks, run via `swift build && .build/debug/FileStack
  --selftest`. Not a full framework — it's the one thing worth keeping in
  sync when `StashStore`'s logic changes.
- Swift 6 language mode's actor-isolation checking is strict even under
  `-swift-version 5` here (this toolchain's compiler, not the language
  mode, enforces it). Expect to see "call to main-actor-isolated ... in a
  synchronous nonisolated context" when a closure crosses from a
  non-`@MainActor` context (e.g. `NSViewRepresentable.updateNSView`,
  `NotificationCenter` callbacks) into `@MainActor` state — fixed by
  wrapping the call in `Task { @MainActor in ... }` at the call site, not by
  changing the isolated type.

## Architecture

One SPM executable target, no dependencies, ~800 lines across 14 files in
`Sources/FileStack/`. No storyboards/xibs, no Xcode project.

- **`StashStore`** — the model. A folder-per-item layout under
  `Stash/<uuid>/<original filename>` *is* the database (no index file);
  `reload()` re-enumerates it. `add(url:mode:)` always copies first, then
  deletes the source only for `.move` — never the other order, so a failed
  delete can't lose the file.
- **`StatusBarController` + `StatusIconView`** — the menu bar icon and the
  floating panel it opens. Custom `NSStatusItem` + hand-drawn `NSView`
  (not `MenuBarExtra`) specifically because dragging a file needs to open the
  panel on hover, which `MenuBarExtra` doesn't support. The panel is a
  borderless `NSPanel`, not `NSPopover` — `NSPopover`'s `.transient` behavior
  closed the panel the instant a drag session started, killing drag-out
  before the drop could land. Opening/closing has two failure modes already
  fixed once each, worth knowing before touching this file again:
  - Plain `.onHover` never fires during a live external file drag (only for
    ordinary mouse movement) — `PopoverContent` also needs the
    `.onDrop(isTargeted:)` catch-all to keep the panel open while dragging
    toward a drop zone, not just `.onHover`.
  - Closing is debounced (`DebouncedAction`) so leaving the icon briefly on
    the way down into the panel doesn't collapse it.
- **`FilePromise` (`DragSourceView`, `PromiseDelegate`)** — drag-out. The
  whole stash row is one hand-laid-out AppKit `NSView` (manual `layout()`
  override, not Auto Layout constraints) — an earlier Auto-Layout version
  left long filenames rendering oddly. Removal from the shelf happens only
  inside `NSFilePromiseProviderDelegate`'s completion handler, i.e. only
  after the receiver actually wrote the file — cancelling a drag leaves the
  entry untouched.
- **`DropZonesView`** — the two drop-in targets (Move / Copy), plain
  SwiftUI `.onDrop`.
- **`PanelMetrics`** — the one place panel width/height live. It used to be
  hardcoded in three places and drifted out of sync, which is exactly what
  caused clipped content before — check here first if sizing looks wrong.
- **`Localization` (`AppLanguage`, `t(en:de:)`)** — English by default,
  German switchable in Settings, independent of system locale. A deliberate
  plain lookup table, not `.strings`/String Catalogs, because this is a
  runtime in-app toggle rather than a bundle-locale switch. SwiftUI views
  read it via `@AppStorage("language")`; the one AppKit context menu (in
  `DragSourceView`) reads `UserDefaults` directly since it isn't a `View`.
  Adding a string: extend `t(_:_:_:)` call sites, no catalog to update.
- **`SettingsView`** — language picker + clear-shelf button. Used to also
  have a menu-bar/notch mode picker; removed along with notch mode.

## Removed: notch mode

A `NotchPanel.swift` (BoringNotch-style expand-from-the-notch panel) existed,
worked, and was later removed at the user's request — one display surface to
maintain instead of two. `docs/PLAN.md` still describes the original notch
design in full as a historical record (with a note at the bottom marking it
removed) — don't resurrect it from that file without checking with the user
first; it's not a hidden feature request, it's an intentional deletion.

## Environment gaps worth knowing about

- **No Screen Recording / Accessibility permission** granted to the
  terminal/harness driving this session. `screencapture` and
  `osascript … "System Events"` both fail. UI bugs have been diagnosed and
  fixed from code reading alone, not visual confirmation — if something
  still looks wrong after a fix described here, it may need the user's own
  eyes, not another blind guess. Ask the user to grant these permissions
  (System Settings → Privacy & Security) if visual verification becomes
  necessary again.
- Manual verification loop used throughout: `swift build` →
  `.build/debug/FileStack --selftest` → `./build.sh` → `killall FileStack;
  open FileStack.app` → ask the user to check the specific behavior in
  question.

## Git discipline

The user explicitly asked for "proper" git usage partway through — since
then, every change gets its own commit with a real message (what + why, not
just what), pushed to `origin` (and `github` when asked) right after. Keep
doing that; don't batch unrelated fixes into one commit.

## Open items / things the user has flagged but not resolved

- No app icon (`.icns`) — using the default generic executable icon.
- `docs/assets/banner.png` is ~1.2MB, uncompressed — fine for now, nobody's
  asked to optimize it.
- No CI, no releases/notarization — build-from-source only, documented as
  such in `README.md`.
