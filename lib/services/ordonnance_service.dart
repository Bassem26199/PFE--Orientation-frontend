import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class OrdonnanceService {
  static Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${AuthService.token}',
        'Content-Type': 'application/json',
      };

  static Future<Map<String, dynamic>> generer(int idPatient) async {
    final response = await http.post(
      Uri.parse('${AuthService.baseUrl}/medecin/ordonnances/generer/$idPatient'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(data['message'] ?? 'Erreur génération ordonnance');
  }

  static Future<List<Map<String, dynamic>>> listByPatient(int idPatient) async {
    final response = await http.get(
      Uri.parse('${AuthService.baseUrl}/medecin/ordonnances/patient/$idPatient'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] == true && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> valider({
    required int idPatient,
    int? idOrientation,
    required List<Map<String, dynamic>> elements,
    String? dosageGlobal,
    String? duree,
    String? conseils,
    String? niveauUrgence,
    String? symptomesSource,
  }) async {
    final response = await http.post(
      Uri.parse('${AuthService.baseUrl}/medecin/ordonnances'),
      headers: _headers(),
      body: jsonEncode({
        'id_patient': idPatient,
        if (idOrientation != null) 'id_orientation': idOrientation,
        'elements': elements,
        'dosage_global': dosageGlobal,
        'duree': duree,
        'conseils': conseils,
        'niveau_urgence': niveauUrgence,
        'symptomes_source': symptomesSource,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(data['message'] ?? 'Erreur enregistrement');
  }

  static Future<List<Map<String, dynamic>>> mesOrdonnances() async {
    final response = await http.get(
      Uri.parse('${AuthService.baseUrl}/patient/ordonnances'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] == true && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }
}
