import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nom = TextEditingController();
  final prenom = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final age = TextEditingController();

  String genre = "M";
  bool isLoading = false;

  Future<void> register() async {
    setState(() => isLoading = true);

    final response = await http.post(
      Uri.parse("${AuthService.baseUrl}/register"),
      headers: {"Accept": "application/json"},
      body: {
        "nom": nom.text,
        "prenom": prenom.text,
        "email": email.text,
        "password": password.text,
        "genre": genre,
        "age": age.text,
      },
    );

    final data = jsonDecode(response.body);

    setState(() => isLoading = false);

    if (data["success"] == true) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Succès"),
          content: const Text("Compte créé + email envoyé"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            )
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data["message"] ?? "Erreur")),
      );
    }
  }

  Widget field(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer compte")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            field(nom, "Nom"),
            field(prenom, "Prénom"),
            field(email, "Email"),
            field(password, "Mot de passe"),
            field(age, "Âge"),

            const SizedBox(height: 10),

            DropdownButtonFormField(
              value: genre,
              items: const [
                DropdownMenuItem(value: "M", child: Text("Homme")),
                DropdownMenuItem(value: "F", child: Text("Femme")),
              ],
              onChanged: (v) => setState(() => genre = v!),
              decoration: const InputDecoration(labelText: "Genre"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isLoading ? null : register,
              child: Text(isLoading ? "..." : "Créer compte"),
            )
          ],
        ),
      ),
    );
  }
}