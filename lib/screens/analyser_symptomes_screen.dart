import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/auth_service.dart';
import 'doctors_by_specialite_screen.dart';
import 'login_screen.dart';

class AnalyserSymptomesScreen extends StatefulWidget {
  const AnalyserSymptomesScreen({super.key});

  @override
  State<AnalyserSymptomesScreen> createState() =>
      _AnalyserSymptomesScreenState();
}

class _AnalyserSymptomesScreenState extends State<AnalyserSymptomesScreen> {
  bool isLoading = false;

  final TextEditingController autreSymptomeController =
      TextEditingController();

  final List<int> selectedSymptomes = [];
  final List<String> symptomesLibres = [];

  final List<Map<String, dynamic>> symptomes = [
    {
      "id": 3,
      "nom": "Douleur thoracique",
      "desc": "Douleur ou pression au niveau de la poitrine.",
      "icon": Icons.favorite,
      "color": Colors.red,
    },
    {
      "id": 1,
      "nom": "Fièvre",
      "desc": "Élévation anormale de la température corporelle.",
      "icon": Icons.thermostat,
      "color": Colors.orange,
    },
    {
      "id": 2,
      "nom": "Toux",
      "desc": "Réflexe respiratoire fréquent.",
      "icon": Icons.air,
      "color": Colors.blue,
    },
    {
      "id": 4,
      "nom": "Maux de tête",
      "desc": "Douleur au niveau de la tête.",
      "icon": Icons.psychology,
      "color": Colors.purple,
    },
    {
      "id": 6,
      "nom": "Douleur abdominale",
      "desc": "Douleur ou gêne au niveau du ventre.",
      "icon": Icons.sick,
      "color": Colors.green,
    },
    {
      "id": 5,
      "nom": "Fatigue",
      "desc": "Sensation de faiblesse ou d’épuisement.",
      "icon": Icons.battery_alert,
      "color": Colors.teal,
    },
  ];

  void toggleSymptome(int id) {
    setState(() {
      selectedSymptomes.contains(id)
          ? selectedSymptomes.remove(id)
          : selectedSymptomes.add(id);
    });
  }

  void ajouterSymptomeLibre() {
    final value = autreSymptomeController.text.trim();

    if (value.isEmpty) return;

    if (!symptomesLibres.contains(value)) {
      setState(() {
        symptomesLibres.add(value);
        autreSymptomeController.clear();
      });
    }
  }

