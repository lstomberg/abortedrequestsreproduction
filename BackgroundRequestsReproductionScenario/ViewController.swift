//
//  ViewController.swift
//  BackgroundRequestsReproductionScenario
//
//  Created by Jaap Mengers on 04/12/2018.
//  Copyright © 2018 Jaap Mengers. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

  @IBAction func didTouchButton(_ sender: Any) {
    UIApplication.shared.open(URL(string: "https://us-central1-postnl-reproductie-redirect.cloudfunctions.net/helloWorld")!)
  }

}

