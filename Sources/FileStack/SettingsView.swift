import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StashStore
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Picker("Anzeige", selection: $settings.mode) {
                Text("Menüleiste").tag(DisplayMode.menuBar)
                Text("Notch").tag(DisplayMode.notch).disabled(!AppSettings.notchAvailable)
            }
            .pickerStyle(.radioGroup)

            if !AppSettings.notchAvailable {
                Text("Kein Notch auf diesem Bildschirm erkannt — Notch-Modus deaktiviert.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("\(store.items.count) Dateien in der Ablage")
                Spacer()
                Button("Ablage leeren", role: .destructive) { store.removeAll() }
                    .disabled(store.items.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
