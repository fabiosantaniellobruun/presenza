import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(awayKey) private var awaySeconds = defaultAwaySeconds
    @State private var language = Self.savedLanguage
    @State private var needsRelaunch = false
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled
    @State private var needsApproval = SMAppService.mainApp.status == .requiresApproval

    var body: some View {
        Form {
            Section {
                LabeledContent("Blocca dopo") {
                    HStack {
                        // whole seconds, without the tick marks a `step` would draw
                        Slider(value: Binding(get: { awaySeconds }, set: { awaySeconds = $0.rounded() }), in: 3...60) {
                            Text("Blocca dopo")
                        }
                        .labelsHidden()
                        .accessibilityValue(Text("\(Int(awaySeconds)) secondi"))
                        Text("\(Int(awaySeconds)) s")
                            .monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                    .frame(width: 220)
                }
            } footer: {
                Text("Quanto aspettare, quando non ti vede più, prima di bloccare lo schermo.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Lingua", selection: $language) {
                    Text("Lingua del sistema").tag(String?.none)
                    Text(verbatim: "Italiano").tag(String?.some("it"))
                    Text(verbatim: "English").tag(String?.some("en"))
                }
                .onChange(of: language) {
                    if let language {
                        UserDefaults.standard.set([language], forKey: Self.languageKey)
                    } else {
                        UserDefaults.standard.removeObject(forKey: Self.languageKey)
                    }
                    needsRelaunch = true
                }
            } footer: {
                if needsRelaunch {
                    HStack {
                        Text("La nuova lingua vale dalla prossima apertura.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Riapri ora", action: Self.relaunch)
                    }
                }
            }

            Section {
                Toggle("Apri Presenza all'avvio del Mac", isOn: Binding(get: { opensAtLogin }, set: setLoginItem))
            } footer: {
                if needsApproval {
                    Text("macOS chiede una conferma: Impostazioni di Sistema → Generali → Elementi login.")
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize()
    }

    // MARK: Language: macOS picks it at launch from the app's own `AppleLanguages`, so changing it means reopening

    private static let languageKey = "AppleLanguages"

    /// The app's own choice, nil = follow the system. `standard` would fall back to the global value.
    private static var savedLanguage: String? {
        let own = Bundle.main.bundleIdentifier.flatMap { UserDefaults.standard.persistentDomain(forName: $0) }
        return (own?[languageKey] as? [String])?.first
    }

    private static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    // MARK: Login item

    private func setLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Presenza login item: %@", error.localizedDescription)
        }
        // the toggle follows what macOS actually did
        let status = SMAppService.mainApp.status
        opensAtLogin = status == .enabled || status == .requiresApproval
        needsApproval = status == .requiresApproval
    }
}
