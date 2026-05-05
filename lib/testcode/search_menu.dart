import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graduation_project/implimentation/ai_implementation.dart';
import 'package:graduation_project/implimentation/api_keys.dart';
import 'package:graduation_project/implimentation/device_location.dart';
import 'package:graduation_project/implimentation/directions_algorithm.dart';
import 'package:graduation_project/implimentation/speech_to_text.dart';
import 'cubits/apitext_cubit.dart';
import 'package:http/http.dart' as http;

class SearchMenu extends StatelessWidget {
  SearchMenu({super.key});
  final TextEditingController _controllerDist = TextEditingController();
  final TextEditingController _controllerSrc = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("cordinate search"),),
      body: Center(
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 150,
                  child: TextField(
                    controller: _controllerSrc,
                    decoration: InputDecoration(),
                  ),
                ),
                ElevatedButton(onPressed: (){
                  getLocationGeoSrc( context);
                }, child: Text("get path"))
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Container(
                  width: 150,
                  child: TextField(
                    controller: _controllerDist,
                    decoration: InputDecoration(),
                  ),
                ),
                ElevatedButton(onPressed: (){
                  getLocationGeo( context,_controllerDist.text==""?true:false);
                  //getLocationGeo(SpeechToText.text);
                }, child: Text("get path"))
              ,
              Text("Hello2.596")
              ],
            ),
          SpeechBar(),
          ],
        ),
      ),
    );
  }  
  void getLocationGeo (BuildContext context,bool usingVoice) async{

    String dist = usingVoice? SpeechToText.text:_controllerDist.text;
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
        SnackBar(content: Text("response received "))
          );
      final json = jsonDecode(body);
      
        //         ScaffoldMessenger.of(context).showSnackBar(
        // SnackBar(content: Text("response is ${body}"))
        //   );
      final cords = json["features"][0]["geometry"]["coordinates"];
      if(context.mounted){
        context.read<ApitextCubit>().updateCordinates(cords[0],cords[1]);
        print("worked");
                        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("dist cords are recieved and they are ${cords[0]} , ${cords[1]}"))
          );
      }
    }
  }
    void getLocationGeoSrc (BuildContext context) async{
    if(_controllerSrc.text != ""){
      print(_controllerSrc.text.replaceAll(" ", "20%"));//ساحة%20التحرير
      String url = "https://api.openrouteservice.org/geocode/search?api_key=${ApiKeys.openRouteServiceKey}&text=${_controllerSrc.text}&boundary.country=iq";
      print(url);
      Uri uri = Uri.parse(url);
      final response = await http.get(uri);
      final body = response.body;
      final json = jsonDecode(body);
      final cords = json["features"][0]["geometry"]["coordinates"];
      
                ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("cords are ${cords[0]} and ${cords[1]}" ))
          );
      if(context.mounted){
        context.read<ApitextCubit>().tempAddCordinates(cords[0],cords[1]);
        print("worked");
                ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("src cords are recieved and they are ${cords[0]} , ${cords[1]}"))
          );
      }
    }
  }
}
class SpeechBar extends StatefulWidget {
  const SpeechBar({super.key});

  @override
  State<SpeechBar> createState() => _SpeechBarState();
}

class _SpeechBarState extends State<SpeechBar> {

  @override
  Widget build(BuildContext context) {
    return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [

                Container(
                  width: 150,
                  child: Text(SpeechToText.text)),
                
                ElevatedButton(onPressed: _listen, child: Icon(SpeechToText.isListening? Icons.mic:Icons.mic_none))
                // Container(
                //   width: 150,
                //   child: TextField(
                //     controller: _controllerSrc,
                //     decoration: InputDecoration(),
                //   ),
                // ),
                // ElevatedButton(onPressed: (){
                //   getLocationGeoSrc( context);
                // }, child: Text("get path"))
              ],
            );
  }
  void _listen() async{

    var locales = await SpeechToText.speech.locales();
    print("locales are : ");
    for (var i = 0; i < locales.length; i++) {
      print(locales[i].name);
    }

   // Some UI or other code to select a locale from the list
   // resulting in an index, selectedLocale

   var selectedLocale = locales[0];

    if(!SpeechToText.isListening){
      bool available = await SpeechToText.speech.initialize(
        onStatus: (val)=> print('onStatus: $val'),
        onError: (val)=> print('onError: $val'),
      );

      if(available){
        setState(() {
          SpeechToText.isListening = true;
        });
        SpeechToText.speech.listen(
          localeId: "ar",
          onResult: (val)=> setState(() {
            SpeechToText.text = val.recognizedWords;
            if(val.hasConfidenceRating && val.confidence > 0){
              SpeechToText.confidence = val.confidence;
            }
          })
        );
      }
    }else{
      setState(() {
        SpeechToText.isListening = false;
      });
      SpeechToText.speech.stop();
    }
  }
}