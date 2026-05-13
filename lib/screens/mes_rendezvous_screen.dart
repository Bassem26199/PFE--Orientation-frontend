import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';

class MesRendezVousScreen extends StatefulWidget {
  const MesRendezVousScreen({super.key});

  @override
  State<MesRendezVousScreen> createState() => _MesRendezVousScreenState();
}

class _MesRendezVousScreenState extends State<MesRendezVousScreen> {
  bool isLoading = true;
  List rendezvous = [];

  @override
  void initState() {
    super.initState();
    fetchRendezVous();
  }

  Future<void> fetchRendezVous() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/demandes-rendezvous"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      setState(() {
        if (data["data"] is Map && data["data"]["data"] != null) {
          rendezvous = data["data"]["data"];
        } else if (data["data"] is List) {
          rendezvous = data["data"];
        } else {
          rendezvous = [];
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Color statutColor(String statut) {
    switch (statut) {
      case "CONFIRMEE":
      case "CONFIRMÉE":
      case "CONFIRMEE":
        return Colors.green;
      case "REFUSEE":
      case "REFUSÉE":
        return Colors.red;
      case "ANNULEE":
      case "ANNULÉE":
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData statutIcon(String statut) {
    switch (statut) {
      case "CONFIRMEE":
      case "CONFIRMÉE":
        return Icons.event_available;
      case "REFUSEE":
      case "REFUSÉE":
        return Icons.cancel;
      case "ANNULEE":
      case "ANNULÉE":
        return Icons.remove_circle;
      default:
        return Icons.pending_actions;
    }
  }

  void showDetails(Map rdv) {
    final medecin =
        "Dr. ${rdv["medecin_nom"] ?? ""} ${rdv["medecin_prenom"] ?? ""}".trim();
    final date = rdv["date_souhaitee"] ?? "-";
    final heure = rdv["heure_souhaitee"] ?? "-";
    final statut = rdv["statut"] ?? "-";

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month, size: 42, color: Colors.blue),
              const SizedBox(height: 12),
              Text(
                medecin,
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),
              detailRow(Icons.date_range, "Date", date),
              detailRow(Icons.access_time, "Heure", heure),
              detailRow(Icons.info, "Statut", statut),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final query = Uri.encodeComponent(medecin);
                    final url = Uri.parse(
                      "https://www.google.com/maps/search/?api=1&query=$query",
                    );
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.map),
                  label: const Text("Voir localisation"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 10),
          Text("$label : ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.event_busy, size: 70, color: Colors.blueGrey),
            SizedBox(height: 16),
            Text(
              "Aucun rendez-vous pour le moment",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Vos demandes de rendez-vous apparaîtront ici.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget rdvCard(Map rdv) {
    final statut = rdv["statut"] ?? "EN_ATTENTE";
    final color = statutColor(statut);

    final medecin =
        "Dr. ${rdv["medecin_nom"] ?? ""} ${rdv["medecin_prenom"] ?? ""}".trim();

    return InkWell(
      onTap: () => showDetails(rdv),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.12),
              child: Icon(statutIcon(statut), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medecin.isEmpty ? "Médecin" : medecin,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Date: ${rdv["date_souhaitee"] ?? "-"}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    "Heure: ${rdv["heure_souhaitee"] ?? "-"}",
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statut,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes rendez-vous"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : rendezvous.isEmpty
              ? emptyState()
              : RefreshIndicator(
                  onRefresh: fetchRendezVous,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: rendezvous.map((e) => rdvCard(e)).toList(),
                  ),
                ),
    );
  }
}