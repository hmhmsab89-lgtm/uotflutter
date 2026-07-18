import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../models/location.dart' as app;

class AssistantChatWidget extends StatefulWidget {
  final List<app.Location> places;
  final Function(app.Location) onLocate;

  const AssistantChatWidget({
    super.key,
    required this.places,
    required this.onLocate,
  });

  @override
  State<AssistantChatWidget> createState() => _AssistantChatWidgetState();
}

class _AssistantChatWidgetState extends State<AssistantChatWidget> {
  bool _isOpen = false;
  bool _isLoading = false;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'content': 'مرحباً 👋 أنا مساعدك الذكي للجامعة التكنولوجية. اسألني عن أي مكان أو معلومة عن الجامعة وسأرشدك إليه.',
    }
  ];

  static const List<String> _suggestions = [
    "أين مكتبة الجامعة؟",
    "ما هي أقسام الجامعة؟",
    "أقرب كافتيريا",
    "أوقات الدوام",
  ];

  app.Location? _pendingNavTarget;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Parse and handle system tools returns
  void _checkForToolCall(String text) {
    // Simple helper parser: if response contains directions/places hints or names
    final textLower = text.toLowerCase();
    for (var place in widget.places) {
      if (textLower.contains(place.name.toLowerCase()) || 
          place.name.toLowerCase().contains(textLower)) {
        setState(() {
          _pendingNavTarget = place;
        });
        break;
      }
    }
  }

  Future<void> _sendMessage(String textContent) async {
    final text = textContent.trim();
    if (text.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isLoading = true;
      _pendingNavTarget = null;
    });
    _scrollToBottom();

    final supabaseService = Provider.of<SupabaseService>(context, listen: false);

    // Setup an empty assistant bubble to receive stream
    setState(() {
      _messages.add({'role': 'assistant', 'content': ''});
    });

    try {
      final assistantMsgIndex = _messages.length - 1;
      final stream = await supabaseService.callAIAssistant(
        _messages.sublist(0, assistantMsgIndex).map((m) => {
          'role': m['role']!,
          'content': m['content']!,
        }).toList()
      );

      String accumulatedResponse = "";
      await for (var chunk in stream) {
        accumulatedResponse += chunk;
        setState(() {
          _messages[assistantMsgIndex]['content'] = accumulatedResponse;
        });
        _scrollToBottom();
      }

      // Check tool triggers
      _checkForToolCall(accumulatedResponse);

    } catch (e) {
      setState(() {
        _messages.removeLast(); // Remove assistant empty message
        _messages.add({
          'role': 'assistant',
          'content': 'عذراً، فشل الاتصال بالمساعد الذكي للجامعة التكنولوجية. يرجى تكرار المحاولة.'
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOpen) {
      // Floating button bubble
      return Positioned(
        bottom: 180,
        right: 20,
        child: FloatingActionButton(
          heroTag: 'ai_bot',
          onPressed: () => setState(() => _isOpen = true),
          backgroundColor: const Color(0xFF1E3A8A),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.assistant_outlined, color: Colors.white),
              Positioned(
                top: 0,
                left: 0,
                child: CircleAvatar(
                  radius: 4,
                  backgroundColor: Colors.green,
                ),
              )
            ],
          ),
        ),
      );
    }

    // Chat Box Drawer overlay
    return Positioned(
      bottom: 20,
      right: 20,
      child: Container(
        width: 340,
        height: 480,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () => setState(() => _isOpen = false),
                  ),
                  const Row(
                    children: [
                      Text(
                        "المساعد الذكي",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.bolt, color: Colors.amber, size: 18),
                    ],
                  ),
                ],
              ),
            ),

            // Messages list view
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isUser = message['role'] == 'user';
                    
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUser ? const Color(0xFF3B82F6) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            topRight: isUser ? Radius.zero : null,
                            topLeft: !isUser ? Radius.zero : null,
                          ),
                        ),
                        child: isUser
                            ? Text(
                                message['content'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              )
                            : MarkdownBody(
                                data: message['content'] ?? '',
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.4),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Navigation Prompt CTA if candidate found
            if (_pendingNavTarget != null && !_isLoading)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.amber.shade50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        widget.onLocate(_pendingNavTarget!);
                        setState(() {
                          _isOpen = false;
                          _pendingNavTarget = null;
                        });
                      },
                      icon: const Icon(Icons.navigation, size: 14),
                      label: Text("انطلق إلى ${_pendingNavTarget!.name}", style: const TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() => _pendingNavTarget = null),
                    ),
                  ],
                ),
              ),

            // Short Suggestion shortcuts
            if (_messages.length <= 1 && !_isLoading)
              Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestions.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return GestureDetector(
                        onTap: () => _sendMessage(item),
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(item, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // Send field box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "اسأل عن أي مكان أو قسم...",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: _sendMessage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isLoading 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: Color(0xFF1E3A8A)),
                      onPressed: () => _sendMessage(_inputController.text),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
