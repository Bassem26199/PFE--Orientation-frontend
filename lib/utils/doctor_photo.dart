import '../config/api_config.dart';

class DoctorPhoto {
  static String get serverOrigin =>
      ApiConfig.baseUrl.replaceAll(RegExp(r'/api/?$'), '');

  static int? parseVersion(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static String appendVersion(String url, {int? version}) {
    if (version == null) return url;

    final uri = Uri.parse(url);
    final query = Map<String, String>.from(uri.queryParameters);
    query['v'] = version.toString();

    return uri.replace(queryParameters: query).toString();
  }

  static String mediaUrl(String relativePath, {int? version}) {
    final clean = relativePath.replaceFirst(RegExp(r'^/'), '');
    final base = '${ApiConfig.baseUrl}/media/$clean';
    return appendVersion(base, version: version);
  }

  static String? urlFromDoctor(Map<dynamic, dynamic> doctor) {
    final version = parseVersion(doctor['photo_version']);
    final raw = doctor['photo_url']?.toString();
    if (raw != null && raw.isNotEmpty) {
      return resolveUrl(raw, version: version);
    }

    final path = doctor['photo_profil']?.toString();
    if (path != null && path.isNotEmpty) {
      return mediaUrl(path, version: version);
    }

    return null;
  }

  static String resolveUrl(String url, {int? version}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    var value = trimmed;

    if (value.contains('/storage/')) {
      value = value.replaceFirst('/storage/', '/api/media/');
    }

    final origin = serverOrigin;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      value = value
          .replaceFirst('http://127.0.0.1:${ApiConfig.port}', origin)
          .replaceFirst('http://localhost:${ApiConfig.port}', origin)
          .replaceFirst('http://localhost/storage', '$origin/api/media')
          .replaceFirst('http://127.0.0.1/storage', '$origin/api/media');
    } else if (value.startsWith('/api/media/')) {
      value = '$origin$value';
    } else if (value.startsWith('api/media/')) {
      value = '$origin/$value';
    } else if (value.startsWith('/storage/')) {
      value = '$origin${value.replaceFirst('/storage/', '/api/media/')}';
    } else if (value.startsWith('storage/')) {
      value = '$origin/api/media/${value.replaceFirst('storage/', '')}';
    } else if (!value.startsWith('/')) {
      value = mediaUrl(value, version: version);
      return value;
    } else {
      value = '$origin$value';
    }

    if (version != null) {
      return appendVersion(value, version: version);
    }

    return value;
  }

  static String fallbackAvatar(int index) {
    const images = [
      'https://cdn-icons-png.flaticon.com/512/3774/3774299.png',
      'https://cdn-icons-png.flaticon.com/512/3304/3304567.png',
      'https://cdn-icons-png.flaticon.com/512/3870/3870822.png',
    ];
    return images[index.abs() % images.length];
  }
}
