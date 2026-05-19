import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class AvisService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Map<String, String> _headers({bool auth = false}) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (auth && AuthService.token != null)
          'Authorization': 'Bearer ${AuthService.token}',
      };

  static Future<Map<String, dynamic>> fetchByMedecin(int idMedecin) async {
    final response = await http.get(
      Uri.parse('$baseUrl/public/medecins/$idMedecin/avis'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final payload = data['data'];
      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }
    }

    return {'avis': <Map<String, dynamic>>[], 'stats': {'nb_avis': 0}};
  }

  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final response = await http.get(
      Uri.parse('$baseUrl/public/avis'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  static Future<String?> submit({
    required int idMedecin,
    required int note,
    required String commentaire,
  }) async {
    if (!AuthService.isPatient) {
      if (!AuthService.isLoggedIn) {
        return 'Connectez-vous en tant que patient pour publier un avis.';
      }
      return 'Seuls les patients connectés peuvent publier un avis.';
    }

    final response = await http.post(
      Uri.parse('$baseUrl/avis'),
      headers: _headers(auth: true),
      body: jsonEncode({
        'id_medecin': idMedecin,
        'note': note,
        'commentaire': commentaire,
      }),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (data['success'] == true) {
        return null;
      }
    }

    return data['message']?.toString() ?? 'Impossible de publier l\'avis.';
  }
}
