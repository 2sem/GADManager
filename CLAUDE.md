# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
swift build
```

## Release Process

1. Bump version in `Package.swift` (if applicable) and update version references
2. Commit: `bump: release a.b.c`
3. Tag: `git tag a.b.c && git push origin a.b.c`

## Architecture

GADManager is a generic Swift library (`GADManager<E>`) that wraps Google Mobile Ads SDK with time-based throttling and lifecycle management.

**Core design:**
- `E` is a user-defined `RawRepresentable` enum where `RawValue == String` — each case maps to an ad unit name
- Ad unit IDs are read from `Info.plist` key `GADUnitIdentifiers` (a `[String: String]` dictionary keyed by enum raw values)
- The manager tracks per-unit state via dictionaries: `adObjects`, `intervals`, `isLoading`, `isTesting`, `completions`, etc.

**Ad lifecycle:**
1. `prepare(...)` — loads the ad and caches it in `adObjects[unit]`
2. `show(unit:force:needToWait:...)` — checks `canShow()` (time interval) and `isPrepared()` (ad validity/expiry), then calls `__show()`
3. After dismissal (`adDidDismissFullScreenContent`), `reprepare()` is called automatically to reload

**Supported ad types:** Interstitial, AppOpen (opening), Banner, Rewarded, Native

**Key timing constants:**
- `defaultInterval`: 1 hour between interstitial/reward shows
- `opeingExpireInterval`: 4 hours (5 min in DEBUG) — AppOpen ad validity window after loading
- `loadingExpirationInterval`: 1 minute

**Delegate (`GADManagerDelegate`):**
- Host app must persist and provide last-shown / last-prepared timestamps per unit
- Optional callbacks: `willPresentAD`, `didDismissAD`

**Extensions in `GADManager/extensions/`:**
- `GADRequest+`: `hideTestLabel()`, `enableCollapsible(direction:)`
- `UIViewController+`, `UIApplication+`, `UIAlertAction+`, `String+`: utilities for presenting alerts and opening settings/App Store

## Distribution

**SPM only** (CocoaPods removed — CocoaPods is deprecated):

```swift
.package(url: "https://github.com/2sem/GADManager.git", from: "1.5.0")
```

Depends on `swift-package-manager-google-mobile-ads` ≥ 12.6.0.

## CI

- **Gemini code review** (`gemini-dispatch.yml`): triggers on PR open or `@gemini` comment from OWNER/MEMBER/COLLABORATOR
- **Claude** (`claude.yml`): separate workflow for Claude-based automation
