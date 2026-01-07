//
//  GADManager.swift
//  GADManager
//
//  Created by 영준 이 on 2019. 5. 11..
//  Copyright © 2019년 Y2KLab. All rights reserved.
//

import UIKit
import GoogleMobileAds
import AdSupport
import AppTrackingTransparency

/// Private extension to safely access the root view controller in iOS 13+ scene-based apps
private extension UIApplication {
    /// Returns the root view controller of the key window in the active scene.
    /// For multi-scene apps, prioritizes the foreground active scene with fallback logic.
    /// - Returns: The root view controller, or nil if no valid scene/window is found.
    var keyRootViewController: UIViewController? {
        // First, try to get the foreground active scene (ideal for multi-scene apps)
        if let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            return windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        }

        // Fallback: try any connected scene if no foreground active scene is available
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return nil
        }

        return windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }
}

public protocol GADManagerDelegate : NSObjectProtocol{
    //associatedtype E : RawRepresentable where E.RawValue == String
    func GAD<E>(manager: GADManager<E>, lastPreparedTimeForUnit unit: E) -> Date;
    func GAD<E>(manager: GADManager<E>, updateLastPreparedTimeForUnit unit: E, preparedTime time: Date);
    func GAD<E>(manager: GADManager<E>, lastShownTimeForUnit unit: E) -> Date;
    func GAD<E>(manager: GADManager<E>, updatShownTimeForUnit unit: E, showTime time: Date);
    func GAD<E>(manager: GADManager<E>, willPresentADForUnit unit: E);
    func GAD<E>(manager: GADManager<E>, didDismissADForUnit unit: E);
}

public extension GADManagerDelegate{
    func GAD<E>(manager: GADManager<E>, lastPreparedTimeForUnit unit: E) -> Date{
        return Date();
    }
    func GAD<E>(manager: GADManager<E>, updateLastPreparedTimeForUnit unit: E, preparedTime time: Date){}
    func GAD<E>(manager: GADManager<E>, willPresentADForUnit unit: E){}
    func GAD<E>(manager: GADManager<E>, didDismissADForUnit unit: E){}
}

public class GADManager<E : RawRepresentable> : NSObject, GoogleMobileAds.FullScreenContentDelegate where E.RawValue == String, E: Hashable{
    var window : UIWindow;
    
    public static var defaultInterval : TimeInterval { return 60.0 * 60.0 * 1.0 }
    #if DEBUG
    public static var opeingExpireInterval : TimeInterval { return 60.0 * 5.0 }
    #else
    public static var opeingExpireInterval : TimeInterval { return 60.0 * 60.0 * 4.0 }
    #endif
    public static var loadingExpirationInterval : TimeInterval { return 60.0 * 1.0 }
    
    lazy var identifiers = Bundle.main.infoDictionary?["GADUnitIdentifiers"] as? [String : String];
    var adObjects : [E : NSObject] = [:];
    var intervals : [E : TimeInterval] = [:];
    var isLoading : [E : Bool] = [:];
    var isTesting : [E : Bool] = [:];
    var isRewardUnit : [E : Bool] = [:];
    var lastBeginLoading : [E : Date] = [:];
    var hideTestLabels : [E: Bool] = [:];
    var completions : [E : (E, NSObject?, Bool) -> Void] = [:];
    public var canShowFirstTime = true;
    public weak var delegate : GADManagerDelegate?;
    
    public enum AdType {
        case opening
        case adaptive
        case banner
        case full
        case reward
        case rewardFull
        case native
        case nativeVideo
    }
    
    var testUnitIds : [AdType : String] = [
        .opening : "ca-app-pub-3940256099942544/5575463023",
        .adaptive: "ca-app-pub-3940256099942544/2435281174",
        .banner: "ca-app-pub-3940256099942544/2934735716",
        .full: "ca-app-pub-3940256099942544/4411468910",
        .reward: "ca-app-pub-3940256099942544/1712485313",
        .rewardFull: "ca-app-pub-3940256099942544/6978759866",
        .native: "ca-app-pub-3940256099942544/3986624511",
        .nativeVideo: "ca-app-pub-3940256099942544/2521693316"
        
    ]
    
    /*fileprivate static var _shared : GADManager<E>?;
     static var shared : GADManager<E>?{
     get{
     return _shared;
     }
     }*/
    
