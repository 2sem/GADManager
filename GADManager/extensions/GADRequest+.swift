//
//  GADRequest+.swift
//  GADManager
//
//  Created by 영준 이 on 2020/11/17.
//  Copyright © 2020 Y2KLab. All rights reserved.
//

import GoogleMobileAds

public enum GADBannerCollapseDirection: String {
    case bottom = "bottom"
    case top = "top"
}

extension GADRequest{
    public func hideTestLabel(){
        let extras = GADExtras();
        extras.additionalParameters = ["suppress_test_label" : "1"];
        self.register(extras)
    }
    
    public func enableCollapsible(direction: GADBannerCollapseDirection = .bottom){
        let extras = GADExtras();
        extras.additionalParameters = ["collapsible" : direction.rawValue];
        self.register(extras)
    }
}
