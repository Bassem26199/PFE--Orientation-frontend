import '../config/api_config.dart';

class DoctorPhoto {
  static String get serverOrigin =>
      ApiConfig.baseUrl.replaceAll(RegExp(r'/api/?$'), '');

  static String mediaUrl(String relativePath) {
    final clean = relativePath.replaceFirst(RegExp(r'^/'), '');
    return '${ApiConfig.baseUrl}/media/$clean';
  }

  static String? urlFromDoctor(Map<dynamic, dynamic> doctor) {
    final raw = doctor['photo_url']?.toString();
    if (raw != null && raw.isNotEmpty) {
      return resolveUrl(raw);
    }

    final path = doctor['photo_profil']?.toString();
    if (path != null && path.isNotEmpty) {
      return mediaUrl(path);
    }

    return null;
  }

  static String resolveUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    var value = trimmed;

    // Anciennes URLs /storage/... -> /api/media/... (CORS Flutter Web)
    if (value.contains('/storage/')) {
      value = value.replaceFirst('/storage/', '/api/media/');
    }

    final origin = serverOrigin;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value
          .replaceFirst('http://127.0.0.1:${ApiConfig.port}', origin)
          .replaceFirst('http://localhost:${ApiConfig.port}', origin)
          .replaceFirst('http://localhost/storage', '$origin/api/media')
          .replaceFirst('http://127.0.0.1/storage', '$origin/api/media');
    }

    if (value.startsWith('/api/media/')) {
      return '$origin$value';
    }

    if (value.startsWith('api/media/')) {
      return '$origin/$value';
    }

    if (value.startsWith('/storage/')) {
      return '$origin${value.replaceFirst('/storage/', '/api/media/')}';
    }

    if (value.startsWith('storage/')) {
      return '$origin/api/media/${value.replaceFirst('storage/', '')}';
    }

    if (!value.startsWith('/')) {
      return mediaUrl(value);
    }

    return '$origin$value';
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
