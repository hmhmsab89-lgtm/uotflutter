import 'profile.dart';

class CallSession {
  final String id;
  final String callerId;
  final String receiverId;
  final String status; // 'calling', 'active', 'ended', 'rejected', 'missed'
  final String callType; // 'audio', 'video'
  final String? roomUrl;
  final DateTime createdAt;
  final DateTime? endedAt;
  Profile? caller;
  Profile? receiver;

  CallSession({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.status,
    required this.callType,
    this.roomUrl,
    required this.createdAt,
    this.endedAt,
    this.caller,
    this.receiver,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id'] as String,
      callerId: json['caller_id'] as String,
      receiverId: json['receiver_id'] as String,
      status: json['status'] as String? ?? 'calling',
      callType: json['call_type'] as String? ?? 'audio',
      roomUrl: json['room_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'status': status,
      'call_type': callType,
      'room_url': roomUrl,
      'created_at': createdAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
    };
  }
}
