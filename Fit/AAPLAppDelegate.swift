//
//  AAPLAppDelegate.swift
//  Fit
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/7/25.
//
//
/*
    Copyright (C) 2016 Apple Inc. All Rights Reserved.
    See LICENSE.txt for this sample’s licensing information

    Abstract:
    The main application delegate.
*/

import UIKit
import HealthKit

protocol HavingHealthStore: class {
    var healthStore: HKHealthStore? {get set}
}

@UIApplicationMain
@objc(AAPLAppDelegate)
class AAPLAppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    
    private var healthStore: HKHealthStore!
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        self.healthStore = HKHealthStore()
        
        self.setUpHealthStoreForTabBarControllers()
        
        return true
    }
    
    //MARK: - Convenience
    
    // Set the healthStore property on each view controller that will be presented to the user. The root view controller is a tab
    // bar controller. Each tab of the root view controller is a navigation controller which contains its root view controller—
    // these are the subclasses of the view controller that present HealthKit information to the user.
    private func setUpHealthStoreForTabBarControllers() {
        let tabBarController = self.window!.rootViewController as! UITabBarController
        
        for navigationController in tabBarController.viewControllers! as! [UINavigationController] {
            if let viewController = navigationController.topViewController as? HavingHealthStore {
                
                viewController.healthStore = self.healthStore
            }
        }
    }
    
}
