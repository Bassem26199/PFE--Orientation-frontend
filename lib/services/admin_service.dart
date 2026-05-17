import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AdminService {
  static Map<String, String> _headers() => {
        'Accept': 'application/json',
        'Authorization': 'Bearer ${AuthService.token}',
        'Content-Type': 'application/json',
      };

  static Future<Map<String, dynamic>> fetchDashboard() async {
    final response = await http.get(
      Uri.parse('${AuthService.baseUrl}/admin/dashboard'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] == true) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    throw Exception(data['message'] ?? 'Erreur dashboard');
  }

  static Future<List<Map<String, dynamic>>> fetchMedecins() async {
    final response = await http.get(
      Uri.parse('${AuthService.baseUrl}/admin/medecins'),
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

  static Future<List<Map<String, dynamic>>> fetchSpecialites() async {
    final response = await http.get(
      Uri.parse('${AuthService.baseUrl}/specialites'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['success'] == true && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    if (data['data'] is List) {
      return (data['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> createMedecin(
    Map<String, dynamic> payload,
  ) async {
    final response = await http.post(
      Uri.parse('${AuthService.baseUrl}/admin/medecins'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Erreur creation medecin');
  }

  static Future<Map<String, dynamic>> updateMedecin(
    int idMedecin,
    Map<String, dynamic> payload,
  ) async {
    final response = await http.put(
      Uri.parse('${AuthService.baseUrl}/admin/medecins/$idMedecin'),
      headers: _headers(),
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Erreur mise a jour');
  }

  static Future<Map<String, dynamic>> deleteMedecin(int idMedecin) async {
    final response = await http.delete(
      Uri.parse('${AuthService.baseUrl}/admin/medecins/$idMedecin'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        data['success'] == true) {
      return data;
    }
    throw Exception(data['message'] ?? 'Erreur suppression');
  }
}
