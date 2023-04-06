import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:speech_to_text/speech_to_text.dart' as sttxt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flag/flag.dart';
import 'package:bubble/bubble.dart';
import 'package:voice_gpt/utils.dart';

enum TtsState { playing, stopped, paused, continued }

enum SettingItems { enableOrDisableVoiceReader, clearMsgs }

const MsgKey = "msgs";
const ViId = "vi-VN";
const ViName = "Vietnamese (Vietnam)";
const EnId = "en-US";
const EnName = "English (United States)";

@immutable
class ChatL10nVi extends ChatL10n {
  const ChatL10nVi({
    super.attachmentButtonAccessibilityLabel = 'Gửi tệp',
    super.emptyChatPlaceholder = 'Không có tin nhắn',
    super.fileButtonAccessibilityLabel = 'File',
    super.inputPlaceholder = 'Tin nhắn',
    super.sendButtonAccessibilityLabel = 'Gửi',
    super.unreadMessagesLabel = 'Tin nhắn chưa đọc',
  });
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // common
  String lang = EnId;
  bool enableVoiceReader = true;
  bool clearMsgs = false;
  ChatGPTSDK sdk = ChatGPTSDK();

  // speech to text
  List<types.Message> _messages = [];
  final _user = const types.User(
      id: '82091008-a484-4a89-ae75-a22bf8d6f3ac',
      firstName: "hyuti",
      lastName: "le");
  final _otherUser = const types.User(
      firstName: "Voice",
      id: "4c2307ba-3d40-442f-b1ff-b271f63904ca",
      lastName: "GPT");
  var _sttxt = sttxt.SpeechToText();
  String text = "";
  bool _speechEnabled = false;

  // text to speech
  late FlutterTts flutterTts;
  String? language;
  String? engine;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.5;
  bool isCurrentLanguageInstalled = false;

  int? _inputLength;

  TtsState ttsState = TtsState.stopped;

