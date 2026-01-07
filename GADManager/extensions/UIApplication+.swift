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
    private func openCompatible(_ url: URL, options: [UIApplication.OpenExternalURLOptionsKey : Any] = [:], completionHandler completion: ((Bool) -> Swift.Void)? = nil){
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
        let url_settings = URL(string:UIApplication.openSettingsURLString);
        self.openCompatible(url_settings!, options: [:], completionHandler: completion)
    }
}

/// Private extension to safely access the root view controller in iOS 13+ scene-based apps
private extension UIApplication {
    /// Returns the root view controller of the key window in the active scene.
    /// For multi-scene apps, prioritizes the foreground active scene with fallback logic.
    /// - Returns: The root view controller, or nil if no valid scene/window is found.
    var keyRootViewController: UIViewController? {
        // First, try to get the foreground active scene (ideal for multi-scene apps)
        if let windowScene = self.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            return windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        }

        // Fallback: try any connected scene if no foreground active scene is available
        guard let windowScene = self.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return nil
        }

        return windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
    }
}
