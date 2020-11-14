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

public protocol GADManagerDelegate : NSObjectProtocol{
    //associatedtype E : RawRepresentable where E.RawValue == String
    func GAD<E>(manager: GADManager<E>, lastPreparedTimeForUnit unit: E) -> Date;
    func GAD<E>(manager: GADManager<E>, updateLastPreparedTimeForUnit unit: E, preparedTime time: Date);
    func GAD<E>(manager: GADManager<E>, lastShownTimeForUnit unit: E) -> Date;
    func GAD<E>(manager: GADManager<E>, updatShownTimeForUnit unit: E, showTime time: Date);
    func GAD<E>(manager: GADManager<E>, willPresentADForUnit unit: E);
    func GAD<E>(manager: GADManager<E>, didDismissADForUnit unit: E);
}

extension GADManagerDelegate{
    public func GAD<E>(manager: GADManager<E>, willPresentADForUnit unit: E){}
    public func GAD<E>(manager: GADManager<E>, didDismissADForUnit unit: E){}
}

public class GADManager<E : RawRepresentable> : NSObject, GADInterstitialDelegate, GADFullScreenContentDelegate where E.RawValue == String, E: Hashable{
    var window : UIWindow;
    
    public static var defaultInterval : TimeInterval { return 60.0 * 60.0 * 1.0 }
    #if DEBUG
    public static var opeingExpireInterval : TimeInterval { return 60.0 * 60.0 * 4.0 }
    #else
    public static var opeingExpireInterval : TimeInterval { return 60.0 * 5.0 }
    #endif

    lazy var identifiers = Bundle.main.infoDictionary?["GADUnitIdentifiers"] as? [String : String];
    var adObjects : [E : NSObject] = [:];
    var intervals : [E : TimeInterval] = [:];
    var isLoading : [E : Bool] = [:];
    var completions : [E : (E, NSObject?, Bool) -> Void] = [:];
    public var canShowFirstTime = true;
    public weak var delegate : GADManagerDelegate?;
    
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
                    DispatchQueue.main.async {
                        viewController?.openSettingsOrCancel(title: title ?? "", msg: msg ?? "You have to agree accessing to IDFA for using this app continue", style: .alert, titleForOK: cancel ?? "Cancel", titleForSettings: settings ?? "Settings");
                    }
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
    
    public func reset(unit: E){
        //RSDefaults.LastFullADShown = Date();
        //self.delegate?.GAD<E>(manager: GADManager<E>, updatShownTimeForUnit: unit, showTime: Date());
        self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
    }
    
    public func canShow(_ unit: E) -> Bool{
        var value = true;
        let now = Date();
        
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
        print("ad time spent \(spent) since \(lastShowTime). name[\(name)] now[\(now)] interval[\(interval)]");
        
        return value;
    }
    
    public func prepare(interstitialUnit unit: E, interval: TimeInterval = GADManager.defaultInterval){
        self.intervals[unit] = interval;
        guard let ad = self.adObjects[unit] else{
            if let unitId = self.identifiers?[unit.rawValue]{
                let newAd = GADInterstitial(adUnitID: unitId);
                newAd.delegate = self;
                let req = GADRequest();
                #if DEBUG
                req.testDevices = ["5fb1f297b8eafe217348a756bdb2de56"];
                #endif
                /*if let alert = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController as? UIAlertController{
                 alert.dismiss(animated: false, completion: nil);
                 }
                 }*/
                self.isLoading[unit] = true;
                newAd.load(req);
                self.adObjects[unit] = newAd;
            }else{
                assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            }
            return;
        }
        
        if let fullAd = ad as? GADInterstitial, !fullAd.isReady{
            self.isLoading[unit] = true;
            fullAd.load(GADRequest());
        }
    }
    
    public func prepare(bannerUnit unit: E, size: GADAdSize = kGADAdSizeBanner) -> GADBannerView?{
        var value : GADBannerView?;
        //self.intervals[unit] = interval;
        //guard let _ = self.adObjects[unit] else{
            if let unitId = self.identifiers?[unit.rawValue]{
                value = GADBannerView.init(adSize: size);
                value?.adUnitID = unitId;
                //ad.delegate = self;
                //let req = GADRequest();
                #if DEBUG
                //req.testDevices = ["5fb1f297b8eafe217348a756bdb2de56"];
                #endif
                /*if let alert = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController as? UIAlertController{
                 alert.dismiss(animated: false, completion: nil);
                 }
                 }*/
                
                //ad.load(req);
                //self.adObjects[unit] = ad;
            }else{
                assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            }
            //return;
        //}
        
        return value;
    }
    
