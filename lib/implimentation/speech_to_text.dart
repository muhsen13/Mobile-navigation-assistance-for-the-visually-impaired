
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechToText {
  static stt.SpeechToText speech = stt.SpeechToText();
  static bool isListening = false;
  static String text = "";
  static double confidence = 1.0;
  static bool didSpeechStop = false;

static void stopListening() async{
  if(isListening){
      isListening = false;
      speech.stop();
  }
}
  static void listen() async{

    //text="";

    var locales = await SpeechToText.speech.locales();
    print("locales are : ");
    for (var i = 0; i < locales.length; i++) {
      print(locales[i].name);
    }

   // Some UI or other code to select a locale from the list
   // resulting in an index, selectedLocale

   var selectedLocale = locales[0];

    if(!SpeechToText.isListening){
      bool available = await speech.initialize(
        onStatus: (val)=> print('onStatus: $val'),
        onError: (val)=> print('onError: $val'),
      );

      if(didSpeechStop){
        didSpeechStop = false;
        return;
      }
      if(available){
        isListening = true;
          print("calculating result");
        speech.listen(
          localeId: "ar",
          onResult: (val)
           {
            text = val.recognizedWords;
            print("result calculated and is : ");
            print(text);
            if(val.hasConfidenceRating && val.confidence > 0){
              confidence = val.confidence;
            }
          }
        );
      }
    }
  }

}
