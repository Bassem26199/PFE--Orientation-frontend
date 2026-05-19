import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/nominatim_service.dart';
import '../widgets/location_map_view.dart';
import '../widgets/patient_doctor_route_map.dart';
import '../widgets/doctor_reviews_section.dart';
import 'create_rendezvous_screen.dart';

class DoctorDetailsScreen extends StatefulWidget {
  final Map doctor;
  final int idOrientation;
  final String imageUrl;

  const DoctorDetailsScreen({
    super.key,
    required this.doctor,
    required this.idOrientation,
    required this.imageUrl,
  });

  @override
  State<DoctorDetailsScreen> createState() => _DoctorDetailsScreenState();
}

class _DoctorDetailsScreenState extends State<DoctorDetailsScreen> {
  double? _doctorLat;
  double? _doctorLng;
  double? _patientLat;
  double? _patientLng;
  bool _mapLoading = true;

  @override
  void initState() {
    super.initState();
    _resolveLocations();
  }

  double? _parseCoord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
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
        _patientLat = _parseCoord(profile["latitude"]);
        _patientLng = _parseCoord(profile["longitude"]);
      }
    } catch (_) {}
  }

  Future<void> _resolveLocations() async {
    await _loadPatientLocation();

    var lat = _parseCoord(widget.doctor['latitude']);
    var lng = _parseCoord(widget.doctor['longitude']);

    if (lat == null || lng == null) {
      final adresse = widget.doctor['adresse_cabinet']?.toString() ?? '';
      final ville = widget.doctor['ville']?.toString() ?? '';
      final query = [adresse, ville, 'Tunisie']
          .where((e) => e.isNotEmpty)
          .join(', ');

      if (query.isNotEmpty) {
        final coords = await NominatimService.forwardGeocode(query);
        if (coords != null) {
          lat = coords.latitude;
          lng = coords.longitude;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _doctorLat = lat;
      _doctorLng = lng;
      _mapLoading = false;
    });
  }

  Future<void> openMap() async {
    final dLat = _doctorLat;
    final dLng = _doctorLng;
    final pLat = _patientLat;
    final pLng = _patientLng;
    final Uri url;

    if (pLat != null && pLng != null && dLat != null && dLng != null) {
      url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1"
        "&origin=$pLat,$pLng&destination=$dLat,$dLng&travelmode=driving",
      );
    } else if (dLat != null && dLng != null) {
      url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$dLat,$dLng",
      );
    } else {
      final adresse =
          widget.doctor["adresse_cabinet"] ?? widget.doctor["ville"] ?? "";
      final query = Uri.encodeComponent(adresse.toString());
      url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    }

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> callDoctor() async {
    final phone = widget.doctor["telephone_professionnel"] ?? "";
    if (phone.toString().isEmpty) return;

    final url = Uri.parse("tel:$phone");
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> whatsappDoctor() async {
    final phone = widget.doctor["telephone_professionnel"] ?? "";
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

  Widget _mapSection() {
    final adresse = widget.doctor["adresse_cabinet"]?.toString() ?? "";
    final hasPatient =
        _patientLat != null && _patientLng != null;
    final hasDoctor = _doctorLat != null && _doctorLng != null;
    final hasRoute = hasPatient && hasDoctor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          hasRoute
              ? "Itinéraire vers le cabinet"
              : "Localisation du cabinet",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (hasRoute) ...[
          const SizedBox(height: 4),
          const Text(
            "Trajet en voiture depuis votre position",
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        if (_mapLoading)
          Container(
            height: 280,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text("Chargement de la carte..."),
              ],
            ),
          )
        else if (hasRoute)
          PatientDoctorRouteMap(
            patientLat: _patientLat!,
            patientLng: _patientLng!,
            doctorLat: _doctorLat!,
            doctorLng: _doctorLng!,
            doctorAddress: adresse.isNotEmpty ? adresse : null,
            height: 280,
          )
        else if (hasDoctor)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasPatient)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Ajoutez votre adresse dans Mon profil pour voir l'itinéraire.",
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              LocationMapView(
                latitude: _doctorLat!,
                longitude: _doctorLng!,
                height: 240,
                markerLabel: adresse.isNotEmpty ? adresse : null,
              ),
            ],
          )
        else
          Container(
            height: 120,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "Carte indisponible pour cette adresse.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final nom = "Dr. ${widget.doctor['nom']} ${widget.doctor['prenom']}";
    final ville = widget.doctor["ville"] ?? "-";
    final telephone = widget.doctor["telephone_professionnel"] ?? "-";
    final adresse = widget.doctor["adresse_cabinet"] ?? "-";
    final note = widget.doctor["note_moyenne"]?.toString() ?? "-";
    final distance = widget.doctor["distance_km"];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails médecin"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    backgroundImage: NetworkImage(widget.imageUrl),
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
                    distance != null
                        ? "$ville • ${distance} km • ⭐ $note"
                        : "$ville • ⭐ $note",
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _mapSection(),
            const SizedBox(height: 20),
            infoTile(Icons.location_city, "Ville", ville),
            infoTile(Icons.location_on, "Adresse du cabinet", adresse),
            infoTile(Icons.phone, "Téléphone", telephone),
            infoTile(Icons.star, "Note moyenne", note),
            const SizedBox(height: 20),
            if (int.tryParse(widget.doctor['id_medecin']?.toString() ?? '') !=
                null)
              DoctorReviewsSection(
                idMedecin:
                    int.parse(widget.doctor['id_medecin'].toString()),
                medecinLabel: nom,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: openMap,
                    icon: const Icon(Icons.map),
                    label: Text(
                      _patientLat != null && _doctorLat != null
                          ? "Itinéraire Maps"
                          : "Ouvrir dans Maps",
                    ),
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
                        doctor: widget.doctor,
                        idOrientation: widget.idOrientation,
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
