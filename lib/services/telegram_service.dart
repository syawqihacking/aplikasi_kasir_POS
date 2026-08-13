import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';

class TelegramService {
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  Future<String?> _getBotToken() async {
    // TODO: Ganti 'TOKEN_BOT_ANDA' dengan token bot Telegram Anda
    return '8651571953:AAHpwGPt49I-SCxQjnROCzGlH9V-bNTB7aE';
  }

  Future<String?> _getChatId() async {
    // TODO: Ganti 'CHAT_ID_ANDA' dengan Chat ID Telegram Anda
    return '8373029727';
  }

  Future<bool> isConfigured() async {
    final token = await _getBotToken();
    final chatId = await _getChatId();
    return token != null && token.isNotEmpty && chatId != null && chatId.isNotEmpty;
  }

  Future<bool> sendMessage(String message) async {
    try {
      final token = await _getBotToken();
      final chatId = await _getChatId();
      if (token == null || chatId == null) return false;

      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text': message,
          'parse_mode': 'Markdown',
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending telegram message: $e');
      return false;
    }
  }

  Future<bool> sendDocument(File file, {String? caption}) async {
    try {
      final token = await _getBotToken();
      final chatId = await _getChatId();
      if (token == null || chatId == null) return false;

      final url = Uri.parse('https://api.telegram.org/bot$token/sendDocument');
      var request = http.MultipartRequest('POST', url)
        ..fields['chat_id'] = chatId
        ..files.add(await http.MultipartFile.fromPath('document', file.path));

      if (caption != null) {
        request.fields['caption'] = caption;
      }

      var response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending telegram document: $e');
      return false;
    }
  }
}
