//
//  String+.swift
//  GADManager
//
//  Created by 영준 이 on 2020/10/15.
//  Copyright © 2020 Y2KLab. All rights reserved.
//
import Foundation

extension String {
    /**
        Gets Localized String by specified Locale
        - parameter defaultText: default String if there is no localized string for this
        - parameter locale: Locale to get localized String with
        - returns: Localized String by specified Locale
    */
    public func localized(_ defaultText : String? = nil, locale: Locale? = Locale.current) -> String{
        var value = self;
        var bundlePath : String? = Bundle.main.path(forResource: locale?.identifier, ofType: "lproj");
        if bundlePath == nil{
            bundlePath = Bundle.main.path(forResource: locale?.languageCode, ofType: "lproj");
        }
        if bundlePath == nil{
            bundlePath = Bundle.main.path(forResource: "\(locale?.languageCode ?? "")-\(locale?.scriptCode ?? "")", ofType: "lproj");
        }
        
        //Check if specified lang equals to base lang
        if bundlePath == nil{
            bundlePath = Bundle.main.path(forResource: "Base", ofType: "lproj");
        }
        
        if bundlePath == nil && locale?.languageCode == "en"{
            bundlePath = Bundle.main.path(forResource: nil, ofType: "lproj");
        }
        
        if bundlePath == nil{
            value = NSLocalizedString(defaultText ?? self, comment: "");
        }else{
            let bundle = Bundle(path: bundlePath!)!;
            
            value = bundle.localizedString(forKey: self, value: defaultText ?? self, table: nil);
        }
        
        return value;
    }
}
