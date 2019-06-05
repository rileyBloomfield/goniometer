//
//  SensorNetwork.swift
//  mobileApp
//
//  Created by Riley Bloomfield on 2017-01-25.
//  Copyright © 2017 Riley Bloomfield. All rights reserved.
//

import Foundation
import MetaWear
import MetaWearCpp
import BoltsSwift
import os.log

@objc
class SensorContext: NSObject {
   init(sensor: MetaWear, index: Int) {
      self.sensor = sensor;
      self.index = index;
   }
   var sensor: MetaWear!
   var index: Int!
}

/**
 Sensor network organizing and controlling all sensors as a single network unit. Responsible for all sensor operations from discovery to streaming data, getting synchronized readings, maintaining connection status and disconnection.
 */
public class SensorNetwork {
   /// Singleton sensor network object.
   public static let shared = SensorNetwork();
   
   private var appDelegate: SensorNetworkDelegate!
   private var sensorConnectionManager = MetaWearScanner.shared;
   private var sensors = [MetaWear]();
   private var numberOfSensors: Int!
   private var networkOrdered = false;
   private var networkConnected = false;
   public var setTestName = false;
   private var calibrationValues: [Int?]!
   private var loggerIDs: [UInt8?]!
   private var downloadHandles: [DownloadHandle]!
   var quatStreamSync: QuaternionStreamSynchronizer!
   var sensorStreamBridges: [SensorStreamBridge]!
   
   // Members to track context of sensor ordering
   private var orderedSensors = [MetaWear]();
   private var sensorButtonPressHandler: (Int) -> Void = {_ in};
   private var orderCompletion: (Bool) -> Void = {_ in};
   
   // Members to track context of sensor logging
   private var loggingStatus = [Bool]();
   private var loggingCompletion : (Bool) -> Void = {_ in};
   
   // Download handlers
   private var progressValues = [Float]();
   private var downloadProgress: (Float) -> Void = {_ in};
   
   // Private constructor forcing the singleton use
   private init() {};
}

// MARK: - Accessors
extension SensorNetwork {
   /// If the sensors have been ordered explicitly.
   ///
   /// - returns: Bool representing if the sensors in the network have had their order specified.
   public var isOrdered:Bool { return networkOrdered; }
   
   /// If the sensors in the sensor network are currently connected.
   ///
   /// - returns: Bool representing if the sensors are currently connected.
   public var isConnected:Bool { return networkConnected; }
   
   
   /// Number of sensors in the sensor network.
   ///
   /// - important: The value consideres sensors in the network in all states, not only connected sensors.
   /// - returns: The number of sensors currently active.
   public var sensorCount:Int { return sensors.count; }
   
   /// If the network has a delegate.
   ///
   /// - returns: Bool representing if an application delegate has been set to handle network events.
   public var hasDelegate:Bool { return appDelegate != nil; }
   
   public var isUsingIMUPlus:Bool {
      //      for sensor in sensors {
      //         if (sensor.sensorFusion?.mode == .imuPlus) {
      //            return true;
      //         }
      //      }
      return true;
   }
   
   /// Sensor names as assigned to the sensors previously.
   ///
   /// - important: If names have not been assigned, the sensors could have names previously assigned by other applications.
   /// - returns: A string array of all sensors ordered as they currently exist.
   public var sensorNames:[String] {
      var listOfNames = [String]();
      for sensor in sensors {
         listOfNames.append(sensor.name);
      }
      return listOfNames;
   }
   
   /// Assign a delegate to the sensor network.
   ///
   /// - parameter delegate: An application delegate that implementes the sensor network delegate protocol.
   public func setDelegate(_ delegate: AnyObject) {
      appDelegate = delegate as? SensorNetworkDelegate;
   }
   
   /// Get the name of a particular sensor in the network order.
   ///
   /// - parameter atIndex: The index of the sensor in the network.
   public func getNameOfSensor(atIndex: Int) -> String {
      if (atIndex > sensors.count || atIndex < 0) {
         if (hasDelegate) {
            appDelegate.hasEncounteredError(error:
               SensorNetworkError("An incorrect sensor index was used to fetch a sensor name."))
         }
         return "";
      }
      return sensors[atIndex].name;
   }
   
