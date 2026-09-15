# FileStack — Lokale Datei-Zwischenablage für macOS

## Context

Das Repo `filestack` ist leer. Ziel: eine eigene, vollständig lokale Mac-App als Ersatz für das
Datei-Ablage-Feature von BoringNotch. Begründung des Nutzers: kein Vertrauen in Drittanbieter mit
Dateizugriff — die App darf daher **keinerlei Netzwerkcode** enthalten, alle Daten bleiben unter
`~/Library/Application Support/FileStack/`.

Funktionsumfang:
- Dateien per Drag & Drop in eine temporäre Ablage legen, später wieder herausziehen.
- Zwei Anzeige-Modi: Menüleisten-Icon (wie WireGuard) **oder** Notch-Panel mit Ausklapp-Animation.
- Beim Hineinziehen zwei Zonen: **Verschieben** (Original am Ursprungsort wird entfernt) und
  **Kopieren** (Original bleibt liegen).
- Beim Herausziehen verschwindet der Eintrag immer aus der Ablage.

Entscheidungen (vom Nutzer bestätigt):
| Thema | Entscheidung |
|---|---|
| Ablage-Speicher | Echte Kopie unter Application Support, nicht nur Referenz |
| Drop-In | Zwei Zonen: Verschieben (Original weg) / Kopieren (Original bleibt) |
| Drag-Out | Eintrag verlässt die Ablage, sobald der Empfänger die Datei angenommen hat |
| Toolchain | Swift Package Manager, kein Xcode (nur Command Line Tools vorhanden) |
| Notch-Fallback | Ohne Hardware-Notch automatisch Menüleisten-Modus |

## Technischer Rahmen

- macOS 26.6, Swift 6.4, SwiftUI + AppKit. Kein Xcode → SPM-Executable + Shell-Skript, das das
  `.app`-Bundle zusammensetzt.
- Keine Sandbox (ohne Xcode kein bequemes Entitlement-Handling) → „Verschieben“ des Originals
  funktioniert mit normalem `FileManager`. Dafür einmalig „Festplattenvollzugriff“ bzw. die
  TCC-Abfragen für Schreibtisch/Dokumente/Downloads beim ersten Zugriff.
- Keine externen Dependencies.

## Dateistruktur

```
Package.swift
build.sh                       # swift build -c release + .app-Bundle bauen
Resources/Info.plist           # LSUIElement=1 (kein Dock-Icon), Bundle-ID, Version
PLAN.md                        # Kopie dieses Plans ins Projektroot (Schritt 0)
Sources/FileStack/
  FileStackApp.swift           # @main, AppDelegate, Modus-Umschaltung
  StashStore.swift             # Modell + Plattenoperationen
  StashItem.swift              # Struct: id, url, name, size, addedAt, NSImage-Icon (lazy)
  DropZonesView.swift          # Zwei Drop-Targets: Verschieben / Kopieren
  StashListView.swift          # Liste, Drag-out, Löschen, Quick Look
  FilePromise.swift            # NSFilePromiseProvider + Delegate (Drag-out)
  NotchPanel.swift             # NSPanel, Notch-Geometrie, Expand/Collapse
  SettingsView.swift           # Modus-Picker, Autostart, Ablage leeren
```

## Kernbausteine

### 1. Speicher (`StashStore.swift`)

Layout auf Platte — das Verzeichnis **ist** die Datenbank, keine separate Index-Datei:

```
~/Library/Application Support/FileStack/Stash/<uuid>/<Originaldateiname>
```

Ein UUID-Unterordner pro Eintrag löst Namenskollisionen und bewahrt den Originalnamen.
Beim Start wird der Ordner einmal enumeriert (`FileManager.contentsOfDirectory`), sortiert nach
`creationDate` → daraus die `[StashItem]`-Liste. Persistenz und Wiederherstellung damit gratis.

