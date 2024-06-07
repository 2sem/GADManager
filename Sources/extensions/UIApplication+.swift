//
//  UIApplication+.swift
//  GADManager
//
//  Created by 영준 이 on 2020/10/15.
//  Copyright © 2020 Y2KLab. All rights reserved.
//

//
//  UIApplication.swift
//  LSExtensions
//
//  Created by 영준 이 on 2017. 1. 10..
//  Copyright © 2017년 leesam. All rights reserved.
//

import UIKit

extension UIApplication{
    
    /**
        os compatible for function to open url
    */
    private func openCompatible(_ url: URL, options: [String : Any] = [:], completionHandler completion: ((Bool) -> Swift.Void)? = nil){
        if #available(iOS 10.0, *) {
            self.open(url, options: options, completionHandler: completion)
        } else {
            self.openURL(url);
        }
    }
    
    /**
        Opens Settings App page for this app
         - parameter completion: block to call after opening Settings App has been completed
    */
    public func openSettings(_ completion: ((Bool) -> Swift.Void)? = nil){
        let url_settings = URL(string:UIApplicationOpenSettingsURLString);
        self.openCompatible(url_settings!, options: [:], completionHandler: completion)
    }
}
