import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'call_service.dart';

// Background handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  print("Handling a background message: ${message.messageId}");
  
  if (message.data['type'] == 'call') {
    final callerName = message.data['callerName'] ?? 'Unknown Caller';
    final callerAvatar = message.data['callerAvatar'] ?? '';
    final callId = message.data['callId'] ?? '';
    
    await CallService().showIncomingCall(
      callerName: callerName,
      callerAvatar: callerAvatar,
      callId: callId,
    );
  }
}

// Background handler for Local Notifications (Action buttons like Reply)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  print('notification(${notificationResponse.id}) action tapped: '
      '${notificationResponse.actionId} with'
      ' payload: ${notificationResponse.payload}');
  
  if (notificationResponse.actionId == 'reply_action') {
    final String? replyText = notificationResponse.input;
    print("Direct Reply Received: $replyText");
    // TODO: Send this reply to your backend (Supabase)
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'high_importance_channel';
  static const String channelName = 'High Importance Notifications';
  static const String replyActionId = 'reply_action';

  Future<void> init() async {
    // 1. Initialize Firebase Messaging Background Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            // iOS setup...
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle foreground notification tap
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 3. Create Android Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: 'This channel is used for important notifications.',
      importance: Importance.high,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Request Permissions for FCM
    await FirebaseMessaging.instance.requestPermission();

    // 5. Listen to Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      
      if (message.notification != null && message.data['type'] == 'chat') {
        showChatNotification(message);
      }
    });
  }

  Future<void> showChatNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Create the reply action
    const AndroidNotificationAction replyAction = AndroidNotificationAction(
      replyActionId,
      'Reply',
      icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      inputs: [
        AndroidNotificationActionInput(
          label: 'Type your message...',
        ),
      ],
      showsUserInterface: false, // Don't open the app when replying
    );

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[replyAction],
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: jsonEncode(message.data),
    );
  }
}