    public init(_ window : UIWindow) {
        self.window = window;
        
        super.init();
        /*if GADManager._shared == nil{
         GADManager._shared = self;
         }*/
    }
    
    func name(forAdObject adObject: NSObject) -> String?{
        return self.adObjects.first(where: { $0.value === adObject })?.key.rawValue;
    }
    
    func unit(forAdObject adObject: NSObject) -> E?{
        guard let name = self.name(forAdObject: adObject), let unit = E.init(rawValue: name) else{
            return nil;
        }
        
        return unit;
    }
    
    func adId(forUnit unit: E, andForAdType adType: AdType, isTesting: Bool) -> String? {
        isTesting ? testUnitIds[adType] : identifiers?[unit.rawValue]
    }
    
    #if true
    @available(iOS 14, *)
    public func requestPermission(viewControllerForAlert viewController: UIViewController? = nil, title: String? = nil, msg: String? = nil, cancel: String? = nil, settings: String? = nil, completion: ((ATTrackingManager.AuthorizationStatus) -> Void)? = nil) {
        ATTrackingManager.requestTrackingAuthorization { status in
            switch status {
                case .authorized: // Tracking authorization dialog was shown // and we are authorized
                    print("[\(#function)] Authorized") // Now that we are authorized we can get the IDFA
                    //print(ASIdentifierManager.shared().advertisingIdentifier);
                    break;
                case .denied: // Tracking authorization dialog was
                    // shown and permission is denied
                    print("[\(#function)] Denied")
//                    DispatchQueue.main.async {
//                        viewController?.openSettingsOrCancel(title: title ?? "", msg: msg ?? "You have to agree accessing to IDFA for using this app continue", style: .alert, titleForOK: cancel ?? "Cancel", titleForSettings: settings ?? "Settings");
//                    }
                    break;
                case .notDetermined: // Tracking authorization dialog has not been shown
                    print("[\(#function)] Not Determined")
                    break;
                case .restricted:
                    print("[\(#function)] Restricted")
                    //show alert
                    //showAlert(title: String, msg: String, actions : [UIAlertAction], style: UIAlertControllerStyle, sourceView: UIView? = nil, sourceRect: CGRect? = nil, popoverDelegate: UIPopoverPresentationControllerDelegate? = nil, completion: (() -> Void)? = nil)
                    return;
                @unknown default:
                    print("[\(#function)] Unknown")
                    break;
            }
            
            completion?(status);
        }
    }
    #endif
    
    public func reset(unit: E){
        //RSDefaults.LastFullADShown = Date();
        //self.delegate?.GAD<E>(manager: GADManager<E>, updatShownTimeForUnit: unit, showTime: Date());
        self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
    }
    
    public func canShow(_ unit: E) -> Bool{
        var value = true;
        let now = Date();

        if self.isRewardUnit[unit] == true {
            return true;
        }

        guard let delegate = self.delegate else {
            return value;
        }
        
        let lastShowTime = delegate.GAD(manager: self, lastShownTimeForUnit: unit);
        let time_1970 = Date.init(timeIntervalSince1970: 0);
        
        //(!self.canShowFirstTime &&
        guard self.canShowFirstTime || lastShowTime > time_1970 else{
            if lastShowTime <= time_1970{
                delegate.GAD(manager: self, updatShownTimeForUnit: unit, showTime: now);
            }
            value = false;
            return value;
        }
        
        let spent = now.timeIntervalSince(lastShowTime);
        let interval = self.intervals[unit] ?? GADManager.defaultInterval;
        value = spent > interval;
        debugPrint("ad time spent \(spent.description) since \(lastShowTime.description). name[\(unit.rawValue)] now[\(now.description)] interval[\(interval.description)]");
        
        return value;
    }
    
