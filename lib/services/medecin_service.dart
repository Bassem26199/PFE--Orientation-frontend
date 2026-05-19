import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';

class MedecinService {
  static String get baseUrl => ApiConfig.baseUrl;

  static Map<String, String> _headers({bool withAuth = false}) => {
        'Accept': 'application/json',
        if (withAuth && AuthService.token != null)
          'Authorization': 'Bearer ${AuthService.token}',
      };

  static List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  static Map<String, dynamic> formatDoctor(Map<String, dynamic> m) {
    final prenom = m['prenom']?.toString() ?? '';
    final nom = m['nom']?.toString() ?? '';

    return {
      ...m,
      'nom_complet': 'Dr. $prenom $nom'.trim(),
      'specialite': m['nom_specialite']?.toString() ?? '-',
      'adresse': m['adresse_cabinet']?.toString() ?? '',
      'telephone': m['telephone_professionnel']?.toString() ?? '',
      'note': m['note_moyenne'],
    };
  }

  static Future<List<Map<String, dynamic>>> fetchMedecins({
    int? idSpecialite,
    String? ville,
    double? patientLat,
    double? patientLng,
    bool withAuth = false,
  }) async {
    final query = <String, String>{};
    if (idSpecialite != null) {
      query['id_specialite'] = idSpecialite.toString();
    }
    if (ville != null && ville.isNotEmpty && ville != 'Toutes') {
      query['ville'] = ville;
    }
    if (patientLat != null && patientLng != null) {
      query['patient_latitude'] = patientLat.toString();
      query['patient_longitude'] = patientLng.toString();
    }

    final uri = idSpecialite != null
        ? Uri.parse('$baseUrl/public/medecins/specialite/$idSpecialite')
            .replace(queryParameters: query.isEmpty ? null : query)
        : Uri.parse('$baseUrl/public/medecins')
            .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: _headers(withAuth: withAuth));
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return _parseList(data['data']).map(formatDoctor).toList();
    }

    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchSpecialites() async {
    final response = await http.get(
      Uri.parse('$baseUrl/public/specialites'),
      headers: _headers(),
    );
    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      return _parseList(data['data']);
    }

    return [];
  }

  static double? _parseCoord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool hasCoordinates(Map<String, dynamic> doctor) {
    final lat = _parseCoord(doctor['latitude']);
    final lng = _parseCoord(doctor['longitude']);
    return lat != null && lng != null;
  }

  static List<Map<String, dynamic>> withMapCoordinates(
    List<Map<String, dynamic>> doctors,
  ) {
    return doctors.where(hasCoordinates).toList();
  }
}
