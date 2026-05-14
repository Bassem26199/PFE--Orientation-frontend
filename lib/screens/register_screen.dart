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
  final confirmPassword = TextEditingController();
  final telephone = TextEditingController();

  DateTime? dateNaissance;
  String genre = "M";
  bool isLoading = false;
  bool obscurePassword = true;
  bool obscureConfirm = true;

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: dateNaissance ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: "Sélectionner la date de naissance",
    );
    if (picked != null) {
      setState(() => dateNaissance = picked);
    }
  }

  Future<void> register() async {
    if (dateNaissance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner votre date de naissance"),
        ),
      );
      return;
    }

    if (password.text != confirmPassword.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Les mots de passe ne correspondent pas")),
      );
      return;
    }

    setState(() => isLoading = true);

    final age = _calculateAge(dateNaissance!);
    final dateStr =
        "${dateNaissance!.year.toString().padLeft(4, '0')}-${dateNaissance!.month.toString().padLeft(2, '0')}-${dateNaissance!.day.toString().padLeft(2, '0')}";

    final response = await http.post(
      Uri.parse("${AuthService.baseUrl}/register"),
      headers: {"Accept": "application/json"},
      body: {
        "nom": nom.text,
        "prenom": prenom.text,
        "email": email.text,
        "mot_de_passe": password.text,
        "telephone": telephone.text,
        "genre": genre,
        "age": age.toString(),
        "date_naissance": dateStr,
      },
    );

    final data = jsonDecode(response.body);

    setState(() => isLoading = false);

    if (!mounted) return;

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
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(data["message"] ?? "Erreur")));
    }
  }

  Widget field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateNaissance == null
        ? "Date de naissance"
        : "${dateNaissance!.day.toString().padLeft(2, '0')}/${dateNaissance!.month.toString().padLeft(2, '0')}/${dateNaissance!.year}  (${_calculateAge(dateNaissance!)} ans)";

    return Scaffold(
      appBar: AppBar(title: const Text("Créer compte")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            field(nom, "Nom", Icons.person_outline),
            field(prenom, "Prénom", Icons.badge_outlined),
            field(
              email,
              "Email",
              Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
            ),
            field(
              telephone,
              "Téléphone",
              Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),

            // Date de naissance picker
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                  ),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 16,
                      color: dateNaissance == null
                          ? Colors.grey
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),

            // Password
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: password,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: "Mot de passe",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
            ),

            // Confirm password
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: confirmPassword,
                obscureText: obscureConfirm,
                decoration: InputDecoration(
                  labelText: "Confirmer le mot de passe",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue: genre,
              items: const [
                DropdownMenuItem(value: "M", child: Text("Homme")),
                DropdownMenuItem(value: "F", child: Text("Femme")),
              ],
              onChanged: (v) => setState(() => genre = v!),
              decoration: const InputDecoration(
                labelText: "Genre",
                prefixIcon: Icon(Icons.wc_outlined),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: isLoading ? null : register,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_outlined),
              label: Text(isLoading ? "Création..." : "Créer compte"),
            ),
          ],
        ),
      ),
    );
  }
}
