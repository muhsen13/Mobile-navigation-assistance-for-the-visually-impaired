import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graduation_project/implimentation/device_location.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

class SavedPointsMenu extends StatefulWidget {
  const SavedPointsMenu({super.key});

  @override
  State<SavedPointsMenu> createState() => _SavedPointsMenuState();
}

class _SavedPointsMenuState extends State<SavedPointsMenu> {

  MapController mapController = MapController();
  bool usingMap = false;
  late Position p;
  int editingWaypointIndex = -1;
  List<wayPointData> waypoints = List.empty(growable: true);
  bool waypointsInitialized = false;

  final TextEditingController addController = TextEditingController();

  // void _onMapCreated(GoogleMapController controller){
  //   mapController = controller;
  // }
  void setWaypoint(wayPointData data) async{
      Position? p2 = await DeviceLocation.getCurrentLocation();

    if(p2==null) return;
    editingWaypointIndex = waypoints.indexOf(data);
    setState(() {
      p = p2;
       usingMap = true;
    });
    // showDialog(context: context, builder: (context) {
    //   return AlertDialog(content: GoogleMap(onMapCreated: _onMapCreated,initialCameraPosition: CameraPosition(target: LatLng(p.latitude, p.longitude),zoom: 11)),);
    // },);
  }
  @override
  void initState(){
    super.initState();
    for (var i = 0; i < Hive.box("savedPoints").length; i++) {
      List<double> data = Hive.box("savedPoints").getAt(i);
      setState(() {
        waypoints.add(wayPointData(longitude: data[0], latitude: data[1], waypointName: Hive.box("savedPoints").keyAt(i)));
      });
    }
    
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("saved points 2.599 final")),
      backgroundColor: const Color.fromARGB(255, 212, 212, 212),

      floatingActionButton: usingMap? FloatingActionButton(onPressed: (){onFloatingButtonPressed2();},child: Icon(Icons.add),) : FloatingActionButton(onPressed: (){onFloatingButtonPressed();},child: Icon(Icons.add),),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: usingMap? 
      Stack(children: [
        FlutterMap(
          mapController:mapController ,
          options: MapOptions(initialCenter:LatLng(p.latitude, p.longitude),initialZoom: 15 )
          ,children: [TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',userAgentPackageName: 'com.example.gradiationProject',)]),
          Center(child: Icon(Icons.circle_outlined))
          ])
      //GoogleMap(onMapCreated: _onMapCreated,initialCameraPosition: CameraPosition(target: LatLng(p.latitude, p.longitude)))
      
      
      : Center(
        child: 
            ListView.builder(
              itemCount: waypoints.length,
              itemBuilder: (context, index) {
              return Column(
                children: [
                  WayPoint(data: waypoints[index],removeFunction: removeWayPointData,setPointFunction: setWaypoint,),
                  SizedBox(height: 20,)
                ],
              );
            })
      ),
    );
  }
  void removeWayPointData(wayPointData data){
    setState(() {
    waypoints.remove(data);
    });
      Hive.box("savedPoints").delete(data.waypointName);
  }

  void onFloatingButtonPressed2(){
      print(mapController.camera.center);
      

      setState(() {
        waypoints[editingWaypointIndex].latitude = mapController.camera.center.latitude;
        waypoints[editingWaypointIndex].longitude = mapController.camera.center.longitude;
        usingMap = false;
      });
      List<double> curPoint = [waypoints[editingWaypointIndex].longitude,waypoints[editingWaypointIndex].latitude];
      Hive.box("savedPoints").put(waypoints[editingWaypointIndex].waypointName, curPoint);
      editingWaypointIndex = -1;
  }
  void onFloatingButtonPressed(){
    showDialog(context: context, builder: (context) {

      addController.text = "";
      return AlertDialog(content: SizedBox(
        height: 125,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextField(controller: addController,decoration: InputDecoration(border:OutlineInputBorder(),hintText: "the arabic name of the place"),),
            ElevatedButton(onPressed: (){onAddButtonPressed();}, child: Text("Add"))
          ],
        ),
      ),);
    },);
  }
  void onAddButtonPressed(){
    if(addController.text!=""){
      setState(() {
        print("added");
        waypoints.add(wayPointData(longitude: 0, latitude: 0, waypointName: addController.text));
        Navigator.pop(context);
      });
    }
  }
}
class WayPoint extends StatelessWidget {
  final wayPointData data;
  final Function removeFunction;
  final Function setPointFunction;
   WayPoint({super.key,required this.data,required this.removeFunction,required this.setPointFunction});

  void deleteButton(){
    removeFunction(data);
  }
  void setPointButton(){
    setPointFunction(data);
  }
  @override
  Widget build(BuildContext context) {
    return Container(

      decoration: BoxDecoration(color: Color.fromARGB(255, 241, 241, 241),borderRadius: BorderRadius.circular(16)),
      child: Row(
        
        children: [
          Flexible(
            fit: FlexFit.tight,
            child: Container(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  
                  children: [
                    Row( mainAxisAlignment: MainAxisAlignment.center, children: [Text(data.waypointName)]),
                    Column( children: [
                      Text("longitude : ${data.longitude.toStringAsFixed(5)}" ,textAlign: TextAlign.start),
                      Text("latitude : ${data.latitude.toStringAsFixed(5)}",textAlign: TextAlign.start)
                    ]),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              ElevatedButton(onPressed: (){deleteButton();}, child: Text("delete")),
              ElevatedButton(onPressed: (){setPointButton();}, child: Text("set point"))
            ],
          )
        ],
      ),
    );
  }
}

class wayPointData {
  double longitude;
  double latitude;
  String waypointName;
  wayPointData({required this.longitude,required this.latitude,required this.waypointName});
}