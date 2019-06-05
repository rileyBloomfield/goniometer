//
//  DisplayViewController.swift
//  kneeFlexion
//
//  Created by Riley Bloomfield on 2017-05-04.
//  Copyright © 2017 Riley Bloomfield. All rights reserved.
//

import UIKit
import SceneKit

/**
 Main display of application used to show the user the flexion angle of the instrumented knee.
 */
class DisplayViewController: UIViewController {
   /// Button used to set the zero orientation of both sensors simultaneously
   @IBOutlet weak var tareButton: UIButton!
   
   /// Numerical display showing the live angle of both sensors relative to each other
   @IBOutlet weak var angleDisplay: UILabel! //Flexion
   @IBOutlet weak var secondAngleDisplay: UILabel! //Rotation
   @IBOutlet weak var thirdAngleDisplay: UILabel! //Varus
   
   //private var sensorNetwork = SensorNetwork.shared;
   private var firstSensorTare = Quaternion();
   private var secondSensorTare = Quaternion();
   private var firstLatestReading: Quaternion!
   private var secondLatestReading: Quaternion!
   
   var flexOffset:Float = 0;
   var rotOffset:Float = 0;
   var varOffset:Float = 0;
   var flexOffsetLatest:Float = 0;
   var rotOffsetLatest:Float = 0;
   var varOffsetLatest:Float = 0;
   
   /// Method executed when the main display is loaded.
   ///
   /// - important: Quaternion streaming is enabled in this method and notifications are started.
   /// ###Tared adjustment###
   /// When the tare button is pressed, the quaternion rotation of each sensor is stored independently. Every subsequent quaternion reading is rotated by the inverse of the tare, to bring the rotation relative to the tared position.
   override func viewDidLoad() {
      super.viewDidLoad();
      enableStreaming();
   }
   
   func enableStreaming() {
      SensorNetwork.shared.enableQuaternionStreaming (handler: { (quaternions) in
         self.firstLatestReading = quaternions[0];
         self.secondLatestReading = quaternions[1];
         let lowerSensorQuat = quaternions[0]; //Quaternion.quatMultiply(q: quaternions[0], r: self.firstSensorTare);
         let anatomicalAngles = Quaternion.extractAnatomicalAngles(lowerSensorQuat: lowerSensorQuat, upperSensorQuat: quaternions[1]);

         self.flexOffsetLatest = anatomicalAngles[0];
         self.rotOffsetLatest = anatomicalAngles[1];
         self.varOffsetLatest = anatomicalAngles[2];
         
         DispatchQueue.main.async {
            self.angleDisplay.text = String(Int(roundf(-anatomicalAngles[0]-self.flexOffset)));
            self.secondAngleDisplay.text = String(Int(roundf(anatomicalAngles[1]-self.rotOffset)));
            self.thirdAngleDisplay.text = String(Int(roundf(anatomicalAngles[2]-self.varOffset)));
         }
         
      }, completion: { (didComplete) in
         if (didComplete) {
            print("streaming started");
         } else {
            print("could not start streaming");
         }
      });
   }
   
   public func extractAnatomicalAngles(lowerSensorQuat: Quaternion, upperSensorQuat: Quaternion) -> [Float] {
      let minimalRotationQuat = Quaternion.quatMultiply(q: lowerSensorQuat.conjugate(), r: upperSensorQuat).negate();
      
      // Determine flexion about the y-axis of the upper sensor with respect to the lower sensor frame  (as if no other rotation occured in the x,z axes)
      var yFlexionQuat = Quaternion(minimalRotationQuat);
      yFlexionQuat.x = 0;
      yFlexionQuat.z = 0;
      yFlexionQuat = yFlexionQuat.normalize();
      let magnitudeFlexionAngle = 2*acosf(yFlexionQuat.w)*(180/Float.pi);
      let flexionAngle = (yFlexionQuat.y < 0) ? -1.0*magnitudeFlexionAngle : magnitudeFlexionAngle;
      //GOOD TO HERE
      
      // Rotate the lower sensor reference frame about the y-axis of the upper sensor to align with the upper sensor frame (as if no x,z rotation occured)
      let flexedLowerReferenceFrame = Quaternion.quatMultiply(q: lowerSensorQuat, r: yFlexionQuat); // local rotation of yFlexionQuat applied to lowerSensorQuat
      
      // Determine the rotation about the x-axis of the upper sensor frame with respect to the lower sensor (as if no rotation occured in the y,z axes)
      var xRotationQuat = Quaternion.quatMultiply(q: flexedLowerReferenceFrame.conjugate(), r: upperSensorQuat).negate();
      xRotationQuat.y = 0;
      xRotationQuat.z = 0;
      xRotationQuat = xRotationQuat.normalize();
      let magnitudeRotationAngle = 2*acosf(xRotationQuat.w)*(180/Float.pi);
      let rotationAngle = (xRotationQuat.x < 0) ? -1.0*magnitudeRotationAngle : magnitudeRotationAngle;
      
      // Determine the varus/valgus rotation about the z axis of the upper sensor frame with respect to the lower sensor reference frame (as if no x,y rotation occured)
      var zVarusQuat = Quaternion.quatMultiply(q: flexedLowerReferenceFrame.conjugate(), r: upperSensorQuat).negate();
      zVarusQuat.x = 0;
      zVarusQuat.y = 0;
      zVarusQuat = zVarusQuat.normalize();
      let magnitudeVarusAngle = 2*acosf(zVarusQuat.w)*(180/Float.pi);
      let varusAngle = (zVarusQuat.z < 0) ? -1.0*magnitudeVarusAngle : magnitudeVarusAngle;
      return [flexionAngle, rotationAngle, varusAngle];
   }
   