    public func prepare(interstitialUnit unit: E, isTesting: Bool = false, interval: TimeInterval = GADManager.defaultInterval, hideTestLabel: Bool? = nil){
        self.isTesting[unit] = isTesting;
        self.intervals[unit] = interval;
        
        if let hideTestLabel = hideTestLabel{
            self.hideTestLabels[unit] = hideTestLabel;
        }
        
        func loadAd(unit: E){
            if let unitId = self.adId(forUnit: unit, andForAdType: .full, isTesting: isTesting){
                let req = GoogleMobileAds.Request();
                if hideTestLabel ?? false { req.hideTestLabel() }
                self.isLoading[unit] = true;
                
                GoogleMobileAds.InterstitialAd.load(with: unitId, request: req) { [weak self](newAd, error) in
                    self?.isLoading[unit] = false;
                    if let error = error{
    //                        guard let _ = GADErrorCode.init(rawValue: error.code) else {
    //                            return;
    //                        }
                        print("GAD Interstitial is error. unit[\(unit)] id[\(unitId)] error[\(error)]");
                        let completion = self?.completions[unit];
                        self?.completions[unit] = nil;
                        completion?(unit, newAd, false);
                        return;
                    }
                    
                    newAd?.fullScreenContentDelegate = self;
                    self?.adObjects[unit] = newAd;
                    debugPrint("GAD Interstitial is ready. unit[\(unit)] id[\(unitId)] ad[\(newAd?.debugDescription ?? "")]");
                }
            }else{
                assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            }
        }
        
        guard let ad = self.adObjects[unit] else{
            loadAd(unit: unit);
            return;
        }
        
        if let fullAd = ad as? GoogleMobileAds.InterstitialAd{
            do{
                try fullAd.canPresent(from: self.window.rootViewController!)
            }catch{
                loadAd(unit: unit);
            }
        }
    }
    
    public func prepare(bannerUnit unit: E, isTesting: Bool = false, size: GoogleMobileAds.AdSize = GoogleMobileAds.AdSizeBanner) -> GoogleMobileAds.BannerView?{
        var value : GoogleMobileAds.BannerView?;
        //self.intervals[unit] = interval;
        //guard let _ = self.adObjects[unit] else{
            if let unitId = self.adId(forUnit: unit, andForAdType: .banner, isTesting: isTesting) {
                value = GoogleMobileAds.BannerView.init(adSize: size);
                
                value?.adUnitID = unitId;
                
                print("GAD Banner is ready. unit[\(unit)] id[\(unitId)] newAd[\(value?.debugDescription ?? "")]");
            }else{
                assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            }
            //return;
        //}
        
        return value;
    }
    
    public func prepare(openingUnit unit: E, isTesting: Bool = false, orientation: UIInterfaceOrientation = .unknown, interval: TimeInterval = GADManager.defaultInterval, hideTestLabel: Bool? = nil){
        self.intervals[unit] = interval;
        self.isTesting[unit] = isTesting;
        self.hideTestLabels[unit] = hideTestLabel;
        guard let _ = self.adObjects[unit] else{
            if let unitId = self.adId(forUnit: unit, andForAdType: .opening, isTesting: isTesting) {
                let req = GoogleMobileAds.Request();
                if hideTestLabel ?? false { req.hideTestLabel() }
                
                self.isLoading[unit] = true;

                GoogleMobileAds.AppOpenAd.load(with: unitId, request: req) { [weak self](newAd, error) in
                    guard let self = self else{
                        return;
                    }
                    
                    newAd?.fullScreenContentDelegate = self;
                    self.adObjects[unit] = newAd;
                    if let error = error{
                        print("GAD Opening is error. unit[\(unit)] id[\(unitId)] error[\(error)]");
                        self.isLoading[unit] = false;
                        return;
                    }
                    
                    debugPrint("Opening is ready. unit[\(unit)]");
                    self.isLoading[unit] = false;
                    self.delegate?.GAD(manager: self, updateLastPreparedTimeForUnit: unit, preparedTime: Date());
                    guard let completion = self.completions[unit] else{
                        return;
                    }
                    
            //        self.completions[unit] = nil;
            //        completion?(unit, ad);
                    self.show(unit: unit, completion: completion);
                }
            }else{
                assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            }
            return;
        }
        
        //reprepare
    }

