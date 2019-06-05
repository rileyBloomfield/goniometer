//
//  AppDelegate.swift
//  kneeFlexion
//
//  Created by Riley Bloomfield on 2017-05-04.
//  Copyright © 2017 Riley Bloomfield. All rights reserved.
//

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
   
   /// Main application window
   var window: UIWindow?
   private var hasDisconnected = false;
   
   /// Initialize main settings
   ///
   /// - important: Sets the sensor network delegate to self and configures number of sensors in the network to two.
   /// Assigns the navigation controller to the root view controller.
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
      UIApplication.shared.isIdleTimerDisabled = true;
      SensorNetwork.shared.setDelegate(self);
      SensorNetwork.shared.setNumberOfSensorsInNetwork(2);
      window = UIWindow(frame: UIScreen.main.bounds);
      window?.makeKeyAndVisible();
      window?.rootViewController = MainNavigationController();
      return true
   }
   
   /// Application has become unactive.
   ///
   /// - important: Sensor network is disconnected.
   func applicationWillResignActive(_ application: UIApplication) {
      SensorNetwork.shared.disconnectSensors();
   }
   
   /// Application has become active.
   ///
   /// - important: Navigation controller pops to the connection view and the network is reconfigured.
   func applicationDidBecomeActive(_ application: UIApplication) {
      if let navigationController = self.window?.rootViewController as? UINavigationController {
         navigationController.popToRootViewController(animated: true);
      }
   }
   
   /// Application will terminate.
   ///
   /// - important: Sensor network is disconnected.
   func applicationWillTerminate(_ application: UIApplication) {
      SensorNetwork.shared.disconnectSensors();
   }
}

extension AppDelegate: SensorNetworkDelegate {
   func hasInitiatedConnectingSequence() {
      
   }
   
   func hasEncounteredError(error: SensorNetworkError) {
      
   }
   
   internal func hasResetConfigurations() {
      os_log("Sensor configuration reset.");
   }
   
   internal func hasOrderedSensors() {
      os_log("Sensor network ordered");
   }
   
   internal func hasConnectedSensors() {
      os_log("Sensor network connected");
   }
   
   internal func hasDisconnectedSensors() {
      os_log("Sensor network disconnected");
   }
   
   internal func hasLostConnection() {
      os_log("Sensor network lost connection");
   }
   
   
}