   /// Set the number of sensors that the network will use.
   ///
   /// - important: Changing this number will have no effect on the network once sensor discovery has finished. It is used to limit discovery to the specified number of sensors.
   /// - parameter count: The number of sensors that the network will use.
   public func setNumberOfSensorsInNetwork(_ count: Int) {
      if (count < 1) {
         reportError("The network sensor count supplied is too low, a value of 1 will be used.");
         self.numberOfSensors = 1;
      }
      self.numberOfSensors = count;
      self.calibrationValues = [Int?](repeating: nil, count: count);
      self.progressValues = [Float](repeating: 0.0, count: count);
      self.loggerIDs = [UInt8](repeating: UInt8(), count: count);
      self.downloadHandles = [DownloadHandle](repeating: DownloadHandle(), count: count);
      self.sensorStreamBridges = [SensorStreamBridge](repeating: SensorStreamBridge(), count: count);
      self.quatStreamSync = QuaternionStreamSynchronizer(sensorCount: count);
   }
   
   public func reportError(_ message: String) {
      if (self.hasDelegate) {
         appDelegate.hasEncounteredError(error:
            SensorNetworkError(message))
      }
   }
   
}

//MARK: - Fetch Counts
extension SensorNetwork {
   /// Get a synchronized reading of battery levels for all sensors.
   ///
   /// - important: The number of readings returned will be equal to the number of sensors in the sensor network
   /// - returns: Escaping completion parameter will return an array of integer readings asynchronously. A reading of zero indicates a failure to obtain the reading from a sensor at the same index.
   public func getSynchronizedBatteryStatus(completion: @escaping (_ result: [Int]) -> Void) {
      var batteryLevels = [Int](repeating: -1, count: sensorCount);
      let assignLevel: (_ index: Int, _ val: Int) -> Void = { (index,val) in
         batteryLevels[index] = val;
         if (!batteryLevels.contains(-1)) {
            completion(batteryLevels);
         }
      }
      for (index,sensor) in sensors.enumerated() {
         if (sensor.isConnectedAndSetup) {
            assignLevel(index, 100);
         } else {
            assignLevel(index, 0);
         }
      }
   }
   
   /// Get a synchronized reading of signal levels for all sensors.
   ///
   /// - important: The number of readings returned will be equal to the number of sensors in the sensor network
   /// - returns: Escaping completion parameter will return an array of integer readings asynchronously. A reading of zero indicates a failure to obtain the reading from a sensor at the same index.
   public func getSynchronizedSignalStatus(completion: @escaping (_ result: [Int]) -> Void) {
      var signalLevels = [Int](repeating: -1, count: sensors.count);
      let assignLevel: (_ index: Int, _ val: Int) -> Void = { (index,val) in
         signalLevels[index] = abs(val);
         if (!signalLevels.contains(-1)) {
            completion(signalLevels);
         }
      }
      for (index,sensor) in sensors.enumerated() {
         if (sensor.isConnectedAndSetup) {
            sensor.readRSSI().continueOnSuccessWith { (value) in
               assignLevel(index, value);
               }.continueOnErrorWith { (error) in
                  if (self.hasDelegate) {
                     self.appDelegate.hasEncounteredError(error: SensorNetworkError(error.localizedDescription));
                  }
            }
         } else {
            assignLevel(index, 0);
         }
      }
   }
}

// MARK: - Discover and Connect
extension SensorNetwork {
   /// Discover nearby sensors to add to the network.
   ///
   /// - important: Sensor network discovery will first disconnect existing network sensors. Discovery will then continue until the previously set **numberOfSensorsInNetwork** is reached. The sensors have been discovered but have not been connected.
   /// - returns: Escaping completion parameter will return true indicating the desired number of sensors have been discovered.
   public func discoverSensors(completion: @escaping (_ result: Bool) -> Void) {
      disconnectSensors();
      self.sensors.removeAll();
      self.networkOrdered = false;
      sensorConnectionManager.startScan(allowDuplicates: false) { (sensor) in
         self.sensors.append(sensor);
         if (self.sensors.count == self.numberOfSensors) {
            self.sensorConnectionManager.stopScan();
            completion(true);
         }
      }
   }
   