    public func prepare(rewardUnit unit: E, isTesting: Bool = false){
        self.isTesting[unit] = isTesting;
        self.isRewardUnit[unit] = true;
        guard let _ = self.adObjects[unit] else{
            if let unitId = self.adId(forUnit: unit, andForAdType: .reward, isTesting: isTesting) {
                let req = GoogleMobileAds.Request();

                self.isLoading[unit] = true;

                GoogleMobileAds.RewardedAd.load(with: unitId, request: req) { [weak self](newAd, error) in
                    guard let self = self else{
                        return;
                    }

                    newAd?.fullScreenContentDelegate = self;
                    self.adObjects[unit] = newAd;
                    if let error = error{
                        print("GAD Reward is error. unit[\(unit)] id[\(unitId)] error[\(error)]");
                        self.isLoading[unit] = false;
                        return;
                    }

                    debugPrint("Reward is ready. unit[\(unit)]");
                    self.isLoading[unit] = false;
                    guard let completion = self.completions[unit] else{
                        return;
                    }

                    self.show(unit: unit, completion: completion);
                }
            }else{
                assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            }
            return;
        }

        //reprepare
    }

    func reprepare(interstitialUnit unit: E, isTesting: Bool = false){
        self.adObjects[unit] = nil;
        
        if let interval = self.intervals[unit]{
            self.prepare(interstitialUnit: unit, isTesting: isTesting, interval: interval, hideTestLabel: self.hideTestLabels[unit]);
        }else{
            self.prepare(interstitialUnit: unit, isTesting: isTesting, hideTestLabel: self.hideTestLabels[unit]);
        }
    }
    
    func reprepare(openingUnit unit: E, isTesting: Bool = false){
        self.adObjects[unit] = nil;

        if let interval = self.intervals[unit]{
            self.prepare(openingUnit: unit, isTesting: isTesting, interval: interval, hideTestLabel: self.hideTestLabels[unit]);
        }else{
            self.prepare(openingUnit: unit, isTesting: isTesting, hideTestLabel: self.hideTestLabels[unit]);
        }
    }

    func reprepare(rewardUnit unit: E, isTesting: Bool = false){
        self.adObjects[unit] = nil;

        self.prepare(rewardUnit: unit, isTesting: isTesting);
    }

    func reprepare(adObject: NSObject, isTesting: Bool = false){
        guard let name = self.name(forAdObject: adObject), let unit = E.init(rawValue: name), let interval = self.intervals[unit] else{
            return;
        }
        
        let isTesting = self.isTesting[unit] ?? isTesting;

        if adObject is GoogleMobileAds.InterstitialAd{
            self.reprepare(interstitialUnit: unit, isTesting: isTesting);
        }else if adObject is GoogleMobileAds.AppOpenAd{
            self.reprepare(openingUnit: unit, isTesting: isTesting);
        }else if adObject is GoogleMobileAds.RewardedAd{
            self.reprepare(rewardUnit: unit, isTesting: isTesting);
        }
    }
    
    func isPrepared(_ unit: E) -> Bool{
        var value = false;
        
        if let interstitial = self.adObjects[unit] as? GoogleMobileAds.InterstitialAd{
            do{
                if let viewController = self.window.rootViewController{
    //                value = interstitial.isReady;
                    try interstitial.canPresent(from: viewController);
                    value = true;
                }
            }catch{}
        }else if let _ = self.adObjects[unit] as? GoogleMobileAds.AppOpenAd{ //opening
//            let time_1970 = Date.init(timeIntervalSince1970: 0);
            let now = Date();
            let lastPrepared = delegate?.GAD(manager: self, lastPreparedTimeForUnit: unit) ?? now;
            print("[\(#function)] opening ad was prepared[\(lastPrepared)] now[\(now)]");

            value = now.timeIntervalSince(lastPrepared) <= type(of: self).opeingExpireInterval;
            if !value{
                print("[\(#function)] opening ad is expired");
            }
        }else if self.adObjects[unit] is GoogleMobileAds.RewardedAd{
            value = true;
        }

        return value;
    }
    
