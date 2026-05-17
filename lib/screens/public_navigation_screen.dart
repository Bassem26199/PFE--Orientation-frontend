import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import 'welcome_screen.dart';
import 'analyser_symptomes_screen.dart';
import 'login_screen.dart';

class PublicNavigationScreen extends StatefulWidget {
  const PublicNavigationScreen({super.key});

  @override
  State<PublicNavigationScreen> createState() => _PublicNavigationScreenState();
}

class _PublicNavigationScreenState extends State<PublicNavigationScreen> {
  int currentIndex = 0;

  List<Widget> get pages => [
        WelcomeScreen(key: ValueKey('welcome_${AuthService.isLoggedIn}')),
        const PublicDoctorsPage(),
        const AnalyserSymptomesScreen(),
        const PublicAvisPage(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() => currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "Accueil",
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: "Médecins",
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: "Analyse",
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline),
            selectedIcon: Icon(Icons.star),
            label: "Avis",
          ),
        ],
      ),
    );
  }
}

class PublicDoctorsPage extends StatefulWidget {
  const PublicDoctorsPage({super.key});

  @override
  State<PublicDoctorsPage> createState() => _PublicDoctorsPageState();
}

class _PublicDoctorsPageState extends State<PublicDoctorsPage> {
  String selectedVille = "Toutes";
  String selectedSpecialite = "Toutes";

  final List<Map<String, dynamic>> doctors = [
    {
      "nom": "Dr. Trabelsi Sami",
      "specialite": "Cardiologie",
      "ville": "Tunis",
      "note": 4.8,
      "adresse": "Centre médical Tunis",
      "telephone": "+21620111222",
    },
    {
      "nom": "Dr. Ben Ali Amel",
      "specialite": "Médecine générale",
      "ville": "Sfax",
      "note": 4.5,
      "adresse": "Cabinet médical Sfax",
      "telephone": "+21622333444",
    },
    {
      "nom": "Dr. Mansouri Karim",
      "specialite": "Neurologie",
      "ville": "Tunis",
      "note": 4.6,
      "adresse": "Clinique neurologique Tunis",
      "telephone": "+21623444555",
    },
  ];

  List<Map<String, dynamic>> get filteredDoctors {
    return doctors.where((d) {
      final matchVille =
          selectedVille == "Toutes" || d["ville"] == selectedVille;
      final matchSpecialite = selectedSpecialite == "Toutes" ||
          d["specialite"] == selectedSpecialite;
      return matchVille && matchSpecialite;
    }).toList();
  }

  Future<void> openMap(Map<String, dynamic> d) async {
    final query = Uri.encodeComponent("${d["adresse"]} ${d["ville"]}");
    final url =
        Uri.parse("https://www.google.com/maps/search/?api=1&query=$query");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> callDoctor(String phone) async {
    final uri = Uri.parse("tel:$phone");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> whatsappDoctor(String phone) async {
    final cleanPhone = phone.replaceAll("+", "");
    final uri = Uri.parse("https://wa.me/$cleanPhone");
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void requireLoginForRdv() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Connexion requise"),
        content: const Text(
          "Pour prendre rendez-vous, veuillez vous connecter avec un compte patient.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
              );
            },
            child: const Text("Se connecter"),
          ),
        ],
      ),
    );
  }

  Widget doctorCard(Map<String, dynamic> d) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.blue.shade50,
                child: const Icon(
                  Icons.medical_services,
                  color: Colors.blue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d["nom"],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${d["specialite"]} • ${d["ville"]}",
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.blueGrey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            d["adresse"],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black45),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 18),
                    const SizedBox(width: 3),
                    Text(
                      d["note"].toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => openMap(d),
                  icon: const Icon(Icons.map),
                  label: const Text("Carte"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => callDoctor(d["telephone"]),
                  icon: const Icon(Icons.call),
                  label: const Text("Appel"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: requireLoginForRdv,
                  icon: const Icon(Icons.event_available),
                  label: const Text("RDV"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => whatsappDoctor(d["telephone"]),
              icon: const Icon(Icons.chat),
              label: const Text("Contacter via WhatsApp"),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final villes = ["Toutes", "Tunis", "Sfax"];
    final specialites = [
      "Toutes",
      "Cardiologie",
      "Médecine générale",
      "Neurologie",
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("Médecins")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Trouver un médecin",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Filtrez les médecins par ville et spécialité.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: selectedVille,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Ville",
                prefixIcon: Icon(Icons.location_city),
              ),
              items: villes
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (value) => setState(() => selectedVille = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedSpecialite,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Spécialité",
                prefixIcon: Icon(Icons.category),
              ),
              items: specialites
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (value) =>
                  setState(() => selectedSpecialite = value!),
            ),
            const SizedBox(height: 18),
            if (filteredDoctors.isEmpty)
              const Center(child: Text("Aucun médecin trouvé"))
            else
              ...filteredDoctors.map(doctorCard),
          ],
        ),
      ),
    );
  }
}

class PublicAvisPage extends StatefulWidget {
  const PublicAvisPage({super.key});

  @override
  State<PublicAvisPage> createState() => _PublicAvisPageState();
}

class _PublicAvisPageState extends State<PublicAvisPage> {
  final nomController = TextEditingController();
  final avisController = TextEditingController();
  int note = 5;

  final List<Map<String, dynamic>> avis = [
    {
      "nom": "Patient anonyme",
      "note": 5,
      "texte": "Application claire et utile pour l’orientation médicale.",
    },
    {
      "nom": "Utilisateur",
      "note": 4,
      "texte": "Interface moderne et navigation facile.",
    },
  ];

  void addAvis() {
    if (avisController.text.trim().isEmpty) return;

    setState(() {
      avis.insert(0, {
        "nom": nomController.text.trim().isEmpty
            ? "Patient anonyme"
            : nomController.text.trim(),
        "note": note,
        "texte": avisController.text.trim(),
      });
    });

    nomController.clear();
    avisController.clear();
    note = 5;
  }

  Widget avisCard(Map<String, dynamic> a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.rate_review, color: Colors.blue),
        title: Text(a["nom"]),
        subtitle: Text(a["texte"]),
        trailing: Text("⭐ ${a["note"]}"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Avis"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      "Ajouter un avis",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nomController,
                      decoration: const InputDecoration(labelText: "Nom"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: avisController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Votre avis",
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        return IconButton(
                          onPressed: () => setState(() => note = value),
                          icon: Icon(
                            value <= note ? Icons.star : Icons.star_border,
                            color: Colors.orange,
                          ),
                        );
                      }),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: addAvis,
                        child: const Text("Publier"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            ...avis.map(avisCard),
          ],
        ),
      ),
    );
  }
}