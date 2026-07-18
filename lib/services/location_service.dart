import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  static final LatLng campusCenter = const LatLng(33.312065, 44.447231);
  static const double campusZoom = 17;

  // Real campus boundary polygon from OpenStreetMap (way 83672623)
  static final List<LatLng> campusBoundary = [
    const LatLng(33.3119617, 44.4437909),
    const LatLng(33.311878, 44.4439407),
    const LatLng(33.3117819, 44.4441177),
    const LatLng(33.3117586, 44.4441241),
    const LatLng(33.3117216, 44.4441246),
    const LatLng(33.3116521, 44.4441729),
    const LatLng(33.3115924, 44.4442076),
    const LatLng(33.3115793, 44.4442154),
    const LatLng(33.3115612, 44.4442343),
    const LatLng(33.3115283, 44.4442964),
    const LatLng(33.3095402, 44.448184),
    const LatLng(33.3093391, 44.4485771),
    const LatLng(33.3093372, 44.4486235),
    const LatLng(33.3106163, 44.4495517),
    const LatLng(33.3121673, 44.4506689),
    const LatLng(33.312219, 44.4506633),
    const LatLng(33.3122526, 44.4506336),
    const LatLng(33.3123882, 44.4503912),
    const LatLng(33.3125423, 44.4500886),
    const LatLng(33.3127095, 44.4497425),
    const LatLng(33.3128846, 44.4493908),
    const LatLng(33.3137402, 44.4477032),
    const LatLng(33.3138933, 44.4473946),
    const LatLng(33.3138372, 44.447355),
    const LatLng(33.3138573, 44.4473184),
    const LatLng(33.3138761, 44.4472842),
    const LatLng(33.3139335, 44.447322),
    const LatLng(33.3147078, 44.4457953),
    const LatLng(33.3140326, 44.4453034),
    const LatLng(33.3138469, 44.4451676),
    const LatLng(33.3133254, 44.4447795),
    const LatLng(33.3122622, 44.4440151),
    const LatLng(33.3119617, 44.4437909),
  ];

  // Helper dictionary label matching CATEGORY_LABELS
  static const Map<String, String> categoryLabels = {
    'department': 'قسم علمي',
    'cafeteria': 'كافتيريا',
    'lab': 'مختبر',
    'library': 'مكتبة',
    'auditorium': 'قاعة محاضرات',
    'mosque': 'مسجد',
    'parking': 'موقف سيارات',
    'other': 'أخرى',
  };

  static const Map<String, String> categoryIcons = {
    'department': '🏛️',
    'cafeteria': '☕',
    'lab': '🧪',
    'library': '📚',
    'auditorium': '🎓',
    'mosque': '🕌',
    'parking': '🅿️',
    'other': '📍',
  };

  // Check if position permissions are active & query the position
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Calculate distance in meters between two latlong points
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const double radius = 6371000; // earth radius in meters
    double toRad(double d) => d * pi / 180;
    
    double dLat = toRad(lat2 - lat1);
    double dLng = toRad(lng2 - lng1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(toRad(lat1)) * cos(toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    
    return 2 * radius * asin(sqrt(a));
  }

  // Ray-casting point-in-polygon algorithm checking if coordinates are within campus boundary
  static bool pointInPolygon(double lat, double lng, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      double yi = polygon[i].latitude;
      double xi = polygon[i].longitude;
      double yj = polygon[j].latitude;
      double xj = polygon[j].longitude;
      
      bool intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / (yj - yi + 1e-12) + xi);
      
      if (intersect) inside = !inside;
      j = i;
    }
    return inside;
  }

  // True if position falls in boundary, with a small 25-meter tolerance buffer
  static bool isWithinCampus(double lat, double lng) {
    if (pointInPolygon(lat, lng, campusBoundary)) return true;
    
    // Tolerance buffer: nearest vertex distance is <= 25 meters
    for (var point in campusBoundary) {
      if (distanceMeters(lat, lng, point.latitude, point.longitude) <= 25) {
        return true;
      }
    }
    return false;
  }
}
