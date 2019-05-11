//
//  GADManager.swift
//  GADManager
//
//  Created by 영준 이 on 2019. 5. 11..
//  Copyright © 2019년 Y2KLab. All rights reserved.
//

import UIKit
import GoogleMobileAds

public protocol GADManagerDelegate : NSObjectProtocol{
    //associatedtype E : RawRepresentable where E.RawValue == String
    func GAD<E>(manager: GADManager<E>, lastShownTimeForUnit unit: E) -> Date;
    func GAD<E>(manager: GADManager<E>, updatShownTimeForUnit unit: E, showTime time: Date);
}

public class GADManager<E : RawRepresentable> : NSObject, GADInterstitialDelegate where E.RawValue == String, E: Hashable{
    var window : UIWindow;
    
    public static var defaultInterval : TimeInterval { return 60.0 * 60.0 * 1.0 }
    lazy var identifiers = Bundle.main.infoDictionary?["GADUnitIdentifiers"] as? [String : String];
    var adObjects : [E : NSObject] = [:];
    var intervals : [E : TimeInterval] = [:];
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
    
    public func reset(unit: E){
        //RSDefaults.LastFullADShown = Date();
        //self.delegate?.GAD<E>(manager: GADManager<E>, updatShownTimeForUnit: unit, showTime: Date());
        self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
    }
    
    public func canShow(_ unit: E) -> Bool{
        var value = true;
        let now = Date();
        
        guard self.delegate != nil else {
            return value;
        }
        
        let lastShowTime = self.delegate!.GAD(manager: self, lastShownTimeForUnit: unit);
        let time_1970 = Date.init(timeIntervalSince1970: 0);
        
        //(!self.canShowFirstTime &&
        guard self.canShowFirstTime || lastShowTime > time_1970 else{
            if lastShowTime <= time_1970{
                self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: now);
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
        guard let _ = self.adObjects[unit] else{
            if let unitId = self.identifiers?[unit.rawValue]{
                let ad = GADInterstitial(adUnitID: unitId);
                ad.delegate = self;
                let req = GADRequest();
                #if DEBUG
                req.testDevices = ["5fb1f297b8eafe217348a756bdb2de56"];
                #endif
                /*if let alert = UIApplication.shared.keyWindow?.rootViewController?.presentedViewController as? UIAlertController{
                 alert.dismiss(animated: false, completion: nil);
                 }
                 }*/
                
                ad.load(req);
                self.adObjects[unit] = ad;
            }else{
                assertionFailure("create dictionary 'GADUnitIdentifiers' and insert new unit id into it.");
            }
            return;
        }
    }
    
    func reprepare(adObject: NSObject){
        
        guard let name = self.name(forAdObject: adObject), let unit = E.init(rawValue: name), let interval = self.intervals[unit] else{
            return;
        }
        
        if adObject is GADInterstitial{
            self.adObjects[unit] = nil;
            self.prepare(interstitialUnit: unit, interval: interval);
        }
    }
    
    func isPrepared(_ unit: E) -> Bool{
        var value = false;
        
        if let interstitial = self.adObjects[unit] as? GADInterstitial{
            value = interstitial.isReady;
        }
        
        return value;
    }
    
    public func show(unit: E, force : Bool = false){
        guard self.canShow(unit) || force else {
            //self.window.rootViewController?.showAlert(title: "알림", msg: "1시간에 한번만 후원하실 수 있습니다 ^^;", actions: [UIAlertAction(title: "확인", style: .default, handler: nil)], style: .alert);
            return;
        }
        
        guard self.isPrepared(unit) else{
            return;
        }
        
        self.__show(unit: unit);
    }
    
    private func __show(unit: E){
        guard self.window.rootViewController != nil else{
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
            return;
        }
        
        if let ad = self.adObjects[unit] as? GADInterstitial{
            print("present ad view[\(self.window.rootViewController?.description ?? "")]");
            ad.present(fromRootViewController: self.window.rootViewController!);
            self.delegate?.GAD(manager: self, updatShownTimeForUnit: unit, showTime: Date());
        }
        
        //RSDefaults.LastFullADShown = Date();
    }
    
    //GADInterstitialDelegate
    /*func interstitialDidReceiveAd(_ ad: GADInterstitial) {
     print("Interstitial is ready. name[\(self.name(forAdObject: ad) ?? "")]");
     
     //self._show();
     }*/
    
    public func interstitialWillPresentScreen(_ ad: GADInterstitial) {
        //self.fullAd = nil;
        print("Interstitial has been presented. name[\(self.name(forAdObject: ad) ?? "")]");
    }
    
    /*func interstitialDidFail(toPresentScreen ad: GADInterstitial) {
     print("Interstitial has been failed. name[\(self.name(forAdObject: ad) ?? "")]");
     }*/
    
    public func interstitialDidDismissScreen(_ ad: GADInterstitial) {
        print("Interstitial has been dismissed. name[\(self.name(forAdObject: ad) ?? "")]");
        /*self.window.rootViewController?.showAlert(title: "후원해주셔서 감사합니다.", msg: "불편하신 사항은 리뷰에 남겨주시면 반영하겠습니다.", actions: [UIAlertAction.init(title: "확인", style: .default, handler: nil), UIAlertAction.init(title: "평가하기", style: .default, handler: { (act) in
         UIApplication.shared.openReview();
         })], style: .alert);*/
        self.reprepare(adObject: ad); //reload
    }
    
    /*func interstitial(_ ad: GADInterstitial, didFailToReceiveAdWithError error: GADRequestError) {
     print("Interstitial occured error. name[\(self.name(forAdObject: ad) ?? "")] error[\(error)]");
     }*/
}

