import SwiftUI

/// Editor for user-authored allow/block rules (the "6. Custom" group).
struct CustomRulesView: View {
    @EnvironmentObject private var model: AppModel

    @State private var action: CustomRule.Action = .block
    @State private var domains = ""
    @State private var pattern = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Action", selection: $action) {
                        Text("Block").tag(CustomRule.Action.block)
                        Text("Allow").tag(CustomRule.Action.allow)
                    }
                    .pickerStyle(.segmented)

                    TextField("Pattern — e.g. */ads/* or doubleclick", text: $pattern)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Domains (optional) — e.g. news.example, shop.test", text: $domains)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button(action: addRule) {
                        Label("Add rule", systemImage: "plus.circle.fill")
                    }
                    .disabled(pattern.trimmingCharacters(in: .whitespaces).isEmpty)
                } header: {
                    Text("New rule")
                } footer: {
                    Text("Patterns use * as a wildcard. Domains limit the rule to those sites; leave empty to apply everywhere. Allow rules override block rules.")
                }

                let rules = model.settings.customRules
                if rules.isEmpty {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No custom rules")
                                .font(.headline)
                            Text("Add a rule to fine-tune blocking on specific sites.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                } else {
                    Section("Your rules (\(rules.count))") {
                        ForEach(rules) { rule in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: rule.action == .block
                                          ? "hand.raised.fill" : "hand.thumbsup.fill")
                                        .foregroundStyle(rule.action == .block ? .red : .green)
                                    Text(rule.pattern)
                                        .font(.body.monospaced())
                                }
                                if !rule.domains.isEmpty {
                                    Text("on \(rule.domains)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteRules)
                    }
                }

                Section {
                    LabeledContent("Rules installed", value: "\(model.ruleCount(for: .custom))")
                    Text("Custom rules compile into the 6. Custom Safari extension.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Custom")
        }
    }

    private func addRule() {
        let cleanedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedPattern.isEmpty else { return }
        let cleanedDomains = domains.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        model.settings.customRules.append(
            CustomRule(action: action, domains: cleanedDomains, pattern: cleanedPattern))
        pattern = ""
        domains = ""
    }

    private func deleteRules(_ offsets: IndexSet) {
        model.settings.customRules.remove(atOffsets: offsets)
    }
}