   public func extractAnatomicalAnglesLateral(lowerSensorQuat: Quaternion, upperSensorQuat: Quaternion) -> [Float] {
      let minimalRotationQuat = Quaternion.quatMultiply(q: lowerSensorQuat.conjugate(), r: upperSensorQuat).negate();
      
      // Determine flexion about the y-axis of the upper sensor with respect to the lower sensor frame  (as if no other rotation occured in the x,z axes)
      var zFlexionQuat = Quaternion(minimalRotationQuat);
      zFlexionQuat.y = 0;
      zFlexionQuat.x = 0;
      zFlexionQuat = zFlexionQuat.normalize();
      let magnitudeFlexionAngle = 2*acosf(zFlexionQuat.w)*(180/Float.pi);
      let flexionAngle = (zFlexionQuat.z < 0) ? -1.0*magnitudeFlexionAngle : magnitudeFlexionAngle;
      //GOOD TO HERE
      
      // Rotate the lower sensor reference frame about the y-axis of the upper sensor to align with the upper sensor frame (as if no x,z rotation occured)
      let flexedLowerReferenceFrame = Quaternion.quatMultiply(q: lowerSensorQuat, r: zFlexionQuat); // local rotation of yFlexionQuat applied to lowerSensorQuat
      
      // Determine the rotation about the x-axis of the upper sensor frame with respect to the lower sensor (as if no rotation occured in the y,z axes)
      var xRotationQuat = Quaternion.quatMultiply(q: flexedLowerReferenceFrame.conjugate(), r: upperSensorQuat).negate();
      xRotationQuat.y = 0;
      xRotationQuat.z = 0;
      xRotationQuat = xRotationQuat.normalize();
      let magnitudeRotationAngle = 2*acosf(xRotationQuat.w)*(180/Float.pi);
      let rotationAngle = (xRotationQuat.x < 0) ? -1.0*magnitudeRotationAngle : magnitudeRotationAngle;
      
      // Determine the varus/valgus rotation about the z axis of the upper sensor frame with respect to the lower sensor reference frame (as if no x,y rotation occured)
      var yVarusQuat = Quaternion.quatMultiply(q: flexedLowerReferenceFrame.conjugate(), r: upperSensorQuat).negate();
      yVarusQuat.x = 0;
      yVarusQuat.z = 0;
      yVarusQuat = yVarusQuat.normalize();
      let magnitudeVarusAngle = 2*acosf(yVarusQuat.w)*(180/Float.pi);
      let varusAngle = (yVarusQuat.y < 0) ? -1.0*magnitudeVarusAngle : magnitudeVarusAngle;
      return [flexionAngle, rotationAngle, varusAngle];
   }
   
   /// Method executed when the main display comes to view.
   override func viewWillAppear(_ animated: Bool) {
      self.navigationController?.navigationBar.isHidden = false;
   }
   
   /// Method executed when the main disappears.
   ///
   /// - important: The sensor network is disconnected, which stops all streaming.
   override func viewWillDisappear(_ animated: Bool) {
      SensorNetwork.shared.disconnectSensors();
   }
   
   /// Pressing the tare button assigns the current orientation of each sensor to the zeroed tare position
   @IBAction func tareButtonPressed(_ sender: Any) {
      self.flexOffset = self.flexOffsetLatest;
      self.rotOffset = self.rotOffsetLatest;
      self.varOffset = self.varOffsetLatest;
   }
}