   fileprivate func connectTo(_ sensor: MetaWear, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
      sensor.connectAndSetup().continueWith(continuation: { t in
         t.result?.continueWith(continuation: { s in
            if (self.networkConnected == true) {
               print("Unexpectedly lost connection to sensor.");
               self.networkConnected = false;
               if (self.hasDelegate) {
                  self.appDelegate.hasLostConnection();
               }
            }
         })
      }).continueOnSuccessWith { (t) in
         success();
         }.continueOnErrorWith { (error) in
            failure(error);
      }
   }
   
   /// Connect and configure to all previously discovered sensors.
   ///
   /// - important: If sensor configurations do not match the sensor configuration required (programmed by another application), the configuration will be reset and the sensor will be reconnected automatically. This method will run as a repeated fallable task to attempt to connect even if initial failure is detected.
   /// - returns: Optional escaping completion parameter will return true indicating that all sensors have been connected successfully and their configurations are appropriate for use with this application. A false completion indicates that the number of attempts has been reached without successful connection, or the configurations could not be set.
   public func connectNetwork(completion: @escaping (_ result: Bool) -> Void = {_ in}) {
      var connectionCheck = [Bool](repeatElement(false, count: sensorCount));
      if (networkConnected == false) {
         if (appDelegate != nil) { appDelegate.hasInitiatedConnectingSequence(); }
      }
      
      let checkIfFinishedConnecting: (_ sensorIndex: Int) -> Void = { (index) in
         connectionCheck[index] = true;
         if (!connectionCheck.contains(false)) {
            completion(true);
            self.networkConnected = true;
            if (self.hasDelegate) { self.appDelegate.hasConnectedSensors() }
         }
      }
      
      let repeatConnectTo: (_ sensor: MetaWear, _ connected: @escaping (_ result: Bool) -> Void) -> Void = { (sensor,connected) in
         self.performFallibleTask(numberOfTimes: 5, task: {success, failure in self.connectTo(sensor, success: success, failure: failure)},
                                  success: {
                                    connected(true);
         }, failure: { error in
            if (self.hasDelegate) {
               self.appDelegate.hasEncounteredError(error: SensorNetworkError(error.localizedDescription));
            }
            connected(false);
         });
      }
      for (index,sensor) in sensors.enumerated() {
         repeatConnectTo(sensor, { (success) in
            if (success) {
               checkIfFinishedConnecting(index);
            } else {
               completion(false);
            }
         });
      }
   }
   
   /// Reconnect a single sensor after individual failure has been detected.
   ///
   /// - important: This method will run as a repeated fallable task to attempt to connect even if initial failure is detected. This method will return if the network has been intentionally disconnected, to prevent reconnection when network disconnection has been intended.
   /// - parameter sensorIndex: The index of the sensor in the network that should be reconnected.
   public func reconnectSingleSensor(_ sensorIndex: Int) {
      if (networkConnected == false) { return }
      let networkReconnectionCheck: () -> Bool = {
         for sensor in self.sensors {
            if (!sensor.isConnectedAndSetup) {
               return false;
            }
         }
         return true;
      }
      if (self.hasDelegate) { appDelegate.hasLostConnection() }
      performFallibleTask(numberOfTimes: 100, task: {success, failure in self.connectTo(self.sensors[sensorIndex], success: success, failure: failure)}, success: {
         if (networkReconnectionCheck() && self.hasDelegate) {
            self.appDelegate.hasConnectedSensors();
         }
      }, failure: { (error) in
         self.reportError("Failed to reconnect one or more sensors after 100 retries");
      });
   }
   
   /// Attempt to disconnect all sensors
   ///
   /// - important: This method will trigger a disconnect on all sensors and set the network status as disconnected first, even if not all sensors disconnect successfully. This is to ensure the network does not reconnect to the disconnected sensors when a disconnect is intended.
   public func disconnectSensors(completion: @escaping (_ success: Bool) -> Void = {_ in}) {
      networkConnected = false;
      disableQuaternionStreaming();
      var disconnectionCheck = [Bool](repeatElement(false, count: sensorCount));
      for (index,sensor) in sensors.enumerated() {
         if (!networkOrdered) {
            sensor.turnOffLed();
         }
         sensor.cancelConnection();
         sensor.forget();
         disconnectionCheck[index] = true;
         if (!disconnectionCheck.contains(false)) {
            completion(true);
            if (self.hasDelegate) { self.appDelegate.hasDisconnectedSensors() }
         }
      }
   }
}

