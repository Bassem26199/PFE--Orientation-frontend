import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../widgets/address_map_picker.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapKey = GlobalKey<AddressMapPickerState>();

  final nom = TextEditingController();
  final prenom = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();
  final telephone = TextEditingController();
  final adresse = TextEditingController();

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

  void _clearForm() {
    nom.clear();
    prenom.clear();
    email.clear();
    password.clear();
    confirmPassword.clear();
    telephone.clear();
    adresse.clear();
    _formKey.currentState?.reset();
    _mapKey.currentState?.reset();
    setState(() {
      dateNaissance = null;
      genre = "M";
      obscurePassword = true;
      obscureConfirm = true;
    });
  }

  void _goToLogin({String? registeredEmail}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(initialEmail: registeredEmail),
      ),
    );
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

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

    final lat = _mapKey.currentState?.latitude;
    final lng = _mapKey.currentState?.longitude;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner votre position sur la carte"),
        ),
      );
      return;
    }

    if (adresse.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez choisir un lieu sur la carte"),
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    final age = _calculateAge(dateNaissance!);
    final dateStr =
        "${dateNaissance!.year.toString().padLeft(4, '0')}-${dateNaissance!.month.toString().padLeft(2, '0')}-${dateNaissance!.day.toString().padLeft(2, '0')}";

    try {
      final response = await http.post(
        Uri.parse("${AuthService.baseUrl}/register"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "nom": nom.text.trim(),
          "prenom": prenom.text.trim(),
          "email": email.text.trim(),
          "mot_de_passe": password.text,
          "telephone": telephone.text.trim(),
          "genre": genre,
          "age": age,
          "date_naissance": dateStr,
          "adresse": adresse.text.trim(),
          "latitude": lat,
          "longitude": lng,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data["success"] == true) {
        final registeredEmail = email.text.trim();
        final message = data["message"]?.toString() ??
            "Compte créé. Connectez-vous avec vos identifiants.";

        setState(() => isLoading = false);
        _clearForm();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );

        _goToLogin(registeredEmail: registeredEmail);
        return;
      } else {
        final message = data["message"]?.toString() ?? "Erreur";
        final errors = data["errors"];
        String details = message;
        if (errors is Map) {
          details = errors.values
              .expand((e) => e is List ? e : [e])
              .map((e) => e.toString())
              .join('\n');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(details)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur réseau : $e")),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  Widget field(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboardType,
        validator: validator ??
            (v) => (v == null || v.trim().isEmpty) ? "Champ requis" : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _disabledAddressField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: adresse,
        readOnly: true,
        enabled: false,
        maxLines: 2,
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return "Choisissez un lieu sur la carte";
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: "Adresse sélectionnée",
          hintText: "Apparaît après avoir choisi sur la carte",
          prefixIcon: const Icon(Icons.location_on_outlined),
          disabledBorder: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }

  Widget _genreField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: genre,
        items: const [
          DropdownMenuItem(value: "M", child: Text("Homme")),
          DropdownMenuItem(value: "F", child: Text("Femme")),
        ],
        onChanged: (v) => setState(() => genre = v!),
        decoration: const InputDecoration(
          labelText: "Genre",
          prefixIcon: Icon(Icons.wc_outlined),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _mapPicker({double? height}) {
    final map = AddressMapPicker(
      key: _mapKey,
      addressController: adresse,
      onAddressUpdated: () => setState(() {}),
    );
    if (height != null) {
      return SizedBox(height: height, child: map);
    }
    return map;
  }

  Widget _buildFormFields({required bool showMapBelowGenre}) {
    final dateLabel = dateNaissance == null
        ? "Date de naissance *"
        : "${dateNaissance!.day.toString().padLeft(2, '0')}/${dateNaissance!.month.toString().padLeft(2, '0')}/${dateNaissance!.year}  (${_calculateAge(dateNaissance!)} ans)";

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Informations du compte",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          field(nom, "Nom", Icons.person_outline),
          field(prenom, "Prénom", Icons.badge_outlined),
          field(
            email,
            "Email",
            Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return "Email requis";
              if (!v.contains('@')) return "Email invalide";
              return null;
            },
          ),
          field(
            telephone,
            "Téléphone",
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) => null,
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: "Date de naissance *",
                  prefixIcon: Icon(Icons.cake_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  dateLabel,
                  style: TextStyle(
                    color: dateNaissance == null
                        ? Colors.grey
                        : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          _genreField(),
          if (showMapBelowGenre) ...[
            const SizedBox(height: 16),
            Text(
              "Votre adresse",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            _mapPicker(height: 280),
            const SizedBox(height: 10),
            _disabledAddressField(),
          ] else ...[
            const SizedBox(height: 4),
            _disabledAddressField(),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: password,
              obscureText: obscurePassword,
              validator: (v) {
                if (v == null || v.length < 6) {
                  return "Minimum 6 caractères";
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: "Mot de passe",
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: confirmPassword,
              obscureText: obscureConfirm,
              validator: (v) {
                if (v != password.text) {
                  return "Les mots de passe ne correspondent pas";
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: "Confirmer le mot de passe",
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Créer compte patient")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Votre adresse",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(child: _mapPicker()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildFormFields(showMapBelowGenre: false),
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildFormFields(showMapBelowGenre: true),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    nom.dispose();
    prenom.dispose();
    email.dispose();
    password.dispose();
    confirmPassword.dispose();
    telephone.dispose();
    adresse.dispose();
    super.dispose();
  }
}
