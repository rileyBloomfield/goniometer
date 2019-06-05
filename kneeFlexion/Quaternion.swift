//
//  Quaternion.swift
//  mobileApp
//
//  Created by Riley Bloomfield on 2017-01-19.
//  Copyright © 2017 Riley Bloomfield. All rights reserved.
//

import Foundation

/**
 Quaternion object containing vector elements [w,x,y,z] where w is a scalar value and x,y,z are vector components.
 
 ##Description##
 ###Axis Angle Relation###
 If [°x,°y,°z] represents an axis in 3-space and °a is the rotation about this axis, the quaternion representation components are as follows:
 - w = cos(°a/2)
 - x = °x * sin(°a/2)
 - y = °y * sin(°a/2)
 - z = °z * sin(°a/2)
 */
public class Quaternion: CustomStringConvertible {
   ///Scaler component
   public var w: Float
   ///X-axis component
   public var x: Float
   ///Y-axis component
   public var y: Float
   ///Z-axis component
   public var z: Float
   
   /// Initializes a zeroed unit quaterion.
   ///
   /// - returns: A quaternion with values [1.0, 0.0, 0.0, 0.0]
   public init() {
      self.w = 1.0;
      self.x = 0.0;
      self.y = 0.0;
      self.z = 0.0;
   }
   
   /// Initializes a quaterion with supplied components.
   ///
   /// - parameter w: Scalar component float value.
   /// - parameter x: X-axis component float value.
   /// - parameter y: Y-axis component float value.
   /// - parameter z: Z-axis component float value.
   /// - returns: A quaternion with components as supplied.
   public init(w:Float, x:Float, y:Float, z:Float) {
      self.w = w;
      self.x = x;
      self.y = y;
      self.z = z;
   }
   
   /// Copy constructor creating a new quaternion identical to the one supplied.
   ///
   /// - parameter q: An existing quaternion to copy.
   /// - returns: A quaternion with components equal to the components of q.
   public init(_ q: Quaternion) {
      self.w = q.w;
      self.x = q.x;
      self.y = q.y;
      self.z = q.z;
   }
   
   /// String representation of quaternion.
   ///
   /// - returns: Components of the form [w,x,y,z] concatenated as comma separated values. Float values are truncated to three decimal places.
   public var description: String {
      return String(format: "%.3f", self.w)+","+String(format: "%.3f", self.x)+","+String(format: "%.3f", self.y)+","+String(format: "%.3f", self.z);
   }
   
   /// Float array representation of quaternion.
   ///
   /// - returns: A four component float array of the form [w,x,y,z].
   public var asFloatArray: [Float] {
      return [Float(w), Float(x), Float(y), Float(z)]
   }
   
   /// Negation of quaternion.
   ///
   /// - returns: An equivalent quaternion with a positive scalar component.
   public func negate() -> Quaternion {
      let mul:Float = (w < 0.0) ? -1.0 : 1.0;
      return Quaternion(w: w * mul, x: x * mul, y: y * mul, z: z * mul);
   }
   
   /// Inverse of quaternion.
   ///
   /// - important: The inverse of a unit quaternion is equivalent to its conjugate. The conjugation should be used because it is more efficient to compute for unit quaternions.
   /// - returns: The quaternion inverse.
   public func inverse() -> Quaternion {
      let den:Float = self.w*self.w + self.x*self.x + self.y*self.y + self.z*self.z;
      return Quaternion(w: self.w/den, x: -self.x/den, y: -self.y/den, z: -self.z/den)
   }
   
   /// Conjugation of quaternion.
   ///
   /// - important: The conjugate of a unit quaternion is equivalent to its inverse. The conjugation should be used because it is more efficient to compute for unit quaternions.
   /// - returns: The quaternion conjugate.
   public  func conjugate() -> Quaternion {
      return Quaternion(w:self.w, x:-self.x, y:-self.y, z:-self.z);
   }
   
   /// Normalization of quaternion.
   ///
   /// - returns: A normalized unit quaternion.
   public func normalize() -> Quaternion {
      let mag:Float = sqrt(self.w*self.w + self.x*self.x + self.y*self.y + self.z*self.z);
      return Quaternion(w: self.w/mag, x: self.x/mag, y: self.y/mag, z: self.z/mag);
   }
   
