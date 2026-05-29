import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';

class CreateRendezvousScreen extends StatefulWidget {
  final Map doctor;
  final int idOrientation;

  const CreateRendezvousScreen({
    super.key,
    required this.doctor,
    required this.idOrientation,
  });

  @override
  State<CreateRendezvousScreen> createState() => _CreateRendezvousScreenState();
}

class _CreateRendezvousScreenState extends State<CreateRendezvousScreen> {
  DateTime? selectedDate;
  String? selectedHeure;
  bool isLoading = false;
  bool loadingCreneaux = false;
  List<Map<String, dynamic>> creneaux = [];
  String? creneauxMessage;

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() {
        selectedDate = date;
        selectedHeure = null;
        creneaux = [];
      });
      await fetchCreneaux(date);
    }
  }

  Future<void> fetchCreneaux(DateTime date) async {
    setState(() {
      loadingCreneaux = true;
      creneauxMessage = null;
    });

    try {
      final dateStr = formatDate(date);
      final response = await http.get(
        Uri.parse(
          '${AuthService.baseUrl}/medecins/${widget.doctor['id_medecin']}/creneaux?date=$dateStr',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${AuthService.token}',
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>;
        final list = (payload['creneaux'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        setState(() {
          creneaux = list;
          creneauxMessage = list.isEmpty
              ? (data['message']?.toString() ??
                  'Aucun créneau disponible ce jour-là.')
              : null;
        });
      } else {
        setState(() {
          creneaux = [];
          creneauxMessage =
              data['message']?.toString() ?? 'Impossible de charger les créneaux';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          creneaux = [];
          creneauxMessage = 'Erreur lors du chargement des créneaux';
        });
      }
    }

    if (mounted) {
      setState(() => loadingCreneaux = false);
    }
  }

  String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> submit() async {
    if (selectedDate == null || selectedHeure == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une date et un créneau horaire')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${AuthService.baseUrl}/demandes-rendezvous'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AuthService.token}',
        },
        body: jsonEncode({
          'id_medecin': widget.doctor['id_medecin'],
          'id_orientation': widget.idOrientation,
          'date_souhaitee': formatDate(selectedDate!),
          'heure_souhaitee': selectedHeure,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        if (!mounted) return;

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Demande envoyée'),
            content: const Text(
              'Votre demande de rendez-vous a été envoyée au secrétariat.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Erreur')),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur serveur')),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prendre rendez-vous'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.doctor['nom']} ${widget.doctor['prenom']}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Les horaires affichés sont configurés par le secrétariat du cabinet.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  selectedDate == null
                      ? 'Choisir une date'
                      : formatDate(selectedDate!),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (selectedDate != null) ...[
              const Text(
                'Créneaux disponibles',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (loadingCreneaux)
                const Center(child: CircularProgressIndicator())
              else if (creneauxMessage != null)
                Text(creneauxMessage!, style: const TextStyle(color: Colors.orange))
              else
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: creneaux.length,
                    itemBuilder: (context, index) {
                      final slot = creneaux[index];
                      final heure = slot['heure']?.toString() ?? '';
                      final label = slot['label']?.toString() ?? heure.substring(0, 5);
                      final selected = selectedHeure == heure;

                      return ChoiceChip(
                        label: Text(label),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => selectedHeure = heure);
                        },
                      );
                    },
                  ),
                ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Sélectionnez une date pour voir les créneaux',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : submit,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Confirmer la demande'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