  get isPlaying => ttsState == TtsState.playing;
  get isStopped => ttsState == TtsState.stopped;
  get isPaused => ttsState == TtsState.paused;
  get isContinued => ttsState == TtsState.continued;

  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  bool get isWindows => !kIsWeb && Platform.isWindows;
  bool get isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _loadMessages();
    _initTts();
  }

  _initTts() {
    flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }

    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });

    if (isAndroid) {
      flutterTts.setInitHandler(() {
        setState(() {
          print("TTS Initialized");
        });
      });
    }

    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setCancelHandler(() {
      setState(() {
        print("Cancel");
        ttsState = TtsState.stopped;
      });
    });

    flutterTts.setPauseHandler(() {
      setState(() {
        print("Paused");
        ttsState = TtsState.paused;
      });
    });

    flutterTts.setContinueHandler(() {
      setState(() {
        print("Continued");
        ttsState = TtsState.continued;
      });
    });

    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  Future<dynamic> _getLanguages() async => await flutterTts.getLanguages;

  Future<dynamic> _getEngines() async => await flutterTts.getEngines;

  Future _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  Future _speak(String msg) async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);
    await flutterTts.setLanguage(getLangCode(context));

    await flutterTts.speak(msg);
  }

  Future _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }

  Future _pause() async {
    var result = await flutterTts.pause();
    if (result == 1) setState(() => ttsState = TtsState.paused);
  }

  @override
  void dispose() {
    super.dispose();
    flutterTts.stop();
  }

  void _addTextMessage(types.TextMessage msg) {
    if (msg.text == "") {
      return;
    }
    _addMessage(msg);
  }

  void _addMessage(types.Message msg) {
    setState(() {
      _messages.insert(0, msg);
      String encoded = jsonEncode(_messages);
      getPrefs().then((value) {
        value.setString(MsgKey, encoded);
      });
    });
  }

  void _handleMessageTap(BuildContext _, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      if (message.uri.startsWith('http')) {
        try {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: true,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });

          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          final index =
              _messages.indexWhere((element) => element.id == message.id);
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: null,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

      await OpenFilex.open(localPath);
    }
  }

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }

  types.TextMessage _buildTextMsgWithStr(String message) {
    return _buildMsgWithUser(message, _user);
  }

  types.TextMessage _buildMsgWithUser(String msg, types.User u) {
    return types.TextMessage(
      author: u,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: const Uuid().v4(),
      status: types.Status.seen,
      text: msg,
    );
  }

  types.TextMessage _buildTextMsg(types.PartialText message) {
    return _buildTextMsgWithStr(message.text);
  }

  void _chatBot(types.PartialText msg) {
    if (msg.text == "") {
      return;
    }
    sdk.fetch(msg.text).then((value) {
      final res = value.choices.first.message.content;
      final botMsg = _buildMsgWithUser(res, _otherUser);
      _addTextMessage(botMsg);
      if (enableVoiceReader) {
        _speak(res);
      }
    });
  }

  void _handleSendPressed(types.PartialText message) {
    if (_sttxt.isNotListening) {
      _chatBot(message);
      _addTextMessage(_buildTextMsg(message));
    }
  }

  Future<SharedPreferences> getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  void _loadMessages() async {
    final SharedPreferences prefs = await getPrefs();

    String msgStr = await prefs.getString(MsgKey) ?? "[]";

    final messages = (jsonDecode(msgStr) as List)
        .map((e) => types.Message.fromJson(e as Map<String, dynamic>))
        .toList();

    setState(() {
      _messages = messages;
    });
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    print(result.recognizedWords);
    setState(() {
      text += result.recognizedWords;
    });
  }

  void _initSpeech() async {
    _speechEnabled = await _sttxt.initialize(
      onStatus: (status) {
        print(status);
        if (status != "listening") {
          _stopListening();
        }
      },
      onError: (errorNotification) {
        _stopListening();
        print(errorNotification);
      },
    );
    setState(() {});
  }

  void _startListening() async {
    setState(() {
      text = "";
    });
    await _sttxt.listen(
      onResult: _onSpeechResult,
      localeId: getLangCode(context),
      pauseFor: const Duration(seconds: 4),
    );
    setState(() {});
  }

  void _stopListening() async {
    await _sttxt.stop();
    String t = text;
    _chatBot(types.PartialText(text: t));
    final textMessage = _buildTextMsgWithStr(t);
    _addTextMessage(textMessage);
    setState(() {});
  }

  String getLangCode(BuildContext context) {
    String langCode = context.locale.toString();
    switch (langCode) {
      case "en":
        return EnId;
      case "vi":
        return ViId;
      default:
        return EnId;
    }
  }

  Widget _bubbleBuilderInner(
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) =>
      Bubble(
        color: _user.id != message.author.id ||
                message.type == types.MessageType.image
            ? Colors.white
            : Colors.blue,
        margin: nextMessageInGroup
            ? const BubbleEdges.symmetric(horizontal: 8)
            : null,
        padding: const BubbleEdges.all(2),
        nip: nextMessageInGroup
            ? BubbleNip.no
            : _user.id != message.author.id
                ? BubbleNip.leftBottom
                : BubbleNip.rightBottom,
        child: child,
      );

  Widget _bubbleBuilder(
    Widget child, {
    required message,
    required nextMessageInGroup,
  }) =>
      _user.id == message.author.id || message.type != types.MessageType.text
          ? _bubbleBuilderInner(child,
              message: message, nextMessageInGroup: nextMessageInGroup)
          : Container(
              child: Row(
                children: [
                  Expanded(
                    flex: 7,
                    child: _bubbleBuilderInner(child,
                        message: message,
                        nextMessageInGroup: nextMessageInGroup),
                  ),
                  Expanded(
                    flex: 3,
                    child: IconButton(
                        onPressed: () {
                          types.TextMessage? m = message as types.TextMessage;
                          _speak(m.text);
                        },
                        icon: const Icon(Icons.play_circle)),
                  ),
                ],
              ),
            );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Speech to text"),
        actions: [
          IconButton(
              onPressed: () {
                switch (getLangCode(context)) {
                  case EnId:
                    context.setLocale(Locale("vi"));
                    break;
                  case ViId:
                    context.setLocale(Locale("en"));
                    break;
                  default:
                    context.setLocale(Locale("en"));
                    break;
                }
              },
              icon: Flag.fromCode(
                  getLangCode(context) == EnId ? FlagsCode.US : FlagsCode.VN,
                  height: 100,
                  width: null)),
          PopupMenuButton(
              icon: const Icon(Icons.settings),
              onSelected: (SettingItems item) {
                switch (item) {
                  case SettingItems.enableOrDisableVoiceReader:
                    enableVoiceReader = !enableVoiceReader;
                    break;
                  case SettingItems.clearMsgs:
                    getPrefs().then((value) {
                      value.remove(MsgKey);
                    });
                    setState(() {
                      _messages.clear();
                    });
                    break;
                  default:
                }
              },
              itemBuilder: ((BuildContext context) => [
                    PopupMenuItem(
                      value: SettingItems.enableOrDisableVoiceReader,
                      child: Text(enableVoiceReader == true
                          ? "disable_voice_reader".tr()
                          : "enable_voice_reader".tr()),
                    ),
                    PopupMenuItem(
                      value: SettingItems.clearMsgs,
                      child: Text("clear_messages".tr()),
                    )
                  ]))
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 74),
        child: Chat(
          theme: const DefaultChatTheme(primaryColor: Colors.blue),
          messages: _messages,
          onMessageTap: _handleMessageTap,
          onPreviewDataFetched: _handlePreviewDataFetched,
          onSendPressed: _handleSendPressed,
          showUserAvatars: true,
          showUserNames: true,
          disableImageGallery: true,
          user: _user,
          l10n: getLangCode(context) == EnId
              ? const ChatL10nEn()
              : const ChatL10nVi(),
          bubbleBuilder: _bubbleBuilder,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: _sttxt.isListening ? _stopListening : _startListening,
        child: Icon(_sttxt.isListening ? Icons.mic_off : Icons.mic),
        elevation: 0.0,
      ),
    );
  }
}
