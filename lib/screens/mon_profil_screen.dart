import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/password_service.dart';
import '../widgets/address_map_picker.dart';
import '../widgets/responsive_content.dart';
import 'modifier_profil_screen.dart';
import 'public_navigation_screen.dart';

class MonProfilScreen extends StatefulWidget {
  const MonProfilScreen({super.key});

  @override
  State<MonProfilScreen> createState() => _MonProfilScreenState();
}

class _MonProfilScreenState extends State<MonProfilScreen> {
  Map? user;
  bool isLoading = true;
  final _adressePreview = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/me"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        user = data["data"];
        _adressePreview.text = user?["adresse"]?.toString() ?? "";
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double? _parseCoord(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  String getProfileImage() {
    if (user == null) {
      return "https://cdn-icons-png.flaticon.com/512/847/847969.png";
    }

    final genre = user!["genre"];

    if (genre == "F") {
      return "https://cdn-icons-png.flaticon.com/512/6997/6997662.png";
    }

    if (genre == "M") {
      return "https://cdn-icons-png.flaticon.com/512/4140/4140048.png";
    }

    return "https://cdn-icons-png.flaticon.com/512/3135/3135715.png";
  }

  String _genreLabel(String? genre) {
    if (genre == "M") return "Homme";
    if (genre == "F") return "Femme";
    return genre ?? "Non défini";
  }

  String _formatDateNaissance() {
    final raw = user?["date_naissance"]?.toString();
    if (raw == null || raw.isEmpty) return "-";
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Widget infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? "-" : value,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _addressMapSection() {
    final lat = _parseCoord(user?["latitude"]);
    final lng = _parseCoord(user?["longitude"]);
    final hasLocation = lat != null && lng != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.map_outlined, color: Colors.blue),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Adresse",
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (user?["adresse"]?.toString() ?? "").isEmpty
                          ? "-"
                          : user!["adresse"].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: hasLocation
                ? AddressMapPicker(
                    addressController: _adressePreview,
                    initialLatitude: lat,
                    initialLongitude: lng,
                    readOnly: true,
                  )
                : Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      "Aucune position enregistrée.\nModifiez votre profil pour l'ajouter.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfile() async {
    if (user == null) return;

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ModifierProfilScreen(
          user: Map<String, dynamic>.from(user!),
        ),
      ),
    );

    if (updated == true) {
      await fetchProfile();
    }
  }

  void _showChangePasswordDialog() {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final confirmPass = TextEditingController();
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Changer mot de passe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Ancien mot de passe *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe * (min. 6)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (newPass.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Minimum 6 caractères'),
                          ),
                        );
                        return;
                      }
                      if (newPass.text != confirmPass.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Les mots de passe ne correspondent pas'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final result = await PasswordService.changePassword(
                          ancienMotDePasse: oldPass.text,
                          nouveauMotDePasse: newPass.text,
                        );
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['success'] == true
                                  ? result['message'] as String
                                  : PasswordService.formatErrors(
                                      result['errors'],
                                      result['message'] as String,
                                    ),
                            ),
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur : $e')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> logout() async {
    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const PublicNavigationScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullName = user == null
        ? ""
        : "${user!["prenom"] ?? ""} ${user!["nom"] ?? ""}".trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mon profil"),
      ),
      body: ResponsiveContent.list(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : user == null
                ? const Center(child: Text('Erreur chargement profil'))
                : SingleChildScrollView(
                    child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                          ),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 54,
                              backgroundColor: Colors.white,
                              backgroundImage:
                                  NetworkImage(getProfileImage()),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              user!["role"] ?? "",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      infoTile(
                        icon: Icons.person,
                        title: "Nom",
                        value: user!["nom"] ?? "",
                      ),
                      infoTile(
                        icon: Icons.badge,
                        title: "Prénom",
                        value: user!["prenom"] ?? "",
                      ),
                      infoTile(
                        icon: Icons.email,
                        title: "Email",
                        value: user!["email"] ?? "",
                      ),
                      infoTile(
                        icon: Icons.phone,
                        title: "Téléphone",
                        value: user!["telephone"] ?? "",
                      ),
                      infoTile(
                        icon: Icons.cake_outlined,
                        title: "Date de naissance",
                        value: _formatDateNaissance(),
                      ),
                      infoTile(
                        icon: Icons.wc,
                        title: "Genre",
                        value: _genreLabel(user!["genre"]?.toString()),
                      ),
                      _addressMapSection(),
                      infoTile(
                        icon: Icons.verified_user,
                        title: "Rôle",
                        value: user!["role"] ?? "",
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _openEditProfile,
                          icon: const Icon(Icons.edit),
                          label: const Text("Modifier profil"),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _showChangePasswordDialog,
                          icon: const Icon(Icons.lock_reset),
                          label: const Text('Changer mot de passe'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: logout,
                          icon: const Icon(Icons.logout),
                          label: const Text("Déconnexion"),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  @override
  void dispose() {
    _adressePreview.dispose();
    super.dispose();
  }
}
