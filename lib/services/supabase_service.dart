import 'dart:async';
import 'dart:convert';
import 'dart:convert' show utf8;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../models/location.dart';
import '../models/message.dart';
import '../models/social.dart';
import '../models/call.dart';

class SupabaseService extends ChangeNotifier {
  static const String supabaseUrl = "https://xuekryobqmqzcufwehbe.supabase.co";
  static const String supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh1ZWtyeW9icW1xemN1ZndlaGJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY2OTI4NjIsImV4cCI6MjA5MjI2ODg2Mn0.c8R3Wtu5eyLbRz_c-Gu4T76vYocGGCSIVbLo34vpPYw";

  final SupabaseClient client = SupabaseClient(supabaseUrl, supabaseAnonKey);

  User? _currentUser;
  Profile? _currentProfile;
  List<Profile> _profiles = [];
  List<Location> _locations = [];
  List<NotificationModel> _notifications = [];
  List<Post> _feedPosts = [];
  List<Story> _activeStories = [];
  List<CallSession> _calls = [];

  // Realtime subscription channels
  RealtimeChannel? _profilesChannel;
  RealtimeChannel? _locationsChannel;
  RealtimeChannel? _callsChannel;

  // Loading flags
  bool _isLoadingAuth = true;
  bool _isLoadingData = false;

  // Getters
  User? get currentUser => _currentUser;
  Profile? get currentProfile => _currentProfile;
  List<Profile> get profiles => _profiles;
  List<Location> get locations => _locations;
  List<NotificationModel> get notifications => _notifications;
  List<Post> get feedPosts => _feedPosts;
  List<Story> get activeStories => _activeStories;
  List<CallSession> get calls => _calls;
  bool get isLoadingAuth => _isLoadingAuth;
  bool get isLoadingData => _isLoadingData;

  SupabaseService() {
    _init();
  }

  Future<void> _init() async {
    _currentUser = client.auth.currentUser;
    client.auth.onAuthStateChange.listen((data) async {
      _currentUser = data.session?.user;
      if (_currentUser != null) {
        await loadInitialData();
        _subscribeToRealtime();
      } else {
        _currentProfile = null;
        _profiles.clear();
        _locations.clear();
        _feedPosts.clear();
        _activeStories.clear();
        _calls.clear();
        _unsubscribeFromRealtime();
      }
      _isLoadingAuth = false;
      notifyListeners();
    });

    if (_currentUser != null) {
      await loadInitialData();
      _subscribeToRealtime();
    }
    _isLoadingAuth = false;
    notifyListeners();
  }

