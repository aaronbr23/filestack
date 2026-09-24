import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StashStore
    @AppStorage("language") private var language: AppLanguage = .english
    @AppStorage("removeAfterDragOut") private var removeAfterDragOut: Bool = false

    var body: some View {
        Form {
            Picker(t("Language", "Sprache", language), selection: $language) {
                ForEach(AppLanguage.allCases, id: \.self) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.radioGroup)

            Divider()

            Toggle(
                t(
                    "Remove file from shelf after dragging it out",
                    "Datei nach dem Herausziehen aus der Ablage entfernen",
                    language
                ),
                isOn: $removeAfterDragOut
            )

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