    public func show(unit: E, force : Bool = false, needToWait wait: Bool = false, isTesting: Bool = false, viewController: UIViewController? = nil, completion: ((E, NSObject?, Bool) -> Void)? = nil){
        self.isTesting[unit] = isTesting;
        
        guard self.canShow(unit) || force else {
            self.completions[unit] = nil;
            completion?(unit, self.adObjects[unit], false);
            return;
        }
        
        guard self.isPrepared(unit) else{
            if wait{
                self.completions[unit] = completion;
            }
            
            let ad = self.adObjects[unit];
            
            if !(self.isLoading[unit] ?? false){
                print("[\(#function)] ad is not loading. unit[\(unit)] ad[\(ad?.debugDescription ?? "")]");

                if ad is GADInterstitialAd{
                    self.reprepare(interstitialUnit: unit, isTesting: isTesting);
                }else if ad is GADAppOpenAd{
                    self.reprepare(openingUnit: unit, isTesting: isTesting);
                }else if ad is GADRewardedAd{
                    self.reprepare(rewardUnit: unit, isTesting: isTesting);
                }
            }else{
                print("[\(#function)] ad is loading");
            }
            
            if !wait{
                completion?(unit, self.adObjects[unit], false);
            }
            return;
        }
        
        self.__show(unit: unit, viewController: viewController, completion: completion);
    }
    
    private func __show(unit: E, viewController: UIViewController? = nil, completion: ((E, NSObject?, Bool) -> Void)? = nil){
        guard self.window.rootViewController != nil else{
            completion?(unit, self.adObjects[unit], false);
            return;
        }
        
        /*guard self.canShow else {
         return;
         }*/
        
        //ignore if alert is being presented
        /*if let alert = UIApplication.shared.keyRootViewController?.presentedViewController as? UIAlertController{
         alert.dismiss(animated: false, completion: nil);
         }*/
        
        guard !(UIApplication.shared.keyRootViewController?.presentedViewController is UIAlertController) else{
            //alert.dismiss(animated: false, completion: nil);
            //self.fullAd = nil;
            completion?(unit, self.adObjects[unit], false);
            return;
        }
        
        if let ad = self.adObjects[unit] as? GoogleMobileAds.InterstitialAd{
            print("present interstital ad view[\(self.window.rootViewController?.description ?? "")]");
            self.completions[unit] = completion;
            ad.present(from: viewController ?? self.window.rootViewController!);
            self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
        }else if let ad = self.adObjects[unit] as? GoogleMobileAds.AppOpenAd{
            print("present opening ad view[\(self.window.rootViewController?.description ?? "")]");
            self.completions[unit] = completion;
            ad.present(from: viewController ?? self.window.rootViewController!);
            self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
        }else if let ad = self.adObjects[unit] as? GoogleMobileAds.RewardedAd{
            print("present reward ad view[\(self.window.rootViewController?.description ?? "")]");
            self.completions[unit] = completion;
            ad.present(from: viewController ?? self.window.rootViewController!) { [weak self] in
                guard let self = self else { return }
                let reward = ad.adReward
                print("user reward earned. type[\(reward.type)] amount[\(reward.amount)]");
            }
            self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
        }

        //RSDefaults.LastFullADShown = Date();
    }
    
    public func createNativeLoader(forAd unit: E, withOptions options: [NativeAdViewAdOptions] = [], isTesting: Bool = false) -> AdLoader? {
        guard let unitId = self.adId(forUnit: unit, andForAdType: .native, isTesting: isTesting) else {
            assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            return nil
        }
        
        print("GAD Native AdLoader is ready. unit[\(unit)] id[\(unitId)]");
        
        return AdLoader(adUnitID: unitId, rootViewController: nil, adTypes: [.native], options: options)
    }
    
//    public func interstitialDidReceiveAd(_ ad: GADInterstitial) {
//        print("Interstitial is ready. name[\(self.name(forAdObject: ad) ?? "")]");
//        guard let unit = self.unit(forAdObject: ad) else{
//            return;
//        }
//
//        self.isLoading[unit] = false;
//        guard let completion = self.completions[unit] else{
//            return;
//        }
//
////        self.completions[unit] = nil;
////        completion?(unit, ad);
//        self.show(unit: unit, completion: completion);
//    }
    
//    public func interstitialWillPresentScreen(_ ad: GADInterstitial) {
//        //self.fullAd = nil;
//        debugPrint("Interstitial has been presented. name[\(self.name(forAdObject: ad) ?? "")]");
//        //UIApplication.shared.setStatusBarHidden(true, with: .none);
//        guard let unit = self.unit(forAdObject: ad) else{
//            return;
//        }
//
//        self.delegate?.GAD(manager: self, willPresentADForUnit: unit);
//        self.window.rootViewController?.setNeedsStatusBarAppearanceUpdate();
//    }
    
