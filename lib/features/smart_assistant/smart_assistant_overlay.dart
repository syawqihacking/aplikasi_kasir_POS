import 'package:flutter/material.dart';
import 'presentation/chat_controller.dart';
import 'presentation/chat_screen.dart';
import '../../theme/app_colors.dart';

class SmartAssistantOverlay extends StatefulWidget {
  final Widget child;

  const SmartAssistantOverlay({super.key, required this.child});

  @override
  State<SmartAssistantOverlay> createState() => _SmartAssistantOverlayState();
}

class _SmartAssistantOverlayState extends State<SmartAssistantOverlay> {
  @override
  void initState() {
    super.initState();
    globalChatController.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    globalChatController.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        
        // Chat Panel
        if (globalChatController.isOpen)
          Positioned(
            bottom: 90,
            right: 24,
            child: SizedBox(
              width: 400,
              height: 600,
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => const Material(
                      color: Colors.transparent,
                      child: ChatScreenPanel(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
        // Floating Action Button
        Positioned(
          bottom: 24,
          right: 24,
          child: Material(
            color: Colors.transparent,
            child: FloatingActionButton(
              onPressed: () => globalChatController.toggleChat(),
              backgroundColor: AppColors.primary,
              child: Icon(
                globalChatController.isOpen ? Icons.close : Icons.support_agent,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