API:
- `add(url: URL, mode: .move | .copy)` — Zielordner anlegen, `copyItem`, bei `.move` anschließend
  `removeItem(at: url)` am Ursprungsort. Reihenfolge ist bewusst kopieren-dann-löschen, damit ein
  Fehler nie zu Datenverlust führt. `moveItem` wird nicht benutzt, weil es über Volume-Grenzen
  hinweg und bei Downloads-TCC unzuverlässig ist.
- `remove(_ item:)` — Unterordner löschen.
- `removeAll()`.
- Ordner überwachen mit `DispatchSource.makeFileSystemObjectSource` (Stdlib) ist optional; bei nur
  einem Schreiber (der App selbst) reicht direktes Aktualisieren der `@Published`-Liste.

### 2. Drop-In: zwei Zonen (`DropZonesView.swift`)

Zwei nebeneinanderliegende `.onDrop(of: [.fileURL], isTargeted:)`-Bereiche, klar beschriftet
(„Verschieben — Original wird entfernt“ / „Kopieren — Original bleibt“), mit Hover-Highlight und
unterschiedlichen Symbolen (`arrow.right.doc.on.clipboard` / `doc.on.doc`).
Beide rufen dasselbe `store.add(url:mode:)` mit unterschiedlichem `mode`. Mehrfachauswahl wird
unterstützt (mehrere Provider pro Drop).

Ordner werden wie Dateien behandelt (`copyItem` kopiert rekursiv).

### 3. Drag-Out mit garantiertem Entfernen (`FilePromise.swift`)

Ein einfaches `.onDrag { NSItemProvider(contentsOf: url) }` meldet nicht zuverlässig, ob der Drop
angenommen wurde. Stattdessen `NSFilePromiseProvider`:

- `NSViewRepresentable`-Wrapper um eine kleine `NSView`, die den Drag startet.
- `NSFilePromiseProviderDelegate.filePromiseProvider(_:writePromiseTo:completionHandler:)` kopiert
  die Datei an das Ziel; **erst im Completion-Handler** wird `store.remove(item)` aufgerufen.
- Bricht der Nutzer ab oder lehnt das Ziel ab, bleibt der Eintrag erhalten.
- Zusätzlich `draggingSession(_:endedAt:operation:)` als Sicherheitsnetz für Ziele, die keine
  Promises unterstützen (dort Fallback auf `operation != []`).

### 4. Menüleisten-Modus

SwiftUI `MenuBarExtra("FileStack", systemImage: …) { StashPanelView() }` mit `.menuBarExtraStyle(.window)`.
Kein manuelles `NSStatusItem` nötig. Das Badge zeigt die Anzahl der Einträge.
Wichtig: Drops auf das Menüleisten-Icon selbst funktionieren nicht — das Popover muss geöffnet sein.
Deshalb zeigt das Icon-Symbol den Füllstand, und die Drop-Zonen liegen im Popover.

### 5. Notch-Modus (`NotchPanel.swift`)

- Verfügbarkeitsprüfung: `NSScreen.main?.safeAreaInsets.top ?? 0 > 0` (bzw.
  `auxiliaryTopLeftArea`). Ist der Wert 0 → Modus-Picker schaltet automatisch auf Menüleiste um und
  zeigt einen erklärenden Hinweis.
- Ein randloser `NSPanel` (`styleMask: [.borderless, .nonactivatingPanel]`,
  `level: .statusBar + 1`, `collectionBehavior: [.canJoinAllSpaces, .fullScreenAuxiliary]`,
  `isOpaque = false`), positioniert an der Oberkante mittig, Breite/Höhe der Notch im eingeklappten
  Zustand.
- Eingeklappt: unsichtbar, deckt exakt die Notch-Fläche ab und ist als Drag-Ziel registriert.
- `draggingEntered` oder `onHover` → Panel wächst animiert (`NSAnimationContext`, Größe + SwiftUI
  `.transition`) auf das volle Ablage-Panel mit abgerundeten unteren Ecken, das optisch aus der
  Notch herauswächst. Verlassen → Einklappen nach kurzer Verzögerung (~0,4 s), damit der Weg zum
  Panel nicht abreißt.