  void showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.lock, color: Colors.blue, size: 34),
              ),
              const SizedBox(height: 16),
              const Text(
                "Connexion requise",
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Veuillez vous connecter pour analyser vos symptômes et enregistrer l’orientation.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Fermer"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      child: const Text("Se connecter"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<int?> resolvePatientAge() async {
    final cached = AuthService.currentUser?["age"];
    if (cached != null) return int.tryParse(cached.toString());

    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/me"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data["data"];
        if (user is Map && user["age"] != null) {
          return int.tryParse(user["age"].toString());
        }
      }
    } catch (_) {}

    return null;
  }

  Future<void> analyser() async {
    if (selectedSymptomes.isEmpty && symptomesLibres.isEmpty) return;

    if (AuthService.token == null) {
      showLoginRequiredDialog();
      return;
    }

    setState(() => isLoading = true);

    final patientAge = await resolvePatientAge();
    final apiUrl = "${AuthService.baseUrl}/orientation";

    debugPrint("[Orientation] API=$apiUrl age=$patientAge");

    try {
      final health = await http.get(Uri.parse("${AuthService.baseUrl}/health"));
      debugPrint("[Orientation] health ${health.statusCode} ${health.body}");

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
        body: jsonEncode({
          "symptomes": selectedSymptomes,
          "symptomes_libres": symptomesLibres,
          if (patientAge != null) "age": patientAge,
        }),
      );

      if (!mounted) return;

      debugPrint(
        "[Orientation] POST ${response.statusCode} body=${response.body}",
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final result = data["data"];
        if (result is! Map) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Réponse serveur invalide")),
          );
          return;
        }

        final engineVersion = result["engine_version"]?.toString();
        final idSpecialite = result["id_specialite"];
        final nomSpecialite = result["nom_specialite"]?.toString() ?? "";
        final ageFromApi = result["age_patient"] ?? patientAge;
        final ageNum = ageFromApi != null ? int.tryParse(ageFromApi.toString()) : patientAge;

        if (engineVersion == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "⚠ Ancien serveur détecté ($apiUrl). Lancez Laravel depuis PFE--Orientation-medical.",
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }

        final isPediatrie = idSpecialite == 3 ||
            nomSpecialite.toLowerCase().contains('pédiat') ||
            nomSpecialite.toLowerCase().contains('pediat');

        if (isPediatrie && ageNum != null && ageNum > 17) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Erreur : le serveur a renvoyé Pédiatrie pour $ageNum ans. "
                "Vérifiez que Laravel tourne sur ${ApiConfig.baseUrl}",
              ),
              duration: const Duration(seconds: 8),
            ),
          );
          return;
        }

        showResultDialog(
          result: Map<String, dynamic>.from(result),
          specialite: result["nom_specialite"]?.toString() ?? "Non définie",
          urgence: result["niveau_urgence"]?.toString() ?? "-",
          agePatient: result["age_patient"],
          profil: result["profil"]?.toString(),
        );
      } else {
        final message = data["message"]?.toString() ??
            "Erreur (${response.statusCode})";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Impossible de joindre le serveur. Vérifiez l'URL API et que Laravel tourne.",
          ),
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  void showResultDialog({
    required Map result,
    required String specialite,
    required String urgence,
    int? agePatient,
    String? profil,
  }) {
    final isUrgent = urgence == "URGENT";
    final isModere = urgence == "MODERE" || urgence == "MODÉRÉ";

    final color = isUrgent
        ? Colors.red
        : isModere
            ? Colors.orange
            : Colors.green;

    final icon = isUrgent
        ? Icons.warning
        : isModere
            ? Icons.info
            : Icons.check_circle;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                "Résultat de l’orientation",
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              Text(
                "Spécialité recommandée : $specialite",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                "Niveau d’urgence : $urgence",
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
              if (agePatient != null) ...[
                const SizedBox(height: 10),
                Text(
                  "Recommandation adaptée à votre profil ($agePatient ans${profil != null ? ", $profil" : ""})",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
              if (symptomesLibres.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  "Symptômes ajoutés : ${symptomesLibres.join(", ")}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Fermer"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DoctorsBySpecialiteScreen(
                              idSpecialite: result["id_specialite"],
                              nomSpecialite: specialite,
                              idOrientation: result["id_orientation"] ?? 0,
                            ),
                          ),
                        );
                      },
                      child: const Text("Voir médecins"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget symptomeCard(Map<String, dynamic> s) {
    final isSelected = selectedSymptomes.contains(s["id"]);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (_) => toggleSymptome(s["id"]),
        activeColor: Colors.blue,
        title: Text(
          s["nom"],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(s["desc"]),
        secondary: CircleAvatar(
          backgroundColor: (s["color"] as Color).withOpacity(0.12),
          child: Icon(s["icon"], color: s["color"]),
        ),
      ),
    );
  }

  Widget autresSymptomesBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Autres symptômes",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: autreSymptomeController,
            decoration: InputDecoration(
              hintText: "Ex: vertiges, nausées, douleur au dos...",
              prefixIcon: const Icon(Icons.add_circle_outline),
              suffixIcon: IconButton(
                icon: const Icon(Icons.add),
                onPressed: ajouterSymptomeLibre,
              ),
            ),
            onSubmitted: (_) => ajouterSymptomeLibre(),
          ),
          const SizedBox(height: 10),
          if (symptomesLibres.isEmpty)
            const Text(
              "Vous pouvez ajouter un symptôme non présent dans la liste.",
              style: TextStyle(color: Colors.black54, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: symptomesLibres.map((s) {
                return Chip(
                  label: Text(s),
                  deleteIcon: const Icon(Icons.close),
                  onDeleted: () {
                    setState(() => symptomesLibres.remove(s));
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAnalyze =
        (selectedSymptomes.isNotEmpty || symptomesLibres.isNotEmpty) &&
            !isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Analyser les symptômes"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Sélectionnez vos symptômes",
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Choisissez les symptômes proposés ou ajoutez d’autres symptômes manuellement.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: [
                  ...symptomes.map(symptomeCard),
                  autresSymptomesBox(),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: canAnalyze ? analyser : null,
                icon: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.health_and_safety),
                label: Text(isLoading ? "Analyse en cours..." : "Analyser"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}