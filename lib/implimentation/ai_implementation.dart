import 'package:geolocator/geolocator.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:graduation_project/implimentation/api_keys.dart';
import 'package:graduation_project/implimentation/confirmation_information.dart';
import 'package:graduation_project/implimentation/device_location.dart';
import 'package:graduation_project/implimentation/text_to_speech.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as js;

class AiImplementation {

  static bool currentlyInConversation = false;
  static ConfirmationInformation? information;
  static ChatSession? chat;
  static GenerativeModel? model;

  static void initiateModel(){
    String systemInstruction = 'you are an ai assistant for a mobile navigation app designed for the visually impaired,'
  ' you can answer the user questions immediately if you can fulfill it, or you can use some pre-defined commands to get'
  ' the information needed to answer the user question. if you choose to answer you should do so in the Arabic language and minimum amount of words.\n'

  "some commands have square brackets for parameters, replace the words inside the square bracket with the parameter you"
  " want, it's okay to use Arabic words and letters for the parameters since the user will probably talk to you in Arabic.\n"

  "below are the pre-defined commands and their descriptions :\n"

  "• findDestination[location_name] : this command searches for the destination the user asked for and stores the coordinates"
  ", it will return the coordinates and distance and area if the location finding was successful, always tell the user the distance and area"
  " and wait for confirmation from the user.\n"
  
  "• setDistanceUnit[unit_type] : this command sets the unit of measuring distance depending on whats in the bracket, you can only use the following words in the bracket : \"meters\" or \"feet\" or \"steps\" depending "
  "on what the user requests. use this command only if the user requested to change the current distance unit.\n"

  "• setOrientationUnit[unit_type] : this command sets the unit of measuring angles depending on whats in the bracket, you can only use the following words in the bracket : \"degrees\" or \"clock\" depending on"
  " what the user requests. use this command only if the user requested to change the current angle unit.\n"

  "• endConversation : after calling the pre-defined commands or answering the user directly, if you see no need to continue the conversation and the user got what he requested "
  "you should send this command to let the app know that this conversation was finished, you won't get another response after this command unless it's about a new conversation, "
  "never end the conversation if you are waiting for a user confirmation.\n"
  
  "if you need to use more than one command, don't send it in a single message, each message should either have one command or a normal answer"
  ", you can send the other command after getting the answer of the previous command";


    model = GenerativeModel(
    model: 'gemini-3.1-flash-lite-preview', // Or the version you used in AI Studio
    apiKey: ApiKeys.geminiKey,
    systemInstruction: Content.system(systemInstruction), 

  );
  startChat();
  }
  static void startChat(){
    
    chat = model!.startChat(history: []);

  }

  static void setInformation(List coordinates, double distance, String? neighbourhood){
    information = ConfirmationInformation();
    information!.coordinates = [coordinates[1],coordinates[0]];
    information!.approximateDistance = distance;
    information!.neighbourhood = neighbourhood??"";
  }

