import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = "http://10.0.2.2:8000/api";

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
}