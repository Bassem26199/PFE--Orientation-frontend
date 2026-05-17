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

    final data = jsonDecode(response.body);

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

  static Future<void> logout() async {
    token = null;
    currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("user");
  }

  static bool get isLoggedIn => token != null;

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