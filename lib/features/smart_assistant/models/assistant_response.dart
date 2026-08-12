enum ResponseType { text, table, chart, actionButtons, fileDownload }

class AssistantResponse {
  final String summaryText;
  final ResponseType type;
  final Map<String, dynamic>? payload;

  AssistantResponse({
    required this.summaryText,
    required this.type,
    this.payload,
  });
}
