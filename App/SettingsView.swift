import SwiftUI

/// Global settings: iCloud sync, app lock, filter update, about.
struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $model.settings.useICloudSync) {
                        Label("iCloud sync", systemImage: "icloud")
                    }
                    Toggle(isOn: $model.settings.useAppLock) {
                        Label("App Lock (Face ID)", systemImage: "lock")
                    }
                } header: {
                    Text("Sync & security")
                } footer: {
                    Text("iCloud sync mirrors settings and list choices across your devices. App Lock requires Face ID or Touch ID when returning from the background.")
                }

                Section("Filters") {
                    Button {
                        Task { await model.updateFilters() }
                    } label: {
                        HStack {
                            Label("Update filter lists", systemImage: "arrow.triangle.2.circlepath")
                            Spacer()
                            if model.isUpdating {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(model.isUpdating)

                    if let date = model.settings.lastFilterUpdate {
                        LabeledContent("Last update",
                                       value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                    LabeledContent("Rules installed", value: "\(model.totalRuleCount)")
                }

                Section("About") {
                    LabeledContent("Version", value: versionString)
                    LabeledContent("License", value: "MIT")
                    Button {
                        openURL(URL(string: "https://easylist.to/")!)
                    } label: {
                        Label("Filter list credits", systemImage: "link")
                    }
                } footer: {
                    Text("LibreBlock is free software with every feature unlocked. Community filter lists are downloaded from their maintainers and remain the property of their authors.")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }
}

// MARK: - Onboarding

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                featureTour.tag(1)
                safariSteps.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack {
                if page > 0 {
                    Button("Back") { withAnimation { page -= 1 } }
                        .buttonStyle(.bordered)
                }
                Spacer()
                if page < 2 {
                    Button("Next") { withAnimation { page += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Get started") {
                        model.settings.onboardingCompleted = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "shield.checkerboard")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("LibreBlock")
                .font(.largeTitle.bold())
            Text("Every blocking feature.\nCompletely free, forever.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(32)
    }

    private var featureTour: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("What you get")
                .font(.title.bold())
            feature("checkmark.shield", "Six blocking extensions",
                    "Ads, privacy, social, safety, annoyances and custom rules — one toggle each in Safari.")
            feature("globe", "28 filter lists",
                    "Community-maintained lists in 20+ languages, updated on demand.")
            feature("icloud", "iCloud sync",
                    "Your settings follow you across iPhone, iPad and Mac.")
            feature("lock", "App Lock",
                    "Optional Face ID protection for the app itself.")
            feature("waveform", "Siri shortcuts",
                    "\u{201C}Hey Siri, update my blockers\u{201D} just works.")
            Spacer()
        }
        .padding(32)
    }

    private var safariSteps: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Turn it on in Safari")
                .font(.title.bold())
            VStack(alignment: .leading, spacing: 18) {
                step(1, "Open the Settings app")
                step(2, "Tap Safari, then Extensions")
                step(3, "Switch on all six LibreBlock extensions")
                step(4, "For each, allow it on the sites you visit")
            }
            Text("This one-time setup takes under a minute.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(32)
    }

    private func feature(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 34)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n).")
                .font(.body.monospaced().weight(.semibold))
                .foregroundStyle(.tint)
            Text(text)
        }
        .font(.body)
    }
}