   public static func extractAnatomicalAngles(lowerSensorQuat: Quaternion, upperSensorQuat: Quaternion) -> [Float] {
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
   
   //   public static func extractAnatomicalAnglesCorrected(lowerSensorQuat: Quaternion, upperSensorQuat: Quaternion) -> [Float] {
   //      let minimalRotationQuat = Quaternion.quatMultiply(q: lowerSensorQuat.negate().conjugate(), r: upperSensorQuat.negate()).negate();
   //
   //      // Determine flexion about the y-axis of the upper sensor with respect to the lower sensor frame  (as if no other rotation occured in the x,z axes)
   //      var yFlexionQuat = Quaternion(minimalRotationQuat);
   //      yFlexionQuat.x = 0;
   //      yFlexionQuat.z = 0;
   //      yFlexionQuat = yFlexionQuat.normalize();
   //      let magnitudeFlexionAngle = 2*acosf(yFlexionQuat.w)*(180/Float.pi);
   //      let flexionAngle = (yFlexionQuat.y < 0) ? -1.0*magnitudeFlexionAngle : magnitudeFlexionAngle;
   //      //GOOD TO HERE
   //
   //      // Rotate the lower sensor reference frame about the y-axis of the upper sensor to align with the upper sensor frame (as if no x,z rotation occured)
   //      let flexedLowerReferenceFrame = Quaternion.quatMultiply(q: lowerSensorQuat, r: yFlexionQuat); // local rotation of yFlexionQuat applied to lowerSensorQuat
   //
   //      // Determine the rotation about the x-axis of the upper sensor frame with respect to the lower sensor (as if no rotation occured in the y,z axes)
   //      var xRotationQuat = Quaternion.quatMultiply(q: flexedLowerReferenceFrame.conjugate(), r: upperSensorQuat).negate();
   //      xRotationQuat.y = 0;
   //      xRotationQuat.z = 0;
   //      xRotationQuat = xRotationQuat.normalize();
   //      let magnitudeRotationAngle = 2*acosf(xRotationQuat.w)*(180/Float.pi);
   //      let rotationAngle = (xRotationQuat.x < 0) ? -1.0*magnitudeRotationAngle : magnitudeRotationAngle;
   //
   //      // Determine the varus/valgus rotation about the z axis of the upper sensor frame with respect to the lower sensor reference frame (as if no x,y rotation occured)
   //      var zVarusQuat = Quaternion.quatMultiply(q: flexedLowerReferenceFrame.conjugate(), r: upperSensorQuat).negate();
   //      zVarusQuat.x = 0;
   //      zVarusQuat.y = 0;
   //      zVarusQuat = zVarusQuat.normalize();
   //      let magnitudeVarusAngle = 2*acosf(zVarusQuat.w)*(180/Float.pi);
   //      let varusAngle = (zVarusQuat.z < 0) ? -1.0*magnitudeVarusAngle : magnitudeVarusAngle;
   //      return [flexionAngle, rotationAngle, varusAngle];
   //   }
   
   /// Multiplication of two quaternion rotations.
   ///
   /// - important: Quaternion multiplication is noncummutative, the order matters! q * r defines the composition of rotation r applied to q.
   /// - parameter q: First quaternion in multiplication order.
   /// - parameter r: Second quaternion in multiplication order.
   /// - returns: Quaternion resulting from multiplying the two rotations.
   public static func quatMultiply(q: Quaternion, r: Quaternion) -> Quaternion {
      return Quaternion(w:(r.w*q.w - r.x*q.x - r.y*q.y - r.z*q.z),
                        x:(r.w*q.x + r.x*q.w - r.y*q.z + r.z*q.y),
                        y:(r.w*q.y + r.x*q.z + r.y*q.w - r.z*q.x),
                        z:(r.w*q.z - r.x*q.y + r.y*q.x + r.z*q.w));
   }
   
   /// Rotation between two quaternions about the x-axis of the relative quaternion.
   ///
   /// - parameter rotation: Quaternion that determines the amount of rotation.
   /// - parameter withRespectTo: The reference position the rotation will be with respect to.
   /// - returns: Rotation angle about axis in degrees.
   public static func angleAboutXAxis(rotation: Quaternion, withRespectTo: Quaternion) -> Float {
      var diffQuat = quatMultiply(q: withRespectTo.conjugate(), r: rotation).negate();
      diffQuat.y = 0;
      diffQuat.z = 0;
      diffQuat = diffQuat.normalize();
      let angle:Float = (2*acos(diffQuat.w)) * (180.0 / .pi);
      return (angle > 180) ? 360-angle : angle;
   }
   
   /// Rotation between two quaternions about the y-axis of the relative quaternion.
   ///
   /// - parameter rotation: Quaternion that determines the amount of rotation.
   /// - parameter withRespectTo: The reference position the rotation will be with respect to.
   /// - returns: Rotation angle about axis in degrees.
   public static func angleAboutYAxis(rotation: Quaternion, withRespectTo: Quaternion) -> Float {
      var diffQuat = quatMultiply(q: withRespectTo.conjugate(), r: rotation).negate();
      diffQuat.x = 0;
      diffQuat.z = 0;
      diffQuat = diffQuat.normalize();
      let angle:Float = (2*acos(diffQuat.w)) * (180.0 / .pi);
      return (angle > 180) ? 360-angle : angle;
      
   }
   
   /// Rotation between two quaternions about the z-axis of the relative quaternion.
   ///
   /// - parameter rotation: Quaternion that determines the amount of rotation.
   /// - parameter withRespectTo: The reference position the rotation will be with respect to.
   /// - returns: Rotation angle about axis in degrees.
   public static func angleAboutZAxis(rotation: Quaternion, withRespectTo: Quaternion, polarity:Bool = false) -> Float {
      let diffQuat = quatMultiply(q: withRespectTo.conjugate(), r: rotation).negate();
      diffQuat.x = 0;
      diffQuat.y = 0;
      var angle:Float = (2*acos(diffQuat.normalize().w)) * (180.0 / .pi);
      if (polarity) { angle =  2*asin(diffQuat.normalize().z) * (180.0 / .pi); }
      return (angle > 180) ? 360-angle : angle;
   }
   
   public static func tare(rotation: Quaternion, tare: Quaternion) -> Quaternion {
      let quat = quatMultiply(q: tare.conjugate(), r: rotation);
      return quat;
   }
   
   public static func flexAngle(_ q: Quaternion) -> Float {
      return -atanf((2*q.w*q.z + 2*q.x*q.y)/(2*q.y*q.y + 2*q.z*q.z - 1))*(180.0 / .pi);
   }
   
   public static func rotAngle(_ q: Quaternion) -> Float {
      return -atanf((2*q.w*q.x - 2*q.y*q.z)/(2*q.x*q.x + 2*q.z*q.z - 1))*(180.0 / .pi);
   }
   
   public static func varAngle(_ q: Quaternion) -> Float {
      return Float.pi - asinf(2*q.w*q.z + 2*q.x*q.y)*(180.0 / .pi);
   }
   
}
