//
//  BufferedLogSynchronizer.swift
//  activityMonitor
//
//  Created by Riley Bloomfield on 2017-05-18.
//  Copyright © 2017 Riley Bloomfield. All rights reserved.
//

import Foundation
import MetaWear

public class QuatLogSynchonizer {
   private var numSensors: Int!
   private var dataLogBuffer: [[MBLQuaternionData]]!
   private var logSyncChecklist: [Bool]!
   public var contents:String = "";
   
   // Set this to the stream frequency of the sensors
   private var streamingFrequency:Float = 25;
   
   // Percentage of delay between samples that will be tolerated.
   private var streamErrorTolerance:Float = 0.25;
   
   public init(numSensors: Int) {
      self.numSensors = numSensors;
      dataLogBuffer = [[MBLQuaternionData]](repeatElement([MBLQuaternionData](), count: numSensors));
      logSyncChecklist = [Bool](repeatElement(false, count: numSensors));
   }
   
   public func clearBuffer() {
      for var buffer in dataLogBuffer {
         buffer.removeAll();
      }
   }
   
   public func addDataToBuffer(sensorIndex: Int, dataArray: [MBLQuaternionData], completion: @escaping (_ didExport: Bool, _ file: LogFile?) -> Void) {
      if (sensorIndex < 0 || sensorIndex >= SensorNetwork.shared.sensorCount) {
         completion(false, nil);
         return;
      }
      self.dataLogBuffer[sensorIndex] = dataLogBuffer[sensorIndex] + dataArray;
      self.logSyncChecklist[sensorIndex] = true;
      if (!logSyncChecklist.contains(false)) {
         resetFileSyncCheck();
         synchronizeBuffer();
         completion(true, trimAndExportSynchronizedBuffer());
      } else {
         completion(false, nil);
      }
   }
   
   private func resetFileSyncCheck() {
      for index in 0..<logSyncChecklist.count {
         logSyncChecklist[index] = false;
      }
   }
   
   private func synchronizeBuffer() {
      var logFileSizes = [Int]();
      for array in dataLogBuffer {
         logFileSizes.append(array.count);
      }
      for pointIndex in 0..<logFileSizes.min()! {
         var latestFirstTime = Date(timeIntervalSince1970: 0);
         for logFile in dataLogBuffer {
            if (logFile.indices.contains(pointIndex)) {
               if (logFile[pointIndex].timestamp.timeIntervalSince(latestFirstTime) > TimeInterval(1.0/streamingFrequency+(1.0/streamingFrequency*streamErrorTolerance))) {
                  latestFirstTime = logFile[pointIndex].timestamp
               };
            } else {
               return;
            }
         }
         for logIndex in 0..<dataLogBuffer.count {
            while ((pointIndex < dataLogBuffer[logIndex].count) && latestFirstTime.timeIntervalSince(dataLogBuffer[logIndex][pointIndex].timestamp) > TimeInterval(1.0/streamingFrequency+(1.0/streamingFrequency*streamErrorTolerance))) {
               dataLogBuffer[logIndex].remove(at: pointIndex);
               logFileSizes[logIndex] = dataLogBuffer[logIndex].count;
            }
         }
      }
   }
   
   private func trimAndExportSynchronizedBuffer() -> LogFile? {
      var timestamps = [Date]();
      var quats = [[Quaternion]]();
      
      if var upperBoundSize = dataLogBuffer.first?.count {
         for array in dataLogBuffer {
            if (array.count) < upperBoundSize {
               upperBoundSize = array.count;
            }
         }
         
         for counter in 0..<upperBoundSize {
            timestamps.append((dataLogBuffer.first![counter].timestamp));
         }
         
         for bufferLogIndex in 0..<dataLogBuffer.count {
            quats.append([Quaternion]());
            let splicedArray = Array(dataLogBuffer[bufferLogIndex].prefix(upperBoundSize));
            dataLogBuffer[bufferLogIndex] = Array(dataLogBuffer[bufferLogIndex].dropFirst(upperBoundSize));
            for point in splicedArray {
               quats[bufferLogIndex].append(Quaternion(w: Float(point.w), x: Float(point.x), y: Float(point.y), z: Float(point.z)));
            }
         }
         
         if (timestamps.count > 0) {
            return LogFile(times: timestamps, quats: quats);
         }
      }
      return nil;
   }
}
