//
//  GADRequest+.swift
//  GADManager
//
//  Created by 영준 이 on 2020/11/17.
//  Copyright © 2020 Y2KLab. All rights reserved.
//

import GoogleMobileAds

extension GADRequest{
    public func hideTestLabel(){
        let extras = GADExtras();
        extras.additionalParameters = ["suppress_test_label" : "1"];
        self.register(extras)
    }
}
