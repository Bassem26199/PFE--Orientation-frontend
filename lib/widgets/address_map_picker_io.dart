import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../services/nominatim_service.dart';

/// Carte OpenStreetMap : le patient touche la carte pour choisir son adresse.
class AddressMapPicker extends StatefulWidget {
  final TextEditingController addressController;
  final VoidCallback? onAddressUpdated;
  final double? initialLatitude;
  final double? initialLongitude;
  final bool readOnly;

  const AddressMapPicker({
    super.key,
    required this.addressController,
    this.onAddressUpdated,
    this.initialLatitude,
    this.initialLongitude,
    this.readOnly = false,
  });

  @override
  State<AddressMapPicker> createState() => AddressMapPickerState();
}

class AddressMapPickerState extends State<AddressMapPicker> {
  static const LatLng _defaultCenter = LatLng(36.8065, 10.1815);

  final MapController _mapController = MapController();
  LatLng? _selected;
  bool _loadingLocation = false;
  bool _loadingAddress = false;

  double? get latitude => _selected?.latitude;
  double? get longitude => _selected?.longitude;

  void reset() {
    setState(() {
      _selected = null;
      _loadingAddress = false;
      _loadingLocation = false;
    });
    widget.addressController.clear();
    _mapController.move(_defaultCenter, 12);
    widget.onAddressUpdated?.call();
  }

  void setInitialPosition(double lat, double lng, {String? address}) {
    _selected = LatLng(lat, lng);
    if (address != null && address.isNotEmpty) {
      widget.addressController.text = address;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selected != null) {
        _mapController.move(_selected!, 14);
      }
    });
    widget.onAddressUpdated?.call();
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    final lat = widget.initialLatitude;
    final lng = widget.initialLongitude;
    if (lat != null && lng != null) {
      _selected = LatLng(lat, lng);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(_selected!, 14);
        if (widget.addressController.text.trim().isEmpty) {
          _updateFromLatLng(_selected!, moveCamera: false);
        } else if (mounted) {
          setState(() {});
        }
      });
    } else if (!widget.readOnly) {
      widget.addressController.clear();
    }
  }

  Future<void> _updateFromLatLng(LatLng position, {bool moveCamera = true}) async {
    setState(() {
      _selected = position;
      _loadingAddress = true;
    });

    if (moveCamera) {
      _mapController.move(position, _mapController.camera.zoom);
    }

    try {
      final address = await NominatimService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      widget.addressController.text = address ?? '';
    } catch (_) {
      widget.addressController.text = '';
    } finally {
      if (mounted) {
        setState(() => _loadingAddress = false);
        widget.onAddressUpdated?.call();
      }
    }
  }

  Future<void> _goToMyPosition() async {
    setState(() => _loadingLocation = true);

    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Autorisez la localisation pour utiliser cette option.",
              ),
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      await _updateFromLatLng(LatLng(pos.latitude, pos.longitude));
      _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Impossible d'obtenir la position : $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _selected ?? _defaultCenter;
    final hasSelection = _selected != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.readOnly)
          Text(
            "Choisissez votre position",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        const SizedBox(height: 6),
        if (!widget.readOnly)
          const Text(
            "Touchez la carte pour placer le repère à votre domicile.",
            style: TextStyle(color: Colors.black54, fontSize: 13),
          ),
        const SizedBox(height: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12,
                    onTap: widget.readOnly
                        ? null
                        : (_, point) => _updateFromLatLng(point),
                    interactionOptions: InteractionOptions(
                      flags: widget.readOnly
                          ? InteractiveFlag.none
                          : InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.frontend_orientation',
                    ),
                    if (hasSelection)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selected!,
                            width: 48,
                            height: 48,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 48,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_loadingAddress || _loadingLocation)
                  const ColoredBox(
                    color: Color(0x33000000),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!widget.readOnly)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: FloatingActionButton.small(
                      heroTag: 'my_location_osm',
                      onPressed: _loadingLocation ? null : _goToMyPosition,
                      tooltip: "Ma position",
                      child: const Icon(Icons.my_location),
                    ),
                  ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "© OpenStreetMap",
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
