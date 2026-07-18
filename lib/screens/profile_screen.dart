import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../models/profile.dart';
import '../models/social.dart';
import '../models/call.dart';
import 'call_screen.dart';
import 'chat_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Profile Edit fields controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _deptCtrl = TextEditingController();
  final TextEditingController _bioCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Fill current profile edits
    final svc = Provider.of<SupabaseService>(context, listen: false);
    _nameCtrl.text = svc.currentProfile?.fullName ?? '';
    _usernameCtrl.text = svc.currentProfile?.username ?? '';
    _deptCtrl.text = svc.currentProfile?.department ?? '';
    _bioCtrl.text = svc.currentProfile?.bio ?? '';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _deptCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, textAlign: TextAlign.right),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _updateProfile(SupabaseService svc) async {
    try {
      await svc.updateProfile(
        fullName: _nameCtrl.text.trim(),
        username: _usernameCtrl.text.trim().toLowerCase(),
        department: _deptCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
      );
      _showSnackBar("تمت مزامنة الملف الشخصي بنجاح! ✔️");
    } catch (e) {
      _showSnackBar("فشل التعديل: ${e.toString()}");
    }
  }

  Future<void> _uploadAvatar(SupabaseService svc) async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final path = await svc.uploadImageToBucket('avatars', svc.currentUser!.id, bytes);
      if (path != null) {
        // Update user avatar reference in Profiles table
        await svc.client.from('profiles').update({'avatar_url': path}).eq('id', svc.currentUser!.id);
        await svc.loadInitialData();
        _showSnackBar("تم تحديث الصورة الشخصية!");
      }
    } catch (e) {
      _showSnackBar("عذراً، فشل رفع الصورة.");
    }
  }

  Future<void> _createNewPost(SupabaseService svc) async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (image == null) return;

    final captionCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("نشر منشور جديد 🖼️", textDirection: TextDirection.rtl),
        content: Directionality(
          textDirection: TextDirection.rtl,
          child: TextField(
            controller: captionCtrl,
            maxLines: 3,
            decoration: const InputDecoration(hintText: "ماذا يدور في ذهنك؟ اكتب تعليقاً..."),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("نشر")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final bytes = await image.readAsBytes();
      final path = await svc.uploadImageToBucket('posts', 'post-${svc.currentUser!.id}', bytes);
      if (path != null) {
        await svc.createPost(captionCtrl.text.trim(), path);
        _showSnackBar("تم نشر مساهمتك بنجاح!");
      }
    } catch (e) {
      _showSnackBar("فشل النشر");
    }
  }

  Future<void> _uploadStory(SupabaseService svc) async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;

    try {
      final bytes = await image.readAsBytes();
      final path = await svc.uploadImageToBucket('stories', 'story-${svc.currentUser!.id}', bytes);
      if (path != null) {
        await svc.createStory(path, "قصة جديدة");
        _showSnackBar("تمت إضافة قصتك بنجاح ⚡");
      }
    } catch (e) {
      _showSnackBar("خطأ في إضافة القصة");
    }
  }

  // Draw full social stories row
  Widget _buildStoryRow(SupabaseService svc) {
    // Unique list of authors for distinct stories circles display
    final Map<String, List<Story>> storiesByAuthor = {};
    for (var s in svc.activeStories) {
      storiesByAuthor.putIfAbsent(s.userId, () => []).add(s);
    }

    return Container(
      height: 96,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        children: [
          // Create story element
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _uploadStory(svc),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: const Icon(Icons.add, color: Color(0xFF1E3A8A), size: 28),
                  ),
                ),
                const SizedBox(height: 4),
                const Text("قصتك", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Render active authors stories
          ...storiesByAuthor.entries.map((entry) {
            final firstStory = entry.value.first;
            final count = entry.value.length;
            final author = firstStory.author;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _viewStories(entry.value, svc),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.purple, Colors.amber, Colors.pink]),
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: CircleAvatar(
                          radius: 25,
                          backgroundImage: author?.avatarUrl != null
                              ? NetworkImage(svc.getPublicImageUrl('avatars', author!.avatarUrl!))
                              : null,
                          child: author?.avatarUrl == null ? Text(author?.fullName?[0] ?? "؟") : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    author?.fullName ?? "مستخدِم",
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Modal displaying active stories in sliding view
  void _viewStories(List<Story> stories, SupabaseService svc) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "StoriesViewer",
      pageBuilder: (context, _, __) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                itemCount: stories.length,
                itemBuilder: (context, index) {
                  final story = stories[index];
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      CachedNetworkImageMock(
                        imageUrl: svc.getPublicImageUrl('stories', story.imageUrl),
                      ),
                      Positioned(
                        bottom: 80,
                        left: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.black54,
                          child: Text(
                            story.caption ?? "",
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    ],
                  );
                },
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<SupabaseService>(context);
    final profile = svc.currentProfile;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text("ملف الحرم والمجتمع", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.amber,
          tabs: const [
            Tab(text: "الإعدادات"),
            Tab(text: "الأصدقاء"),
            Tab(text: "سجل الاتصال"),
            Tab(text: "المنشورات"),
          ],
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildProfileTab(svc, profile),
            _buildPeopleTab(svc),
            _buildCallsTab(svc),
            _buildFeedTab(svc),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: PROFILE SETTINGS ---

  Widget _buildProfileTab(SupabaseService svc, Profile? profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => _uploadAvatar(svc),
                  child: CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: profile?.avatarUrl != null
                        ? NetworkImage(svc.getPublicImageUrl('avatars', profile!.avatarUrl!))
                        : null,
                    child: profile?.avatarUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF1E3A8A), shape: BoxShape.circle),
                    child: const Icon(Icons.edit, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: "الاسم الكامل", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _usernameCtrl,
            decoration: const InputDecoration(labelText: "اسم المستخدم", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _deptCtrl,
            decoration: const InputDecoration(labelText: "القسم الأكاديمي", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: "نبذة شخصية (Bio)", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _updateProfile(svc),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text("حفظ التغييرات", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: PEOPLE SEARCH & MESSAGES REQ ---

  Widget _buildPeopleTab(SupabaseService svc) {
    final searchController = TextEditingController();
    List<Profile> filteredList = svc.profiles.where((p) => p.id != svc.currentUser?.id).toList();

    return StatefulBuilder(
      builder: (context, setPeopleState) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: "ابحث عن طلاب، زملاء الدراسة...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onChanged: (val) {
                setPeopleState(() {
                  filteredList = svc.profiles.where((p) {
                    if (p.id == svc.currentUser?.id) return false;
                    final q = val.toLowerCase();
                    return (p.fullName ?? "").toLowerCase().contains(q) ||
                        (p.username ?? "").toLowerCase().contains(q) ||
                        (p.department ?? "").toLowerCase().contains(q);
                  }).toList();
                });
              },
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("لا توجد نتائج بحث"))
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final p = filteredList[index];
                      final isOnline = p.isSharingLocation && p.lastLocationUpdate != null && 
                          DateTime.now().difference(p.lastLocationUpdate!).inSeconds < 90;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: p.avatarUrl != null
                              ? NetworkImage(svc.getPublicImageUrl('avatars', p.avatarUrl!))
                              : null,
                        ),
                        title: Text(p.fullName ?? ''),
                        subtitle: Text("${p.department ?? ''}  ${isOnline ? '🟢 متصل' : '🔴 غير متصل'}"),
                        trailing: IconButton(
                          icon: const Icon(Icons.send_rounded, color: Colors.blue),
                          onPressed: () async {
                            final chatRoom = await svc.checkOrCreateConversation(p.id);
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MessagesScreen(conversationId: chatRoom, otherProfile: p),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  // --- TAB 3: CALL LOGS ---

  Widget _buildCallsTab(SupabaseService svc) {
    if (svc.calls.isEmpty) {
      return const Center(child: Text("سجل المعاملات والمكالمات فارغ"));
    }

    return ListView.builder(
      itemCount: svc.calls.length,
      itemBuilder: (context, index) {
        final call = svc.calls[index];
        final isIncoming = call.receiverId == svc.currentUser?.id;
        final peer = isIncoming ? call.caller : call.receiver;

        final isAudio = call.callType == 'audio';
        final statusAr = {
          'calling': 'يرن',
          'active': 'نشط',
          'ended': 'منتهية',
          'rejected': 'مرفوضة',
          'missed': 'فائتة'
        }[call.status] ?? call.status;

        return ListTile(
          leading: Icon(
            isIncoming ? Icons.call_received : Icons.call_made,
            color: call.status == 'missed' ? Colors.red : Colors.green,
          ),
          title: Text(peer?.fullName ?? "مستخِدم الحرم"),
          subtitle: Text("نوع: ${isAudio ? 'صوت' : 'فيديو'} - الحالة: $statusAr"),
          trailing: Text(
            "${call.createdAt.hour}:${call.createdAt.minute}",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        );
      },
    );
  }

  // --- TAB 4: SOCIAL POST FEED & COMMENTS ---

  Widget _buildFeedTab(SupabaseService svc) {
    return Column(
      children: [
        // Story row
        _buildStoryRow(svc),
        const Divider(),
        
        // Feed trigger & listing
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => svc.loadSocialFeed(),
            child: svc.feedPosts.isEmpty
                ? const Center(child: Text("لا توجد منشورات، التقط اللحظة الأولى!"))
                : ListView.builder(
                    itemCount: svc.feedPosts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: ElevatedButton.icon(
                            onPressed: () => _createNewPost(svc),
                            icon: const Icon(Icons.photo_camera, color: Colors.white),
                            label: const Text("شارك منشوراً جديداً مع زملائك", style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        );
                      }
                      
                      final post = svc.feedPosts[index - 1];
                      return _buildPostCard(post, svc);
                    },
                  ),
          ),
        )
      ],
    );
  }

  Widget _buildPostCard(Post post, SupabaseService svc) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Author Header
          ListTile(
            leading: CircleAvatar(
              backgroundImage: post.author?.avatarUrl != null
                  ? NetworkImage(svc.getPublicImageUrl('avatars', post.author!.avatarUrl!))
                  : null,
            ),
            title: Text(post.author?.fullName ?? "مستخِدم", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(post.author?.department ?? ''),
          ),

          // Caption space
          if (post.caption != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Text(post.caption!, style: const TextStyle(fontSize: 14)),
            ),

          // Image Attachment Space
          if (post.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.zero),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 280),
                width: double.infinity,
                child: Image.network(
                  svc.getPublicImageUrl('posts', post.imageUrl!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),

          // Likes Actions Row bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                    color: post.likedByMe ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => svc.toggleLikePost(post),
                ),
                Text("${post.likeCount}"),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.grey),
                  onPressed: () => _showCommentsBottomSheet(post, svc),
                ),
                Text("${post.commentCount}"),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Post Comments bottom modal panel sheet
  void _showCommentsBottomSheet(Post post, SupabaseService svc) {
    final commentCtrl = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) => FutureBuilder<List<PostComment>>(
            future: svc.fetchComments(post.id),
            builder: (context, snapshot) {
              final comments = snapshot.data ?? [];

              return Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 20, right: 20, top: 20
                ),
                height: 480,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    children: [
                      const Text("التعليقات والمناقشة 💬", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      Expanded(
                        child: snapshot.connectionState == ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator())
                            : comments.isEmpty
                                ? const Center(child: Text("لا توجد تعليقات بعد، كن الأول في الرد!"))
                                : ListView.builder(
                                    itemCount: comments.length,
                                    itemBuilder: (c, i) {
                                      final comm = comments[i];
                                      return ListTile(
                                        leading: CircleAvatar(
                                          backgroundImage: comm.author?.avatarUrl != null
                                              ? NetworkImage(svc.getPublicImageUrl('avatars', comm.author!.avatarUrl!))
                                              : null,
                                        ),
                                        title: Text(comm.author?.fullName ?? "مستخِدم", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        subtitle: Text(comm.content, style: const TextStyle(fontSize: 13)),
                                      );
                                    },
                                  ),
                      ),
                      
                      // comment send bar
                      Container(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: commentCtrl,
                                decoration: InputDecoration(
                                  hintText: "أضف تعليقاً لطيفاً...",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.send, color: Color(0xFF1E3A8A)),
                              onPressed: () async {
                                if (commentCtrl.text.isEmpty) return;
                                await svc.addComment(post.id, commentCtrl.text);
                                commentCtrl.clear();
                                setSheetState(() {}); // rebuild local future
                              },
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Cached Images Helper representation
class CachedNetworkImageMock extends StatelessWidget {
  final String imageUrl;

  const CachedNetworkImageMock({
    super.key,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.black87,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
          ),
        );
      },
    );
  }
}