- Displaywechsel/Auflösungsänderung: `NSApplication.didChangeScreenParametersNotification` →
  neu positionieren.

### 6. Einstellungen (`SettingsView.swift`)

- Modus: Menüleiste / Notch (Notch deaktiviert, wenn kein Notch vorhanden) — `@AppStorage`.
- Autostart: `SMAppService.mainApp.register()` / `.unregister()`.
- Belegter Speicher anzeigen + „Ablage leeren“.
- Optional (später): automatisches Löschen von Einträgen älter als N Tage.

### 7. Build (`build.sh`)

```
swift build -c release
mkdir -p FileStack.app/Contents/{MacOS,Resources}
cp .build/release/FileStack FileStack.app/Contents/MacOS/
cp Resources/Info.plist FileStack.app/Contents/
codesign --force --deep --sign - FileStack.app     # Ad-hoc, damit TCC-Rechte stabil bleiben
```

Ad-hoc-Signatur ist wichtig: ohne stabile Signatur fragt macOS nach jedem Rebuild erneut nach
Dateizugriffsrechten.

## Umsetzungsreihenfolge

1. `PLAN.md` ins Projektroot schreiben (Kopie dieses Dokuments).
2. `Package.swift`, `Info.plist`, `build.sh` → leere App startet als Menüleisten-Icon (Rung 1).
3. `StashStore` + `StashItem` + Verzeichnis-Enumeration, mit Selbsttest.
4. Menüleisten-Popover: Liste + zwei Drop-Zonen. Ab hier ist die App benutzbar.
5. Drag-Out über `NSFilePromiseProvider`, inkl. Entfernen nach bestätigtem Drop.
6. Einstellungen (Modus, Autostart, Leeren).
7. Notch-Panel mit Animation + automatischer Fallback.
8. Feinschliff: Icons per `NSWorkspace.shared.icon(forFile:)`, Quick Look via `QLPreviewPanel`,
   Kontextmenü (Im Finder zeigen / Entfernen).

## Verifikation

Selbsttest im Code: eine `demo()`-Funktion bzw. `Tests/StashStoreTests.swift` mit `assert`-Prüfungen
für `add(.copy)` (Original existiert noch), `add(.move)` (Original weg, Kopie da), `remove`
(Ordner weg) — auf einem temporären Verzeichnis, ohne UI.

Manuell nach dem Build (`./build.sh && open FileStack.app`):
1. Datei aus dem Finder auf die **Kopieren**-Zone → erscheint in der Liste, Original liegt noch da.
2. Dieselbe Datei auf die **Verschieben**-Zone → erscheint in der Liste, Original ist weg.
3. `ls ~/Library/Application\ Support/FileStack/Stash/` → ein UUID-Ordner pro Eintrag.
4. Eintrag auf den Schreibtisch ziehen → Datei liegt dort, Eintrag ist aus der Liste verschwunden.
5. Drag abbrechen (Escape / ins Leere) → Eintrag bleibt erhalten.
6. App beenden und neu starten → Liste identisch.
7. Modus auf Notch umstellen → Panel klappt bei Hover und bei Drag-Hover aus; auf externem Monitor
   ohne Notch fällt die App auf den Menüleisten-Modus zurück.
8. Ordner und Mehrfachauswahl droppen.
9. `grep -rE "URLSession|Network|http" Sources/` → keine Treffer (Datenschutz-Zusage).

## Bewusst weggelassen

- iCloud/Sync, Verschlüsselung, Verlaufsdatenbank — lokal und flach reicht.
- Eigenes Icon-Cache-Layer — `NSWorkspace` liefert die Icons.
- Sandbox-Entitlements — würden das „Original verschieben“ ohne Xcode unnötig verkomplizieren.