// MARK: - Sensor State and Configuration
extension SensorNetwork {
   /// Perform a factory reset to all sensors in the network.
   private func resetAllSensors() {
      for (index,sensor) in sensors.enumerated() {
         sensor.connectAndSetup().continueOnSuccessWith { (t) in
            sensor.clearAndReset();
            }.continueOnErrorWith { (error) in
               if (self.hasDelegate) {
                  self.appDelegate.hasEncounteredError(error: SensorNetworkError(error.localizedDescription + "\nError on sensor " + String(index)));
               }
         }
      }
   }
   
   public func updateFirmware() {
      networkConnected = false;
      for sensor in sensors {
         sensor.updateFirmware().continueOnSuccessWith { _ in
            print("Firmware updated successfully.")
            }.continueOnErrorWith { _ in
               print("Error updating firmware.")
         }
      }
   }
   
   public func setTareOrientation(completion: @escaping (_ result: Bool) -> Void) {
      var syncCheck = [Bool](repeating: false, count: sensors.count);
      for (index,sensor) in self.sensors.enumerated() {
         sensor.configureSensorFusion().continueOnSuccessWith {
            var sensorFusionSignal: OpaquePointer!
            sensor.getSensorFusionSignal(withPeriod: 35).continueOnSuccessWithTask { (signal) -> Task<OpaquePointer> in
               sensorFusionSignal = signal;
               return sensorFusionSignal.datasignalLog();
               }.continueOnSuccessWith { (logger) in
                  syncCheck[index] = true;
                  if (!syncCheck.contains(false)) {
                     self.connectNetwork(completion: { (netConnected) in
                        if (netConnected) {
                           completion(true);
                        } else {
                           completion(false);
                        }
                     })
                  }
               }.continueOnErrorWith(continuation: { (error) in
                  completion(false);
               })
         }
      }
   }
}

// MARK: - Sensor Ordering and Naming
extension SensorNetwork {
   /// Reset the sensor configuration for all sensors in the network.
   ///
   /// - important: This method will enable button press handlers and flashing LEDs on all sensors. If the method is not completed, these will persist on the sensors and may drain the battery. The method must complete to allow sensors to return to a low power state.
   /// - returns: Escaping button press handler parameter is called when an individual sensor has been ordered. Escaping completion handler is called when all sensors in the network have been ordered.
   
   public func orderSensorsByButtonPress(buttonPressHandler: @escaping (_ sensorsOrdered: Int) -> Void, completion: @escaping (_ result: Bool) -> Void) {
      self.orderedSensors.removeAll();
      self.sensorButtonPressHandler = buttonPressHandler;
      self.orderCompletion = completion;
      for sensor in self.sensors {
         sensor.apiAccessQueue.async {
            sensor.flashLED(color: .blue, intensity: 1.0);
            let switchEvent = mbl_mw_switch_get_state_data_signal(sensor.board);
            mbl_mw_datasignal_read(switchEvent);
            
            //Callback function with context passed
            mbl_mw_datasignal_subscribe(switchEvent, bridge(obj: sensor)) { (context, data) in
               let sensor: MetaWear = bridge(ptr: context!);
               mbl_mw_datasignal_unsubscribe(mbl_mw_switch_get_state_data_signal(sensor.board));
               let val = (data?.pointee.value.assumingMemoryBound(to: Int.self));
               if let on = val?.pointee {
                  if (on == 1) {
                     SensorNetwork.shared.orderedSensors.append(sensor);
                     sensor.flashLED(color: .green, intensity: 1.0, _repeat: 1);
                     //mbl_mw_led_stop_and_clear(sensor.board);
                     let count =  SensorNetwork.shared.orderedSensors.count;
                     SensorNetwork.shared.sensorButtonPressHandler(count);
                     if (count == SensorNetwork.shared.numberOfSensors) {
                        SensorNetwork.shared.networkOrdered = true;
                        SensorNetwork.shared.sensors = SensorNetwork.shared.orderedSensors;
                        if (SensorNetwork.shared.hasDelegate) {
                           SensorNetwork.shared.appDelegate.hasOrderedSensors();
                        }
                        SensorNetwork.shared.orderCompletion(true);
                     }
                  }
               }
            }
         }
      }
   }
}

