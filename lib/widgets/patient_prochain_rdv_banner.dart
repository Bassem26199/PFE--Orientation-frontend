import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';

class PatientProchainRdvBanner extends StatefulWidget {
  const PatientProchainRdvBanner({super.key});

  @override
  State<PatientProchainRdvBanner> createState() => _PatientProchainRdvBannerState();
}

class _PatientProchainRdvBannerState extends State<PatientProchainRdvBanner> {
  bool loading = true;
  Map<String, dynamic>? prochain;

  @override
  void initState() {
    super.initState();
    fetchProchain();
  }

  Future<void> fetchProchain() async {
    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/patient/prochain-rendezvous'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${AuthService.token}',
        },
      );
      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        final raw = data['data']?['prochain_rendezvous'];
        setState(() {
          prochain = raw is Map ? Map<String, dynamic>.from(raw) : null;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 4,
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    if (prochain == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_available, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Prochain rendez-vous',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prochain!['libelle']?.toString() ?? '',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            prochain!['medecin']?.toString() ?? '',
            style: const TextStyle(color: Colors.black87),
          ),
          if (prochain!['specialite'] != null)
            Text(
              prochain!['specialite'].toString(),
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
        ],
      ),
    );
  }
}
