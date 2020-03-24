//
//  AppDelegate.swift
//  Puzzles
//
//  Created by Duncan MacGregor on 13/03/2020.
//  Copyright © 2020 Greg Hewgill. All rights reserved.
//

import Foundation
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UINavigationControllerDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let glvc = GameListViewController(frame: window!.bounds)
        let nc = UINavigationController(rootViewController: glvc)
        nc.delegate = self
        nc.hidesBarsWhenVerticallyCompact = true
        let gvc = glvc.saveGameViewController()
        if (gvc != nil) {
            nc.setViewControllers([glvc, gvc!], animated: false)
        }
        window?.rootViewController = nc
        window?.makeKeyAndVisible()
        return true
    }
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        if (viewController is GameViewController) {
            navigationController.setToolbarHidden(false, animated: false)
        } else {
            navigationController.setToolbarHidden(true, animated: false)
        }
    }
}