  static void handleAIresponse(String msg, Function(String) getlocationGeoFnc,Function getRouteFnc,Function(double ,double) updatecords,Function(int) forcePosition) async{

    if(currentlyInConversation==false){
      currentlyInConversation = true;
    }
 //   String response = await sendToAI(msg);
    late GenerateContentResponse contentResponse;
    try {
     contentResponse = await chat!.sendMessage(Content.text(msg)); 
    } catch (e ) {
      TextToSpeech.speak("هناك ايرور من نوع :${e.runtimeType} ");
      print(e);
      return;
    }
    String response = contentResponse.text??"";
    print(response);
    if(response=="")return;
    if (response.contains("findDestination")) {
      String locationName = response.substring(response.indexOf("[")+1,response.indexOf("]"));
      print("destination is $locationName");

      if(Hive.box("savedPoints").get(locationName)!=null ){
        print("-----found location through saved points-----");
        List<double> d = Hive.box("savedPoints").get(locationName);
        updatecords(d[0],d[1]);
        String coord = "coordinates : ${d[0]},${d[1]}";
        
        Position? approxPos = await forcePosition(0);

        handleAIresponse("Location found.\n$coord\napproximate distance : ${DeviceLocation.getDistance(d[1], d[0], approxPos!.latitude,approxPos!.longitude)} KM\n",getlocationGeoFnc,getRouteFnc,updatecords,forcePosition);
        return;
      }
      await getlocationGeoFnc(locationName);
     // handleAIresponse("route found successfully",getlocationGeoFnc,getRouteFnc);
     String neighbour = "";
     String distance = "";
     if(information!.neighbourhood!="") neighbour = "neighbourhood : ${information!.neighbourhood}";
     if(information!.approximateDistance!=0)  distance = "approximate distance : ${information!.approximateDistance} km";
     if(information!.neighbourhood=="" && information!.approximateDistance==0){
      TextToSpeech.speak("لم يتم العثور على الموقع");
      currentlyInConversation = false;
      return;
     }
     String coord = "coordinates : ${information!.coordinates}";
      handleAIresponse("Location found.\n$coord\n$neighbour\n$distance",getlocationGeoFnc,getRouteFnc,updatecords,forcePosition);
      return;
    }
    else if (response.contains("setDistanceUnit")){
      if(response.contains("[meters]")){
        DeviceLocation.distanceType = Distancetype.meter;
        TextToSpeech.speak("تم تعديل عرض المسافات الى امتار ");
      }
      else if (response.contains("[feet]")){
        DeviceLocation.distanceType = Distancetype.feet;
        TextToSpeech.speak("تم تعديل عرض المسافات الى اقدام ");
      }else if (response.contains("[steps]")){
        DeviceLocation.distanceType = Distancetype.steps;
        TextToSpeech.speak("تم تعديل عرض المسافات الى خطوات ");
      }
      currentlyInConversation = false;
      startChat();
      return;
    }
    else if (response.contains("setOrientationUnit")){
      if(response.contains("[degrees]")){
        DeviceLocation.angleInClocks = false;
        TextToSpeech.speak("تم تعديل عرض الزوايا الى درجات ");
      }
      else if (response.contains("[clock]")){
        DeviceLocation.angleInClocks = true;
        TextToSpeech.speak("تم تعديل عرض الزوايا الى ساعات ");
      }
      currentlyInConversation = false;
      startChat();
      return;
    }
    else if (response.contains("endConversation")){
      List<String> res = response.split("endConversation");
      await TextToSpeech.speak(res.join());
      currentlyInConversation = false;
      getRouteFnc();
      startChat();
      return;
    }else{
      TextToSpeech.speak(response);
      return;
    }
    

  }


  //found location
  //coordinates : 44.389511, 33.353626
  //area : Al Wazīrīyah
  //distance : 1.6 KM
  


  //RE ADD SYSTEM INSTRUCTION IF YOU WANT TO USE IT
  static Future<String> sendToAI(String msg) async {

  
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent');
  dynamic payload = {
      "system_instruction":{
        "parts" :[
          {
    //        "text": systemInstruction
          }]
          
        },
      
      "contents":[
        {"parts" : [
          {"text":msg}
        ]}]
    };
  try {
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        'x-goog-api-key': ApiKeys.geminiKey
      },
      body: js.jsonEncode(payload)
      //jsonEncode(<String, String>{
     //     'contents'
  //      'title': 'Dart Post Request',
     //   'body': 'Example content',
    //    'userId': '1',
     // }),
    );

    if (response.statusCode == 201 ||  response.statusCode == 200) {
      // Success: Resource created
      print('Response data: ${response.body}');
      dynamic json = js.jsonDecode(response.body);
      return json["candidates"][0]["content"]["parts"][0]["text"];
    } else {
      // Error handling
      print('Failed to post: ${response.statusCode}');
      return "";
    }
  } catch (e) {
    print('Error occurred: $e');
    return"";
  }
}
}