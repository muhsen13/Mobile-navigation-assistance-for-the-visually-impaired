import 'dart:convert';
import 'dart:async';
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graduation_project/implimentation/ai_implementation.dart';
import 'package:graduation_project/implimentation/api_keys.dart';
import 'package:graduation_project/implimentation/device_location.dart';
import 'package:graduation_project/implimentation/directions_algorithm.dart';
import 'package:graduation_project/implimentation/speech_to_text.dart';
import 'package:graduation_project/implimentation/text_to_speech.dart';
import 'package:graduation_project/testcode/cubits/apitext_cubit.dart';
import 'package:graduation_project/testcode/cubits/apitext_model.dart';
import 'package:graduation_project/testcode/saved_points_menu.dart';
import 'package:graduation_project/testcode/search_menu.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

void main() async{
  await Hive.initFlutter();
  await Hive.openBox("savedPoints");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  
  const MyApp({super.key});

  // This widget is the root of your application.
  
  @override
  Widget build(BuildContext context) {
        return BlocProvider(
      create: (context) => ApitextCubit(ApitextModel()),
      child: MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 85, 118, 122)),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    ));
  }
}

class MyHomePage extends StatefulWidget {

  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();

}

class _MyHomePageState extends State<MyHomePage> {

  List<dynamic> apiText =[];
  List<dynamic> coordinates = [];
  int currentApiTextIndex = -1;
  List<dynamic> nextCoordinate = [];

  int _counter = 0;
  int menuIndex = 0;
  bool mapEnabled = false;
  MapController mapController = MapController();

  int numberOfIncorrectDirectionMovement = 0;
  int numberOfcorrectDirectionMovement = 0;

  
  List<dynamic> tempdotsCoordinates = [];
  double tempDistance = -1;
  Position? tempPosition;
  bool longPressing = false;
  bool debugMode= false;
  final TextEditingController _controller = TextEditingController();



  late Timer _periodicTimer; // Declare a Timer variable
/*
    void startPeriodicCall(BuildContext context) {
      const Duration interval = Duration(seconds: 5); // Define the interval
      _periodicTimer = Timer.periodic(interval, (Timer timer) {
        _myPeriodicFunction(context);
      });
    }
        Future<void> _myPeriodicFunction(BuildContext context) async {
      // Your code to be executed periodically
      if(nextCoordinate.isEmpty){ print("no destination yet"); return;}
      Position? p = await DeviceLocation.getCurrentLocation();
      if(p==null) { print("couldn't get device location for checking distance");return;}
      print("next waypoint is this far");
      setState(() {
        lastDistanceCalculated = DeviceLocation.getDistance(p.latitude,p.longitude, nextCoordinate[1], nextCoordinate[0]);
      });
      print(lastDistanceCalculated);
      if(lastDistanceCalculated < 0.01){
        moveToNextStep();
      }else{
        DeviceLocation.coordinateCheck = [p.longitude,p.latitude];
        double dist = DeviceLocation.getDistance(p.latitude,p.longitude, DeviceLocation.startPos[1], DeviceLocation.startPos[0]);
        lastAngleCalculated = DeviceLocation.getVectorsAngle(p.latitude,p.longitude,DeviceLocation.checkpointPos[1], DeviceLocation.checkpointPos[0],nextCoordinate[1],nextCoordinate[0]);
        print("distance and last angle is ");
        print(dist);
        print(lastAngleCalculated);
        if(dist >= 0.02 && lastAngleCalculated.abs() > 30){
          if(numberOfIncorrectDirectionMovement % 2 == 1){
            print("you are walking in the wrong direction");

            String dir = lastAngleCalculated > 0 ? "باتجاه اليسار": "بتجاه اليمين";
            TextToSpeech.speak("انت تسير في الاتجاه الخاطئ, سر $dir وبزاوية ${lastAngleCalculated.abs().toStringAsFixed(0)}"); 
          }
          
          numberOfIncorrectDirectionMovement++;
          numberOfcorrectDirectionMovement=0;
          if(numberOfIncorrectDirectionMovement >= 3){
            numberOfIncorrectDirectionMovement=0;
            lastAngleCalculated = -400;
//            isCompassIntstruction = false;
            print("getting location again");
            getLocation(BlocProvider.of<ApitextCubit>(context).state.cordinates,context);
          }
        }else if (dist>=0.02){
          numberOfIncorrectDirectionMovement = 0;
          numberOfcorrectDirectionMovement++;
          if(numberOfcorrectDirectionMovement>=2){
            numberOfcorrectDirectionMovement = 0;
            DeviceLocation.checkpointPos = [p.longitude,p.latitude];
          }
        }
      }
    }
*/
    

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    print("distance in KM is : ");
    print(DeviceLocation.getDistance(33.369727518563884, 44.364139317133926, 33.368262622647364, 44.36917863193135));
    DeviceLocation.getVectorsAngle(33.354092846737245, 44.37907441856224, 33.34479881235959, 44.37896311791495,33.35259319573792, 44.393301725333956);
    TextToSpeech.InitTTS();
  //  startPeriodicCall(context);

  }
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }
  void showSnackBar(String txt){
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(txt)),);
  }
    void checkIfpassedThePoint(Timer timer) {
      // Your code to be executed periodically
      print('Function called at ${DateTime.now()}');
      // Example: If you want to stop the timer after a certain condition
      // if (someCondition) {
      //   timer.cancel();
      // }
    }

  void getLocation(List cords,BuildContext context)async{
    DirectionsAlgorithm.startTheAlgorithm(cords,updatecoordinates);
  }

