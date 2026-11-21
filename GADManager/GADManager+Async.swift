//
//  GADManager+Async.swift
//  GADManager
//
//  async/await counterparts of the completion based APIs of GADManager.
//

import UIKit
import GoogleMobileAds

/// Errors thrown by the async APIs of `GADManager`.
public enum GADManagerError: Error {
    /// No ad unit identifier is registered for the requested unit (see `GADUnitIdentifiers` in Info.plist).
    case missingUnitIdentifier
    /// The loader finished without delivering an ad or an error.
    case noAdReceived
}

/// Resumes a checked continuation at most once.
final class OneShot<T> {
    private var continuation: CheckedContinuation<T, Never>?
    private let lock = NSLock()
    
    init(_ continuation: CheckedContinuation<T, Never>) {
        self.continuation = continuation
    }
    
    func resume(_ value: T) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}

extension GADManager {
    
    /// Result of `showAsync(unit:...)`.
    public struct ShowResult {
        /// The unit that was requested.
        public let unit: E
        /// The ad object involved, if any.
        public let ad: NSObject?
        /// `true` when the ad was shown and dismissed; `false` when it was skipped, failed, or superseded.
        public let isCompleted: Bool
    }
    
    /// Result of `showAsync(rewardUnit:...)`.
    public struct RewardResult {
        /// The unit that was requested.
        public let unit: E
        /// The rewarded ad involved, if any.
        public let ad: GoogleMobileAds.RewardedAd?
        /// `true` when the user earned the reward.
        public let isRewarded: Bool
    }
    
    // MARK: Show
    
    /// Async version of `show(unit:force:needToWait:isTesting:viewController:completion:)`.
    /// Suspends until the ad is dismissed, skipped, or fails.
    @MainActor @discardableResult
    public func showAsync(unit: E, force: Bool = false, needToWait wait: Bool = false, isTesting: Bool = false, viewController: UIViewController? = nil) async -> ShowResult {
        await withCheckedContinuation { continuation in
            let box = OneShot(continuation)
            self.show(unit: unit, force: force, needToWait: wait, isTesting: isTesting, viewController: viewController) { unit, ad, isCompleted in
                box.resume(ShowResult(unit: unit, ad: ad, isCompleted: isCompleted))
            }
        }
    }
    
    /// Async version of `show(rewardUnit:force:needToWait:isTesting:viewController:completion:)`.
    /// Suspends until the ad is dismissed, skipped, or fails.
    @MainActor @discardableResult
    public func showAsync(rewardUnit unit: E, force: Bool = false, needToWait wait: Bool = true, isTesting: Bool = false, viewController: UIViewController? = nil) async -> RewardResult {
        await withCheckedContinuation { continuation in
            let box = OneShot(continuation)
            self.show(rewardUnit: unit, force: force, needToWait: wait, isTesting: isTesting, viewController: viewController) { unit, ad, isRewarded in
                box.resume(RewardResult(unit: unit, ad: ad, isRewarded: isRewarded))
            }
        }
    }
    
    // MARK: Prepare
    
    /// Registers a waiter, runs `start`, and suspends until the load callbacks resolve the waiter.
    @MainActor
    private func awaitLoad(_ unit: E, start: (() -> Void)? = nil) async -> Bool {
        await withCheckedContinuation { continuation in
            let box = OneShot(continuation)
            self.loadWaiters[unit, default: []].append { box.resume($0) }
            start?()
            
            //the sync prepare did not start a load, so no callback will come
            if !(self.isLoading[unit] ?? false) {
                self.resolveLoadWaiters(unit, success: self.isPrepared(unit))
            }
        }
    }
    
    /// Async version of `prepare(interstitialUnit:isTesting:interval:hideTestLabel:)`.
    /// - Returns: `true` when the ad is loaded and ready, `false` on load error or missing unit identifier.
    @MainActor @discardableResult
    public func prepareAsync(interstitialUnit unit: E, isTesting: Bool = false, interval: TimeInterval = GADManager.defaultInterval, hideTestLabel: Bool? = nil) async -> Bool {
        if self.isPrepared(unit) {
            self.prepare(interstitialUnit: unit, isTesting: isTesting, interval: interval, hideTestLabel: hideTestLabel)
            return true
        }
        if self.isLoading[unit] ?? false {
            return await self.awaitLoad(unit)
        }
        guard self.adId(forUnit: unit, andForAdType: .full, isTesting: isTesting) != nil else {
            return false
        }
        return await self.awaitLoad(unit) {
            self.prepare(interstitialUnit: unit, isTesting: isTesting, interval: interval, hideTestLabel: hideTestLabel)
        }
    }
    
