import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/assistant_response.dart';
import '../domain/intent_matcher.dart';
import '../domain/command_handler.dart';
import '../data/assistant_repository.dart';

class ChatController extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  final CommandHandler _commandHandler;
  final Uuid _uuid = const Uuid();

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  ChatController() : _commandHandler = CommandHandler(AssistantRepository()) {
    // Add initial greeting message
    _addMessage(
      text: 'Halo! Saya Smart Assistant DashDock. Silakan pilih menu di bawah ini untuk memulai atau ketik pertanyaan Anda:',
      isFromUser: false,
      response: AssistantResponse(
        summaryText: '',
        type: ResponseType.actionButtons,
        payload: {
          'actions': [
            {'label': '📊 Penjualan Hari Ini', 'message': 'penjualan hari ini'},
            {'label': '💰 Laba Hari Ini', 'message': 'laba hari ini'},
            {'label': '⚠️ Cek Stok Menipis', 'message': 'stok menipis'},
            {'label': '🏆 Produk Terlaris', 'message': 'produk terlaris'},
            {'label': '📥 Unduh Laporan', 'message': 'download laporan'},
            {'label': '🛒 Buka Kasir (POS)', 'route': '/pos'},
            {'label': '📈 Buka Laporan Bisnis', 'route': '/reports'},
          ]
        }
      ),
    );
  }

  void toggleChat() {
    _isOpen = !_isOpen;
    notifyListeners();
  }

  void _addMessage({required String text, required bool isFromUser, AssistantResponse? response}) {
    _messages.add(
      ChatMessage(
        id: _uuid.v4(),
        text: text,
        isFromUser: isFromUser,
        timestamp: DateTime.now(),
        response: response,
      ),
    );
    notifyListeners();
  }

  Future<void> processInput(String input) async {
    if (input.trim().isEmpty) return;

    // Add user message
    _addMessage(text: input, isFromUser: true);

    // Show typing indicator (we can just delay a bit for realism or process immediately)
    // Here we just process immediately for now.
    final matchResult = IntentMatcher.match(input);
    final dateRange = DateRangeParser.parse(input) ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(hours: 24)), 
      end: DateTime.now()
    );

    try {
      final response = await _commandHandler.execute(matchResult, dateRange);
      _addMessage(
        text: response.summaryText,
        isFromUser: false,
        response: response,
      );
    } catch (e) {
      _addMessage(
        text: 'Maaf, terjadi kesalahan saat memproses permintaan Anda: $e',
        isFromUser: false,
      );
    }
  }
}

// Global singleton instance for the app
final globalChatController = ChatController();
