# GADManager

A Swift library for managing Google Mobile Ads with time-based throttling and lifecycle management.

## Requirements

- iOS 12.0+
- Swift 5.10+

## Installation

### Swift Package Manager

```swift
.package(url: "https://github.com/2sem/GADManager.git", from: "1.4.0")
```

## Setup

### 1. Info.plist

Add your ad unit IDs under the key `GADUnitIdentifiers` as a `[String: String]` dictionary. The keys must exactly match your enum's `rawValue`s.

```xml
<key>GADUnitIdentifiers</key>
<dict>
    <key>interstitial</key>
    <string>ca-app-pub-xxxx/xxxx</string>
    <key>opening</key>
    <string>ca-app-pub-xxxx/xxxx</string>
    <key>rewarded</key>
    <string>ca-app-pub-xxxx/xxxx</string>
</dict>
```

### 2. Define your ad units

```swift
enum AdUnit: String {
    case interstitial
    case opening
    case rewarded
}
```

### 3. Initialize

Create the manager and assign a delegate. Call this early — typically in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` or your app's root scene setup.

```swift
// UIKit
let adManager = GADManager<AdUnit>(window)
adManager.delegate = self

// SwiftUI
let adManager = GADManager<AdUnit>(UIApplication.shared.connectedScenes
    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
    .first!)
adManager.delegate = self
```

## Usage

Call `prepare` early to preload the ad. Call `show` when you want to display it.

### Interstitial

```swift
// In AppDelegate or scene setup
adManager.prepare(interstitialUnit: .interstitial, interval: 60 * 60)

// When ready to show (e.g. after a level completes)
adManager.show(unit: .interstitial) { unit, _, shown in
    // shown: true if the ad was displayed and dismissed
}
```

### App Open

`needToWait: true` holds the completion until the ad finishes loading and showing, instead of returning immediately when the ad isn't ready yet.

```swift
adManager.prepare(openingUnit: .opening)

// Call on every app foreground
adManager.show(unit: .opening, needToWait: true) { unit, _, shown in }
```

### Rewarded

```swift
import GoogleMobileAds

adManager.prepare(rewardUnit: .rewarded)

adManager.show(unit: .rewarded) { unit, obj, rewarded in
    if rewarded, let reward = obj as? GoogleMobileAds.AdReward {
        print("Earned \(reward.amount) \(reward.type)")
    }
}
```

### Banner

```swift
if let bannerView = adManager.prepare(bannerUnit: .banner) {
    bannerView.rootViewController = self
    view.addSubview(bannerView)
    bannerView.load(GoogleMobileAds.Request())
}
```

### ATT Permission

Request tracking permission before loading ads to maximise ad revenue.

```swift
if #available(iOS 14, *) {
    adManager.requestPermission { status in
        adManager.prepare(interstitialUnit: .interstitial)
    }
}
```

## Delegate

The delegate is responsible for persisting the last-shown time per unit so throttling works correctly across app launches.

```swift
extension MyClass: GADManagerDelegate {
    // Required: return the last time this unit was shown
    func GAD<E>(manager: GADManager<E>, lastShownTimeForUnit unit: E) -> Date {
        return UserDefaults.standard.object(forKey: (unit as! AdUnit).rawValue) as? Date ?? .distantPast
    }

    // Required: persist the shown time
    func GAD<E>(manager: GADManager<E>, updatShownTimeForUnit unit: E, showTime time: Date) {
        UserDefaults.standard.set(time, forKey: (unit as! AdUnit).rawValue)
    }

    // Optional
    func GAD<E>(manager: GADManager<E>, didEarnRewardForUnit unit: E, reward: GoogleMobileAds.AdReward) {
        print("Reward earned: \(reward.amount) \(reward.type)")
    }

    func GAD<E>(manager: GADManager<E>, willPresentADForUnit unit: E) {}
    func GAD<E>(manager: GADManager<E>, didDismissADForUnit unit: E) {}
}
```

## Timing

| Constant | Default | Description |
|---|---|---|
| `defaultInterval` | 1 hour | Minimum time between interstitial/opening shows |
| `opeingExpireInterval` | 4 hours (5 min DEBUG) | App Open ad validity after loading |

## License

MIT
