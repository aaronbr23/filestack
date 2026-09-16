import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: StashStore
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