//MARK: - Streaming
extension SensorNetwork {
   
   public func disableQuaternionStreaming(completion: @escaping (_ success: Bool) -> Void = {_ in}) {
      var syncCheck = [Bool]();
      for (index,sensor) in sensors.enumerated() {
         sensor.stopStreamingQuaternion(sensorStreamBridge: sensorStreamBridges[index]).continueOnSuccessWith { _ in
               syncCheck.append(true)
               if (syncCheck.count == 4 && !syncCheck.contains(false)) {
                  completion(true);
               }
            }.continueOnErrorWith { (error) in
               syncCheck.append(false);
               if (syncCheck.count == 4 && syncCheck.contains(false)) {
                  completion(false);
               }
         };
      }
   }
   
   public func enableQuaternionStreaming(handler: @escaping (_ quaternions: [Quaternion]) -> Void, completion: @escaping (_ success:Bool) -> Void = {_ in}) {
      guard self.isOrdered == true else {
         print("Sensors have not been ordered");
         completion(false);
         return;
      }
      self.quatStreamSync.handler = handler;
      for (index,sensor) in sensors.enumerated() {
         self.sensorStreamBridges[index] = SensorStreamBridge(self.quatStreamSync, sensor, sensorIndex: index);
         sensor.configureSensorFusion().continueOnSuccessWithTask {_ in
            return sensor.getSensorFusionSignal(withPeriod: 35);
            }.continueOnSuccessWithTask { timer in
               self.sensorStreamBridges[index].quaternionTimeSignal = timer;
               return sensor.startStreamingQuaternion(timerSignal: timer, sensorDataBridge: self.sensorStreamBridges[index]);
            }.continueOnErrorWith{ error in
               print("error getting sensor fusion signal for sensor \(index)");
         }
      }
      completion(true);
   }
}

//MARK: - Logging
extension SensorNetwork {
   
   class DownloadHandle {
      var sensorIndex: Int!
      var quatBuffer = [MBLQuaternionData]();
      init(forIndex: Int) {
         sensorIndex = forIndex;
         quatBuffer = [MBLQuaternionData]();
      }
      init() {
         quatBuffer = [MBLQuaternionData]();
      };
      var progress: (_ progress: Float, _ sensor: Int) -> Void = {_,_ in};
      var completion: (_ sensorIndex: Int, _ log: [MBLQuaternionData], _ hasFailed: Bool) -> Void = {_,_,_ in};
   }
   
   public func downloadLoggedQuaternions(progressHandler: @escaping (_ progress: Float) -> Void = {_ in}, logReadyHandler: @escaping (_ sensorIndex: Int, _ log: [MBLQuaternionData], _ hasFailed: Bool) -> Void) {
      
      var progressSync = [Float](repeating: 0.0, count: self.numberOfSensors);
      let addProgress: (_ progress: Float, _ sensor: Int) -> Void = { (progress, sensorIndex) in
         progressSync[sensorIndex] = progress;
         progressHandler(progressSync.min()!);
      }
      
      for (index,sensor) in sensors.enumerated() {
         // Sensor is not connected, send failed
         if (!sensor.isConnectedAndSetup) {
            logReadyHandler(index, [], true);
            return;
         }
         
         // If sensor is connected but disconnects at any point during download, send failed
         sensor.connectAndSetup().continueWith { t in
            t.result?.continueWith { t in
               logReadyHandler(index, [], true);
               return;
            }
         }
         
         sensor.stopLogging();
         self.downloadHandles[index] = DownloadHandle(forIndex: index);
         self.downloadHandles[index].completion = logReadyHandler;
         self.downloadHandles[index].progress = addProgress;
         
         sensor.apiAccessQueue.async {
            let logger = mbl_mw_logger_lookup_id(sensor.board, self.loggerIDs[index]!)
            mbl_mw_logger_subscribe(logger, bridge(obj: self.downloadHandles[index])) { (context, data) in
               let handle: DownloadHandle = bridge(ptr: context!);
               handle.quatBuffer.append(MBLQuaternionData(quat: (data?.pointee.value.load(as: MblMwQuaternion.self))!, timestamp: (data?.pointee.timestamp)!))
            }
            
            // Setup the handlers for events during the download
            var handlers = MblMwLogDownloadHandler(context: bridge(obj: self.downloadHandles[index]), received_progress_update: { (context, entriesLeft, totalEntries) in
               let handle: DownloadHandle = bridge(ptr: context!);
               if (totalEntries > 0) {
                  if (entriesLeft == 0) {
                     handle.completion(handle.sensorIndex!, handle.quatBuffer, false);
                  }
                  handle.progress(1-(Float(entriesLeft)/Float(totalEntries)), handle.sensorIndex);
               } else {
                  handle.completion(handle.sensorIndex!, handle.quatBuffer, false);
               }
            }, received_unknown_entry: { (context, id, epoch, data, length) in
               print("hit unknown entry");
            }, received_unhandled_entry: { (context, data) in
               print("hit unhandled entry");
            });
            
            // Start the log download
            mbl_mw_logging_download(sensor.board, 255, &handlers)
         }
      }
   }
   
