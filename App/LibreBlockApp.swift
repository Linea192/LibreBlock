import SwiftUI

@main
struct LibreBlockApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var lock = AppLockController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .environmentObject(lock)
                .tint(.accent)
                .onAppear {
                    lock.updatePolicy(enabled: model.settings.useAppLock)
                }
                .onChange(of: scenePhase) { phase in
                    if phase == .background {
                        lock.relock()
                    }
                }
                .onChange(of: model.settings.useAppLock) { enabled in
                    lock.updatePolicy(enabled: enabled)
                }
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Register for iCloud key-value sync early.
        NSUbiquitousKeyValueStore.default.synchronize()
        return true
    }
}
