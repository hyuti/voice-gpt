import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:speech_to_text/speech_to_text.dart' as sttxt;
import 'package:speech_to_text/speech_recognition_result.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var _sttxt = sttxt.SpeechToText();
  String text = "Press the button to speak";
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    print(result);
    setState(() {
      text = result.recognizedWords;
    });
  }

  void _initSpeech() async {
    _speechEnabled = await _sttxt.initialize();
    setState(() {});
  }

  void _startListening() async {
    await _sttxt.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  /// Manually stop the active speech recognition session
  /// Note that there are also timeouts that each platform enforces
  /// and the SpeechToText plugin supports setting timeouts on the
  /// listen method.
  void _stopListening() async {
    await _sttxt.stop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Speech to text"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Container(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              _sttxt.isListening
                  ? '$text'
                  : _speechEnabled
                      ? "Tap the microphone to start listening..."
                      : "Speech not available",
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AvatarGlow(
          animate: _sttxt.isListening,
          repeat: true,
          endRadius: 80,
          duration: Duration(milliseconds: 1000),
          glowColor: Colors.blue,
          child: FloatingActionButton(
            onPressed: _sttxt.isListening ? _stopListening : _startListening,
            child: Icon(_sttxt.isListening ? Icons.mic_off : Icons.mic),
          )),
    );
  }
}
