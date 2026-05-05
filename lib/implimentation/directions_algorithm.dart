import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:graduation_project/implimentation/api_keys.dart';
import 'package:graduation_project/implimentation/device_location.dart';
import 'package:graduation_project/implimentation/text_to_speech.dart';
import 'package:http/http.dart' as http;


class DirectionsAlgorithm {

  static AlgorithmProgress currentAlgorithmProgress = AlgorithmProgress.first;

  static double minAccuracy = 16;
  static double minDistanceBetweenPoints = 12;
  static double maxAngle = 25;
  static double maximumDistanceToEndpoint = 0.016;//in kilometers
  static int maxDotsCoordinates = 5;

  static double lastAngleCalculated = -400;
  static Position? lastPlayerPosition;
  static List<dynamic> dotsDirections = [];

  static String lastArabicResult = "";
  static bool isCompassIntstruction = false;
  static List cords = [];
  static List<dynamic> apiText =[];
  static List<dynamic> coordinates = [];
  static int currentApiTextIndex = -1;
  static List<dynamic> nextCoordinate = [];
  static List<dynamic> temporaryCoordinate = [];
  static int incorrectCoordinateFlag = -1;

  static List<dynamic> dotsCoordinates = [];

  static late void Function(String) snackbarFnc;
  static late void Function() updateDots;
  static double lastDistanceToDot = -1;

  static Map<String,String> compassTranslations = 
    {"north": "الشمال",
    "northeast": "الشمال الشرقي",
    "east":"الشرق",
    "southeast":"الجنوب الشرقي",
    "south":"الجنوب",
    "southwest":"الجنوب الغربي",
    "west":"الغرب",
    "northwest":"الشمال الغربي"};
  static Map<int,String> numberTranslations ={
    1:"الاول",
    2:"الثاني",
    3:"الثالث",
    4:"الرابع",
    5:"الخامس",
    6:"السادس",
    7:"السابع",
    8:"الثامن",
    9:"التاسع",
    10:"العاشر"};
      static Map<int,String> clockTranslations ={
    0:"الثانية عشر",
    1:"الواحدة",
    2:"الثانية",
    3:"الثالثة",
    4:"الرابعة",
    5:"الخامسة",
    6:"السادسة",
    7:"السابعة",
    8:"الثامنة",
    9:"التاسعة",
    10:"العاشرة",
    11:"الحادي عشر",
    12:"الثانية عشر",};
  static final arabicRegex = RegExp(r'[\u0600-\u06FF]');

  static late Timer firstAlgorithmTimer;
  static late Timer thirdAlgorithmTimer;
  static bool algorithmStarted = false;

  static void startTheAlgorithm(List coords,Function() f){
    algorithmStarted = true;
    cords = coords;
    updateDots = f;
    DeviceLocation.startPositionStream();
    startFirstAlgorithm();
  }

  static void startFirstAlgorithm() {
    currentAlgorithmProgress = AlgorithmProgress.first;
    const Duration interval = Duration(seconds: 2);
    firstAlgorithmTimer = Timer.periodic(interval, (Timer timer) {
      firstAlgorithmCheck();
    });
  }

  static void firstAlgorithmCheck() async {
      Position? p = lastPlayerPosition;
      if(p==null) return;
      print("current accuracy is : ${p.accuracy}");
      bool isAccurate = (p.accuracy) < minAccuracy;
      if (isAccurate) {
        firstAlgorithmTimer.cancel();
        secondAlgorithmCheck();
      }
  }
  static void secondAlgorithmCheck() async {
    currentAlgorithmProgress = AlgorithmProgress.second;
    await getLocation();
    if(nextCoordinate.isEmpty) {TextToSpeech.speak("فشلت عملية تحديد المسار"); algorithmStarted = false; return;}
    startThirdAlgorithm();
  }

  static void startThirdAlgorithm(){
    currentAlgorithmProgress = AlgorithmProgress.third;
    const Duration interval = Duration(seconds: 2);
    thirdAlgorithmTimer = Timer.periodic(interval, (Timer timer) {
      thirdAlgorithmCheck();
    });
  }

