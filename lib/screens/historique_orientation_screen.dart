import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../utils/orientation_display.dart';

class HistoriqueOrientationScreen extends StatefulWidget {
  const HistoriqueOrientationScreen({super.key});

  @override
  State<HistoriqueOrientationScreen> createState() =>
      _HistoriqueOrientationScreenState();
}

class _HistoriqueOrientationScreenState
    extends State<HistoriqueOrientationScreen> {
  bool isLoading = true;
  List orientations = [];

  @override
  void initState() {
    super.initState();
    fetchHistorique();
  }

  Future<void> fetchHistorique() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/orientations/patient"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      setState(() {
        orientations = data["data"] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Color urgenceColor(String urgence) {
    switch (urgence) {
      case "URGENT":
        return Colors.red;
      case "MODERE":
      case "MODÉRÉ":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData urgenceIcon(String urgence) {
    switch (urgence) {
      case "URGENT":
        return Icons.warning;
      case "MODERE":
      case "MODÉRÉ":
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  Widget emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history, size: 70, color: Colors.blueGrey),
            SizedBox(height: 16),
            Text(
              "Aucune orientation trouvée",
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Vos analyses de symptômes apparaîtront ici.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget orientationCard(Map orientation) {
    final specialite = orientation["nom_specialite"] ??
        orientation["specialite"] ??
        "Spécialité non définie";

    final urgence = orientation["niveau_urgence"] ?? "-";
    final date = orientation["date_orientation"] ??
        orientation["created_at"] ??
        orientation["date_creation"] ??
        "-";
    final maladie = OrientationDisplay.maladieSuspectee(
      Map<String, dynamic>.from(orientation),
    );

    final color = urgenceColor(urgence);

    return Container(
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
            child: Icon(urgenceIcon(urgence), color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  specialite,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$date • ${OrientationDisplay.urgenceLabel(urgence.toString())}",
                  style: const TextStyle(color: Colors.black54),
                ),
                if (maladie != null && maladie.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    maladie,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique orientation"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : orientations.isEmpty
              ? emptyState()
              : RefreshIndicator(
                  onRefresh: fetchHistorique,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children:
                        orientations.map((e) => orientationCard(e)).toList(),
                  ),
                ),
    );
  }
}