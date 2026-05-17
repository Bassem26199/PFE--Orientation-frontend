import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../widgets/address_map_picker.dart';

class ModifierProfilScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ModifierProfilScreen({super.key, required this.user});

  @override
  State<ModifierProfilScreen> createState() => _ModifierProfilScreenState();
}

class _ModifierProfilScreenState extends State<ModifierProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapKey = GlobalKey<AddressMapPickerState>();

  late final TextEditingController nom;
  late final TextEditingController prenom;
  late final TextEditingController email;
  late final TextEditingController telephone;
  late final TextEditingController adresse;

  late String genre;
  DateTime? dateNaissance;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    nom = TextEditingController(text: u['nom']?.toString() ?? '');
    prenom = TextEditingController(text: u['prenom']?.toString() ?? '');
    email = TextEditingController(text: u['email']?.toString() ?? '');
    telephone = TextEditingController(text: u['telephone']?.toString() ?? '');
    adresse = TextEditingController(text: u['adresse']?.toString() ?? '');
    genre = u['genre']?.toString() ?? 'M';

    final dn = u['date_naissance']?.toString();
    if (dn != null && dn.isNotEmpty) {
      dateNaissance = DateTime.tryParse(dn);
    }
  }

  double? get _initialLat {
    final v = widget.user['latitude'];
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

  double? get _initialLng {
    final v = widget.user['longitude'];
    if (v == null) return null;
    return double.tryParse(v.toString());
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (dateNaissance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner votre date de naissance"),
        ),
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
      final response = await http.put(
        Uri.parse("${AuthService.baseUrl}/profile"),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
        body: jsonEncode({
          "nom": nom.text.trim(),
          "prenom": prenom.text.trim(),
          "email": email.text.trim(),
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
        final updated = data["data"] as Map<String, dynamic>?;
        if (updated != null) {
          AuthService.currentUser = {
            ...?AuthService.currentUser,
            ...updated,
          };
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            "user",
            jsonEncode(AuthService.currentUser),
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profil mis à jour avec succès")),
        );
        Navigator.pop(context, true);
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

  Widget _field(
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

  Widget _mapPicker({double? height}) {
    final map = AddressMapPicker(
      key: _mapKey,
      addressController: adresse,
      initialLatitude: _initialLat,
      initialLongitude: _initialLng,
      onAddressUpdated: () => setState(() {}),
    );
    if (height != null) {
      return SizedBox(height: height, child: map);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = dateNaissance == null
        ? "Date de naissance *"
        : "${dateNaissance!.day.toString().padLeft(2, '0')}/${dateNaissance!.month.toString().padLeft(2, '0')}/${dateNaissance!.year}  (${_calculateAge(dateNaissance!)} ans)";

    return Scaffold(
      appBar: AppBar(title: const Text("Modifier profil")),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          final formFields = Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(nom, "Nom", Icons.person_outline),
                _field(prenom, "Prénom", Icons.badge_outlined),
                _field(
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
                _field(
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
                Padding(
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
                ),
                if (!isWide) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Votre adresse",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _mapPicker(height: 280),
                  const SizedBox(height: 10),
                ],
                _disabledAddressField(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _save,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isLoading ? "Enregistrement..." : "Enregistrer"),
                ),
              ],
            ),
          );

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
                    child: SingleChildScrollView(child: formFields),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: formFields,
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
    telephone.dispose();
    adresse.dispose();
    super.dispose();
  }
}