   /// Begin logging quaternions on all sensors in the network.
   ///
   /// - important: Starting logging is idempotent.
   /// - returns: Optional escaping completion handler returns a Bool value indicating if all sensors began logging successfully.
   public func startLoggingQuaternions(completion: @escaping (_ success: Bool) -> Void = {_ in}) {
      self.loggingCompletion = completion;
      var syncCheck = [Bool](repeatElement(false, count: self.numberOfSensors));
      
      for (index,sensor) in sensors.enumerated() {
         if (sensor.isConnectedAndSetup) {
            sensor.startLogging();
            syncCheck[index] = true;
            if (!syncCheck.contains(false)) {
               completion(true);
            }
         } else {
            completion(false);
            return;
         }
      }
   }
   
   /// Stop logging quaternions on all sensors in the network.
   ///
   /// - important: Stopping logging is idempotent.
   /// - returns: Optional escaping completion handler returns a Bool value indicating if all sensors stopped logging successfully.
   public func stopLoggingQuaternions(completion: @escaping (_ success: Bool) -> Void = {_ in}) {
      for sensor in sensors {
         sensor.stopLogging();
      }
      completion(true);
   }
}

// MARK: - Fallible Command Configuration
extension SensorNetwork {
   /// Perform a sensor network task multiple times to prevent failure.
   ///
   /// - important: There is a three second delay between task retries.
   /// - parameter numberOfTimes: The number of times to attempt the task before declaring failure.
   /// - parameter task: The task to be performed multiple times.
   /// - parameter success: Code block to be executed on success.
   /// - parameter success: Code block to be executed on failure.
   /// - returns: Escaping completion parameter will success or failure depending on completion of the task.
   public func performFallibleTask(numberOfTimes: Int, task: @escaping (_ success: @escaping () -> Void, _ failure: @escaping (Error) -> Void) -> Void, success: @escaping () -> Void, failure: @escaping (Error) -> Void) {
      task(success, { error in
         if numberOfTimes > 1 {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5) {
               self.performFallibleTask(numberOfTimes: numberOfTimes - 1, task: task,success: success,failure: failure);
            }
         } else {
            failure(error);
         }
      })
   }
}

// // MARK: - Testing Extension Methods
//extension SensorNetwork {
//   func simulateInstantDisconnectOfSensors(withIndices: [Int]) {
//      for index in 0..<withIndices.count {
//         sensors[index].simulateDisconnect();
//      }
//   }
//}

/**
 Sensor network delegate should be implemented by the application delegate to handle the events generated by the static sensor network object.
 */
public protocol SensorNetworkDelegate {
   /// Delegate method is called when the sensor network ordering has been completed.
   func hasOrderedSensors();
   
   //
   func hasResetConfigurations();
   /// Delegate method is called when the sensor network has successfully connected to all sensors in the network.
   ///
   /// - important: Note that this method is also called when sensors have successfully reconnected once a disconnect was detected and recovered.
   func hasConnectedSensors();
   
