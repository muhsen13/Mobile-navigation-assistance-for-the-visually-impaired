import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graduation_project/implimentation/api_keys.dart';
import 'package:graduation_project/implimentation/directions_algorithm.dart';

import 'dart:math';

import 'package:graduation_project/implimentation/speech_to_text.dart';
import 'package:graduation_project/testcode/cubits/apitext_cubit.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

 enum Distancetype{
  meter,
  feet,
  steps
  }

class DeviceLocation {

  static List<dynamic> startPos = [];
  static List<dynamic> checkpointPos = [];
  static List<dynamic> coordinateCheck = [];
  static Position? lastCurrentPosition;
  static Distancetype distanceType = Distancetype.meter;
  static bool angleInClocks = false;


  
  static List<dynamic> debugLocation = [];//longitude,latitude
  static double debugAccuracy = 15;

  static final LocationSettings locationSettings = LocationSettings(
  accuracy: LocationAccuracy.high,
  distanceFilter: 0,
  );
  static StreamSubscription<Position>? positionStream;

  static void startPositionStream(){
    if(positionStream != null) cancelPositionStream();
    positionStream =  Geolocator.getPositionStream(locationSettings: locationSettings).listen(
    (Position? position) {
        print(position == null ? 'Unknown' : '${position.latitude.toString()}, ${position.longitude.toString()}, ${position.accuracy}');
        if(debugLocation.isNotEmpty && lastCurrentPosition!=null){//for manual location setting
          Position n = Position(longitude:debugLocation[0] , latitude: debugLocation[1], timestamp: lastCurrentPosition!.timestamp, accuracy: debugAccuracy, altitude: lastCurrentPosition!.altitude, altitudeAccuracy: lastCurrentPosition!.altitudeAccuracy, heading: lastCurrentPosition!.heading, headingAccuracy: lastCurrentPosition!.headingAccuracy, speed: lastCurrentPosition!.speed, speedAccuracy: lastCurrentPosition!.speedAccuracy);
          DirectionsAlgorithm.lastPlayerPosition = n;
          lastCurrentPosition = n;
          print("last player position was set to :${DirectionsAlgorithm.lastPlayerPosition} ");
          DirectionsAlgorithm.updateDots();
        }else{
        lastCurrentPosition = position;
        DirectionsAlgorithm.lastPlayerPosition = position;
        DirectionsAlgorithm.updateDots();
        }

    });
  }
  static void cancelPositionStream(){
    if(positionStream==null)return;
    positionStream!.cancel();
    positionStream = null;
  }

  static Future<bool> getPermission() async{
    
      bool serviceEnabled;
      LocationPermission permission;
    
      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
          print("location services disabled");
          return false;
      }

      // Check for location permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("location permissions denied");
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
          print("Location permission permanently denied");
          return false;
      }
      if(permission == LocationPermission.always || permission == LocationPermission.whileInUse){
        return true;
      }
      return false;

  }
  static Future<Position?> getCurrentLocation() async {

      bool serviceEnabled;
      LocationPermission permission;
    
      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are disabled, show a message or prompt to enable
          //   ScaffoldMessenger.of(context).showSnackBar(
          // SnackBar(content: Text('Location services are disabled.')),
          //   );
          print("location services disabled");
        return Future.error('Location services are disabled.');
      }

      // Check for location permissions
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, show a message
          print("location permissions denied");

          //             ScaffoldMessenger.of(context).showSnackBar(
          // SnackBar(content: Text('Location permissions are denied.')),
          //   );
          return Future.error('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied, show a message and guide to settings
        
          //             ScaffoldMessenger.of(context).showSnackBar(
          // SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
          //   );
          print("Location permission permanently denied");

        
        return Future.error('Location permissions are permanently denied, we cannot request permissions.');

      }

      // Permissions granted, get the current position
      lastCurrentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if(debugLocation.isNotEmpty && lastCurrentPosition!=null){//for manual location setting
      Position n = Position(longitude:debugLocation[0] , latitude: debugLocation[1], timestamp: lastCurrentPosition!.timestamp, accuracy: debugAccuracy, altitude: lastCurrentPosition!.altitude, altitudeAccuracy: lastCurrentPosition!.altitudeAccuracy, heading: lastCurrentPosition!.heading, headingAccuracy: lastCurrentPosition!.headingAccuracy, speed: lastCurrentPosition!.speed, speedAccuracy: lastCurrentPosition!.speedAccuracy);
      DirectionsAlgorithm.lastPlayerPosition = n;
      lastCurrentPosition = n;
      print("last player position was set to :${DirectionsAlgorithm.lastPlayerPosition} ");
      DirectionsAlgorithm.updateDots();
      return n;
      }
      return lastCurrentPosition;
    }


  //CONVERT ALL LATITUDE,LONGITUDE USES FROM DEGREES TO RADIANS

  
  static List<double> getVector(double lat1,double long1,double lat2,double long2){
    
    List<double> startPoint = 
      [cos(lat1)*cos(long1),
      cos(lat1) * sin(long1),
      sin(lat1)];

    List<double> point1 = 
      [cos(lat2)*cos(long2),
      cos(lat2) * sin(long2),
      sin(lat2)];

      List<double> vector = [point1[0]-startPoint[0],point1[1]-startPoint[1],point1[2]-startPoint[2]];
      return vector;
  }

