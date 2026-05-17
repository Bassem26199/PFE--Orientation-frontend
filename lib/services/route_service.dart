import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Itinéraire routier via OSRM (OpenStreetMap).
class RouteService {
  static const _baseUrl = 'https://router.project-osrm.org/route/v1/driving';

  static Future<RouteResult?> getDrivingRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl/$startLng,$startLat;$endLng,$endLat'
      '?overview=full&geometries=geojson&steps=false',
    );

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'OrientationMedicale/1.0 (PFE Flutter App)',
        },
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['code'] != 'Ok') return null;

      final routes = data['routes'];
      if (routes is! List || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'];
      if (coords is! List || coords.isEmpty) return null;

      final points = <LatLng>[];
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lng = double.tryParse(c[0].toString());
          final lat = double.tryParse(c[1].toString());
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }

      if (points.isEmpty) return null;

      final distanceM = (route['distance'] as num?)?.toDouble() ?? 0;
      final durationS = (route['duration'] as num?)?.toDouble() ?? 0;

      return RouteResult(
        points: points,
        distanceKm: distanceM / 1000,
        durationMinutes: durationS / 60,
      );
    } catch (_) {
      return null;
    }
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMinutes;

  const RouteResult({
    required this.points,
    required this.distanceKm,
    required this.durationMinutes,
  });

  String get distanceLabel =>
      distanceKm < 1 ? '${(distanceKm * 1000).round()} m' : '${distanceKm.toStringAsFixed(1)} km';

  String get durationLabel {
    if (durationMinutes < 1) return '< 1 min';
    if (durationMinutes < 60) return '${durationMinutes.round()} min';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes.round() % 60;
    return m > 0 ? '$h h $m min' : '$h h';
  }
}