    /// Async version of `prepare(openingUnit:isTesting:orientation:interval:hideTestLabel:)`.
    /// - Returns: `true` when the ad is loaded and still valid, `false` on load error or missing unit identifier.
    @MainActor @discardableResult
    public func prepareAsync(openingUnit unit: E, isTesting: Bool = false, orientation: UIInterfaceOrientation = .unknown, interval: TimeInterval = GADManager.defaultInterval, hideTestLabel: Bool? = nil) async -> Bool {
        if self.isPrepared(unit) {
            self.prepare(openingUnit: unit, isTesting: isTesting, orientation: orientation, interval: interval, hideTestLabel: hideTestLabel)
            return true
        }
        if self.isLoading[unit] ?? false {
            return await self.awaitLoad(unit)
        }
        guard self.adId(forUnit: unit, andForAdType: .opening, isTesting: isTesting) != nil else {
            return false
        }
        return await self.awaitLoad(unit) {
            //an expired ad is never reloaded by the sync prepare, so drop it first
            self.adObjects[unit] = nil
            self.prepare(openingUnit: unit, isTesting: isTesting, orientation: orientation, interval: interval, hideTestLabel: hideTestLabel)
        }
    }
    
    /// Async version of `prepare(rewardUnit:isTesting:hideTestLabel:)`.
    /// - Returns: `true` when the ad is loaded, `false` on load error or missing unit identifier.
    @MainActor @discardableResult
    public func prepareAsync(rewardUnit unit: E, isTesting: Bool = false, hideTestLabel: Bool? = nil) async -> Bool {
        if self.isPrepared(unit) {
            self.prepare(rewardUnit: unit, isTesting: isTesting, hideTestLabel: hideTestLabel)
            return true
        }
        if self.isLoading[unit] ?? false {
            return await self.awaitLoad(unit)
        }
        guard self.adId(forUnit: unit, andForAdType: .reward, isTesting: isTesting) != nil else {
            return false
        }
        return await self.awaitLoad(unit) {
            self.prepare(rewardUnit: unit, isTesting: isTesting, hideTestLabel: hideTestLabel)
        }
    }
    
    // MARK: Native
    
    /// Loads a native ad and returns it.
    /// - Throws: `GADManagerError.missingUnitIdentifier` when no unit id exists, or the error reported by the loader.
    @MainActor
    public func loadNativeAd(forAd unit: E, withOptions options: [NativeAdViewAdOptions] = [], isTesting: Bool = false, rootViewController: UIViewController? = nil) async throws -> GoogleMobileAds.NativeAd {
        guard let unitId = self.adId(forUnit: unit, andForAdType: .native, isTesting: isTesting) else {
            throw GADManagerError.missingUnitIdentifier
        }
        
        let loader = AdLoader(adUnitID: unitId, rootViewController: rootViewController, adTypes: [.native], options: options)
        return try await NativeAdLoadHelper().load(with: loader)
    }
}

/// Retains an `AdLoader` (whose delegate is weak) until it reports a result.
@MainActor
private final class NativeAdLoadHelper: NSObject, NativeAdLoaderDelegate {
    private var continuation: CheckedContinuation<GoogleMobileAds.NativeAd, Error>?
    private var loader: AdLoader?
    private var selfRetain: NativeAdLoadHelper?
    
    func load(with loader: AdLoader) async throws -> GoogleMobileAds.NativeAd {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.loader = loader
            self.selfRetain = self
            loader.delegate = self
            loader.load(GoogleMobileAds.Request())
        }
    }
    
    private func finish(_ result: Result<GoogleMobileAds.NativeAd, Error>) {
        let pending = continuation
        continuation = nil
        loader?.delegate = nil
        loader = nil
        selfRetain = nil
        pending?.resume(with: result)
    }
    
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: GoogleMobileAds.NativeAd) {
        finish(.success(nativeAd))
    }
    
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        finish(.failure(error))
    }
    
    func adLoaderDidFinishLoading(_ adLoader: AdLoader) {
        //delivered after didReceive on success; resolves the (unexpected) no-ad case
        finish(.failure(GADManagerError.noAdReceived))
    }
}
