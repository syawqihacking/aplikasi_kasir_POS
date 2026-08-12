import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../models/assistant_response.dart';

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../../main.dart';
import '../chat_controller.dart' as import_chat_controller;

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isFromUser;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Icon(Icons.support_agent, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 0),
                  bottomRight: Radius.circular(isUser ? 0 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: GoogleFonts.outfit(
                      color: isUser ? Colors.white : AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                  if (message.response != null) _buildResponseWidget(context, message.response!),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildResponseWidget(BuildContext context, AssistantResponse response) {
    if (response.type == ResponseType.text) return const SizedBox.shrink();

    final payload = response.payload;
    if (payload == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: () {
        switch (response.type) {
          case ResponseType.table:
            return _buildTable(payload['data'] as List<dynamic>?);
          case ResponseType.actionButtons:
            return _buildActionButtons(context, payload['actions'] as List<dynamic>?);
          case ResponseType.fileDownload:
            return _buildFileDownload(context, payload);
          default:
            return const SizedBox.shrink();
        }
      }(),
    );
  }

  Widget _buildTable(List<dynamic>? data) {
    if (data == null || data.isEmpty) return const SizedBox.shrink();
    
    // Convert to List<Map<String, dynamic>>
    final List<Map<String, dynamic>> tableData = List.castFrom(data);
    if (tableData.isEmpty) return const SizedBox.shrink();

    final columns = tableData.first.keys.toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 36,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 48,
          columns: columns.map((e) => DataColumn(
            label: Text(e, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12))
          )).toList(),
          rows: tableData.map((row) => DataRow(
            cells: columns.map((col) => DataCell(
              Text(row[col].toString(), style: GoogleFonts.outfit(fontSize: 12))
            )).toList(),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, List<dynamic>? actions) {
    if (actions == null || actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((action) {
        final label = action['label'] as String;
        final route = action['route'] as String?;
        final message = action['message'] as String?;
        return ElevatedButton(
          onPressed: () {
            if (route != null) {
              final Map<String, int> routeToTabIndex = {
                '/dashboard': 0,
                '/pos': 1,
                '/products': 2,
                '/inventory': 3,
                '/transactions': 4,
                '/users': 6,
                '/settings': 7,
                '/suppliers': 8,
                '/categories': 9,
                '/reports': 10,
                '/backup': 11,
                '/audit': 12,
              };
              if (routeToTabIndex.containsKey(route)) {
                mainLayoutTabNotifier.value = routeToTabIndex[route]!;
              } else {
                appNavigatorKey.currentState!.pushNamed(route);
              }
            } else if (message != null) {
              // We need to import chat_controller or we can dispatch an event.
              // Given globalChatController is available, let's use it.
              import_chat_controller.globalChatController.processInput(message);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: Text(label, style: GoogleFonts.outfit(fontSize: 12)),
        );
      }).toList(),
    );
  }

  Widget _buildFileDownload(BuildContext context, Map<String, dynamic>? payload) {
    if (payload == null) return const SizedBox.shrink();
    final fileName = payload['fileName'] as String? ?? 'laporan.pdf';
    final fileUrl = payload['fileUrl'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file, color: AppColors.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Siap diunduh',
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.download, color: AppColors.primary),
            onPressed: () async {
              try {
                if (fileUrl.isNotEmpty) {
                  final file = File(fileUrl);
                  if (await file.exists()) {
                    final String? chosenPath = await FilePicker.platform.saveFile(
                      dialogTitle: 'Simpan Laporan',
                      fileName: fileName,
                    );
                    if (chosenPath != null) {
                      await file.copy(chosenPath);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Berhasil mengunduh dan menyimpan ke: $chosenPath'),
                            backgroundColor: AppColors.success,
                            action: SnackBarAction(
                              label: 'Buka',
                              textColor: Colors.white,
                              onPressed: () {
                                Process.run('xdg-open', [chosenPath]);
                              },
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    throw Exception("File temporary tidak ditemukan.");
                  }
                } else {
                  throw Exception("Path file kosong.");
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal mengunduh file: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
