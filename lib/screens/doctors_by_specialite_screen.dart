import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import 'doctor_details_screen.dart';

class DoctorsBySpecialiteScreen extends StatefulWidget {
  final int idSpecialite;
  final String nomSpecialite;
  final int idOrientation;

  const DoctorsBySpecialiteScreen({
    super.key,
    required this.idSpecialite,
    required this.nomSpecialite,
    required this.idOrientation,
  });

  @override
  State<DoctorsBySpecialiteScreen> createState() =>
      _DoctorsBySpecialiteScreenState();
}

class _DoctorsBySpecialiteScreenState extends State<DoctorsBySpecialiteScreen> {
  List doctors = [];
  bool isLoading = true;
  double? patientLat;
  double? patientLng;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  double? _parseCoord(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  Future<void> _loadPatientLocation() async {
    if (AuthService.token == null) return;

    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/me"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );
      final data = jsonDecode(response.body);
      if (data["success"] == true && data["data"] is Map) {
        final profile = data["data"] as Map;
        patientLat = _parseCoord(profile["latitude"]);
        patientLng = _parseCoord(profile["longitude"]);
      }
    } catch (_) {}
  }

  Future<void> _loadDoctors() async {
    setState(() => isLoading = true);
    await _loadPatientLocation();

    try {
      final query = <String, String>{};
      if (patientLat != null && patientLng != null) {
        query['patient_latitude'] = patientLat.toString();
        query['patient_longitude'] = patientLng.toString();
      }

      final uri = Uri.parse(
        "${AuthService.baseUrl}/medecins/specialite/${widget.idSpecialite}",
      ).replace(queryParameters: query.isEmpty ? null : query);

      final response = await http.get(
        uri,
        headers: {
          "Accept": "application/json",
          if (AuthService.token != null)
            "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        doctors = data["data"] ?? [];
        isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String getDoctorImage(int index) {
    final images = [
      "https://cdn-icons-png.flaticon.com/512/3774/3774299.png",
      "https://cdn-icons-png.flaticon.com/512/3304/3304567.png",
      "https://cdn-icons-png.flaticon.com/512/3870/3870822.png",
    ];
    return images[index % images.length];
  }

  Widget doctorCard(Map doctor, int index) {
    final adresse = doctor['adresse_cabinet']?.toString() ?? '';
    final ville = doctor['ville']?.toString() ?? '-';
    final distance = doctor['distance_km'];
    final distanceLabel = distance != null ? " • ${distance} km" : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: Colors.blue.shade50,
          backgroundImage: NetworkImage(getDoctorImage(index)),
        ),
        title: Text(
          "Dr. ${doctor['nom']} ${doctor['prenom']}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$ville$distanceLabel • ⭐ ${doctor['note_moyenne'] ?? '-'}"),
            if (adresse.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                adresse,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ],
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DoctorDetailsScreen(
                doctor: doctor,
                idOrientation: widget.idOrientation,
                imageUrl: getDoctorImage(index),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Médecins - ${widget.nomSpecialite}"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : doctors.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.medical_services_outlined,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text(
                          "Aucun médecin disponible pour cette spécialité",
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Exécutez sur le serveur :\nphp artisan db:seed --class=MedecinsDemoSeeder",
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadDoctors,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Actualiser"),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDoctors,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: doctors.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            patientLat != null
                                ? "${doctors.length} médecin(s) — triés par proximité"
                                : "${doctors.length} médecin(s) recommandé(s)",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        );
                      }
                      return doctorCard(doctors[index - 1], index - 1);
                    },
                  ),
                ),
    );
  }
}
