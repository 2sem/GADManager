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

Add your ad unit IDs to `Info.plist` under the key `GADUnitIdentifiers` as a `[String: String]` dictionary:

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

Define an enum for your ad units:

```swift
enum AdUnit: String {
    case interstitial
    case opening
    case rewarded
}
```

## Usage

### Initialization

```swift
let adManager = GADManager<AdUnit>(window)
adManager.delegate = self
```

### Interstitial

```swift
// Prepare (load)
adManager.prepare(interstitialUnit: .interstitial, interval: 60 * 60)

// Show
adManager.show(unit: .interstitial) { unit, _, shown in
    // shown: true if ad was displayed and dismissed
}
```

### App Open

```swift
adManager.prepare(openingUnit: .opening)

adManager.show(unit: .opening, needToWait: true) { unit, _, shown in }
```

### Rewarded

```swift
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

```swift
if #available(iOS 14, *) {
    adManager.requestPermission { status in
        // load ads after permission resolved
    }
}
```

## Delegate

```swift
extension MyClass: GADManagerDelegate {
    // Required: persist last shown time per unit
    func GAD<E>(manager: GADManager<E>, lastShownTimeForUnit unit: E) -> Date {
        return UserDefaults.standard.object(forKey: unit.rawValue) as? Date ?? .distantPast
    }

    func GAD<E>(manager: GADManager<E>, updatShownTimeForUnit unit: E, showTime time: Date) {
        UserDefaults.standard.set(time, forKey: unit.rawValue)
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
