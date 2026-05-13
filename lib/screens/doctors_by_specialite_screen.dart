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

  @override
  void initState() {
    super.initState();
    fetchDoctors();
  }

  Future<void> fetchDoctors() async {
    try {
      final response = await http.get(
        Uri.parse(
          "${AuthService.baseUrl}/medecins/specialite/${widget.idSpecialite}",
        ),
        headers: {
          "Accept": "application/json",
          if (AuthService.token != null)
            "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      setState(() {
        doctors = data["data"] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
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
        subtitle: Text(
          "${doctor['ville'] ?? '-'}\nNote: ${doctor['note_moyenne'] ?? '-'} ⭐",
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
              ? const Center(
                  child: Text("Aucun médecin disponible pour cette spécialité"),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: doctors.length,
                  itemBuilder: (context, index) {
                    return doctorCard(doctors[index], index);
                  },
                ),
    );
  }
}