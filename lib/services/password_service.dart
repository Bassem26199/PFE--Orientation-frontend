import 'dart:convert';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class PasswordService {
  static Future<Map<String, dynamic>> changePassword({
    required String ancienMotDePasse,
    required String nouveauMotDePasse,
  }) async {
    final response = await http.put(
      Uri.parse('${AuthService.baseUrl}/change-password'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AuthService.token}',
      },
      body: jsonEncode({
        'ancien_mot_de_passe': ancienMotDePasse,
        'nouveau_mot_de_passe': nouveauMotDePasse,
      }),
    );

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    return {
      'status': response.statusCode,
      'success': data['success'] == true,
      'message': data['message']?.toString() ?? 'Erreur',
      'errors': data['errors'],
    };
  }

  static String formatErrors(dynamic errors, String fallback) {
    if (errors is! Map) return fallback;
    return errors.values
        .expand((e) => e is List ? e : [e])
        .map((e) => e.toString())
        .join('\n');
  }
}
