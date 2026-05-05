import 'package:flutter_tts/flutter_tts.dart';
class TextToSpeech {
  static FlutterTts tts = FlutterTts();
  static bool initialized = false;
  static Map? currentVoice;

  static void InitTTS(){
    tts.getVoices.then((data) async{
      
      try {

        List l = await tts.getLanguages;
        await tts.setLanguage("ar");
        print(l);

        List<Map> _voices = List<Map>.from(data);
        _voices = _voices.where((_voice)=> _voice["name"].contains("ar")).toList();
        print(_voices);

        currentVoice = _voices[1];
        if(currentVoice==null){return;}

        tts.setVoice(
          {
            "name": currentVoice!["name"],
           "locale":currentVoice!["locale"]
          });
        tts.setQueueMode(1);
        initialized = true;

      } catch (e) {
        print(e);
      }
    });
  }

  static Future<void> speak(String s)async{
      if(initialized){
        await tts.speak(s);
        await tts.awaitSpeakCompletion(true);
        print("done");
      }
  }
}
