import SwiftUI

/// Per-group settings: master switch, filter lists, site overrides.
struct GroupsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(BlockerGroup.allCases) { group in
                    NavigationLink {
                        GroupDetailView(group: group)
                    } label: {
                        row(for: group)
                    }
                }
            }
            .navigationTitle("Blocking")
        }
    }

    private func row(for group: BlockerGroup) -> some View {
        HStack(spacing: 14) {
            Image(systemName: group.systemImage)
                .font(.title3)
                .frame(width: 30)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.title).font(.headline)
                Text(group.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if model.settings.groups[group]?.enabled != false {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GroupDetailView: View {
    @EnvironmentObject private var model: AppModel
    let group: BlockerGroup

    @State private var newSite = ""

    var body: some View {
        List {
            Section {
                Toggle("Enable \(group.title.lowercased()) blocking", isOn: binding)
                    .font(.headline)
            } footer: {
                Text("Turning this off writes an empty rule set: the Safari extension stays installed but stops blocking.")
            }

            Section("Filter lists") {
                ForEach(model.lists.filter { $0.group == group }) { list in
                    Button {
                        model.toggleList(list.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(list.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                if let url = list.url {
                                    Text(url.host ?? "")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: list.chosen ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(list.chosen ? .tint : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                TextField("example.com", text: $newSite)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addSite)
                Button("Add site override", action: addSite)
            } header: {
                Text("Site overrides")
            } footer: {
                Text("Turn a site off to allow-list it (blockers won't run there) or on to force blocking only there. Site domains may be plain like example.com.")
            }

            let overrides = model.settings.groups[group]?.siteOverrides ?? [:]
            if !overrides.isEmpty {
                Section("Current overrides") {
                    let sortedKeys = overrides.keys.sorted()
                    ForEach(sortedKeys, id: \.self) { domain in
                        Toggle(domain, isOn: siteBinding(domain))
                    }
                    .onDelete { offsets in
                        for idx in offsets where sortedKeys.indices.contains(idx) {
                            model.settings.groups[group]?.siteOverrides[sortedKeys[idx]] = nil
                        }
                    }
                }
            }

            Section {
                LabeledContent("Rules installed", value: "\(model.ruleCount(for: group))")
            }
        }
        .navigationTitle(group.title)
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { model.settings.groups[group]?.enabled ?? true },
            set: { model.setGroup(group, enabled: $0) })
    }

    private func siteBinding(_ domain: String) -> Binding<Bool> {
        Binding(
            get: { model.settings.groups[group]?.siteOverrides[domain] ?? false },
            set: { model.setSite(domain, group: group, enabled: $0) })
    }

    private func addSite() {
        let domain = newSite.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !domain.isEmpty, domain.contains(".") else { return }
        model.setSite(domain, group: group, enabled: true)
        newSite = ""
    }
}
