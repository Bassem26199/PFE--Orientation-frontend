import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';
import '../utils/doctor_photo.dart';
import '../widgets/address_map_picker.dart';
import '../widgets/doctor_avatar.dart';

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
  bool uploadingPhoto = false;
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    photoUrl = DoctorPhoto.urlFromDoctor(u);
    nom = TextEditingController(text: u['nom']?.toString() ?? '');
    prenom = TextEditingController(text: u['prenom']?.toString() ?? '');
    email = TextEditingController(text: u['email']?.toString() ?? '');
    telephone = TextEditingController(text: u['telephone']?.toString() ?? '');
    ville = TextEditingController(text: u['ville']?.toString() ?? '');
    adresse = TextEditingController(text: u['adresse_cabinet']?.toString() ?? '');
  }

  MediaType _mimeTypeForFileName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) {
      return MediaType('image', 'png');
    }
    if (lower.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }
    return MediaType('image', 'jpeg');
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

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => uploadingPhoto = true);

    try {
      final bytes = await picked.readAsBytes();
      final fileName = picked.name.isNotEmpty ? picked.name : 'photo.jpg';
      final contentType = _mimeTypeForFileName(fileName);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${AuthService.baseUrl}/medecin/profile/photo'),
      );
      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer ${AuthService.token}';
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          bytes,
          filename: fileName,
          contentType: contentType,
        ),
      );

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true &&
          data['data'] is Map) {
        final updatedPhoto = Map<String, dynamic>.from(data['data'] as Map);
        final newUrl = updatedPhoto['photo_url']?.toString();
        final savedPath = updatedPhoto['photo_profil']?.toString();
        setState(() {
          photoUrl = newUrl != null ? DoctorPhoto.resolveUrl(newUrl) : photoUrl;
        });

        AuthService.currentUser = {
          ...?AuthService.currentUser,
          'photo_url': updatedPhoto['photo_url'],
          'photo_profil': updatedPhoto['photo_profil'],
        };
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', jsonEncode(AuthService.currentUser));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              savedPath != null
                  ? 'Photo enregistrée : $savedPath'
                  : 'Photo de profil mise à jour',
            ),
          ),
        );
      } else {
        final errors = data['errors'];
        String message = data['message']?.toString() ?? 'Erreur photo';
        if (errors is Map && errors.isNotEmpty) {
          message = errors.values
              .expand((value) => value is List ? value : [value])
              .map((e) => e.toString())
              .join('\n');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur photo : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => uploadingPhoto = false);
    }
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
            Center(
              child: Stack(
                children: [
                  DoctorAvatar(
                    doctor: widget.user,
                    photoUrl: photoUrl,
                    radius: 52,
                  ),
                  if (uploadingPhoto)
                    Positioned.fill(
                      child: CircleAvatar(
                        radius: 52,
                        backgroundColor: Colors.black38,
                        child: const CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.blue,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        onPressed: uploadingPhoto ? null : _pickAndUploadPhoto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: uploadingPhoto ? null : _pickAndUploadPhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choisir une photo'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Cette photo sera visible par les patients.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 8),
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