    /*func interstitialDidFail(toPresentScreen ad: GADInterstitial) {
     print("Interstitial has been failed. name[\(self.name(forAdObject: ad) ?? "")]");
     }*/
    
//    public func interstitialDidDismissScreen(_ ad: GADInterstitial) {
//        print("Interstitial has been dismissed. name[\(self.name(forAdObject: ad) ?? "")]");
//        /*self.window.rootViewController?.showAlert(title: "후원해주셔서 감사합니다.", msg: "불편하신 사항은 리뷰에 남겨주시면 반영하겠습니다.", actions: [UIAlertAction.init(title: "확인", style: .default, handler: nil), UIAlertAction.init(title: "평가하기", style: .default, handler: { (act) in
//         UIApplication.shared.openReview();
//         })], style: .alert);*/
//        defer{
////            UIApplication.shared.setStatusBarHidden(self.window.rootViewController?.prefersStatusBarHidden ?? false, with: .none);
//            self.reprepare(adObject: ad); //reload
//        }
//
//        guard let unit = self.unit(forAdObject: ad) else{
//            return;
//        }
//
//        self.isLoading[unit] = false;
//        self.delegate?.GAD(manager: self, didDismissADForUnit: unit);
//        self.window.rootViewController?.setNeedsStatusBarAppearanceUpdate();
//
//        let completion = self.completions[unit];
//        self.completions[unit] = nil;
//        completion?(unit, ad, true);
//    }
    
//    public func interstitial(_ ad: GADInterstitial, didFailToReceiveAdWithError error: GADRequestError) {
//        print("Interstitial occured error. name[\(self.name(forAdObject: ad) ?? "")] error[\(error)]");
//
//        guard let _ = GADErrorCode.init(rawValue: error.code) else {
//            return;
//        }
//
//        guard let unit = self.unit(forAdObject: ad) else {
//            return;
//        }
//
//        self.isLoading[unit] = false;
//
////        switch code {
////        case .internalError:
//            let completion = self.completions[unit];
//            self.completions[unit] = nil;
//            completion?(unit, ad, false);
////            break;
////        default:
////            break;
////        }
//
//    }
    
    // MARK: GADFullScreenContentDelegate
    public func adWillPresentFullScreenContent(_ ad: GoogleMobileAds.FullScreenPresentingAd) {
        print("Opening has been presented. name[\(self.name(forAdObject: ad as! NSObject) ?? "")]");
        guard let unit = self.unit(forAdObject: ad as! NSObject) else{
            return;
        }
        
        self.delegate?.GAD(manager: self, willPresentADForUnit: unit);
    }
    
    public func adDidDismissFullScreenContent(_ ad: GoogleMobileAds.FullScreenPresentingAd) {
        let adObj = ad as! NSObject;
        print("Opening has been dismissed. name[\(self.name(forAdObject: adObj) ?? "")]");
        /*self.window.rootViewController?.showAlert(title: "후원해주셔서 감사합니다.", msg: "불편하신 사항은 리뷰에 남겨주시면 반영하겠습니다.", actions: [UIAlertAction.init(title: "확인", style: .default, handler: nil), UIAlertAction.init(title: "평가하기", style: .default, handler: { (act) in
         UIApplication.shared.openReview();
         })], style: .alert);*/
        
        defer{
            self.reprepare(adObject: adObj); //reload
        }
        
        guard let unit = self.unit(forAdObject: adObj) else{
            return;
        }
        
        self.isLoading[unit] = false;
        self.delegate?.GAD(manager: self, didDismissADForUnit: unit);
        let completion = self.completions[unit];
        self.completions[unit] = nil;
        completion?(unit, adObj, true);
    }
    
    public func ad(_ ad: GoogleMobileAds.FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let adObj = ad as! NSObject;
        
        print("Opening occured error. name[\(self.name(forAdObject: adObj) ?? "")] error[\(error)]");
        
        guard let unit = self.unit(forAdObject: adObj) else {
            return;
        }
        
        self.isLoading[unit] = false;
        
//        switch code {
//        case .internalError:
            let completion = self.completions[unit];
            self.completions[unit] = nil;
        completion?(unit, adObj, false);
//            break;
//        default:
//            break;
//        }
    }
}

