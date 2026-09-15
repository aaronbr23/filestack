import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StashStore
    @ObservedObject var settings: AppSettings
    @AppStorage("language") private var language: AppLanguage = .english

    var body: some View {
        Form {
            Picker(t("Language", "Sprache", language), selection: $language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            Picker(t("Display", "Anzeige", language), selection: $settings.mode) {
                Text(t("Menu Bar", "Menüleiste", language)).tag(DisplayMode.menuBar)
                Text("Notch").tag(DisplayMode.notch).disabled(!AppSettings.notchAvailable)
            }
            .pickerStyle(.radioGroup)

            if !AppSettings.notchAvailable {
                Text(t(
                    "No notch detected on this display — notch mode disabled.",
                    "Kein Notch auf diesem Bildschirm erkannt — Notch-Modus deaktiviert.",
                    language
                ))
                .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text(t("\(store.items.count) files in the shelf", "\(store.items.count) Dateien in der Ablage", language))
                Spacer()
                Button(t("Clear Shelf", "Ablage leeren", language), role: .destructive) { store.removeAll() }
                    .disabled(store.items.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