   /// Delegate method is called when the network has successfully disconnected from all sensors.
   func hasDisconnectedSensors();
   
   /// Delegate method is called when the network has detected a communication failure in one or more of the sensors in the network.
   func hasLostConnection();
   
   /// Delegate method is called when the network has enountered an error that must be displayed to the user.
   func hasEncounteredError(error: SensorNetworkError);
   
   func hasInitiatedConnectingSequence();
}

public class SensorNetworkError: Error {
   public let description: String!
   public let timestamp: Date!
   init(_ description: String) {
      self.description = description;
      self.timestamp = Date();
   }
}

extension MetaWear {
   func configureSensorFusion() -> Task<()> {
      // Return error if the device is not connected and setup
      guard isConnectedAndSetup else {
         return Task<()>.init(error: MetaWearError.operationFailed(message: "Device was not connected when trying to configure sensor fusion."));
      }
      
      let completionSource = TaskCompletionSource<()>();
      self.apiAccessQueue.async {
         mbl_mw_logging_stop(self.board);
         mbl_mw_metawearboard_tear_down(self.board);
         mbl_mw_logging_clear_entries(self.board);
         mbl_mw_macro_erase_all(self.board);
         mbl_mw_settings_set_connection_parameters(self.board, 7.5, 7.5, 0, 6000);
         mbl_mw_sensor_fusion_set_acc_range(self.board, MBL_MW_SENSOR_FUSION_ACC_RANGE_4G);
         mbl_mw_sensor_fusion_set_gyro_range(self.board, MBL_MW_SENSOR_FUSION_GYRO_RANGE_1000DPS);
         mbl_mw_sensor_fusion_set_mode(self.board, MBL_MW_SENSOR_FUSION_MODE_NDOF);//MBL_MW_SENSOR_FUSION_MODE_IMU_PLUS);
         mbl_mw_sensor_fusion_write_config(self.board);
         mbl_mw_sensor_fusion_enable_data(self.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION);
         completionSource.trySet(result: ());
      }
      return completionSource.task;
   }
   
   
   
   func getSensorFusionSignal(withPeriod: UInt32) -> Task<OpaquePointer> {
      // Check to ensure the sensor has a valid sensor fusion module
      guard mbl_mw_metawearboard_lookup_module(board, MBL_MW_MODULE_SENSOR_FUSION) != MBL_MW_MODULE_TYPE_NA else {
         return Task<OpaquePointer>(error: MetaWearError.operationFailed(message: "No sensor fusion module."))
      }
      
      // Create the filtered timer signal from the raw sensor fusion signal
      let completionTask = TaskCompletionSource<OpaquePointer>();
      self.apiAccessQueue.async {
         let sensorFusionSignal = mbl_mw_sensor_fusion_get_data_signal(self.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION)!
         mbl_mw_dataprocessor_time_create(sensorFusionSignal, MBL_MW_TIME_ABSOLUTE, withPeriod, bridgeRetained(obj: completionTask)) { (context, dataPtr) in
            let _completionTask: TaskCompletionSource<OpaquePointer> = bridgeTransfer(ptr: context!);
            
            guard let dataPtr = dataPtr else {
               _completionTask.trySet(error: MetaWearError.operationFailed(message: "No data pointer"))
               return;
            }
            
            _completionTask.trySet(result: dataPtr);
         }
      }
      
      return completionTask.task;
   }
   
