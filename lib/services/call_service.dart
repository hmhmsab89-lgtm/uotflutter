import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:uuid/uuid.dart';

class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  Future<void> init() async {
    // Listen to call events (accept, decline, etc.)
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      
      if (event is CallEventActionCallAccept) {
        print('Call Accepted: ${event.callKitParams.id}');
        // TODO: Navigate to the active call screen
      } else if (event is CallEventActionCallDecline) {
        print('Call Declined: ${event.callKitParams.id}');
        // TODO: Notify backend that call was declined
      } else if (event is CallEventActionCallEnded) {
        print('Call Ended: ${event.callKitParams.id}');
      } else if (event is CallEventActionCallTimeout) {
        print('Call Timeout: ${event.id}');
      }
    });
  }

  /// Displays the incoming call UI.
  /// Call this when a data message of type 'call' is received via FCM.
  Future<void> showIncomingCall({
    required String callerName,
    required String callerAvatar,
    required String callId,
  }) async {
    final params = CallKitParams(
      id: callId.isNotEmpty ? callId : const Uuid().v4(),
      nameCaller: callerName,
      appName: 'UOT Smart Campus',
      avatar: callerAvatar,
      handle: callerName, // Typically a phone number or ID
      type: 0, // 0 for Audio, 1 for Video
      duration: 30000, // Ring for 30 seconds
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      extra: <String, dynamic>{'userId': '123'},
      headers: <String, dynamic>{'apiKey': 'xxxx'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#1E3A8A', // The seed color of your app
        backgroundUrl: 'https://i.pravatar.cc/500', // Example
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: "Incoming Call",
        missedCallNotificationChannelName: "Missed Call",
        isShowCallID: false,
        textAccept: 'Accept',
        textDecline: 'Decline',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }
}
