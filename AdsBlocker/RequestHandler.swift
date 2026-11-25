import Foundation
import SafariServices
import UniformTypeIdentifiers

/// Safari content blocker extension: 1. Ads.
/// Loads compiled rules written by the LibreBlock app into the shared App
/// Group container; falls back to the bundled defaults when no container
/// exists (free developer accounts) or nothing has been written yet.
final class RequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let profileID = request?.userInfo?[SFExtensionProfileKey] as? UUID

        let attachment = NSItemProvider(
            item: Self.ruleData(profileID: profileID) as NSSecureCoding,
            typeIdentifier: UTType.json.identifier)

        let item = NSExtensionItem()
        item.attachments = [attachment]
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }

    private static func ruleData(profileID: UUID?) -> Data {
        // 1. Rules the app compiled into the shared container (if any).
        if SharedStore.isAppGroupAvailable,
           let data = try? Data(contentsOf: SharedStore.rulesURL(for: .ads)),
           !data.isEmpty {
            return data
        }
        // 2. Build-time defaults: always present, correct on first launch.
        return DefaultRules.json(for: .ads)
    }
}

import SafariServices