//possitive = left
//negative = right
// a = came from, b = center , c = destination

 static double getBearing(double lat1, double lon1, double lat2,double lon2) {
    // Helper to convert degrees to radians
 //   const toRad = (deg) => (deg * Math.PI) / 180;
    // Helper to convert radians to degrees
  //  const toDeg = (rad) => (rad * 180) / Math.PI;

    double phi1 = (lat1 *pi) / 180;
    double phi2 = (lat2 * pi) / 180;

    double deltaLambda = ((lon2 - lon1) * pi) / 180;

    double y = sin(deltaLambda) * cos(phi2);
    double x = cos(phi1) * sin(phi2) -
              sin(phi1) * cos(phi2) * cos(deltaLambda);

    double bearing =  (atan2(y, x) * 180) / pi;
    
    // Normalize to 0-360 range
    return (bearing + 360) % 360; 
}

//possitive = left
//negative = right
// a = came from, b = center , c = destination
//try using this next time
 static double getTwoBearing(double a0,double a1,double b0,double b1, double c0,double c1){

  double bear1 = getBearing(b0,b1,a0,a1);
  double bear2 = getBearing(b0,b1,c0,c1);
  double pure = bear2-bear1;
  double angle3 = pure;

  if (pure > 180) {
      angle3 -= 360;
  } else if (pure < -180) {
      angle3 += 360;
  }
  double finalAngle = angle3;
  if(angle3 >= 0){
      finalAngle = 180-angle3;
  }else{
      finalAngle = -180-angle3;
  }
  return finalAngle;
}


  static double getVectorsAngle(double lat1,double long1,double lat2,double long2,double lat3,double long3){

      List<double> vector1 = getVector(lat1, long1, lat2, long2);
      List<double> vector2 = getVector(lat1, long1, lat3, long3);

      double vectorDotProduct = (vector1[0] * vector2[0]) + (vector1[1] * vector2[1]) + (vector1[2] * vector2[2]);
      double Vector1magnitude = sqrt(pow(vector1[0],2) + pow(vector1[1],2) + pow(vector1[2],2));
      double Vector2magnitude = sqrt(pow(vector2[0],2) + pow(vector2[1],2) + pow(vector2[2],2));

      double equal = vectorDotProduct/(Vector1magnitude*Vector2magnitude);
      double theta = acos(equal);
      double AcrossB = vector1[0]*vector2[1]-vector1[1]*vector2[0];
      double angle2 = (atan2(AcrossB ,vectorDotProduct) * 57.2958);
      angle2 = (180 - angle2.abs()) * (-1 * (-(angle2/angle2.abs())));
      print("first angle is ${theta * 57.2958} but the second angle is $angle2");
      

   // return (theta * 57.2958);
  return angle2;
  }
  static double getVectorsAngle2(List<double> vector1,List<double> vector2){

      if(vector1.length == 2){ vector1.add(0);}
      if(vector2.length == 2){ vector2.add(0);}
      vector1[2] = 0;
      vector2[2] = 0;
      double vectorDotProduct = (vector1[0] * vector2[0]) + (vector1[1] * vector2[1]) + (vector1[2] * vector2[2]);
      double Vector1magnitude = sqrt(pow(vector1[0],2) + pow(vector1[1],2) + pow(vector1[2],2));
      double Vector2magnitude = sqrt(pow(vector2[0],2) + pow(vector2[1],2) + pow(vector2[2],2));

      double equal = vectorDotProduct/(Vector1magnitude*Vector2magnitude);
      double theta = acos(equal);
      double AcrossB = vector1[0]*vector2[1]-vector1[1]*vector2[0];
      double angle2 = (atan2(AcrossB ,vectorDotProduct) * 57.2958);
      angle2 = (180 - angle2.abs()) * (-1 * (-(angle2/angle2.abs())));
      print("first angle is ${theta * 57.2958} but the second angle is $angle2");
   // return (theta * 57.2958);
  return theta * 57.2958;
  }
  static double getDistance(double lat1,double long1,double lat2,double long2){

    double deltaLat = (lat2-lat1) * (pi/180);    
    double deltaLon = (long2-long1) * (pi/180);   

    double firstpart = pow(sin(deltaLat/2),2).toDouble();
    double secondpart = cos(lat1 * 0.0174533)*cos(lat2 * 0.0174533)*(pow(sin(deltaLon/2), 2));
    double theta = pow(firstpart + secondpart, 0.5).toDouble(); 

    double distance = 2 * 6371 * asin(theta);
    return distance;
  }
  //dis is distance in meters
  static double getDistanceInFeet(double dis){
    return dis*3.28084;
  }
  static double getDistanceInSteps(double dis){
    return dis*1.31;
  }
  //opposite = right is negative
    static int getAngleInClock(double angle,bool opposite){


    //  print("getAngleInClock: angle is : $angle");
      if(opposite) angle = angle * -1;
      int answer = ((angle.abs() + 15)/30).floor();
    //  print("getAngleInClock: answer before editing is : $answer");
      if(angle <0 && answer != 0){
        answer = 12 - answer;
      }
   //   print("getAngleInClock: answer after editing is : $answer");

      
      return answer;
  }
  static Future<void> getLocationGeo (BuildContext context) async{


    String dist =  SpeechToText.text;
    if(dist=="") return ;
    
    print(dist.replaceAll(" ", "20%"));//ساحة%20التحرير
    String url = "https://api.openrouteservice.org/geocode/search?api_key=${ApiKeys.openRouteServiceKey}&text=${dist}&boundary.country=iq";
    print(url);
    Uri uri = Uri.parse(url);
    
    final response = await http.get(uri);
    final body = response.body;
    
    final json = jsonDecode(body);
    
      //         ScaffoldMessenger.of(context).showSnackBar(
      // SnackBar(content: Text("response is ${body}"))
      //   );
    final cords = json["features"][0]["geometry"]["coordinates"];
    if(context.mounted){
      context.read<ApitextCubit>().updateCordinates(cords[0],cords[1]);
      print("worked");
    }
    
  }
}