  // --- AUTH SERVICES ---

  Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String username,
    required String department,
    String? redirectUrl,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'username': username,
        'department': department,
      },
      emailRedirectTo: redirectUrl,
    );
    _currentUser = response.user;
    notifyListeners();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _currentUser = response.user;
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_currentProfile != null && _currentProfile!.isSharingLocation) {
      await updateLocationSharing(false);
    }
    await client.auth.signOut();
    _currentUser = null;
    _currentProfile = null;
    notifyListeners();
  }

  Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // --- DATABASE & DATA SERVICES ---

  Future<void> loadInitialData() async {
    if (_currentUser == null) return;
    _isLoadingData = true;
    notifyListeners();

    try {
      // 1. Fetch current profile
      final profileRes = await client
          .from('profiles')
          .select()
          .eq('id', _currentUser!.id)
          .maybeSingle();
      if (profileRes != null) {
        _currentProfile = Profile.fromJson(profileRes);
      }

      // 2. Fetch all profiles
      final profilesRes = await client.from('profiles').select();
      _profiles = (profilesRes as List)
          .map((json) => Profile.fromJson(json))
          .toList();

      // 3. Fetch locations
      final locationsRes = await client.from('locations').select();
      _locations = (locationsRes as List)
          .map((json) => Location.fromJson(json))
          .toList();

      // 4. Fetch notifications
      final notifRes = await client
          .from('notifications')
          .select()
          .eq('user_id', _currentUser!.id)
          .order('created_at', ascending: false);
      _notifications = (notifRes as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();

      // 5. Fetch calls history
      final callsRes = await client
          .from('calls')
          .select()
          .eq('receiver_id', _currentUser!.id)
          .order('created_at', ascending: false)
          .limit(50);
      
      _calls = (callsRes as List)
          .map((json) {
            final session = CallSession.fromJson(json);
            session.caller = _profiles.firstWhere(
              (p) => p.id == session.callerId,
              orElse: () => Profile(id: session.callerId, isSharingLocation: false),
            );
            return session;
          })
          .toList();

      // Load Social Feed
      await loadSocialFeed();
    } catch (e) {
      if (kDebugMode) print("Error loading initial data: $e");
    } finally {
      _isLoadingData = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String username,
    required String department,
    String? bio,
  }) async {
    if (_currentUser == null) return;

    final updates = {
      'full_name': fullName,
      'username': username.toLowerCase(),
      'department': department,
      'bio': bio,
    };

    await client.from('profiles').update(updates).eq('id', _currentUser!.id);

    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(
        fullName: fullName,
        username: username.toLowerCase(),
        department: department,
        bio: bio,
      );
      notifyListeners();
    }
  }

  Future<void> updateLiveLocation(double lat, double lng) async {
    if (_currentUser == null) return;

    final updates = {
      'current_lat': lat,
      'current_lng': lng,
      'last_location_update': DateTime.now().toIso8601String(),
    };

    await client.from('profiles').update(updates).eq('id', _currentUser!.id);
  }

  Future<void> updateLocationSharing(bool isSharing) async {
    if (_currentUser == null) return;

    final updates = {
      'is_sharing_location': isSharing,
      if (!isSharing) 'status': 'offline',
      if (isSharing) 'status': 'online',
    };

    await client.from('profiles').update(updates).eq('id', _currentUser!.id);

    if (_currentProfile != null) {
      _currentProfile = _currentProfile!.copyWith(
        isSharingLocation: isSharing,
        status: isSharing ? 'online' : 'offline',
      );
      notifyListeners();
    }
  }

  // --- PLACES / LOCATIONS MANAGEMENT ---

  Future<void> addNewPlace({
    required String name,
    required String description,
    required String category,
    required double lat,
    required double lng,
  }) async {
    if (_currentUser == null) return;

    final newLoc = {
      'name': name,
      'description': description.isNotEmpty ? description : null,
      'category': category,
      'lat': lat,
      'lng': lng,
      'created_by': _currentUser!.id,
    };

    await client.from('locations').insert(newLoc);
  }

  Future<void> deletePlace(String id) async {
    await client.from('locations').delete().eq('id', id);
  }

  // --- SOCIAL FEED & STORIES ---

  Future<void> loadSocialFeed() async {
    if (_currentUser == null) return;

    try {
      // 1. Load active stories (not expired)
      final nowStr = DateTime.now().toIso8601String();
      final storiesData = await client
          .from('stories')
          .select()
          .gt('expires_at', nowStr)
          .order('created_at', ascending: true);
      
      _activeStories = (storiesData as List).map((json) {
        final story = Story.fromJson(json);
        story.author = _profiles.firstWhere(
          (p) => p.id == story.userId,
          orElse: () => Profile(id: story.userId, isSharingLocation: false),
        );
        return story;
      }).toList();

      // 2. Load all posts
      final postsData = await client
          .from('posts')
          .select()
          .order('created_at', ascending: false);

      List<Post> postsList = (postsData as List).map((json) => Post.fromJson(json)).toList();

      // Aggregate post metadata
      if (postsList.isNotEmpty) {
        final postIds = postsList.map((p) => p.id).toList();

        // Likes count & if liked by me
        final likesData = await client
            .from('post_likes')
            .select('post_id, user_id')
            .inFilter('post_id', postIds);

        // Comments count
        final commentsData = await client
            .from('post_comments')
            .select('post_id')
            .inFilter('post_id', postIds);

        final likesList = likesData as List;
        final commentsList = commentsData as List;

        for (var post in postsList) {
          post.likeCount = likesList.where((l) => l['post_id'] == post.id).length;
          post.commentCount = commentsList.where((c) => c['post_id'] == post.id).length;
          post.likedByMe = likesList.any((l) => l['post_id'] == post.id && l['user_id'] == _currentUser!.id);
          post.author = _profiles.firstWhere(
            (p) => p.id == post.userId,
            orElse: () => Profile(id: post.userId, isSharingLocation: false),
          );
        }
      }

      _feedPosts = postsList;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print("Error loading social feed: $e");
    }
  }

  Future<void> toggleLikePost(Post post) async {
    if (_currentUser == null) return;

    if (post.likedByMe) {
      await client
          .from('post_likes')
          .delete()
          .match({'post_id': post.id, 'user_id': _currentUser!.id});
      post.likedByMe = false;
      post.likeCount = post.likeCount > 0 ? post.likeCount - 1 : 0;
    } else {
      await client
          .from('post_likes')
          .insert({'post_id': post.id, 'user_id': _currentUser!.id});
      post.likedByMe = true;
      post.likeCount += 1;

      // Notify post owner
      if (post.userId != _currentUser!.id) {
        await createNotification(
          userId: post.userId,
          type: 'like',
          title: 'إعجاب جديد',
          body: '${_currentProfile?.fullName ?? "مستخدِم"} أعجب بمنشورك.',
          link: '/post/${post.id}',
        );
      }
    }
    notifyListeners();
  }

  Future<void> addComment(String postId, String content) async {
    if (_currentUser == null) return;

    await client.from('post_comments').insert({
      'post_id': postId,
      'user_id': _currentUser!.id,
      'content': content.trim(),
    });

    final post = _feedPosts.firstWhere((p) => p.id == postId);
    post.commentCount += 1;
    notifyListeners();
  }

  Future<List<PostComment>> fetchComments(String postId) async {
    final res = await client
        .from('post_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (res as List).map((json) {
      final comment = PostComment.fromJson(json);
      comment.author = _profiles.firstWhere(
        (p) => p.id == comment.userId,
        orElse: () => Profile(id: comment.userId, isSharingLocation: false),
      );
      return comment;
    }).toList();
  }

  Future<void> createPost(String? caption, String? imagePathBucket) async {
    if (_currentUser == null) return;
    await client.from('posts').insert({
      'user_id': _currentUser!.id,
      'caption': caption,
      'image_url': imagePathBucket,
    });
    await loadSocialFeed();
  }

  Future<void> createStory(String imagePathBucket, String? caption) async {
    if (_currentUser == null) return;
    await client.from('stories').insert({
      'user_id': _currentUser!.id,
      'image_url': imagePathBucket,
      'caption': caption,
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
    });
    await loadSocialFeed();
  }

  // --- NOTIFICATIONS WORK ---

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? link,
  }) async {
    await client.from('notifications').insert({
      'user_id': userId,
      'type': type,
      'title': title,
      'body': body,
      'link': link,
      'is_read': false,
    });
  }

  Future<void> markNotificationsAsRead() async {
    if (_currentUser == null) return;
    await client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', _currentUser!.id)
        .eq('is_read', false);
    
    _notifications = _notifications.map((n) {
      return NotificationModel(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        link: n.link,
        isRead: true,
        createdAt: n.createdAt,
      );
    }).toList();
    notifyListeners();
  }

  // --- IMAGES STORAGE UPLOAD WORK ---

  Future<String?> uploadImageToBucket(String bucket, String filename, Uint8List fileBytes) async {
    try {
      final path = "$filename-${DateTime.now().millisecondsSinceEpoch}.jpg";
      await client.storage.from(bucket).uploadBinary(path, fileBytes);
      return path; // Return the relative path inside bucket
    } catch (e) {
      if (kDebugMode) print("Error uploading asset storage: $e");
      return null;
    }
  }

  String getPublicImageUrl(String bucket, String path) {
    return client.storage.from(bucket).getPublicUrl(path);
  }

  // --- DIRECT MESSAGING / INBOX ---

  Future<List<Map<String, dynamic>>> loadInboxThreads() async {
    if (_currentUser == null) return [];
    
    try {
      // Find conversations containing me
      final convs = await client
          .from('conversations')
          .select()
          .or('user_a.eq.${_currentUser!.id},user_b.eq.${_currentUser!.id}')
          .order('updated_at', ascending: false);

      List<Map<String, dynamic>> threads = [];
      for (var c in convs as List) {
        final otherUserId = c['user_a'] == _currentUser!.id ? c['user_b'] : c['user_a'];
        final otherProfile = _profiles.firstWhere(
          (p) => p.id == otherUserId,
          orElse: () => Profile(id: otherUserId, isSharingLocation: false),
        );

        // Fetch last message
        final messages = await client
            .from('messages')
            .select()
            .eq('conversation_id', c['id'])
            .order('created_at', ascending: false)
            .limit(1);

        Message? lastMsg;
        if (messages != null && (messages as List).isNotEmpty) {
          lastMsg = Message.fromJson(messages[0]);
        }

        // Count unread
        final unreadCountRes = await client
            .from('messages')
            .select()
            .eq('conversation_id', c['id'])
            .neq('sender_id', _currentUser!.id)
            .isFilter('read_at', null);
        
        final unreadCount = (unreadCountRes as List).length;

        threads.add({
          'conversation_id': c['id'],
          'other_profile': otherProfile,
          'last_message': lastMsg,
          'unread_count': unreadCount,
        });
      }
      return threads;
    } catch (e) {
      if (kDebugMode) print("Error loading inbox: $e");
      return [];
    }
  }

  Future<List<Message>> fetchChatMessages(String conversationId) async {
    final res = await client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    // Mark as read
    await client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', _currentUser!.id)
        .isFilter('read_at', null);

    return (res as List).map((json) => Message.fromJson(json)).toList();
  }

  Future<void> sendChatMessage(String conversationId, String content, {String? attachUrl, String? attachType}) async {
    if (_currentUser == null) return;

    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': _currentUser!.id,
      'content': content.isNotEmpty ? content : null,
      'attachment_url': attachUrl,
      'attachment_type': attachType,
    });

    await client.from('conversations').update({
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', conversationId);
  }

  Future<String> checkOrCreateConversation(String otherUserId) async {
    if (_currentUser == null) return "";

    final res = await client
        .from('conversations')
        .select()
        .or('and(user_a.eq.${_currentUser!.id},user_b.eq.$otherUserId),and(user_a.eq.$otherUserId,user_b.eq.${_currentUser!.id})')
        .maybeSingle();

    if (res != null) {
      return res['id'] as String;
    }

    final newConv = await client.from('conversations').insert({
      'user_a': _currentUser!.id,
      'user_b': otherUserId,
    }).select().single();

    return newConv['id'] as String;
  }

  // --- CALLS INTEGRATION WORK ---

  Future<CallSession> initiateCall(String receiverId, String callType) async {
    if (_currentUser == null) throw Exception("User not signed in");

    final callRecord = {
      'caller_id': _currentUser!.id,
      'receiver_id': receiverId,
      'status': 'calling',
      'call_type': callType,
      'room_url': 'https://daily.co/mock-room-${DateTime.now().millisecondsSinceEpoch}',
    };

    final created = await client.from('calls').insert(callRecord).select().single();
    final session = CallSession.fromJson(created);
    session.receiver = _profiles.firstWhere((p) => p.id == receiverId);
    return session;
  }

  Future<void> updateCallStatus(String callId, String status) async {
    final updates = {
      'status': status,
      if (status == 'ended' || status == 'rejected' || status == 'missed')
        'ended_at': DateTime.now().toIso8601String(),
    };
    await client.from('calls').update(updates).eq('id', callId);
  }

  // --- REAL-TIME LIVE UPDATE LISTENERS ---

  void _subscribeToRealtime() {
    _unsubscribeFromRealtime();

    // 1. Subscribe to profiles changes (location mapping, offline status checking)
    _profilesChannel = client
        .channel('profiles-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            final type = payload.eventType;
            if (type == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'];
              _profiles.removeWhere((p) => p.id == oldId);
            } else {
              final updated = Profile.fromJson(payload.newRecord);
              final idx = _profiles.indexWhere((p) => p.id == updated.id);
              if (idx != -1) {
                _profiles[idx] = updated;
              } else {
                _profiles.add(updated);
              }
              if (updated.id == _currentUser?.id) {
                _currentProfile = updated;
              }
            }
            notifyListeners();
          },
        )
        .subscribe();

    // 2. Subscribe to locations changes
    _locationsChannel = client
        .channel('locations-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'locations',
          callback: (payload) {
            final type = payload.eventType;
            if (type == PostgresChangeEvent.delete) {
              final oldId = payload.oldRecord['id'];
              _locations.removeWhere((loc) => loc.id == oldId);
            } else if (type == PostgresChangeEvent.insert) {
              _locations.add(Location.fromJson(payload.newRecord));
            } else if (type == PostgresChangeEvent.update) {
              final updated = Location.fromJson(payload.newRecord);
              final idx = _locations.indexWhere((loc) => loc.id == updated.id);
              if (idx != -1) {
                _locations[idx] = updated;
              }
            }
            notifyListeners();
          },
        )
        .subscribe();

    // 3. Subscribe to calls for incoming calls
    _callsChannel = client
        .channel('calls-live')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'calls',
          callback: (payload) {
            final type = payload.eventType;
            if (type == PostgresChangeEvent.insert || type == PostgresChangeEvent.update) {
              final updatedSession = CallSession.fromJson(payload.newRecord);
              // Only react if we are the destination of the calling record
              if (updatedSession.receiverId == _currentUser?.id) {
                final idx = _calls.indexWhere((c) => c.id == updatedSession.id);
                updatedSession.caller = _profiles.firstWhere(
                  (p) => p.id == updatedSession.callerId,
                  orElse: () => Profile(id: updatedSession.callerId, isSharingLocation: false),
                );
                if (idx != -1) {
                  _calls[idx] = updatedSession;
                } else {
                  _calls.insert(0, updatedSession);
                }
                notifyListeners();
              }
            }
          },
        )
        .subscribe();
  }

  void _unsubscribeFromRealtime() {
    if (_profilesChannel != null) {
      client.removeChannel(_profilesChannel!);
      _profilesChannel = null;
    }
    if (_locationsChannel != null) {
      client.removeChannel(_locationsChannel!);
      _locationsChannel = null;
    }
    if (_callsChannel != null) {
      client.removeChannel(_callsChannel!);
      _callsChannel = null;
    }
  }

  // --- AI ASSISTANT CLIENT CALL ---

  Future<Stream<String>> callAIAssistant(List<Map<String, dynamic>> messagesList) async {
    final controller = StreamController<String>();
    
    try {
      final url = Uri.parse("$supabaseUrl/functions/v1/campus-assistant");
      final requestBody = jsonEncode({
        'messages': messagesList,
        'places': _locations.map((p) => {
          'id': p.id,
          'name': p.name,
          'category': p.category,
          'description': p.description,
          'lat': p.lat,
          'lng': p.lng,
        }).toList(),
      });

      final clientHttp = http.Client();
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer $supabaseAnonKey'
        ..body = requestBody;

      final response = await clientHttp.send(request);

      if (response.statusCode != 200) {
        controller.add("خطأ في الاتصال بالخادم: (${response.statusCode})");
        controller.close();
        return controller.stream;
      }

      // Read SSE stream
      response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.trim().isEmpty) return;
          if (!line.hasDataPrefix) return;
          
          final jsonStr = line.replaceFirst("data: ", "").trim();
          if (jsonStr == "[DONE]") {
            controller.close();
            return;
          }

          try {
            final parsed = jsonDecode(jsonStr);
            final delta = parsed['choices']?[0]?['delta'];
            if (delta != null && delta['content'] != null) {
              controller.add(delta['content'] as String);
            }
          } catch (_) {
            // chunk parse errors can happen on partial lines
          }
        },
        onError: (err) {
          controller.addError(err);
          controller.close();
        },
        onDone: () => controller.close(),
        cancelOnError: true,
      );

    } catch (e) {
      controller.add("عذراً، فشل الاتصال بالمساعد الذكي: $e");
      controller.close();
    }

    return controller.stream;
  }
}

extension on String {
  bool get hasDataPrefix => startsWith("data: ");
}
