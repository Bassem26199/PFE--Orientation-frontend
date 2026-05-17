import 'dart:convert';
import 'package:http/http.dart' as http;

/// Géocodage inverse gratuit via OpenStreetMap Nominatim.
class NominatimService {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  static Future<String?> reverseGeocode(double lat, double lon) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'format': 'json',
        'addressdetails': '1',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'OrientationMedicale/1.0 (PFE Flutter App)',
      },
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final display = data['display_name']?.toString();
    if (display != null && display.isNotEmpty) return display;

    final addr = data['address'];
    if (addr is! Map) return null;

    final raw = <String?>[
      addr['road']?.toString(),
      addr['suburb']?.toString() ?? addr['neighbourhood']?.toString(),
      addr['city']?.toString() ??
          addr['town']?.toString() ??
          addr['village']?.toString(),
      addr['country']?.toString(),
    ];
    final parts = raw
        .where((e) => e != null && e.isNotEmpty)
        .map((e) => e as String)
        .toList();

    return parts.isEmpty ? null : parts.join(', ');
  }

  static Future<({double latitude, double longitude})?> forwardGeocode(
    String query,
  ) async {
    final uri = Uri.parse('$_baseUrl/search').replace(
      queryParameters: {
        'q': query,
        'format': 'json',
        'limit': '1',
      },
    );

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'OrientationMedicale/1.0 (PFE Flutter App)',
      },
    );

    if (response.statusCode != 200) return null;

    final list = jsonDecode(response.body);
    if (list is! List || list.isEmpty) return null;

    final item = list.first;
    if (item is! Map) return null;

    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lon = double.tryParse(item['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;

    return (latitude: lat, longitude: lon);
  }
}
