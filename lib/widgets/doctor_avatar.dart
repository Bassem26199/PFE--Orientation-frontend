import 'package:flutter/material.dart';

import '../utils/doctor_photo.dart';

class DoctorAvatar extends StatelessWidget {
  final Map<dynamic, dynamic>? doctor;
  final String? photoUrl;
  final double radius;
  final int fallbackIndex;
  final Color? backgroundColor;

  const DoctorAvatar({
    super.key,
    this.doctor,
    this.photoUrl,
    this.radius = 30,
    this.fallbackIndex = 0,
    this.backgroundColor,
  });

  bool get _hasCustomPhoto {
    if (photoUrl != null && photoUrl!.isNotEmpty) return true;
    if (doctor == null) return false;
    final url = doctor!['photo_url']?.toString();
    final path = doctor!['photo_profil']?.toString();
    return (url != null && url.isNotEmpty) || (path != null && path.isNotEmpty);
  }

  String get _effectiveUrl {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return DoctorPhoto.resolveUrl(photoUrl!);
    }
    if (doctor != null) {
      final fromDoctor = DoctorPhoto.urlFromDoctor(doctor!);
      if (fromDoctor != null && fromDoctor.isNotEmpty) {
        return fromDoctor;
      }
    }
    return DoctorPhoto.fallbackAvatar(fallbackIndex);
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.blue.shade50;

    if (!_hasCustomPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        backgroundImage: NetworkImage(DoctorPhoto.fallbackAvatar(fallbackIndex)),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          _effectiveUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.person,
            size: radius,
            color: Colors.blue.shade700,
          ),
        ),
      ),
    );
  }
}
