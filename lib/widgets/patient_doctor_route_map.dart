import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/route_service.dart';

/// Carte avec itinéraire routier entre le patient et le médecin.
class PatientDoctorRouteMap extends StatefulWidget {
  final double patientLat;
  final double patientLng;
  final double doctorLat;
  final double doctorLng;
  final String? doctorAddress;
  final double height;
  final void Function(RouteResult route, {required bool isRoadRoute})?
      onRouteCalculated;

  const PatientDoctorRouteMap({
    super.key,
    required this.patientLat,
    required this.patientLng,
    required this.doctorLat,
    required this.doctorLng,
    this.doctorAddress,
    this.height = 280,
    this.onRouteCalculated,
  });

  @override
  State<PatientDoctorRouteMap> createState() => _PatientDoctorRouteMapState();
}

class _PatientDoctorRouteMapState extends State<PatientDoctorRouteMap> {
  final MapController _mapController = MapController();

  RouteResult? _route;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final route = await RouteService.getDrivingRoute(
      startLat: widget.patientLat,
      startLng: widget.patientLng,
      endLat: widget.doctorLat,
      endLng: widget.doctorLng,
    );

    if (!mounted) return;

    final fallbackRoute = route ??
        RouteResult(
          points: [
            LatLng(widget.patientLat, widget.patientLng),
            LatLng(widget.doctorLat, widget.doctorLng),
          ],
          distanceKm: const Distance().as(
            LengthUnit.Kilometer,
            LatLng(widget.patientLat, widget.patientLng),
            LatLng(widget.doctorLat, widget.doctorLng),
          ),
          durationMinutes: 0,
        );

    if (!mounted) return;

    setState(() {
      _route = fallbackRoute;
      _loading = false;
      _error = route == null ? 'Trajet approximatif (ligne directe)' : null;
    });

    widget.onRouteCalculated?.call(
      fallbackRoute,
      isRoadRoute: route != null,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds(fallbackRoute));
  }

  void _fitBounds(RouteResult route) {
    final all = [
      LatLng(widget.patientLat, widget.patientLng),
      LatLng(widget.doctorLat, widget.doctorLng),
      ...route.points,
    ];

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(all),
        padding: const EdgeInsets.all(48),
      ),
    );
  }

  Widget _marker(IconData icon, Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        Icon(icon, color: color, size: 40),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final patient = LatLng(widget.patientLat, widget.patientLng);
    final doctor = LatLng(widget.doctorLat, widget.doctorLng);
    final center = LatLng(
      (widget.patientLat + widget.doctorLat) / 2,
      (widget.patientLng + widget.doctorLng) / 2,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 12,
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
                if (_route != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _route!.points,
                        color: _error != null
                            ? Colors.orange.shade700
                            : const Color(0xFF1565C0),
                        strokeWidth: _error != null ? 4 : 5,
                        borderColor: Colors.white,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: patient,
                      width: 80,
                      height: 70,
                      alignment: Alignment.topCenter,
                      child: _marker(
                        Icons.home,
                        Colors.green.shade700,
                        'Vous',
                      ),
                    ),
                    Marker(
                      point: doctor,
                      width: 80,
                      height: 70,
                      alignment: Alignment.topCenter,
                      child: _marker(
                        Icons.local_hospital,
                        Colors.red,
                        'Médecin',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_loading)
              const ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: _loading
                      ? const Text(
                          'Calcul de l\'itinéraire...',
                          style: TextStyle(fontSize: 12),
                        )
                      : _route != null
                          ? Row(
                              children: [
                                Icon(
                                  _error != null
                                      ? Icons.straighten
                                      : Icons.directions_car,
                                  size: 18,
                                  color: _error != null
                                      ? Colors.orange.shade800
                                      : const Color(0xFF1565C0),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error != null
                                        ? '${_route!.distanceLabel} (ligne directe)'
                                        : '${_route!.distanceLabel} • ${_route!.durationLabel} en voiture',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Itinéraire indisponible',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
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
                  '© OpenStreetMap • OSRM',
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