    public func prepare(openingUnit unit: E, isTest: Bool = false, orientation: UIInterfaceOrientation = .unknown, interval: TimeInterval = GADManager.defaultInterval){
        self.intervals[unit] = interval;
        guard let ad = self.adObjects[unit] else{
            if let _unitId = self.identifiers?[unit.rawValue]{
                let req = GADRequest();
//                #if DEBUG
//                req.testDevices = ["5fb1f297b8eafe217348a756bdb2de56"];
//                #endif
                let unitId = isTest ? "ca-app-pub-3940256099942544/5662855259" : _unitId;
                
                self.isLoading[unit] = true;
                GADAppOpenAd.load(withAdUnitID: unitId, request: req, orientation: orientation) { [weak self](newAd, error) in
                    guard let self = self else{
                        return;
                    }
                    
                    newAd?.fullScreenContentDelegate = self;
                    self.adObjects[unit] = newAd;
                    if let error = error{
                        print("Opening is error. unit[\(unit)] error[\(error)]");
                        self.isLoading[unit] = false;
                        return;
                    }
                    
                    print("Opening is ready. unit[\(unit)]");
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
    
    func reprepare(interstitialUnit unit: E){
        if let interval = self.intervals[unit]{
            self.prepare(interstitialUnit: unit, interval: interval);
        }else{
            self.prepare(interstitialUnit: unit);
        }
    }
    
    func reprepare(openingUnit unit: E, isTest: Bool = false){
        if let interval = self.intervals[unit]{
            self.prepare(openingUnit: unit, interval: interval);
        }else{
            self.prepare(openingUnit: unit);
        }
    }
    
    func reprepare(adObject: NSObject, isTest: Bool = false){
        guard let name = self.name(forAdObject: adObject), let unit = E.init(rawValue: name), let interval = self.intervals[unit] else{
            return;
        }
        
        if adObject is GADInterstitial{
            self.adObjects[unit] = nil;
            self.prepare(interstitialUnit: unit, interval: interval);
        }else if adObject is GADAppOpenAd{
            self.adObjects[unit] = nil;
            self.prepare(openingUnit: unit, isTest: isTest, interval: interval);
        }
    }
    
    func isPrepared(_ unit: E) -> Bool{
        var value = false;
        
        if let interstitial = self.adObjects[unit] as? GADInterstitial{
            value = interstitial.isReady;
        }else if let opening = self.adObjects[unit] as? GADAppOpenAd{
//            let time_1970 = Date.init(timeIntervalSince1970: 0);
            let now = Date();
            let lastPrepared = delegate?.GAD(manager: self, lastPreparedTimeForUnit: unit) ?? now;
            
            value = now.timeIntervalSince(lastPrepared) <= type(of: self).opeingExpireInterval;
        }
        
        return value;
    }
    
    public func show(unit: E, force : Bool = false, needToWait wait: Bool = false, isTest: Bool = false, viewController: UIViewController? = nil, completion: ((E, NSObject?, Bool) -> Void)? = nil){
        guard self.canShow(unit) || force else {
            //self.window.rootViewController?.showAlert(title: "알림", msg: "1시간에 한번만 후원하실 수 있습니다 ^^;", actions: [UIAlertAction(title: "확인", style: .default, handler: nil)], style: .alert);
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
                if ad is GADInterstitial{
                    self.reprepare(interstitialUnit: unit);
                }else if ad is GADAppOpenAd{
                    self.reprepare(openingUnit: unit, isTest: isTest);
                }
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
        /*if let alert = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController as? UIAlertController{
         alert.dismiss(animated: false, completion: nil);
         }*/
        
        guard !(UIApplication.shared.keyWindow?.rootViewController?.presentedViewController is UIAlertController) else{
            //alert.dismiss(animated: false, completion: nil);
            //self.fullAd = nil;
            completion?(unit, self.adObjects[unit], false);
            return;
        }
        
        if let ad = self.adObjects[unit] as? GADInterstitial{
            print("present interstital ad view[\(self.window.rootViewController?.description ?? "")]");
            self.completions[unit] = completion;
            ad.present(fromRootViewController: viewController ?? self.window.rootViewController!);
            self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
        }else if let ad = self.adObjects[unit] as? GADAppOpenAd{
            print("present opening ad view[\(self.window.rootViewController?.description ?? "")]");
            self.completions[unit] = completion;
            ad.present(fromRootViewController: viewController ?? self.window.rootViewController!);
            self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
        }
        
        //RSDefaults.LastFullADShown = Date();
    }
    
    // MARK: GADInterstitialDelegate
    public func interstitialDidReceiveAd(_ ad: GADInterstitial) {
        print("Interstitial is ready. name[\(self.name(forAdObject: ad) ?? "")]");
        guard let unit = self.unit(forAdObject: ad) else{
            return;
        }
        
        self.isLoading[unit] = false;
        guard let completion = self.completions[unit] else{
            return;
        }
        
//        self.completions[unit] = nil;
//        completion?(unit, ad);
        self.show(unit: unit, completion: completion);
    }
    
    public func interstitialWillPresentScreen(_ ad: GADInterstitial) {
        //self.fullAd = nil;
        print("Interstitial has been presented. name[\(self.name(forAdObject: ad) ?? "")]");
        guard let unit = self.unit(forAdObject: ad) else{
            return;
        }
        
        self.delegate?.GAD(manager: self, willPresentADForUnit: unit);
    }
    
    /*func interstitialDidFail(toPresentScreen ad: GADInterstitial) {
     print("Interstitial has been failed. name[\(self.name(forAdObject: ad) ?? "")]");
     }*/
    
    public func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        print("Interstitial has been dismissed. name[\(self.name(forAdObject: ad) ?? "")]");
        /*self.window.rootViewController?.showAlert(title: "후원해주셔서 감사합니다.", msg: "불편하신 사항은 리뷰에 남겨주시면 반영하겠습니다.", actions: [UIAlertAction.init(title: "확인", style: .default, handler: nil), UIAlertAction.init(title: "평가하기", style: .default, handler: { (act) in
         UIApplication.shared.openReview();
         })], style: .alert);*/
        defer{
            self.reprepare(adObject: ad); //reload
        }
        
        guard let unit = self.unit(forAdObject: ad) else{
            return;
        }
        
        self.isLoading[unit] = false;
        self.delegate?.GAD(manager: self, didDismissADForUnit: unit);
        let completion = self.completions[unit];
        self.completions[unit] = nil;
        completion?(unit, ad, true);
    }
    
    public func interstitial(_ ad: GADInterstitial, didFailToReceiveAdWithError error: GADRequestError) {
        print("Interstitial occured error. name[\(self.name(forAdObject: ad) ?? "")] error[\(error)]");
        
        guard let code = GADErrorCode.init(rawValue: error.code) else {
            return;
        }
        
        guard let unit = self.unit(forAdObject: ad) else {
            return;
        }
        
        self.isLoading[unit] = false;
        
//        switch code {
//        case .internalError:
            let completion = self.completions[unit];
            self.completions[unit] = nil;
            completion?(unit, ad, false);
//            break;
//        default:
//            break;
//        }
     
    }
    
    // MARK: GADFullScreenContentDelegate
    public func adDidPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Opening has been presented. name[\(self.name(forAdObject: ad as! NSObject) ?? "")]");
        guard let unit = self.unit(forAdObject: ad as! NSObject) else{
            return;
        }
        
        self.delegate?.GAD(manager: self, willPresentADForUnit: unit);
    }
    
    public func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        print("Opening has been dismissed. name[\(self.name(forAdObject: ad as! NSObject) ?? "")]");
        /*self.window.rootViewController?.showAlert(title: "후원해주셔서 감사합니다.", msg: "불편하신 사항은 리뷰에 남겨주시면 반영하겠습니다.", actions: [UIAlertAction.init(title: "확인", style: .default, handler: nil), UIAlertAction.init(title: "평가하기", style: .default, handler: { (act) in
         UIApplication.shared.openReview();
         })], style: .alert);*/
        defer{
            self.reprepare(adObject: ad as! NSObject); //reload
        }
        
        guard let unit = self.unit(forAdObject: ad as! NSObject) else{
            return;
        }
        
        self.isLoading[unit] = false;
        self.delegate?.GAD(manager: self, didDismissADForUnit: unit);
        let completion = self.completions[unit];
        self.completions[unit] = nil;
        completion?(unit, ad as! NSObject, true);
    }
    
    public func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("Opening occured error. name[\(self.name(forAdObject: ad as! NSObject) ?? "")] error[\(error)]");
        let error = error as NSError;
        
        guard let code = GADErrorCode.init(rawValue: error.code) else {
            return;
        }
        
        guard let unit = self.unit(forAdObject: ad as! NSObject) else {
            return;
        }
        
        self.isLoading[unit] = false;
        
//        switch code {
//        case .internalError:
            let completion = self.completions[unit];
            self.completions[unit] = nil;
        completion?(unit, ad as! NSObject, false);
//            break;
//        default:
//            break;
//        }
    }
}

