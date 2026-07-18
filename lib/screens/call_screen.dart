import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../models/call.dart';

class CallScreen extends StatefulWidget {
  final CallSession callSession;
  final bool isInitiator;

  const CallScreen({
    super.key,
    required this.callSession,
    required this.isInitiator,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  // Option toggles
  bool _isMuted = false;
  bool _speakerOn = false;
  bool _videoOn = true;

  RealtimeChannel? _callStateChannel;
  StreamSubscription? _timeoutSub;

  @override
  void initState() {
    super.initState();
    _videoOn = widget.callSession.callType == 'video';
    _subscribeToCallUpdates();

    // Outcoming call automatically times out after 30 seconds if unanswered
    if (widget.isInitiator) {
      _timeoutSub = Future.delayed(const Duration(seconds: 30)).asStream().listen((_) {
        _endCall('missed');
      });
    }
  }

  @override
  void dispose() {
    _timeoutSub?.cancel();
    if (_callStateChannel != null) {
      final svc = Provider.of<SupabaseService>(context, listen: false);
      svc.client.removeChannel(_callStateChannel!);
    }
    super.dispose();
  }

  // Subscribe to changes in the active call record to catch declines or answers
  void _subscribeToCallUpdates() {
    final svc = Provider.of<SupabaseService>(context, listen: false);
    
    _callStateChannel = svc.client
        .channel('call-session-${widget.callSession.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'calls',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.callSession.id,
          ),
          callback: (payload) {
            final updated = CallSession.fromJson(payload.newRecord);
            
            if (updated.status == 'rejected' || 
                updated.status == 'ended' || 
                updated.status == 'missed') {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("تم إنهاء المكالمة: ${_getFriendlyStatus(updated.status)}")),
                );
                Navigator.of(context).pop();
              }
            } else if (updated.status == 'active') {
              _timeoutSub?.cancel();
              setState(() {
                // peer answered!
              });
            }
          },
        )
        .subscribe();
  }

  String _getFriendlyStatus(String status) {
    if (status == 'rejected') return 'مرفوضة';
    if (status == 'missed') return 'لم يتم الرد';
    return 'منتهية';
  }

  Future<void> _acceptCall() async {
    final svc = Provider.of<SupabaseService>(context, listen: false);
    try {
      await svc.updateCallStatus(widget.callSession.id, 'active');
    } catch (_) {}
  }

  Future<void> _endCall(String status) async {
    _timeoutSub?.cancel();
    final svc = Provider.of<SupabaseService>(context, listen: false);
    try {
      await svc.updateCallStatus(widget.callSession.id, status);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<SupabaseService>(context);
    
    // Determine target profile to display
    final peerProfile = widget.isInitiator ? widget.callSession.receiver : widget.callSession.caller;
    
    // Fetch live state from service calls list
    final liveSession = svc.calls.firstWhere(
      (c) => c.id == widget.callSession.id,
      orElse: () => widget.callSession,
    );

    final showIncomingOverlay = !widget.isInitiator && liveSession.status == 'calling';
    final isCallActive = liveSession.status == 'active';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Premium Dark Slate
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Top Call Status Header
              Column(
                children: [
                  const SizedBox(height: 20),
                  Text(
                    liveSession.callType == 'video' ? 'مكالمة فيديو' : 'مكالمة صوتية',
                    style: const TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusArabic(liveSession.status),
                    style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              // 2. Center Profile Avatar & Video Preview
              Expanded(
                child: Center(
                  child: _videoOn && isCallActive
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 240,
                            height: 320,
                            color: Colors.black87,
                            child: const Center(
                              child: Text(
                                "المعاينـة المباشـرة نشطـة 📹",
                                style: TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.white10,
                              backgroundImage: peerProfile?.avatarUrl != null
                                  ? NetworkImage(svc.getPublicImageUrl('avatars', peerProfile!.avatarUrl!))
                                  : null,
                              child: peerProfile?.avatarUrl == null
                                  ? Text(
                                      peerProfile?.fullName?[0] ?? "؟",
                                      style: const TextStyle(fontSize: 48, color: Colors.white),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              peerProfile?.fullName ?? 'طالب الحرم',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              peerProfile?.department ?? '',
                              style: const TextStyle(color: Colors.white60, fontSize: 14),
                            ),
                          ],
                        ),
                ),
              ),

              // 3. Bottom controls
              showIncomingOverlay
                  ? _buildIncomingControls()
                  : _buildConversationControls(),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusArabic(String status) {
    switch (status) {
      case 'calling':
        return widget.isInitiator ? 'جاري الاتصال...' : 'مكالمة واردة...';
      case 'active':
        return 'متصلة الآن';
      case 'rejected':
        return 'مرفوضة';
      case 'ended':
        return 'انتهت المكالمة';
      case 'missed':
        return 'لم يتم الرد';
      default:
        return 'جاري الاتصال...';
    }
  }

  // Action Buttons for receiving incoming calls
  Widget _buildIncomingControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Decline Call Button
        FloatingActionButton(
          heroTag: 'incoming_reject',
          onPressed: () => _endCall('rejected'),
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.call_end, color: Colors.white),
        ),

        // Accept Call Button
        FloatingActionButton(
          heroTag: 'incoming_accept',
          onPressed: _acceptCall,
          backgroundColor: Colors.green,
          child: const Icon(Icons.call, color: Colors.white),
        ),
      ],
    );
  }

  // Conversation control toggles: Mute, speaker, video feed, decline call
  Widget _buildConversationControls() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Speaker toggle
            IconButton(
              icon: Icon(
                _speakerOn ? Icons.volume_up : Icons.volume_down,
                color: Colors.white70,
                size: 28,
              ),
              onPressed: () {
                setState(() => _speakerOn = !_speakerOn);
              },
            ),

            // Video Feed toggle
            if (widget.callSession.callType == 'video')
              IconButton(
                icon: Icon(
                  _videoOn ? Icons.videocam : Icons.videocam_off,
                  color: Colors.white70,
                  size: 28,
                ),
                onPressed: () {
                  setState(() => _videoOn = !_videoOn);
                },
              ),

            // Mute mic toggle
            IconButton(
              icon: Icon(
                _isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white70,
                size: 28,
              ),
              onPressed: () {
                setState(() => _isMuted = !_isMuted);
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Hang Up Button
        FloatingActionButton(
          heroTag: 'hangup',
          onPressed: () => _endCall('ended'),
          backgroundColor: Colors.redAccent,
          child: const Icon(Icons.call_end, color: Colors.white),
        ),
      ],
    );
  }
}
