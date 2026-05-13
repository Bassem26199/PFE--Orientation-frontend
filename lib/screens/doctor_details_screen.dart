import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'create_rendezvous_screen.dart';

class DoctorDetailsScreen extends StatelessWidget {
  final Map doctor;
  final int idOrientation;
  final String imageUrl;

  const DoctorDetailsScreen({
    super.key,
    required this.doctor,
    required this.idOrientation,
    required this.imageUrl,
  });

  Future<void> openMap() async {
    final adresse = doctor["adresse_cabinet"] ?? doctor["ville"] ?? "";
    final query = Uri.encodeComponent(adresse);
    final url =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> callDoctor() async {
    final phone = doctor["telephone_professionnel"] ?? "";
    if (phone.toString().isEmpty) return;

    final url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> whatsappDoctor() async {
    final phone = doctor["telephone_professionnel"] ?? "";
    if (phone.toString().isEmpty) return;

    final cleanPhone = phone.toString().replaceAll("+", "");
    final url = Uri.parse("https://wa.me/$cleanPhone");

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget infoTile(IconData icon, String label, String value) {
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
                Text(label, style: const TextStyle(color: Colors.black54)),
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

  @override
  Widget build(BuildContext context) {
    final nom = "Dr. ${doctor['nom']} ${doctor['prenom']}";
    final ville = doctor["ville"] ?? "-";
    final telephone = doctor["telephone_professionnel"] ?? "-";
    final adresse = doctor["adresse_cabinet"] ?? "-";
    final note = doctor["note_moyenne"]?.toString() ?? "-";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails médecin"),
      ),
      body: SingleChildScrollView(
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
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    backgroundImage: NetworkImage(imageUrl),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    nom,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "$ville • ⭐ $note",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            infoTile(Icons.location_city, "Ville", ville),
            infoTile(Icons.location_on, "Adresse", adresse),
            infoTile(Icons.phone, "Téléphone", telephone),
            infoTile(Icons.star, "Note moyenne", note),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: openMap,
                    icon: const Icon(Icons.map),
                    label: const Text("Carte"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: callDoctor,
                    icon: const Icon(Icons.call),
                    label: const Text("Appel"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: whatsappDoctor,
                icon: const Icon(Icons.chat),
                label: const Text("Contacter via WhatsApp"),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateRendezvousScreen(
                        doctor: doctor,
                        idOrientation: idOrientation,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text("Prendre rendez-vous"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}