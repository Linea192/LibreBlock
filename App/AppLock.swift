import SwiftUI
import LocalAuthentication

/// Gatekeeper for the App Lock feature: when enabled, returning from
/// background requires Face ID / Touch ID (or the device passcode).
@MainActor
final class AppLockController: ObservableObject {
    @Published var isLocked = false
    private var policyEnabled = false

    func updatePolicy(enabled: Bool) {
        policyEnabled = enabled
        isLocked = enabled && isLocked
        if enabled { isLocked = false } // start unlocked; lock on background
    }

    func relock() {
        guard policyEnabled else { return }
        isLocked = true
    }

    func unlock() async {
        guard policyEnabled else { isLocked = false; return }
        let ctx = LAContext()
        var error: NSError?
        let reason = "Unlock LibreBlock"

        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            do {
                let ok = try await ctx.evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason)
                if ok { isLocked = false }
            } catch {
                // Stay locked; user can retry with the passcode.
            }
        } else {
            // No biometry/passcode configured: do not lock the app out.
            isLocked = false
        }
    }
}

/// Full-screen lock cover.
struct LockScreen: View {
    @EnvironmentObject private var lock: AppLockController

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.shield")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("LibreBlock is locked")
                .font(.title2.bold())
            Text("Authenticate to change your blocking settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await lock.unlock() }
            } label: {
                Label("Unlock", systemImage: "faceid")
                    .font(.headline)
                    .padding(.horizontal, 8)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
