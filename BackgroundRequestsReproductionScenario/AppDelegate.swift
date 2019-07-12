//
//  AppDelegate.swift
//  BackgroundRequestsReproductionScenario
//
//  Created by Jaap Mengers on 04/12/2018.
//  Copyright © 2018 Jaap Mengers. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, URLSessionDelegate, URLSessionTaskDelegate {

    var window: UIWindow?

    func applicationDidEnterBackground(_ application: UIApplication) {
        print("backgrounded")
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        print("foregrounded")
    }
}

