import SwiftUI

/// Chooses between onboarding, lock screen and the main UI.
struct RootView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var lock: AppLockController

    var body: some View {
        ZStack {
            if !model.settings.onboardingCompleted {
                OnboardingView()
            } else {
                MainTabView()
                if lock.isLocked {
                    LockScreen()
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: lock.isLocked)
    }
}

struct MainTabView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "shield.checkerboard") }
            GroupsView()
                .tabItem { Label("Blocking", systemImage: "slider.horizontal.3") }
            CustomRulesView()
                .tabItem { Label("Custom", systemImage: "person.and.background.dotted") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("Blocking is active")
                                .font(.title3.bold())
                        } icon: {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.title)
                                .foregroundStyle(.green)
                        }
                        Text("\(model.totalRuleCount) rules installed across \(enabledGroupCount) of \(BlockerGroup.allCases.count) extensions.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Open Safari Settings → Extensions to verify each of the six LibreBlock extensions is allowed on the websites you visit.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Last filter update") {
                    if model.isUpdating {
                        HStack {
                            ProgressView()
                            Text("Updating filter lists…")
                                .foregroundStyle(.secondary)
                        }
                    } else if let date = model.settings.lastFilterUpdate {
                        Label(date.formatted(date: .abbreviated, time: .shortened),
                              systemImage: "clock.arrow.circlepath")
                    } else {
                        Label("Never — update now", systemImage: "clock")
                            .foregroundStyle(.orange)
                    }
                    Button {
                        Task { await model.updateFilters() }
                    } label: {
                        Label("Update now", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .disabled(model.isUpdating)
                }

                if !model.lastUpdateResult.isEmpty {
                    Section {
                        ForEach(model.lastUpdateResult.keys.sorted(), id: \.self) { id in
                            HStack {
                                Text(listName(id))
                                Spacer()
                                switch model.lastUpdateResult[id] {
                                case .success:
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                case .failure:
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                                default:
                                    EmptyView()
                                }
                            }
                        }
                    } header: {
                        Text("Update report")
                    } footer: {
                        Text("Failures keep the previously cached copy; blocking continues.")
                    }
                }
            }
            .navigationTitle("LibreBlock")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        HelpView()
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                }
            }
        }
    }

    private var enabledGroupCount: Int {
        BlockerGroup.allCases.filter { model.settings.groups[$0]?.enabled != false }.count
    }

    private func listName(_ id: String) -> String {
        model.lists.first(where: { $0.id == id })?.name ?? id
    }
}

// MARK: - Help

struct HelpView: View {
    var body: some View {
        List {
            Section("Enable in Safari") {
                numberedSteps([
                    "Open the Settings app.",
                    "Tap Safari → Extensions.",
                    "Enable all six LibreBlock extensions (1. Ads … 6. Custom).",
                    "For each, tap Permissions and choose Allow on every website you want protected.",
                ])
            }
            Section("Custom rules") {
                Text("A custom rule has a pattern (like */ads/*), optional domains (like news.example) and an action. Block rules hide or stop matching requests; allow rules make exceptions that override blocking.")
            }
            Section("iCloud sync") {
                Text("Settings and list selections sync through iCloud key-value storage across your devices when enabled. Filter list content itself is downloaded per device.")
            }
            Section("Privacy") {
                Text("LibreBlock never sends your browsing anywhere. Filter downloads go directly to the list maintainers' servers; no analytics, no accounts, no tracking.")
            }
        }
        .navigationTitle("Help")
    }
}

/// Lays out numbered guide steps; plain List rows, no list numbering.
private func numberedSteps(_ steps: [String]) -> some View {
    ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(index + 1).")
                .foregroundStyle(.secondary)
                .monospaced()
            Text(text)
        }
    }
}
