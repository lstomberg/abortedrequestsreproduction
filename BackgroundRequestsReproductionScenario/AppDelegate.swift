//
//  AppDelegate.swift
//  BackgroundRequestsReproductionScenario
//
//  Created by Jaap Mengers on 04/12/2018.
//  Copyright © 2018 Jaap Mengers. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?
  let session = URLSession(configuration: .default)

  func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

    let datatask = session.dataTask(with: URL(string: "https://reqres.in/api/users")!) { data, response, error in
      switch (response as? HTTPURLResponse, error as NSError?) {
      case (.some(let response), _) where response.statusCode == 200: print("Request succeeded")
      case (_, .some(let error)) where error.code == 53:
        print("Request aborted")
      default: break
      }
    }

    datatask.resume()

    return true
  }
}

