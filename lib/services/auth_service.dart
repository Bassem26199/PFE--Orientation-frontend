import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

class AuthService {
  static String get baseUrl => ApiConfig.baseUrl;

  static String? token;
  static Map<String, dynamic>? currentUser;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    token = prefs.getString("token");

    final userString = prefs.getString("user");
    if (userString != null) {
      currentUser = jsonDecode(userString);
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final health = await http
          .get(Uri.parse("$baseUrl/health"))
          .timeout(const Duration(seconds: 5));

      if (health.statusCode != 200) {
        return _serverUnavailableMessage(
          'Le serveur sur $baseUrl ne répond pas correctement.',
        );
      }

      final healthData = jsonDecode(health.body) as Map<String, dynamic>;
      if (healthData['service'] != 'orientation-medical-api') {
        return _serverUnavailableMessage(
          'Mauvais serveur détecté sur le port ${ApiConfig.port}. '
          'Lancez Laravel depuis PFE--Orientation-medical.',
        );
      }
    } catch (_) {
      return _serverUnavailableMessage(
        'Impossible de joindre l\'API ($baseUrl). '
        'Exécutez: .\\scripts\\start-api.ps1 dans PFE--Orientation-medical',
      );
    }

    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "email": email,
        "mot_de_passe": password,
      }),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return {
        "status": response.statusCode,
        "success": false,
        "message": response.statusCode == 404
            ? "Route API introuvable. Redémarrez le serveur Laravel (scripts/start-api.ps1)."
            : "Réponse serveur invalide (${response.statusCode}).",
        "data": null,
      };
    }

    if (response.statusCode == 404) {
      return {
        "status": 404,
        "success": false,
        "message":
            "Route /api/login introuvable. Démarrez l'API depuis PFE--Orientation-medical "
            "(pas un autre projet sur le port ${ApiConfig.port}).",
        "data": data,
      };
    }

    if ((response.statusCode == 200 || response.statusCode == 201) &&
        data["success"] == true) {
      token = data["data"]["token"];
      currentUser = data["data"]["user"];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("token", token!);
      await prefs.setString("user", jsonEncode(currentUser));
    }

    return {
      "status": response.statusCode,
      "success": data["success"] ?? false,
      "message": data["message"] ?? "Erreur",
      "data": data,
    };
  }

  static Map<String, dynamic> _serverUnavailableMessage(String message) {
    return {
      "status": 0,
      "success": false,
      "message": message,
      "data": null,
    };
  }

  static Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/forgot-password'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email.trim()}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      return {
        'status': response.statusCode,
        'success': data['success'] == true,
        'message': data['message']?.toString() ?? 'Erreur',
        'data': data['data'],
      };
    } catch (_) {
      return {
        'status': 0,
        'success': false,
        'message': 'Impossible de joindre l\'API ($baseUrl).',
        'data': null,
      };
    }
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String nouveauMotDePasse,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reset-password'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.trim(),
          'token': token.trim(),
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
    } catch (_) {
      return {
        'status': 0,
        'success': false,
        'message': 'Impossible de joindre l\'API ($baseUrl).',
        'errors': null,
      };
    }
  }

  static Future<void> logout() async {
    token = null;
    currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("user");
  }

  static bool get isLoggedIn => token != null;

  static String? get role =>
      currentUser?['role']?.toString().toUpperCase();

  static bool get isPatient =>
      isLoggedIn && role == 'PATIENT';

  static String get displayName {
    final user = currentUser;
    if (user == null) return 'Patient';

    final prenom = user['prenom']?.toString().trim() ?? '';
    final nom = user['nom']?.toString().trim() ?? '';

    if (prenom.isNotEmpty && nom.isNotEmpty) return '$prenom $nom';
    if (prenom.isNotEmpty) return prenom;
    if (nom.isNotEmpty) return nom;

    return user['email']?.toString() ?? 'Patient';
  }

  static String get firstName {
    final prenom = currentUser?['prenom']?.toString().trim();
    if (prenom != null && prenom.isNotEmpty) return prenom;
    return displayName;
  }
}