/* ORIGINAL getLocation
  void getLocation(List cords,BuildContext context) async{

    setState(() {
      currentApiTextIndex = -1;
    });
    apiText.length = 0;
    coordinates.length = 0;

    setState(() {
      apiText;
      coordinates;
    });

    print("running the get paths");
    print(cords.length);
    print(cords);
    if(cords.length <2){
        
        print("cords are less that the correct ammount..");
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("cords are less than the correct amount... ${cords.length}")),
          );
        return ;
      }
    Position? p = await DeviceLocation.getCurrentLocation();


        // ScaffoldMessenger.of(context).showSnackBar(
        // SnackBar(content: Text(p.toString())),
        //   );
        print("position is : ${p.toString()}");

    if(p==null) {
              ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("p is null for some reason")),
          ); 
      return;
    }
    String url = "https://api.openrouteservice.org/v2/directions/foot-walking?api_key=${ApiKeys.openRouteServiceKey}&start=${p.longitude},${p.latitude}&end=${cords[0]},${cords[1]}";
    if(cords.length == 4){
    url = "https://api.openrouteservice.org/v2/directions/foot-walking?api_key=${ApiKeys.openRouteServiceKey}&start=${cords[2]},${cords[3]}&end=${cords[0]},${cords[1]}";

    }
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
    setState(() {
      apiText;
      coordinates;
    });
    setState(() {
      currentApiTextIndex = 0;
      nextCoordinate = coordinates[apiText[currentApiTextIndex]["way_points"][1]];
    });
      DeviceLocation.startPos = coordinates[apiText[currentApiTextIndex]["way_points"][0]];
      DeviceLocation.checkpointPos = [DeviceLocation.startPos[0],DeviceLocation.startPos[1]];


      
//      await _myPeriodicFunction(context);

  //    TextToSpeech.speak(getInstruction(apiText[currentApiTextIndex]["instruction"],apiText[currentApiTextIndex]["name"],apiText[currentApiTextIndex]["exit_number"]));

    
  }*/
  void updatecoordinates(){
   // print("this is getting invoked");
    setState(() {
      tempPosition = DirectionsAlgorithm.lastPlayerPosition;
      tempdotsCoordinates = DirectionsAlgorithm.dotsCoordinates;
      tempDistance = DirectionsAlgorithm.lastDistanceToDot;
    });
  }
  void moveToNextStep() async{


    //note : calling the periodic function here messes up alot of stuff, so for the sake of the actual project the periodic call was deleted and it will result incorrect numbers
    //or text when called manually using the swipe

  //  await _myPeriodicFunction(context);
    Position? p = await DeviceLocation.getCurrentLocation();

  if(apiText.isEmpty) return;
    currentApiTextIndex++;
    if(currentApiTextIndex == apiText.length){currentApiTextIndex--;print("reached the end step");}
    nextCoordinate = coordinates[apiText[currentApiTextIndex]["way_points"][1]];
    DeviceLocation.startPos = coordinates[apiText[currentApiTextIndex]["way_points"][0]];
      DeviceLocation.checkpointPos = [DeviceLocation.startPos[0],DeviceLocation.startPos[1]];

    print(jsonEncode(apiText[currentApiTextIndex]));

 //   lastAngleCalculated = -400;
  //  if(p!=null) lastAngleCalculated = DeviceLocation.getVectorsAngle(p.latitude,p.longitude,DeviceLocation.checkpointPos[1], DeviceLocation.checkpointPos[0],nextCoordinate[1],nextCoordinate[0]);

  //  TextToSpeech.speak(getInstruction(apiText[currentApiTextIndex]["instruction"],apiText[currentApiTextIndex]["name"],apiText[currentApiTextIndex]["exit_number"]));

  }
  void moveToPreviousStep() async{
    
  //  await _myPeriodicFunction(context);
  if(apiText.isEmpty) return;
    currentApiTextIndex--;
    if(currentApiTextIndex == -1){currentApiTextIndex = 0;print("reached the first step");}
    nextCoordinate = coordinates[apiText[currentApiTextIndex]["way_points"][1]];
    DeviceLocation.startPos = coordinates[apiText[currentApiTextIndex]["way_points"][0]];
    DeviceLocation.checkpointPos = [DeviceLocation.startPos[0],DeviceLocation.startPos[1]];

    print(jsonEncode(apiText[currentApiTextIndex]));
 //   TextToSpeech.speak(getInstruction(apiText[currentApiTextIndex]["instruction"],apiText[currentApiTextIndex]["name"],apiText[currentApiTextIndex]["exit_number"]));

  }
  void getLocationGeo (String location) async{

    String dist = location;
    if(dist != ""){
      print(dist.replaceAll(" ", "20%"));//ساحة%20التحرير
      String url = "https://api.openrouteservice.org/geocode/search?api_key=${ApiKeys.openRouteServiceKey}&text=${dist}&boundary.country=iq";
      print(url);
      Uri uri = Uri.parse(url);
      
                ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("starting to await respose"))
          );

      final response = await http.get(uri);
      final body = response.body;
      
                ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("response received....2 "))
          );
      final json = jsonDecode(body);
      
        //         ScaffoldMessenger.of(context).showSnackBar(
        // SnackBar(content: Text("response is ${body}"))
        //   );
      final cords = json["features"][0]["geometry"]["coordinates"];
      final neighbourhood = json["features"][0]["properties"]["neighbourhood"];
      Position? approxPos = await forceReceiveCurrentLocation(0);
      double dis = 0;
      if(approxPos!=null) dis = DeviceLocation.getDistance(approxPos.latitude,approxPos.longitude,cords[1],cords[0]);
      AiImplementation.setInformation(cords,dis,neighbourhood);

      print("this conde is working and the cords are : ");
      print(cords);
        BlocProvider.of<ApitextCubit>(context).updateCordinates(cords[0],cords[1]);
        print("worked");
                        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("dist cords are recieved and they are ${cords[0]} , ${cords[1]}"))
          );

    }
  }
  void updatecords(double x,double y){
    BlocProvider.of<ApitextCubit>(context).updateCordinates(x,y);
  }
  Future<Position?> forceReceiveCurrentLocation(int i)async{
    Position? p = await DeviceLocation.getCurrentLocation();
    if(p==null){
      i++;
      if(i > 5) return null;
      return forceReceiveCurrentLocation(i);
    }
    return p;
  }
  void getRoute() {
    getLocation(context.read<ApitextCubit>().state.cordinates,context);
  }


 
  @override
  Widget build(BuildContext context) {
    
    return Container(
         // decoration: BoxDecoration(image: DecorationImage(image: AssetImage("assets/images/graduationBG.png"))),
          child: Scaffold(
            
            backgroundColor: const Color.fromARGB(255, 212, 212, 212),
            // appBar: AppBar(
            //   backgroundColor: Colors.transparent , // Theme.of(context).colorScheme.inversePrimary
            //   title: Text(widget.title),),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: menuIndex,
              type: BottomNavigationBarType.fixed,
              
              backgroundColor: const Color.fromARGB(255, 241, 241, 241),
              onTap:(value) {
                if(value==1) return;
                setState(() {
                  menuIndex = value;
                });
              } ,
              items: [
              BottomNavigationBarItem(icon: Icon(Icons.home) ,label: "home"),
              BottomNavigationBarItem(icon: SizedBox.shrink() ,label: ""),
              BottomNavigationBarItem(icon: Icon(Icons.search),label: "search")
            ]),
            body: mainbody(),
            floatingActionButton: (menuIndex !=0 || !debugMode) ? null: floatingAction(),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          ),
        );
  }


  Widget mainbody(){


    if(menuIndex==0){
      if(mapEnabled==true){
        return Stack(
          children: [
            FlutterMap(
              mapController:mapController ,
              options: MapOptions(initialCenter:LatLng(DeviceLocation.lastCurrentPosition?.latitude ?? 33.3609618 , DeviceLocation.lastCurrentPosition?.longitude ?? 44.3797936),initialZoom: 15, )
              ,children: [TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName: 'com.example.gradiationProject',),
                          MarkerLayer(markers: generateMarker2()) ]),
            Center(child: Icon(Icons.circle_outlined)),
            Column(children: [Text("accuracy =  ${tempPosition?.accuracy}"),
            Text("distance =  $tempDistance"),],)
            ],
        );
      }else{
        return GestureDetector(
                    // onTap: ()async{
                    //   bool gotPermission = await DeviceLocation.getPermission();
                    //   if(!gotPermission) {print("couldn't get permission"); return;}
                    //   print("starting location stream");
                    //   DeviceLocation.startPositionStream();
                    // },
                    onTap: () async{
                      Position? p = DeviceLocation.lastCurrentPosition;
                      if(p==null || DirectionsAlgorithm.nextCoordinate.isEmpty)return;
                      double dis = DeviceLocation.getDistance(p.latitude,p.longitude, DirectionsAlgorithm.nextCoordinate[1], DirectionsAlgorithm.nextCoordinate[0]);
                      String displayDistance = "${(dis*1000).toStringAsFixed(0)} متر";
                      if(DeviceLocation.distanceType == Distancetype.feet){
                        displayDistance = "${DeviceLocation.getDistanceInFeet(dis*1000).toStringAsFixed(0)} قدم";
                      }
                      else if(DeviceLocation.distanceType == Distancetype.steps){
                        displayDistance = "${DeviceLocation.getDistanceInSteps(dis*1000).toStringAsFixed(0)} خطوة";
                      }
                      TextToSpeech.speak("باقي $displayDistance على المنعطف القادم");
                    },
                    onDoubleTap: (){
                      print("getting location again");
                      getLocation(context.read<ApitextCubit>().state.cordinates,context);
                    },
                    onLongPress: () {
                      print("started listening.....");
                      SpeechToText.didSpeechStop = false;
                      SpeechToText.listen();
                      setState(() {
                        longPressing=true;
                      });
                    },
                    onLongPressUp: () async{
                      print("stop listening......");
                      SpeechToText.didSpeechStop = true;
                      SpeechToText.stopListening();
                      print("spoken text is : ");
                      setState(() {
                        longPressing=false;
                      });
        
                      print(SpeechToText.text);
        
                      if(SpeechToText.text=="") return;

                        //getLocationGeo(SpeechToText.text);
                        if(AiImplementation.model == null) AiImplementation.initiateModel();
                        AiImplementation.handleAIresponse(SpeechToText.text, getLocationGeo,getRoute,updatecords,forceReceiveCurrentLocation);
                      
                    },
                    onVerticalDragEnd: (details){
                      setState(() {
                        debugMode = !debugMode;
                      });
                    },
                    // onHorizontalDragEnd: (details) {
                    //   print("horizontal drag ended and it was moving at ${details.primaryVelocity} ");
                    //   if(details.primaryVelocity! > 600){
                    //     setState(() {
                    //       moveToNextStep();
                    //     });
                    //   }else if (details.primaryVelocity! < -600){
                    //     setState(() {
                    //       moveToPreviousStep();
                    //     });
                    //   }
                    // },
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(color: Color.fromARGB(0, 255, 255, 255)),
                      
                      child: Stack(
                        alignment: AlignmentGeometry.center,
                        children: [
                          Icon(Icons.fingerprint_outlined,color: !longPressing? Colors.black : Colors.green,size: 150,),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children:debugMode==true? [ 
                              SizedBox(
                                width: 300,
                                child: TextField(
                                                    style: TextStyle(color: Colors.black),
                                                    controller: _controller,
                                                    decoration: InputDecoration(),
                                                  ),
                              ),
                              
                                              ElevatedButton(onPressed: (){
                            if(AiImplementation.model == null) AiImplementation.initiateModel();
                            AiImplementation.handleAIresponse(_controller.text, getLocationGeo,getRoute,updatecords,forceReceiveCurrentLocation);}, child: Text("ask ai"),),
                          
                                              //    currentApiTextIndex ==-1? Transform.translate(offset: Offset(0, MediaQuery.of(context).size.height * -0.18),child: Text("no instructions found yet",style: TextStyle(color: Colors.white))) : 
                                              //    Transform.translate(offset: Offset(0, MediaQuery.of(context).size.height * -0.195),child: Column(mainAxisAlignment: MainAxisAlignment.start,children: [Text(apiText[currentApiTextIndex]["instruction"],style: TextStyle(color: Colors.white))
                                              //    ,Text(DirectionsAlgorithm.lastArabicResult,style: TextStyle(color: Colors.white))
                                              //    ,Padding(
                                              //      padding: const EdgeInsets.only(top: 20.0),
                                              //      child: Text("distance : deprecated for now",style: TextStyle(color: Colors.white)),//${DirectionsAlgorithm.lastDistanceCalculated} removed
                                              //    )])),
                            // Row(
                            //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            //   crossAxisAlignment: CrossAxisAlignment.end,
                            //   children: [
                            //     ElevatedButton(onPressed: (){
                            //       setState(() {
                            //         moveToPreviousStep();
                                    
                            //       });
                            //       }, child: Text("Back")),
                            //     ElevatedButton(onPressed: (){
                                  
                            //       setState(() {
                            //         moveToNextStep();
                            //       });
                            //     }, child: Text("Front"))
                            //   ],
                            // )
                            ]:[],
                          ),
                        ],
                      ),
                    ),
                  );
      }
    }
    return SavedPointsMenu();//SavedPointsMenu(),
  }
  List<Marker> generateMarker(){ //old algorithm markers

    Marker? lastPlayerPosition = DeviceLocation.lastCurrentPosition!=null ? Marker(point: LatLng(DeviceLocation.lastCurrentPosition!.latitude, DeviceLocation.lastCurrentPosition!.longitude), child: Icon(Icons.circle,color: Colors.blue )) : null;
    Marker? nextCoordinateMarker = nextCoordinate.isNotEmpty == true ? Marker(point: LatLng(nextCoordinate[1], nextCoordinate[0]), child: Icon(Icons.location_pin,color: Colors.red )) : null;
    Marker? angleChecker = DeviceLocation.checkpointPos.isNotEmpty == true ? Marker(point: LatLng(DeviceLocation.checkpointPos[1], DeviceLocation.checkpointPos[0]), child: Icon(Icons.location_pin,color: Colors.green )) : null;
    
    return [?lastPlayerPosition,?nextCoordinateMarker,?angleChecker];
  
  }

  List<Marker> generateMarker2(){ //new algorithm markers

    List<Marker> result = [];
    if(tempPosition!=null){
    Marker lastPlayerPosition = Marker(point: LatLng(tempPosition!.latitude, tempPosition!.longitude), child: Icon(Icons.circle,color: Colors.blue ));
    result.add(lastPlayerPosition);}

    for (var i = 0; i < tempdotsCoordinates.length; i++) {
      Marker t = Marker(point: LatLng(tempdotsCoordinates[i][1], tempdotsCoordinates[i][0]), child: Icon(Icons.circle,color: Colors.orange ));
      result.add(t);
    }
    if(DirectionsAlgorithm.nextCoordinate.isNotEmpty) {
      Marker e = Marker(point: LatLng(DirectionsAlgorithm.nextCoordinate[1], DirectionsAlgorithm.nextCoordinate[0]), child: Icon(Icons.circle,color: Colors.red ));
      result.add(e);
    }

    return result;
  
  }
  
  Widget floatingAction(){
    return BlocBuilder<ApitextCubit,ApitextModel>(
              builder: (context, state) {
                
              
              return Padding(
                padding: EdgeInsetsGeometry.symmetric(vertical: 96,horizontal: 32),
                child: Stack(
                  children: [
                    Align(
                
                      alignment: Alignment.bottomLeft,
                      child: FloatingActionButton(
                        onPressed: ()
                        {
                          setState(() {
                            mapEnabled = !mapEnabled ;
                          });
                        },
                        tooltip: 'map',
                        child: const Icon(Icons.map),
                      ),
                    ),
                    Align(
                
                      alignment: Alignment.bottomRight,
                      child: mapEnabled? FloatingActionButton(
                        onPressed: (){
                          DeviceLocation.debugLocation = [mapController.camera.center.longitude,mapController.camera.center.latitude];
                        },
                        tooltip: 'set',
                        child: const Icon(Icons.location_pin),
                      ):null,
                    ),
                    
                  ],
                ),
              );
            });
  }

}

