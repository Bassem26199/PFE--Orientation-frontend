import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../widgets/address_map_picker.dart';

class ModifierProfilMedecinScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const ModifierProfilMedecinScreen({super.key, required this.user});

  @override
  State<ModifierProfilMedecinScreen> createState() =>
      _ModifierProfilMedecinScreenState();
}

class _ModifierProfilMedecinScreenState extends State<ModifierProfilMedecinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mapKey = GlobalKey<AddressMapPickerState>();

  late final TextEditingController nom;
  late final TextEditingController prenom;
  late final TextEditingController email;
  late final TextEditingController telephone;
  late final TextEditingController ville;
  late final TextEditingController adresse;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    nom = TextEditingController(text: u['nom']?.toString() ?? '');
    prenom = TextEditingController(text: u['prenom']?.toString() ?? '');
    email = TextEditingController(text: u['email']?.toString() ?? '');
    telephone = TextEditingController(text: u['telephone']?.toString() ?? '');
    ville = TextEditingController(text: u['ville']?.toString() ?? '');
    adresse = TextEditingController(text: u['adresse_cabinet']?.toString() ?? '');
  }

  double? get _initialLat {
    final v = widget.user['latitude'];
    if (v == null) return null;
    return v is num ? v.toDouble() : double.tryParse(v.toString());
  }

  double? get _initialLng {
    final v = widget.user['longitude'];
    if (v == null) return null;
    return v is num ? v.toDouble() : double.tryParse(v.toString());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = _mapKey.currentState?.latitude;
    final lng = _mapKey.currentState?.longitude;

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez l\'emplacement du cabinet sur la carte')),
      );
      return;
    }

    if (adresse.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse du cabinet requise')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.put(
        Uri.parse('${AuthService.baseUrl}/medecin/profile'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthService.token}',
        },
        body: jsonEncode({
          'nom': nom.text.trim(),
          'prenom': prenom.text.trim(),
          'email': email.text.trim(),
          'telephone': telephone.text.trim(),
          'ville': ville.text.trim(),
          'adresse_cabinet': adresse.text.trim(),
          'latitude': lat,
          'longitude': lng,
        }),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (data['success'] == true) {
        final updated = Map<String, dynamic>.from(data['data']);
        AuthService.currentUser = {...?AuthService.currentUser, ...updated};
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(AuthService.currentUser));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Erreur')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier profil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: nom,
              decoration: const InputDecoration(
                labelText: 'Nom',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: prenom,
              decoration: const InputDecoration(
                labelText: 'Prénom',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: email,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: telephone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ville,
              decoration: const InputDecoration(
                labelText: 'Ville',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 16),
            const Text(
              'Emplacement du cabinet',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: AddressMapPicker(
                key: _mapKey,
                addressController: adresse,
                initialLatitude: _initialLat,
                initialLongitude: _initialLng,
                onAddressUpdated: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: adresse,
              readOnly: true,
              enabled: false,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Adresse du cabinet',
                filled: true,
                fillColor: Colors.grey.shade100,
                disabledBorder: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : _save,
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(isLoading ? 'Enregistrement...' : 'Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    nom.dispose();
    prenom.dispose();
    email.dispose();
    telephone.dispose();
    ville.dispose();
    adresse.dispose();
    super.dispose();
  }
}
