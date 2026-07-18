import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/profile.dart';
import '../models/message.dart';

class MessagesScreen extends StatefulWidget {
  final String conversationId;
  final Profile otherProfile;

  const MessagesScreen({
    super.key,
    required this.conversationId,
    required this.otherProfile,
  });

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<Message> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _chatChannel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToLiveChat();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollController.dispose();
    if (_chatChannel != null) {
      final svc = Provider.of<SupabaseService>(context, listen: false);
      svc.client.removeChannel(_chatChannel!);
    }
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadMessages() async {
    final svc = Provider.of<SupabaseService>(context, listen: false);
    try {
      final list = await svc.fetchChatMessages(widget.conversationId);
      setState(() {
        _messages = list;
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // Set up real-time WebSocket channel for incoming messages in this thread
  void _subscribeToLiveChat() {
    final svc = Provider.of<SupabaseService>(context, listen: false);
    _chatChannel = svc.client
        .channel('messages-room-${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (payload) {
            final newMsg = Message.fromJson(payload.newRecord);
            setState(() {
              // Ensure we do not add duplicates
              if (!_messages.any((m) => m.id == newMsg.id)) {
                _messages.add(newMsg);
              }
            });
            _scrollToBottom();
            
            // Mark as read in supabase background if received from peer
            if (newMsg.senderId != svc.currentUser?.id) {
              svc.client
                  .from('messages')
                  .update({'read_at': DateTime.now().toIso8601String()})
                  .eq('id', newMsg.id);
            }
          },
        )
        .subscribe();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    _msgCtrl.clear();
    final svc = Provider.of<SupabaseService>(context, listen: false);

    try {
      await svc.sendChatMessage(widget.conversationId, text);
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("عذراً، فشل إرسال الرسالة.")),
      );
    }
  }

  Future<void> _sendImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    final svc = Provider.of<SupabaseService>(context, listen: false);
    
    // Show preview dialog first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("إرسال صورة؟", textDirection: TextDirection.rtl),
        content: const Text("هل تود مشاركة هذه الصورة في الدردشة؟", textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("موافق")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final bytes = await image.readAsBytes();
      final path = await svc.uploadImageToBucket('chat_attachments', 'attach-${svc.currentUser!.id}', bytes);
      if (path != null) {
        final publicUrl = svc.getPublicImageUrl('chat_attachments', path);
        await svc.sendChatMessage(
          widget.conversationId,
          "",
          attachUrl: publicUrl,
          attachType: "image",
        );
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("فشل في إرسال المرفق")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<SupabaseService>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherProfile.avatarUrl != null
                  ? NetworkImage(svc.getPublicImageUrl('avatars', widget.otherProfile.avatarUrl!))
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherProfile.fullName ?? 'مستخِدم الحرم',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  widget.otherProfile.isSharingLocation ? "متصل الآن" : "غير متصل",
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                )
              ],
            )
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text("لا توجد رسائل سابقة. ابدأ المحادثة الآن!"))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == svc.currentUser?.id;
                          
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16).copyWith(
                                  topRight: isMe ? Radius.zero : null,
                                  topLeft: !isMe ? Radius.zero : null,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  if (msg.attachmentUrl != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        msg.attachmentUrl!,
                                        width: 200,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  if (msg.content != null && msg.content!.isNotEmpty)
                                    Text(
                                      msg.content!,
                                      style: TextStyle(
                                        color: isMe ? Colors.white : Colors.black87,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          
          // Send Message Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_outlined, color: Colors.blue),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: TextField(
                      controller: _msgCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: "اكتب رسالتك هنا...",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send_rounded, color: Color(0xFF1E3A8A)),
                  onPressed: _send,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
