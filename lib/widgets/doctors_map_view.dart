import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/medecin_service.dart';

/// Carte OpenStreetMap affichant plusieurs médecins.
class DoctorsMapView extends StatefulWidget {
  final List<Map<String, dynamic>> doctors;
  final double height;
  final double initialZoom;

  const DoctorsMapView({
    super.key,
    required this.doctors,
    this.height = 260,
    this.initialZoom = 7,
  });

  @override
  State<DoctorsMapView> createState() => _DoctorsMapViewState();
}

class _DoctorsMapViewState extends State<DoctorsMapView> {
  final MapController _mapController = MapController();

  double? _parseCoord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  List<Map<String, dynamic>> get _locatedDoctors =>
      MedecinService.withMapCoordinates(widget.doctors);

  LatLng _initialCenter() {
    final located = _locatedDoctors;
    if (located.isEmpty) {
      return const LatLng(36.8065, 10.1815);
    }

    double latSum = 0;
    double lngSum = 0;
    for (final doctor in located) {
      latSum += _parseCoord(doctor['latitude'])!;
      lngSum += _parseCoord(doctor['longitude'])!;
    }

    return LatLng(latSum / located.length, lngSum / located.length);
  }

  double _zoomForDoctors() {
    final count = _locatedDoctors.length;
    if (count <= 1) return 13;
    if (count <= 3) return 10;
    if (count <= 8) return 8;
    return widget.initialZoom;
  }

  void _showDoctorInfo(Map<String, dynamic> doctor) {
    final name = doctor['nom_complet']?.toString() ??
        'Dr. ${doctor['prenom']} ${doctor['nom']}';
    final specialite =
        doctor['specialite'] ?? doctor['nom_specialite'] ?? '-';
    final ville = doctor['ville']?.toString() ?? '-';
    final adresse = doctor['adresse']?.toString() ??
        doctor['adresse_cabinet']?.toString() ??
        '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$specialite • $ville',
              style: const TextStyle(color: Colors.black54),
            ),
            if (adresse.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(child: Text(adresse)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final located = _locatedDoctors;

    if (located.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Aucun médecin géolocalisé pour le moment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    final center = _initialCenter();
    final markers = located.map((doctor) {
      final point = LatLng(
        _parseCoord(doctor['latitude'])!,
        _parseCoord(doctor['longitude'])!,
      );

      return Marker(
        point: point,
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: () => _showDoctorInfo(doctor),
          child: const Icon(
            Icons.location_pin,
            color: Color(0xFF0D47A1),
            size: 44,
          ),
        ),
      );
    }).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: _zoomForDoctors(),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.pinchZoom |
                      InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.frontend_orientation',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '${located.length} médecin(s) sur la carte',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
