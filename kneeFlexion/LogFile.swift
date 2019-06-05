//
//  LogFile.swift
//
//
//  Created by Riley Bloomfield on 2017-09-12.
//  Copyright © 2018 Riley Bloomfield. All rights reserved.
//

import Foundation

/**
 Type of log file test recorded (TUG from the iPod application).
 */
public enum TestType:String, CaseIterable {
   case missing = "Not Specified"
   case tug = "TUG"
}

public enum Armrest:String, CaseIterable {
   case missing = "Not Specified"
   case none = "None"
   case toStand = "Used to Stand"
   case toSit = "Used to Sit"
   case both = "Used for Sitting and Standing"
}

public enum Timepoint:String, CaseIterable {
   case missing = "Not Specified"
   case preOp = "Pre-Op"
   case oneWeek = "1 Week"
   case twoWeek = "2 Week"
   case threeWeek = "3 Week"
   case oneMonth = "1 Month"
   case sixWeek = "6 Week"
   case threeMonth = "3 Month"
   case fourMonth = "4 Month"
   case fiveMonth = "5 Month"
   case sixMonth = "6 Month"
   case oneYear = "1 Year"
   case eighteenMonth = "18 Month"
   case twoYear = "2 Year"
}

public enum ReplacementType:String, CaseIterable {
   case missing = "Not Specified"
   case hip = "Hip"
   case knee = "Knee"
}

public enum surgicalApproach:String, CaseIterable {
   case missing = "Not Specified"
   case gapBalance = "Knee, Gap Balancing"
   case measuredResection = "Knee, Measured Resection"
   case directLateral = "Hip, Direct Lateral"
   case directAnterior = "Hip, Direct Anterior"
}

public enum OperativeSide:String, CaseIterable {
   case missing = "Not Specified"
   case left = "Left"
   case right = "Right"
}

public enum WalkingAid:String, CaseIterable {
   case missing = "Not Specified"
   case noAid = "No Aid"
   case leftCane = "Left Cane"
   case rightCane = "Right Cane"
   case crutches = "Crutches"
   case walker = "Walker"
   case rollator = "Rollator"
}

public class LogFile {
   public var timestamps = [Date]();
   public var quats = [[Quaternion]](repeatElement([Quaternion](), count: 4));
   private let dateFormatter = DateFormatter();
   public let isoFormatter = DateFormatter();
   private let header = "year,time,q0w,q0x,q0y,q0z,q1w,q1x,q1y,q1z,q2w,q2x,q2y,q2z,q3w,q3x,q3y,q3z\n"
   
   // Log file metadata
   public var creationDate:Date = Date.init(timeIntervalSinceReferenceDate: 0);
   public var subject: String = "UNKNOWN";
   public var user:String = "UNKNOWN";
   public var notes:String = "";
   public var testType:TestType = .tug;
   public var timepoint:Timepoint = .missing;
   public var replacementType:ReplacementType = .missing;
   public var operativeSide:OperativeSide = .missing;
   public var walkingAid:WalkingAid = .missing;
   public var armrest:Armrest = .missing;
   
   public var count: Int {
      var count:Int = Int(INT8_MAX);
      for quat in quats {
         if(quat.count < count) { count = quat.count; }
      }
      return min(timestamps.count, count);
   }
   
   
   /**
    Create a local copy of the log file before manipulating.
    
    @return Returns a local copy.
    */
   public var copy:LogFile {
      return LogFile(times: self.timestamps, quats: self.quats, notes: self.notes, timepoint: self.timepoint, replacementType: self.replacementType, operativeSide: self.operativeSide, walkingAid: self.walkingAid, testType: self.testType, user: self.user, creationDate: self.creationDate, subject: self.subject, armrest: self.armrest);
   }
   
   /**
    Create a JSON proper string with all file contents.
    
    @return Optionally returns the correct JSON string if all log file contents are correct.
    */
   public var toFileString: String? {
      isoFormatter.calendar = Calendar(identifier: .iso8601)
      isoFormatter.locale = Locale(identifier: "en_US_POSIX")
      isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
      isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX";
      
      let jsonFile: [String:String]  = [
         "creationDate": isoFormatter.string(from: self.creationDate),
         "subject": self.subject,
         "user": self.user,
         "data": self.description,
         "notes": self.notes,
         "testType": self.testType.rawValue,
         "timepoint": self.timepoint.rawValue,
         "replacementType": self.replacementType.rawValue,
         "operativeSide": self.operativeSide.rawValue,
         "walkingAid": self.walkingAid.rawValue,
         "armrest": self.armrest.rawValue
      ]
      do {
         let jsonData = try JSONSerialization.data(withJSONObject: jsonFile, options: []);
         return String(data: jsonData, encoding: .utf8);
      } catch {
         return nil;
      }
   }
   
   public var description: String {
      dateFormatter.dateFormat = "yyyy-MM-dd,hh:mm:ss.SSS,"
      var fileString = "";
      fileString += header;
      for (index,time) in timestamps.enumerated() {
         fileString.append(dateFormatter.string(from: time));
         for quat in quats {
            fileString.append(quat[index].description+",")
         }
         fileString.append("\n");
      }
      return fileString;
   }
   
