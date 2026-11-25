import Foundation
import SafariServices

/// Native handler for the Safari web extension target.
///
/// The web extension's JS runs inside Safari; this principal class only has
/// to exist so the extension bundle contains a valid host executable
/// (`_Extension` process). It implements the standard
/// `NSExtensionRequestHandling` entry point and completes immediately;
/// message passing between the extension and the app is not needed because
/// the popup drives everything through the app's URL scheme.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        // No native messages are used on iOS; complete with an empty item.
        let item = NSExtensionItem()
        context.completeRequest(returningItems: [item], completionHandler: nil)
    }
}
