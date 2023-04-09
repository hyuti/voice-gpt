import 'dart:convert';
import 'dart:ffi';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final ChatGPTApiKey = dotenv.env["ApiKey"];
const ChatGPTUrl = "https://api.openai.com/v1/chat/completions";
const ChatGPTModel = "gpt-3.5-turbo";
const ChatGPTMaxTokens = 100;

T? cast<T>(x) => x is T ? x : null;

class Usage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory Usage.fromJson(Map<String, dynamic> json) {
    return Usage(
        promptTokens: json["prompt_tokens"],
        completionTokens: json["completion_tokens"],
        totalTokens: json["total_tokens"]);
  }
}

class Message {
  String role;
  String content;

  Message({
    required this.role,
    required this.content,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(role: json["role"], content: json["content"]);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "role": role,
      "content": content,
    };
  }
}

class Choice {
  final int index;
  final Message message;
  final String finishReason;

  const Choice({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  factory Choice.fromJson(Map<String, dynamic> json) {
    return Choice(
        index: json["index"],
        message: Message.fromJson(json["message"]),
        finishReason: json["finish_reason"]);
  }
}

class ChatGPTResp {
  final String id;
  final String object;
  final int created;
  final Usage usage;
  final List<Choice> choices;

  const ChatGPTResp({
    required this.id,
    required this.object,
    required this.created,
    required this.usage,
    required this.choices,
  });

  factory ChatGPTResp.fromJson(Map<String, dynamic> json) {
    return ChatGPTResp(
      id: json["id"],
      object: json["object"],
      created: json["created"],
      usage: Usage.fromJson(json["usage"]),
      choices: (json["choices"] as List)
          .map((e) => Choice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatGPTSDK {
  late String apiKey = ChatGPTApiKey ?? "";
  late String url = ChatGPTUrl;
  late String model = ChatGPTModel;
  late int maxTokens = ChatGPTMaxTokens;
  late Map<String, String> headers;
  late Map<String, dynamic> body;
  late List<Message> msgs;

  ChatGPTSDK() {
    headers = <String, String>{
      "Authorization": 'Bearer $apiKey',
      "Content-Type": "application/json",
    };
    msgs = <Message>[Message(role: "user", content: "")];
    body = <String, dynamic>{
      "model": model,
      "max_tokens": maxTokens,
    };
  }

  Future<ChatGPTResp> fetch(String msg) async {
    msgs.first.content = msg;
    body.update("messages", (value) => msgs, ifAbsent: () => msgs);

    print(jsonEncode(body));
    final resp = await http.post(Uri.parse(url),
        headers: headers, body: jsonEncode(body));

    print(resp.statusCode);
    if (resp.statusCode == 200) {
      print(jsonDecode(utf8.decode(resp.bodyBytes)));
      return ChatGPTResp.fromJson(jsonDecode(utf8.decode(resp.bodyBytes)));
    } else {
      throw Exception('Failed to load response');
    }
  }
}
