//
//  ConfigureSensorsViewController.swift
//  kneeFlexion
//
//  Created by Riley Bloomfield on 2017-05-04.
//  Copyright © 2017 Riley Bloomfield. All rights reserved.
//

import UIKit

/**
 Used to connect and configure the sensor network in preparation of streaming.
 */
class ConfigureSensorsViewController: UIViewController {
   /// Label indicates the current network status.
   @IBOutlet weak var statusLabel: UILabel!
   
   /// Displays an animating activity indicator.
   @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
   
   /// Called when view is loaded.
   override func viewDidLoad() {
      super.viewDidLoad();
   }
   
   /// Called when the view will appear.
   override func viewWillAppear(_ animated: Bool) {
      self.navigationController?.navigationBar.isHidden = true;
   }
   
   /// Method called when the view has appeared.
   ///
   /// - important: Method begins discovering sensors and proceeds to connect to them upon successful discovery.
   override func viewDidAppear(_ animated: Bool) {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5) {
         SensorNetwork.shared.discoverSensors { (status) in
            SensorNetwork.shared.connectNetwork(completion: { (didConnect) in
               if (!didConnect) {
                  print("Could not connect");
               } else {
                  SensorNetwork.shared.orderSensorsByButtonPress(buttonPressHandler: { (sensorIndex) in
                     print("Ordered sensor \(sensorIndex)");
                  }, completion: { (didOrder) in
                     print("All sensors ordered");
                     DispatchQueue.main.async {
                        if let view = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "displayView") as? DisplayViewController {
                           self.activityIndicator.stopAnimating();
                           self.navigationController?.pushViewController(view, animated: true);
                        }
                     }
                  })
               }
            })
         }
      }
      self.activityIndicator.startAnimating();
   }
}

/**
 Used to hold the display view and configure network view. Allows the user to navigate back to the connect and configure view at any time while viewing the displayed streaming angles.
 */
class MainNavigationController: UINavigationController {
   /// Used to configure the navigation controller colours and settings.
   override func viewDidLoad() {
      super.viewDidLoad();
      self.navigationBar.barTintColor = UIColor(red: 79/255, green: 38/255, blue: 131/255, alpha: 1);
      self.navigationBar.tintColor = .white;
      let view = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "configureViewController");
      viewControllers = [view];
   }
}
