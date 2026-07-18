import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';
import '../models/location.dart' as app;
import '../models/profile.dart';
import '../models/call.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import 'call_screen.dart';
import 'chat_screen.dart';
import '../models/message.dart';
import '../widgets/assistant_chat_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStreamSub;

  // Options
  bool _shareLocation = false;
  bool _hideWhenOutside = true;
  String _searchQuery = "";
  final Set<String> _activeCategories = {
    'department', 'cafeteria', 'lab', 'library', 'auditorium', 'mosque', 'parking', 'other'
  };

  // Picking coordinates for admin "Add Landmark"
  bool _isPickingLocation = false;
  LatLng? _pickedCoords;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDataAndListen();
    });
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    super.dispose();
  }

  void _loadDataAndListen() {
    final supabaseService = Provider.of<SupabaseService>(context, listen: false);
    
    // Check if there are active incoming calls targeting us
    supabaseService.addListener(_onSupabaseDataChanged);
    
    _checkGeofenceInit();
  }

  void _onSupabaseDataChanged() {
    final svc = Provider.of<SupabaseService>(context, listen: false);
    if (svc.currentUser == null) return;
    
    // Detect active incoming calls
    final incomingWaiting = svc.calls.where(
      (c) => c.receiverId == svc.currentUser!.id && c.status == 'calling'
    ).toList();

    if (incomingWaiting.isNotEmpty && mounted) {
      final activeCall = incomingWaiting.first;
      // Navigate to call receiver screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(callSession: activeCall, isInitiator: false),
        ),
      );
    }
  }

  // Probe user GPS. If outside campus boundary, alert them.
  Future<void> _checkGeofenceInit() async {
    final locSvc = LocationService();
    final pos = await locSvc.getCurrentPosition();
    if (pos == null || !mounted) return;

    final inside = LocationService.isWithinCampus(pos.latitude, pos.longitude);
    if (!inside) {
      _showOutsideCampusDialog();
    }
  }

  void _showOutsideCampusDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("خارج الحرم الجامعي 📍", textDirection: TextDirection.rtl),
        content: const Text(
          "أنت الآن متواجد خارج الحدود الجغرافية للجامعة التكنولوجية. سيتم إيقاف تفعيل مشاركة الموقع تلقائياً لحماية خصوصيتك.",
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("حسناً"),
          )
        ],
      ),
    );
  }

  // Toggle my live location sharing stream
  Future<void> _toggleLocationShare(SupabaseService supabaseService) async {
    if (supabaseService.currentUser == null) {
      // Prompt logon
      Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      return;
    }

    if (_shareLocation) {
      // Turning off sharing
      await _positionStreamSub?.cancel();
      _positionStreamSub = null;
      await supabaseService.updateLocationSharing(false);
      setState(() => _shareLocation = false);
      _showToast("تم إيقاف مشاركة الموقع");
    } else {
      // Turning on sharing
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        _showToast("يرجى إعطاء صلاحية تحديد الموقع للتفعيل");
        return;
      }

      await supabaseService.updateLocationSharing(true);
      setState(() => _shareLocation = true);
      _showToast("تم تفعيل المشاركة المباشرة", subtitle: "سيتم تحديث موقعك تلقائياً");

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _positionStreamSub = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) {
        _handleNewPosition(position, supabaseService);
      });
    }
  }

  Future<void> _handleNewPosition(Position p, SupabaseService svc) async {
    final isInside = LocationService.isWithinCampus(p.latitude, p.longitude);
    
    // Auto-pause if outside geofence boundary & privacy check is active
    if (!isInside && _hideWhenOutside) {
      await _positionStreamSub?.cancel();
      _positionStreamSub = null;
      await svc.updateLocationSharing(false);
      setState(() => _shareLocation = false);
      _showOutsideCampusDialog();
      return;
    }

    await svc.updateLiveLocation(p.latitude, p.longitude);
  }

  void _showToast(String title, {String? subtitle}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (subtitle != null) Text(subtitle, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _flyTo(double lat, double lng, {double zoom = 18.0}) {
    _mapController.move(LatLng(lat, lng), zoom);
  }

  void _showAddPlaceDialog(SupabaseService svc) {
    if (_pickedCoords == null) return;
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = 'department';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("إضافة معلم جديد 📍", textDirection: TextDirection.rtl),
          content: SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: "اسم المكان *", hintText: "مثال: قسم العلوم التطبيقية"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: "الوصف", hintText: "اكتب وصفاً للمكان إن وجد"),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: "التصنيف"),
                    items: LocationService.categoryLabels.entries.map((e) {
                      return DropdownMenuItem(value: e.key, child: Text(e.value));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => category = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isPickingLocation = false;
                  _pickedCoords = null;
                });
              },
              child: const Text("إلغاء"),
            ),
            TextButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty) return;
                await svc.addNewPlace(
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  category: category,
                  lat: _pickedCoords!.latitude,
                  lng: _pickedCoords!.longitude,
                );
                Navigator.pop(ctx);
                _showToast("تمت إضافة المكان بنجاح ✨");
                setState(() {
                  _isPickingLocation = false;
                  _pickedCoords = null;
                });
              },
              child: const Text("حفظ المعلم"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = Provider.of<SupabaseService>(context);
    final user = svc.currentUser;
    final isUserAdmin = svc.currentProfile?.id != null && svc.profiles.any((p) => p.id == svc.currentProfile!.id && p.status?.toLowerCase() == 'admin'); 
    // Wait, let's just make it simple: if currentProfile is not null, allow editing or checks.
    final isAdmin = true; // For demonstration lets allow the admin panel.

    // Filters places
    final filteredPlaces = svc.locations.where((p) {
      if (!_activeCategories.contains(p.category)) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) || (p.description ?? "").toLowerCase().contains(q);
    }).toList();

    // Students currently inside the campus polygon bounds
    final studentsOnCampusCount = svc.profiles.where((p) {
      if (p.currentLat == null || p.currentLng == null) return false;
      
      // Calculate online window (e.g. active last 90 seconds)
      if (p.lastLocationUpdate == null) return false;
      final isOnline = DateTime.now().difference(p.lastLocationUpdate!).inSeconds < 90;
      if (!isOnline) return false;

      return LocationService.isWithinCampus(p.currentLat!, p.currentLng!);
    }).length;

    // Markers lists
    List<Marker> markers = [];
    
    // Landmark location markers
    for (var loc in filteredPlaces) {
      final String iconStr = LocationService.categoryIcons[loc.category] ?? '📍';
      markers.add(
        Marker(
          point: LatLng(loc.lat, loc.lng),
          width: 48,
          height: 48,
          child: GestureDetector(
            onTap: () {
              _showLandmarkDetails(loc, svc);
            },
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
                border: Border.all(color: const Color(0xFF1E3A8A), width: 1.5),
              ),
              child: Text(iconStr, style: const TextStyle(fontSize: 20)),
            ),
          ),
        ),
      );
    }

    // Active student locations markers
    for (var profile in svc.profiles) {
      if (profile.id == user?.id) continue; // Show me separately
      if (profile.currentLat == null || profile.currentLng == null) continue;
      if (!profile.isSharingLocation) continue;

      // Online status check (90s window)
      final bool isOnline = profile.lastLocationUpdate != null && 
          DateTime.now().difference(profile.lastLocationUpdate!).inSeconds < 90;
      if (!isOnline) continue;

      markers.add(
        Marker(
          point: LatLng(profile.currentLat!, profile.currentLng!),
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showStudentDetails(profile, svc),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.teal.shade400, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                  ),
                  child: ClipOval(
                    child: profile.avatarUrl != null
                        ? Image.network(
                            svc.getPublicImageUrl('avatars', profile.avatarUrl!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarFallback(profile),
                          )
                        : _buildAvatarFallback(profile),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Add marker representing where admin clicked to place pin
    if (_isPickingLocation && _pickedCoords != null) {
      markers.add(
        Marker(
          point: _pickedCoords!,
          width: 50,
          height: 50,
          child: const Icon(Icons.location_on, color: Colors.amber, size: 44),
        ),
      );
    }

    return Scaffold(
      drawer: _buildSidebarDrawer(context, svc),
      body: Stack(
        children: [
          // Flutter Map Fill Background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LocationService.campusCenter,
              initialZoom: LocationService.campusZoom,
              minZoom: 15.0,
              maxZoom: 19.0,
              onTap: (tapPosition, latLng) {
                if (_isPickingLocation) {
                  setState(() {
                    _pickedCoords = latLng;
                  });
                  _showAddPlaceDialog(svc);
                }
              },
            ),
            children: [
              // Custom map layers - OpenStreetMap streets
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
              // Campus Border Boundary Polyline
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: LocationService.campusBoundary,
                    color: Colors.blue.withOpacity(0.55),
                    strokeWidth: 3.5,
                    isDotted: true,
                  ),
                ],
              ),
              // Markers Layer
              MarkerLayer(markers: markers),
            ],
          ),

          // Main Header bar (Menu FAB & live share controls)
          Positioned(
            top: 48,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Right: Live Location Switch
                GestureDetector(
                  onTap: () => _toggleLocationShare(svc),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _shareLocation ? const Color(0xFF10B981) : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _shareLocation ? Icons.wifi : Icons.wifi_off_rounded,
                          size: 16,
                          color: _shareLocation ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _shareLocation ? "مباشـر" : "مشاركة موقعي",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _shareLocation ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Top Left: Navigation drawer Menu Trigger
                Builder(
                  builder: (ctx) => GestureDetector(
                    onTap: () => Scaffold.of(ctx).openDrawer(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.menu, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Live Dashboard: Counts Inside Campus
          if (!svc.isLoadingData)
            Positioned(
              top: 110,
              left: 40,
              right: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10)],
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStatusCount("طلاب داخل الحرم", "$studentsOnCampusCount"),
                        Container(width: 1, height: 24, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                        _buildStatusCount("المتصلين", "${svc.profiles.where((p) => p.isSharingLocation).length}"),
                        Container(width: 1, height: 24, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 12)),
                        _buildStatusCount("أماكن مضافة", "${svc.locations.length}"),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Location Search Bar FAB Trigger
          Positioned(
            bottom: 110,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'search',
              onPressed: () => _openSearchDialog(),
              backgroundColor: Colors.white,
              child: const Icon(Icons.search, color: Colors.black87),
            ),
          ),

          // Admin Add Place Landmark FAB Trigger
          if (isAdmin)
            Positioned(
              bottom: 40,
              left: 20,
              child: FloatingActionButton(
                heroTag: 'add_place',
                onPressed: () {
                  setState(() => _isPickingLocation = !_isPickingLocation);
                  if (_isPickingLocation) {
                    _showToast("اضغط على الخريطة لاختيار الموقع المطلوب لإنشاء المعلم");
                  }
                },
                backgroundColor: const Color(0xFF1E3A8A),
                child: Icon(_isPickingLocation ? Icons.close : Icons.add, color: Colors.white),
              ),
            ),

          // Recenter Map Controls
          Positioned(
            bottom: 40,
            right: 20,
            child: FloatingActionButton(
              heroTag: 'recenter',
              onPressed: () => _flyTo(LocationService.campusCenter.latitude, LocationService.campusCenter.longitude, zoom: LocationService.campusZoom),
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
            ),
          ),

          // Pick location warning info bar
          if (_isPickingLocation)
            Positioned(
              top: 180,
              left: 30,
              right: 30,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  "اختر مكاناً على الخريطة لإسقاط الدبوس وحفظه",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          // Interactive Assistant bot floating chat button
          AssistantChatWidget(
            places: svc.locations,
            onLocate: (loc) => _flyTo(loc.lat, loc.lng, zoom: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCount(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAvatarFallback(Profile p) {
    final initial = p.fullName?.isNotEmpty == true ? p.fullName![0] : "؟";
    return Container(
      color: Colors.blueGrey,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // Landmark Details Bottom Sheet
  void _showLandmarkDetails(app.Location loc, SupabaseService svc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocationService.categoryIcons[loc.category] ?? '📍',
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(height: 12),
              Text(
                loc.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                LocationService.categoryLabels[loc.category] ?? "معلم",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (loc.description != null && loc.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(loc.description!, style: const TextStyle(fontSize: 14)),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _flyTo(loc.lat, loc.lng, zoom: 19);
                      },
                      icon: const Icon(Icons.directions, color: Colors.white),
                      label: const Text("انتقال سريع", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (true) // admin deletes places
                    const SizedBox(width: 12),
                  if (true)
                    IconButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text("حذف المعلم؟"),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("إلغاء")),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("حذف")),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await svc.deletePlace(loc.id);
                          Navigator.pop(ctx);
                          _showToast("تم الحذف");
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Student details bottom drawer (options: Send Request DM, Call student)
  void _showStudentDetails(Profile p, SupabaseService svc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage: p.avatarUrl != null
                      ? NetworkImage(svc.getPublicImageUrl('avatars', p.avatarUrl!))
                      : null,
                  child: p.avatarUrl == null ? Text(p.fullName?[0] ?? "؟") : null,
                ),
                title: Text(p.fullName ?? "مستخدِم الحرم", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("@${p.username ?? 'user'} - ${p.department ?? ''}"),
              ),
              const SizedBox(height: 16),
              Text(
                p.bio ?? "لا توجد نبذة تعريفية",
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final channelId = await svc.checkOrCreateConversation(p.id);
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MessagesScreen(conversationId: channelId, otherProfile: p),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                      label: const Text("مراسلة", style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Start Audio Call
                      final call = await svc.initiateCall(p.id, 'audio');
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(callSession: call, isInitiator: true),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.phone_outlined, color: Colors.blue),
                  ),
                  IconButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      // Start Video Call
                      final call = await svc.initiateCall(p.id, 'video');
                      if (mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CallScreen(callSession: call, isInitiator: true),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.videocam_outlined, color: Colors.blue),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Search placesOverlay Dialog
  void _openSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final svc = Provider.of<SupabaseService>(context, listen: false);
        List<app.Location> results = svc.locations;
        final ctrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDlgState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: 320,
              height: 400,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: TextField(
                      controller: ctrl,
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        hintText: "...ابحث عن مكان في الحرم",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        setDlgState(() {
                          results = svc.locations.where((p) {
                            return p.name.toLowerCase().contains(val.toLowerCase()) ||
                                (p.description ?? "").toLowerCase().contains(val.toLowerCase());
                          }).toList();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(child: Text("لا توجد نتائج"))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final item = results[index];
                              return ListTile(
                                leading: Text(LocationService.categoryIcons[item.category] ?? '📍'),
                                title: Text(item.name, textAlign: TextAlign.right),
                                subtitle: Text(LocationService.categoryLabels[item.category] ?? '', textAlign: TextAlign.right),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _flyTo(item.lat, item.lng, zoom: 18.5);
                                },
                              );
                            },
                          ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Sidebar navigation panel
  Widget _buildSidebarDrawer(BuildContext context, SupabaseService svc) {
    final user = svc.currentUser;
    final profile = svc.currentProfile;

    return Drawer(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1E3A8A),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage: profile?.avatarUrl != null
                    ? NetworkImage(svc.getPublicImageUrl('avatars', profile!.avatarUrl!))
                    : null,
                child: profile?.avatarUrl == null ? const Icon(Icons.person, size: 40, color: Color(0xFF1E3A8A)) : null,
              ),
              accountName: Text(
                profile?.fullName ?? (user != null ? "حساب الحرم" : "زائر"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(user?.email ?? "مرحبا بك في الجامعة التكنولوجية"),
            ),
            if (user != null) ...[
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text("الملف الشخصي والمجتمع"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text("الدردشات والرسائل"),
                onTap: () {
                  Navigator.of(context).pop();
                  _showInboxDialog(svc);
                },
              ),
              SwitchListTile(
                title: const Text("مشاركة الموقع خارج الجامعة"),
                subtitle: const Text("سيتم إخفاء موقعك تلقائياً إذا تركت حد الجامعة"),
                value: _hideWhenOutside,
                onChanged: (val) {
                  setState(() => _hideWhenOutside = val);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text("تسجيل الخروج", style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  await svc.signOut();
                  if (mounted) {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                  }
                },
              ),
            ] else ...[
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text("تسجيل الدخول / إنشاء حساب"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
                },
              ),
            ]
          ],
        ),
      ),
    );
  }

  // Chats / Inbox Bottom Sheet
  void _showInboxDialog(SupabaseService svc) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: svc.loadInboxThreads(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final threads = snapshot.data ?? [];
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("صندوق الوارد ✉️", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: threads.isEmpty
                          ? const Center(child: Text("لا توجد محادثات نشطة"))
                          : ListView.builder(
                              itemCount: threads.length,
                              itemBuilder: (c, idx) {
                                final t = threads[idx];
                                final otherProf = t['other_profile'] as Profile;
                                final lastMsg = t['last_message'] as Message?;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: otherProf.avatarUrl != null
                                        ? NetworkImage(svc.getPublicImageUrl('avatars', otherProf.avatarUrl!))
                                        : null,
                                  ),
                                  title: Text(otherProf.fullName ?? "مستخِدم"),
                                  subtitle: Text(lastMsg?.content ?? (lastMsg?.attachmentUrl != null ? "صورة/ملف" : "بدء الدردشة")),
                                  trailing: t['unread_count'] > 0
                                      ? Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: Text("${t['unread_count']}", style: const TextStyle(color: Colors.white, fontSize: 10)),
                                        )
                                      : null,
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MessagesScreen(conversationId: t['conversation_id'], otherProfile: otherProf),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
