# LibreBlock

A free, open-source Safari ad blocker for iOS with **every feature unlocked** —
no subscriptions, no paywalls, no locked lists. Built from scratch on Safari's
public content blocker APIs.

LibreBlock is an independent, clean-room project. It is not affiliated with
or derived from any other ad blocker.

## Features

| Feature | Where |
| --- | --- |
| 6 Safari content blocker extensions (Ads, Privacy, Social, Safety, Others, Custom) | one toggle each in Settings → Safari → Extensions |
| 28 filter lists (built-in + community downloads, 20+ languages) | Blocking tab |
| Custom allow/block rules with per-site domains | Custom tab |
| Per-group master switches + per-site overrides | Blocking tab |
| iCloud sync of settings (paid accounts) | Settings |
| App Lock (Face ID / Touch ID) | Settings |
| Siri shortcuts: enable / disable / update filters | Shortcuts app |
| Onboarding guide with Safari setup steps | first launch |
| Web extension popup with per-page block counter | Safari toolbar |

All features are free. There is no premium tier, no IAP, no tracking.

## Requirements

- a Mac with **Xcode 15+** and **xcodegen**
- an Apple ID (a free account works; see "Free vs paid accounts" below)
- iOS 16 or later on the device

## Build & run

```bash
# 1. Install xcodegen (once)
brew install xcodegen

# 2. Generate the Xcode project
cd LibreBlock
xcodegen generate

# 3. Open it
open LibreBlock.xcodeproj
```

Then in Xcode:

1. Select the **LibreBlock** scheme and your device.
2. Set a Team under *Signing & Capabilities* for the app and every extension
   target (Signing Certificate: Apple Development). With a free account,
   change each bundle ID to something unique, e.g.
   `org.<yourname>.libreblock.app`, `...app.Ads`, `...app.Privacy`,
   `...app.Social`, `...app.Safety`, `...app.Others`, `...app.Custom`,
   `...app.WebExt`, and set the App Group in the entitlements files to a
   unique `group.<yourname>.libreblock` (see below).
3. Build & run (⌘R). First launch writes the compiled rule sets.
4. On the device: Settings → Safari → Extensions → enable all seven
   LibreBlock entries and allow them on the sites you visit.

Free accounts must sideload (7-day signing) — rebuild from Xcode to refresh.
Paid accounts can distribute via TestFlight or Ad Hoc.

### Free vs paid accounts

| Capability | Free account | Paid account |
| --- | --- | --- |
| Run all 7 extensions on device | ✅ | ✅ |
| Blocking works on first launch | ✅ via bundled default rules | ✅ |
| Live rule updates from the app | ⚠️ limited* | ✅ |
| iCloud settings sync | ❌ | ✅ |
| Signing duration | 7 days | 1 year |

\* App Groups need provisioning. Without one, each extension uses its
bundled default rules and the app compiles into its own container; toggles
then take effect after rebuilding/reinstalling. With App Groups (paid
account, or enabled manually), updates apply immediately.

If you change the App Group ID, update `SharedStore.appGroupID` in
`Shared/SharedStore.swift` and all `*.entitlements` files.

### Regenerating build-time defaults

After editing `Resources/filters/*.txt`, regenerate the compiled defaults:

```bash
python3 scripts/gen_default_rules.py   # from the repository root
```

(The generator is included in the `scripts/` directory of the deliverable.)

## Architecture

```
LibreBlock (iOS app, SwiftUI)
├── App/            app UI, model, Siri intents, app lock, onboarding
├── Shared/         rule compiler, filter engine, catalog, settings model
├── AdsBlocker … CustomBlocker   6 Safari content blocker extensions
├── WebExtension/   Safari web extension (block counter popup)
├── Resources/      asset catalog + bundled filter lists
├── SharedTests/    RuleCompiler unit tests
└── Support/        Info.plist properties, entitlements, privacy manifest
```

Blocking flow: the app compiles ABP-style rules into WebKit content
blocker JSON (`Shared/RuleCompiler.swift`), writes one file per group
(`Shared/FilterEngine.swift`), and each extension's `RequestHandler`
serves that file to Safari. Community lists are downloaded on demand and
cached; failures keep the previous copy.

## Tests

The `LibreBlockTests` target covers the compiler: domain anchors,
exceptions, resource types, `domain=` include/exclude, cosmetic rules,
skipped constructs (regex, snippets, `$csp`-style unknown options), the
rule cap and JSON validity. Run with ⌘U in Xcode.

## License & attribution

Code: MIT (see `LICENSE`). Filter list licenses: see `ATTRIBUTION.md`.
Community lists are downloaded at runtime from their maintainers; nothing
proprietary is bundled.