  static void thirdAlgorithmCheck() async {
    Position? p = lastPlayerPosition;
    if(p==null) return;

    int dotsLength = dotsCoordinates.length;
    if (dotsLength ==0) {dotsCoordinates.add([p.longitude,p.latitude]); return;}

    double distance = DeviceLocation.getDistance(p.latitude,p.longitude,dotsCoordinates[dotsLength-1][1],dotsCoordinates[dotsLength-1][0]);
    lastDistanceToDot = distance;
    if(distance*1000>= p.accuracy*1.6 && distance*1000>= minDistanceBetweenPoints) 
    {
      print("this is valid... adding a new dot");
      dotsCoordinates.add([p.longitude,p.latitude]);
      updateDots();

    //  if(dotsLength!=7){}
      if(dotsCoordinates.length==maxDotsCoordinates) //made the directions from 7 to 4... idk if I broke something.. 
      {
        dotsCoordinates.removeAt(0);
        updateDots();
      }
        if(dotsCoordinates.length > 1) fourthAlgorithmCheck();
      
    }
    fifthAlgorithmCheck();
    updateDots();
    
  }
  static void fourthAlgorithmCheck() {
    if(currentAlgorithmProgress==AlgorithmProgress.third) currentAlgorithmProgress = AlgorithmProgress.fourth;
    //get average direction of all dots
    dotsDirections.clear();
    for (var i = 0; i < dotsCoordinates.length-1; i++) {
      dotsDirections.add(DeviceLocation.getVector(dotsCoordinates[i][1], dotsCoordinates[i][0], dotsCoordinates[i+1][1],dotsCoordinates[i+1][0]));
    }
    List<double> averageDirection = getAverageDirection(dotsDirections);
    //get direction from average dots to end point 
    List<double> desiredDirection = getDesiredDirection();
    //get angle between these directions
    double angle = DeviceLocation.getVectorsAngle2(averageDirection,desiredDirection);
    print("vector angles two error angle is  $angle ");
    if(angle.abs() > maxAngle && dotsCoordinates.length > 2){
      //tell the user is walking wrong and correct him, aka sixth algorithm step
      startSixthAlgorithm();
      print("اليوزر يمشي بالاتجاه الخاطء");
    }else{
      incorrectCoordinateFlag = -1;
      //probably do nothing
    }
  }
  static void fifthAlgorithmCheck() async{
    Position? p = lastPlayerPosition;
    if(p==null) return;
    if (DeviceLocation.getDistance(p!.latitude,p!.longitude, nextCoordinate[1], nextCoordinate[0]) < maximumDistanceToEndpoint ) {

      if (temporaryCoordinate.isNotEmpty) {

        List<double> desiredDirection = DeviceLocation.getVector(nextCoordinate[1],nextCoordinate[0], temporaryCoordinate[1],temporaryCoordinate[0]);
        List<double> currentDirection = DeviceLocation.getVector(dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0], nextCoordinate[1],nextCoordinate[0]);
        
        //if distance between last checkpoint and the end goal is tooo small
        if( dotsCoordinates.length>1 &&DeviceLocation.getDistance(dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0], nextCoordinate[1], nextCoordinate[0]) < 0.002 ){
        currentDirection = DeviceLocation.getVector(dotsCoordinates[dotsCoordinates.length-2][1],dotsCoordinates[dotsCoordinates.length-2][0], nextCoordinate[1],nextCoordinate[0]);

        }
  //      double correctionAngle = DeviceLocation.getVectorsAngle2(currentDirection,desiredDirection);


        double correctionAngle = 0;
        if(dotsCoordinates.length > 1) {correctionAngle = DeviceLocation.getTwoBearing(dotsCoordinates[dotsCoordinates.length-2][1],dotsCoordinates[dotsCoordinates.length-2][0],dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0],temporaryCoordinate[1],temporaryCoordinate[0]);}
        else {correctionAngle = DeviceLocation.getTwoBearing(dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0],p.latitude,p.longitude,temporaryCoordinate[1],temporaryCoordinate[0]);}

        //select the temporary coordinate as the next coordinate with the coorection angle
        nextCoordinate.clear();
        nextCoordinate.add(temporaryCoordinate[0]);
        nextCoordinate.add(temporaryCoordinate[1]);
        temporaryCoordinate.clear();
        dotsCoordinates.clear();

        String dir = correctionAngle > 0 ? "يسارا" : "يمينا"; 
        double backDistance = DeviceLocation.getDistance(p!.latitude, p!.longitude, nextCoordinate[1], nextCoordinate[0]);
        String displayAngle = "استدر $dir وبزاوية ${correctionAngle.abs().toStringAsFixed(0)}";
        String displayDistance = "${(backDistance*1000).toStringAsFixed(0)} متر";
        if(DeviceLocation.distanceType == Distancetype.feet){
          displayDistance = "${DeviceLocation.getDistanceInFeet(backDistance*1000).toStringAsFixed(0)} قدم";
        }
        else if(DeviceLocation.distanceType == Distancetype.steps){
          displayDistance = "${DeviceLocation.getDistanceInSteps(backDistance*1000).toStringAsFixed(0)} خطوة";
        }
        if(DeviceLocation.angleInClocks){
          displayAngle = "استدر على الساعة ${clockTranslations[DeviceLocation.getAngleInClock(correctionAngle, false)]}";
        } 
        if(displayAngle=="0" || correctionAngle.abs() <15){
        TextToSpeech.speak("لقد رجعت للاتجاه الصحيح,تابع للامام ولمسافة $displayDistance");
        return;

        }
        TextToSpeech.speak("لقد رجعت للاتجاه الصحيح,$displayAngle ولمسافة $displayDistance");

        return;
        
      }


      //select the next point and display the instruction with the correction angle
    if(apiText.isEmpty) return;
    currentApiTextIndex++;
 //   if not api.length but distance to next one is very small
    while(currentApiTextIndex < apiText.length){
      double diss = DeviceLocation.getDistance(p!.latitude,p!.longitude, coordinates[apiText[currentApiTextIndex]["way_points"][1]][1], coordinates[apiText[currentApiTextIndex]["way_points"][1]][0]);
      if(diss < maximumDistanceToEndpoint){
        currentApiTextIndex++;
      }else{
        break;
      }
    }
    
    
    if(currentApiTextIndex == apiText.length){
      currentApiTextIndex--;print("reached the end step");
      //END ROUTE FUNCTION
      currentAlgorithmProgress = AlgorithmProgress.done;
      thirdAlgorithmTimer.cancel();
      algorithmStarted = false;
      dotsCoordinates.clear();
      await TextToSpeech.speak("لقد وصلت الى وجهتك");

      return;
    }
    nextCoordinate = coordinates[apiText[currentApiTextIndex]["way_points"][1]];
    DeviceLocation.startPos = coordinates[apiText[currentApiTextIndex]["way_points"][0]];
    DeviceLocation.checkpointPos = [DeviceLocation.startPos[0],DeviceLocation.startPos[1]];
    //speak
   // List<double> desiredDirection = DeviceLocation.getVector(dotsCoordinates[dotsCoordinates.length-1][1] ,dotsCoordinates[dotsCoordinates.length-1][0], nextCoordinate[1],nextCoordinate[0]);
  //  List<double> currentDirection = DeviceLocation.getVector(dotsCoordinates[dotsCoordinates.length-2][1] ,dotsCoordinates[dotsCoordinates.length-2][0], dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0]);
    //double correctionAngle = DeviceLocation.getVectorsAngle2(currentDirection,desiredDirection); //default one
    double correctionAngle = 0;
    if(dotsCoordinates.length > 1) {correctionAngle = DeviceLocation.getTwoBearing(dotsCoordinates[dotsCoordinates.length-2][1],dotsCoordinates[dotsCoordinates.length-2][0],dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0],nextCoordinate[1],nextCoordinate[0]);}
    else {correctionAngle = DeviceLocation.getTwoBearing(dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0],p!.latitude,p!.longitude,nextCoordinate[1],nextCoordinate[0]);}

      print(correctionAngle);
    String dir = correctionAngle > 0 ? "يسارا" : "يمينا"; 
    double backDistance = DeviceLocation.getDistance(p!.latitude, p!.longitude, nextCoordinate[1], nextCoordinate[0]);
    String displayAngle = "استدر $dir وبزاوية ${correctionAngle.abs().toStringAsFixed(0)}";
    String displayDistance = "${(backDistance*1000).toStringAsFixed(0)} متر";
    if(DeviceLocation.distanceType == Distancetype.feet){
      displayDistance = "${DeviceLocation.getDistanceInFeet(backDistance*1000).toStringAsFixed(0)} قدم";
    }
    else if(DeviceLocation.distanceType == Distancetype.steps){
        displayDistance = "${DeviceLocation.getDistanceInSteps(backDistance*1000).toStringAsFixed(0)} خطوة";
      }
    if(DeviceLocation.angleInClocks){
      displayAngle = "استدر على الساعة ${clockTranslations[DeviceLocation.getAngleInClock(correctionAngle, true)]}";
    } 
    if(displayAngle=="0" || correctionAngle.abs() <15){
      TextToSpeech.speak("جيد, الان تابع الى الامام و لمسافة $displayDistance");

    }else{
      TextToSpeech.speak("جيد, الان $displayAngle ولمسافة $displayDistance");    
    }
      
      dotsCoordinates.clear();
      currentAlgorithmProgress = AlgorithmProgress.third;

    }
  }
  static void startSixthAlgorithm(){
      Position? p = lastPlayerPosition;
      if(p==null) return;

    currentAlgorithmProgress = AlgorithmProgress.sixth;
    int flag = dotsDirections.length;
    for (var i = dotsDirections.length-1; i >= 0; i--) {
      double angle = DeviceLocation.getVectorsAngle2(dotsDirections[i],getDesiredDirection());
      if(angle.abs() < maxAngle){ break;}
      flag-=1;
    }
    incorrectCoordinateFlag = flag;
    if(flag>= 0 || dotsDirections.length <maxDotsCoordinates-2 ){
      temporaryCoordinate.clear();
      temporaryCoordinate.add(nextCoordinate[0]);
      temporaryCoordinate.add(nextCoordinate[1]);
      nextCoordinate.clear();
      if(flag <0) flag =0;
      nextCoordinate.add(dotsCoordinates[flag][0]);
      nextCoordinate.add(dotsCoordinates[flag][1]);
      

      //correct to next coordinate
      List<double> desiredReturnDirection = DeviceLocation.getVector(dotsCoordinates[dotsCoordinates.length-1][1],dotsCoordinates[dotsCoordinates.length-1][0], dotsCoordinates[flag][1],dotsCoordinates[flag][0]);
      double correctionAngle = DeviceLocation.getVectorsAngle2(getAverageDirection(dotsCoordinates),desiredReturnDirection);
      String dir = correctionAngle > 0 ? "يمينا" : "يسارا"; 
      double backDistance = DeviceLocation.getDistance(p!.latitude, p!.longitude, dotsCoordinates[flag][1], dotsCoordinates[flag][0]);
      String displayDistance = "${(backDistance*1000).toStringAsFixed(0)} متر";
      if(DeviceLocation.distanceType == Distancetype.feet){
        displayDistance = "${DeviceLocation.getDistanceInFeet(backDistance*1000).toStringAsFixed(0)} قدم";
      }
      else if(DeviceLocation.distanceType == Distancetype.steps){
        displayDistance = "${DeviceLocation.getDistanceInSteps(backDistance*1000).toStringAsFixed(0)} خطوة";
      }
     // TextToSpeech.speak("انت تسير بالاتجاه الخاطئ, استدر $dir وبزاوية ${correctionAngle.abs()}");
      TextToSpeech.speak("انت تسير بالاتجاه الخاطئ, عد الى الوراء ولمسافة $displayDistance");
      
      //stop the checking of walking in the wrong dir....
      dotsCoordinates.clear();
    }else{
      //walked the wrong direction without having any correct direction to begin with
      //in case of just started, say عد من اينما جئت and do the temporary coordinate stuff
      //in case of was walking and managed to have all 4 dirctions wrong then start again calculating... 
      TextToSpeech.speak("لقد سرت بالاتجاه الخاطئ, جاري اعادة حساب المسار");
      currentAlgorithmProgress = AlgorithmProgress.done;
      thirdAlgorithmTimer.cancel();
      dotsCoordinates.clear();
      startFirstAlgorithm();


    }

  }


  //average direction of a xyz vector list
  static List<double> getAverageDirection(List<dynamic> list){
    double xSum = 0;
    double ySum = 0;
    double zSum = 0;

    for (var i = 0; i < list.length; i++) {
     xSum += list[i][0]; 
     ySum += list[i][1]; 
     if(list[i].length >2) zSum += list[i][2]; 
    }
    int length = list.length;
    if(list[0].length > 2) return [xSum/length,ySum/length,zSum/length];
    return [xSum/length,ySum/length];
  }
  static List<double> getDesiredDirection({int centerIndex = -1}){
    double avgLong = 0;
    double avgLat = 0;
    for (var i = 0; i < dotsCoordinates.length; i++) {
      avgLong += dotsCoordinates[i][0];
      avgLat += dotsCoordinates[i][1];
    }
    avgLong = avgLong/dotsCoordinates.length;
    avgLat = avgLat/dotsCoordinates.length;
    if(centerIndex>= 0){
      avgLong = dotsCoordinates[centerIndex][0];
      avgLat = dotsCoordinates[centerIndex][1];
    }
    return DeviceLocation.getVector(avgLat, avgLong, nextCoordinate[1], nextCoordinate[0]);
  }

  static String getInstruction(String currentInstruction,String locationName,int? exitNumber){
    String curString = currentInstruction.toLowerCase();
    String result = "";
    List<String> compassWord = compassTranslations.keys.where((item)=>curString.split(" ").contains(item)).toList();
    print("current instruciton is : $currentInstruction");
    print("current compass is : ${compassWord[0]}");
    if (compassWord.isNotEmpty) {
      result = "سر بتجاه ${compassTranslations[compassWord[0]]}";
      isCompassIntstruction = true;
    }else if(curString.contains("turn")){
      if(curString.contains("right")){ result = "انعطف يمينا";}
      else if(curString.contains("left")){ result = "انعطف يسارا";}
      if(lastAngleCalculated!=400){
        result += " و بزاوية ${lastAngleCalculated.toStringAsFixed(0)}";
      }
    }else if(curString.contains("continue")){
      result = "تابع الى الامام";
    }
    else if (curString.contains("roundabout")){
     result = "ادخل الفلكة و اخرج من الفرع ${numberTranslations[exitNumber]}";
    }
    if(arabicRegex.hasMatch(locationName)){
      result += " على $locationName";
    }
    result +=" ولمسافة ${(DeviceLocation.getDistance(lastPlayerPosition!.latitude , lastPlayerPosition!.longitude, nextCoordinate[1], nextCoordinate[0])*1000).toStringAsFixed(0)} متر";

    lastArabicResult = result;
    return result;
  }

  static Future<void> getLocation() async {

    currentApiTextIndex = -1;
    apiText.length = 0;
    coordinates.length = 0;

    print("running the get paths");
    print(cords.length);
    print(cords);

    if(cords.length <2){
      print("cords are less that the correct ammount..");
      snackbarFnc("cords are less than the correct amount... ${cords.length}");
      return;
    }
    Position? p = lastPlayerPosition;
    print("position is : ${p.toString()}");

    if(p==null) {
      snackbarFnc("p is null for some reason");
      return;
    }
    String url = "https://api.openrouteservice.org/v2/directions/foot-walking?api_key=${ApiKeys.openRouteServiceKey}&start=${p.longitude},${p.latitude}&end=${cords[0]},${cords[1]}";
    // if(cords.length == 4){
    //   url = "https://api.openrouteservice.org/v2/directions/foot-walking?api_key=${ApiKeys.openRouteServiceKey}&start=${cords[2]},${cords[3]}&end=${cords[0]},${cords[1]}";
    // }
    print(url);
    print("this is the url");
    Uri uri = Uri.parse(url);
    final response = await http.get(uri);
    final body = response.body;
    print("response : ");
    print(response);
    
    final json = jsonDecode(body);
    for (var i = 0; i < json["features"][0]["properties"]["segments"][0]["steps"].length; i++) {
      apiText.add(json["features"][0]["properties"]["segments"][0]["steps"][i]);//
    }
    for (var i = 0; i < json["features"][0]["geometry"]["coordinates"].length; i++) {
      coordinates.add(json["features"][0]["geometry"]["coordinates"][i]);
      
    }
    currentApiTextIndex = 0;
    nextCoordinate = coordinates[apiText[currentApiTextIndex]["way_points"][1]];

    DeviceLocation.startPos = coordinates[apiText[currentApiTextIndex]["way_points"][0]];
    DeviceLocation.checkpointPos = [DeviceLocation.startPos[0],DeviceLocation.startPos[1]];

    TextToSpeech.speak(getInstruction(apiText[currentApiTextIndex]["instruction"],apiText[currentApiTextIndex]["name"],apiText[currentApiTextIndex]["exit_number"]));
  }

}

  enum AlgorithmProgress{
    first,
    second,
    third,
    fourth,
    fifth,
    sixth,
    done
  }
  