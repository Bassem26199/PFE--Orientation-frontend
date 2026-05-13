import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import 'public_navigation_screen.dart';

class MonProfilScreen extends StatefulWidget {
  const MonProfilScreen({super.key});

  @override
  State<MonProfilScreen> createState() => _MonProfilScreenState();
}

class _MonProfilScreenState extends State<MonProfilScreen> {
  Map? user;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/me"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      setState(() {
        user = data["data"];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? const Center(child: Text("Erreur chargement profil"))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
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
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 54,
                                  backgroundColor: Colors.white,
                                  backgroundImage:
                                      NetworkImage(getProfileImage()),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 18,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
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
                        icon: Icons.wc,
                        title: "Genre",
                        value: user!["genre"] ?? "Non défini",
                      ),
                      infoTile(
                        icon: Icons.verified_user,
                        title: "Rôle",
                        value: user!["role"] ?? "",
                      ),
                      SizedBox(
  width: double.infinity,
  height: 52,
  child: ElevatedButton.icon(
    onPressed: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Modification du profil à ajouter prochainement."),
        ),
      );
    },
    icon: const Icon(Icons.edit),
    label: const Text("Modifier profil"),
  ),
),
const SizedBox(height: 12),
                      const SizedBox(height: 16),
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
    );
  }
}