   func startStreamingQuaternion(timerSignal: OpaquePointer, sensorDataBridge: SensorStreamBridge) -> Task<()> {
      guard isConnectedAndSetup else {
         return Task<()>.init(error: MetaWearError.operationFailed(message: "device not connected"))
      }
      let completionSource = TaskCompletionSource<()>()
      sensorDataBridge.completionSource = completionSource
      self.apiAccessQueue.async {
         mbl_mw_datasignal_subscribe(sensorDataBridge.quaternionTimeSignal, bridge(obj: sensorDataBridge)) { (context, dataPtr) in
            let _sensorStreamBridge: SensorStreamBridge = bridge(ptr: context!)
            guard let dataPtr = dataPtr else {
               if !(_sensorStreamBridge.completionSource?.task.completed ?? false) {
                  _sensorStreamBridge.completionSource?.trySet(error: MetaWearError.operationFailed(message: "could not subscribe to quaternion streaming"))
               }
               return
            }
            //return completed task only when first data has streamed
            if !(_sensorStreamBridge.completionSource?.task.completed ?? false) {
               _sensorStreamBridge.completionSource?.trySet(result: ())
            }
            let mblQuaternion = dataPtr.pointee.copy().valueAs() as MblMwQuaternion
            _sensorStreamBridge.metawearHandler?.quaternionData(quaternion: mblQuaternion, sensorIndex: _sensorStreamBridge.sensorIndex)
         }
         mbl_mw_sensor_fusion_enable_data(self.board, MBL_MW_SENSOR_FUSION_DATA_QUATERNION)
         mbl_mw_sensor_fusion_start(self.board)
      }
      return completionSource.task
   }
   
   func stopStreamingQuaternion(sensorStreamBridge: SensorStreamBridge) -> Task<()> {
      guard isConnectedAndSetup else {
         return Task<()>.init(error: MetaWearError.operationFailed(message: "device not connected"))
      }
      let source = TaskCompletionSource<()>()
      apiAccessQueue.async {
         mbl_mw_datasignal_unsubscribe(sensorStreamBridge.quaternionTimeSignal)
         mbl_mw_dataprocessor_remove(sensorStreamBridge.quaternionTimeSignal)
         sensorStreamBridge.quaternionTimeSignal = nil
         mbl_mw_sensor_fusion_stop(self.board)
         mbl_mw_sensor_fusion_clear_enabled_mask(self.board)
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            source.trySet(result: ())
         }
      }
      return source.task
   }
   
   func startLogging() {
      self.apiAccessQueue.async {
         mbl_mw_sensor_fusion_start(self.board);
         mbl_mw_logging_start(self.board, 1);
         self.flashLED(color: .green, intensity: 0.5);
      }
   }
   
   func stopLogging() {
      self.apiAccessQueue.async {
         mbl_mw_logging_stop(self.board);
         mbl_mw_sensor_fusion_stop(self.board);
         mbl_mw_led_stop(self.board);
      }
   }
}

public class MBLQuaternionData {
   var timestamp: Date!
   var w: Float!
   var x: Float!
   var y:Float!
   var z:Float!
   
   init(quat: MblMwQuaternion, timestamp: Date) {
      self.timestamp = timestamp;
      self.w = quat.w;
      self.x = quat.x;
      self.y = quat.y;
      self.z = quat.z;
   }
   
}

class SensorStreamBridge {
   weak var metawearHandler: MetaWearDelegate?
   //var metawear: MetaWear!
   var sensorIndex: Int!
   var quaternionTimeSignal: OpaquePointer?
   var completionSource: TaskCompletionSource<()>?
   init() {}
   init (_ metawearHandler: MetaWearDelegate, _ metawear: MetaWear, sensorIndex: Int) {
      self.metawearHandler = metawearHandler
      //self.metawear = metawear
      self.sensorIndex = sensorIndex;
   }
}

protocol MetaWearDelegate: class {
   func quaternionData(quaternion: MblMwQuaternion, sensorIndex: Int)
}

class QuaternionStreamSynchronizer: MetaWearDelegate {
   var quats: [Quaternion]
   var syncCheck: [Bool]
   var handler: (([Quaternion]) -> Void)!
   
   init(sensorCount: Int) {
      self.syncCheck = [Bool](repeating: false, count: sensorCount);
      self.quats = [Quaternion](repeating: Quaternion(), count: sensorCount);
   }
   
   func quaternionData(quaternion: MblMwQuaternion, sensorIndex: Int) {
      quats[sensorIndex] = Quaternion(w: quaternion.w, x: quaternion.x, y: quaternion.y, z: quaternion.z);
      syncCheck[sensorIndex] = true;
      
      // All sensor values have been input
      if (!self.syncCheck.contains(false)) {
         // Call handler here
         handler(quats);
         
         // Reset sync array
         for ind in 0..<syncCheck.count {
            syncCheck[ind] = false;
         }
      }
   }
}