   public init() {
      creationDate = Date();
   }
   
   public init(times: [Date], quats: [[Quaternion]]) {
      isoFormatter.dateFormat = "yyyy-MM-ddThh:mm:ss.SSS";
      self.timestamps = times;
      self.quats = quats;
      creationDate = Date();
   }
   
   public init(times: [Date], quats: [[Quaternion]], notes: String, timepoint: Timepoint, replacementType: ReplacementType, operativeSide: OperativeSide, walkingAid: WalkingAid, testType: TestType, user: String, creationDate: Date, subject: String, armrest: Armrest) {
      isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
      self.subject = subject;
      self.user = user;
      self.creationDate = creationDate;
      self.timestamps = times;
      self.quats = quats;
      self.notes = notes;
      self.timepoint = timepoint;
      self.replacementType = replacementType;
      self.operativeSide = operativeSide;
      self.walkingAid = walkingAid;
      self.testType = testType;
      self.armrest = armrest;
   }
   
   public init?(_ string: String) {
      isoFormatter.calendar = Calendar(identifier: .iso8601)
      isoFormatter.locale = Locale(identifier: "en_US_POSIX")
      isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)
      isoFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX";
      
      var dataString = string;
      var fileDict = [String: String]();
      if let data = string.data(using: .utf8) {
         do {
            fileDict = try JSONSerialization.jsonObject(with: data, options: []) as! [String: String];
            guard let dString = fileDict["data"],
               let cDate = fileDict["creationDate"],
               let sub = fileDict["subject"],
               let use = fileDict["user"],
               let note = fileDict["notes"],
               let opSide = fileDict["operativeSide"],
               let replaceT = fileDict["replacementType"],
               let testT = fileDict["testType"],
               let timeP = fileDict["timepoint"],
               let walk = fileDict["walkingAid"],
               let arm = fileDict["armrest"] else {
                  return nil;
            }
            
            guard let eValOpSide = OperativeSide(rawValue: opSide),
               let eValCreationDate = isoFormatter.date(from: cDate),
               let eValReplacementT = ReplacementType(rawValue: replaceT),
               let eValTestT = TestType(rawValue: testT),
               let eValTimeP = Timepoint(rawValue: timeP),
               let eValWalk = WalkingAid(rawValue: walk),
               let eValArm = Armrest(rawValue: arm)
               else {
                  return nil;
            }
            dataString = dString;
            self.subject = sub;
            self.user = use;
            self.notes = note;
            self.operativeSide = eValOpSide;
            self.creationDate = eValCreationDate;
            self.replacementType = eValReplacementT;
            self.testType = eValTestT;
            self.timepoint = eValTimeP;
            self.walkingAid = eValWalk;
            self.armrest = eValArm;
            
         } catch {
            
         }
      }
      dateFormatter.dateFormat = "yyyy-MM-ddhh:mm:ss.SSS"
      var fileLines = dataString.split(separator: "\n");
      fileLines.removeFirst();
      for line in fileLines {
         let lineContents = String(line).split(separator: ",");
         timestamps.append(dateFormatter.date(from: String(lineContents[0]+lineContents[1]))!)
         quats[0].append(Quaternion(w:Float(String(lineContents[2]))!, x:Float(String(lineContents[3]))!, y:Float(String(lineContents[4]))!, z:Float(String(lineContents[5]))!));
         quats[1].append(Quaternion(w:Float(String(lineContents[6]))!, x:Float(String(lineContents[7]))!, y:Float(String(lineContents[8]))!, z:Float(String(lineContents[9]))!));
         quats[2].append(Quaternion(w:Float(String(lineContents[10]))!, x:Float(String(lineContents[11]))!, y:Float(String(lineContents[12]))!, z:Float(String(lineContents[13]))!));
         quats[3].append(Quaternion(w:Float(String(lineContents[14]))!, x:Float(String(lineContents[15]))!, y:Float(String(lineContents[16]))!, z:Float(String(lineContents[17]))!));
      }
      if let firstDate = timestamps.first {
         self.creationDate = firstDate;
      }
   }
   
   public func append(times: [Date], quats: [[Quaternion]]) {
      self.timestamps.append(contentsOf: times);
      self.quats.append(contentsOf: quats);
   }
   
   public func append(logFile: LogFile) {
      self.timestamps.append(contentsOf: logFile.timestamps);
      self.quats.append(contentsOf: logFile.quats);
   }
   
   public func removeLeadingData(newStartIndex: Int) {
      if (newStartIndex < timestamps.count) {
         self.timestamps = Array(timestamps.dropFirst(newStartIndex));
         self.quats = [Array(quats[0].dropFirst(newStartIndex)),
                       Array(quats[1].dropFirst(newStartIndex)),
                       Array(quats[2].dropFirst(newStartIndex)),
                       Array(quats[3].dropFirst(newStartIndex))]
      }
   }
}
