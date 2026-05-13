import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/ordonnance_pdf_service.dart';
import '../data/medicaments_data.dart';
import 'public_navigation_screen.dart';
import '../services/ordonnance_pdf_service.dart';
class MedecinHome extends StatefulWidget {
  const MedecinHome({super.key});

  @override
  State<MedecinHome> createState() => _MedecinHomeState();
}

class _MedecinHomeState extends State<MedecinHome> {
  int selectedIndex = 0;
  bool isLoading = true;

  String rdvSearch = "";
  String patientSearch = "";

  List<Map<String, dynamic>> rendezvous = [];

  final List<String> medicaments = medicamentsData;

  final List<String> conseilsGeneraux = [
    "Repos",
    "Hydratation",
    "Surveillance de la température",
    "Contrôle médical si aggravation",
  ];

  final List<Map<String, dynamic>> patients = [
    {
      "nom": "Ben Salah",
      "prenom": "Ali",
      "age": "32",
      "genre": "M",
      "telephone": "20111222",
      "email": "ali.patient@gmail.com",
      "dernierRdv": "2026-04-27",
      "symptomes": "Douleur thoracique, fatigue",
      "specialite": "Cardiologie",
      "urgence": "MODERE",
      "notes": [
        {
          "date": "2026-04-27 10:00",
          "type": "Observation clinique",
          "contenu": "Patient à surveiller. Consultation recommandée.",
        }
      ],
      "ordonnances": [],
    },
    {
      "nom": "User",
      "prenom": "Test",
      "age": "28",
      "genre": "M",
      "telephone": "20111222",
      "email": "test@test.com",
      "dernierRdv": "2026-04-29",
      "symptomes": "Fièvre, toux",
      "specialite": "Médecine générale",
      "urgence": "FAIBLE",
      "notes": [
        {
          "date": "2026-04-29 09:30",
          "type": "Observation clinique",
          "contenu": "Orientation indicative. Aucun signe grave déclaré.",
        }
      ],
      "ordonnances": [],
    },
  ];

  final List<Map<String, dynamic>> secretaires = [
    {
      "nom": "Mansouri",
      "prenom": "Sarra",
      "email": "sarra.secretariat@gmail.com",
      "telephone": "22111222",
      "actif": true,
    },
  ];

  @override
  void initState() {
    super.initState();
    fetchRendezVous();
  }

  Future<void> fetchRendezVous() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/rendezvous"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      setState(() {
        if (data["data"] is Map && data["data"]["data"] != null) {
          rendezvous = List<Map<String, dynamic>>.from(
            data["data"]["data"].map((e) => Map<String, dynamic>.from(e)),
          );
        } else if (data["data"] is List) {
          rendezvous = List<Map<String, dynamic>>.from(
            data["data"].map((e) => Map<String, dynamic>.from(e)),
          );
        } else {
          rendezvous = [];
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        rendezvous = [];
        isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get filteredRendezVous {
    return rendezvous.where((r) {
      final text =
          "${r["patient_nom"] ?? ""} ${r["patient_prenom"] ?? ""} ${r["date_rendezvous"] ?? ""}"
              .toLowerCase();

      return text.contains(rdvSearch.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get filteredPatients {
    return patients.where((p) {
      final text =
          "${p["nom"]} ${p["prenom"]} ${p["email"]} ${p["telephone"]}"
              .toLowerCase();

      return text.contains(patientSearch.toLowerCase());
    }).toList();
  }

  BoxDecoration whiteCard() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Color urgenceColor(String urgence) {
    switch (urgence) {
      case "URGENT":
        return Colors.red;
      case "MODERE":
      case "MODÉRÉ":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Widget badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text("$label : ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget searchField({
    required String hint,
    required Function(String) onChanged,
  }) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search),
      ),
    );
  }

  String sectionTitle() {
    switch (selectedIndex) {
      case 1:
        return "Mes rendez-vous";
      case 2:
        return "Mes patients";
      case 3:
        return "Secrétaire";
      case 4:
        return "Mon profil";
      default:
        return "Tableau de bord médecin";
    }
  }

  Widget appDrawer() {
  final user = AuthService.currentUser ?? {};

  return Drawer(
    child: SafeArea(
      child: Column(
        children: [
          // 👤 HEADER
          ListTile(
            leading: const CircleAvatar(
              radius: 26,
              child: Icon(Icons.medical_services),
            ),
            title: Text(
              "Dr. ${user["prenom"] ?? ""} ${user["nom"] ?? ""}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              user["specialite"] ?? "Médecin",
              style: const TextStyle(color: Colors.black54),
            ),
          ),

          const Divider(),

          // 📊 NAVIGATION
          drawerItem(0, Icons.dashboard, "Tableau de bord"),
          drawerItem(1, Icons.calendar_month, "Rendez-vous"),
          drawerItem(2, Icons.people, "Patients"),
          drawerItem(3, Icons.support_agent, "Secrétaire"),
          drawerItem(4, Icons.person, "Mon profil"),

          const Spacer(),

          // 🏠 ACCUEIL
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text("Page d'accueil"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PublicNavigationScreen(),
                ),
              );
            },
          ),

          // 🔴 DECONNEXION
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Déconnexion",
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              await AuthService.logout();

              if (!mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const PublicNavigationScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
    ),
  );
}
  Widget drawerItem(int index, IconData icon, String title) {
  final active = selectedIndex == index;

  return ListTile(
    leading: Icon(icon, color: active ? Colors.blue : Colors.blueGrey),
    title: Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: active ? Colors.blue : Colors.black87,
      ),
    ),
    onTap: () {
      Navigator.pop(context);
      setState(() => selectedIndex = index);
    },
  );
}

  Widget headerCard() {
    final user = AuthService.currentUser ?? {};

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            child: Icon(Icons.medical_services, color: Colors.blue, size: 38),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sectionTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Dr. ${user["prenom"] ?? ""} ${user["nom"] ?? ""}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget statCard(IconData icon, String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(title, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget dashboardPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            statCard(Icons.calendar_today, "RDV", "${rendezvous.length}", Colors.blue),
            statCard(Icons.people, "Patients", "${patients.length}", Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statCard(
              Icons.warning,
              "Urgents",
              "${patients.where((p) => p["urgence"] == "URGENT").length}",
              Colors.red,
            ),
            statCard(Icons.support_agent, "Secrétaires", "${secretaires.length}", Colors.orange),
          ],
        ),
        const SizedBox(height: 22),
        const Text("Rendez-vous récents", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (rendezvous.isEmpty)
          emptyState(
            Icons.event_busy,
            "Aucun rendez-vous trouvé",
            "Les rendez-vous confirmés apparaîtront ici.",
          )
        else
          ...rendezvous.take(3).map(rdvCard),
        const SizedBox(height: 18),
        const Text("Patients à suivre", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...patients.take(2).map(patientCard),
      ],
    );
  }

  Widget rendezVousPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        searchField(
          hint: "Rechercher par patient ou date...",
          onChanged: (v) => setState(() => rdvSearch = v),
        ),
        const SizedBox(height: 16),
        if (filteredRendezVous.isEmpty)
          emptyState(
            Icons.event_busy,
            "Aucun rendez-vous trouvé",
            "Les rendez-vous confirmés apparaîtront ici.",
          )
        else
          ...filteredRendezVous.map(rdvCard),
      ],
    );
  }

  Widget rdvCard(Map<String, dynamic> r) {
    final patient =
        "${r["patient_prenom"] ?? ""} ${r["patient_nom"] ?? ""}".trim();

    final date = r["date_rendezvous"] ?? r["date_souhaitee"] ?? r["date"] ?? "-";
    final heure = r["heure_rendezvous"] ?? r["heure_souhaitee"] ?? r["heure"] ?? "-";

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: whiteCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.event_available, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  patient.isEmpty ? "Patient" : patient,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              badge("PLANIFIÉ", Colors.green),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.date_range, "Date", "$date"),
          infoRow(Icons.access_time, "Heure", "$heure"),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => showConsultationDialog(patient),
              icon: const Icon(Icons.visibility),
              label: const Text("Voir dossier patient"),
            ),
          ),
        ],
      ),
    );
  }

  Widget patientsPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        searchField(
          hint: "Rechercher patient...",
          onChanged: (v) => setState(() => patientSearch = v),
        ),
        const SizedBox(height: 16),
        if (filteredPatients.isEmpty)
          emptyState(
            Icons.people,
            "Aucun patient trouvé",
            "Les patients suivis apparaîtront ici.",
          )
        else
          ...filteredPatients.map(patientCard),
      ],
    );
  }

  Widget patientCard(Map<String, dynamic> p) {
    final fullName = "${p["prenom"]} ${p["nom"]}";
    final urgence = "${p["urgence"]}";
    final color = urgenceColor(urgence);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: whiteCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(Icons.person, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              badge(urgence, color),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.cake, "Âge", "${p["age"]}"),
          infoRow(Icons.wc, "Genre", "${p["genre"]}"),
          infoRow(Icons.phone, "Téléphone", "${p["telephone"]}"),
          infoRow(Icons.email, "Email", "${p["email"]}"),
          infoRow(Icons.event, "Dernier RDV", "${p["dernierRdv"]}"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showDossierMedicalDialog(p),
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text("Dossier"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showDossierMedicalDialog(p),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text("Ordonnance"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showConsultationDialog(String patientName) {
    final patient = patients.firstWhere(
      (p) => "${p["prenom"]} ${p["nom"]}" == patientName,
      orElse: () => {
        "prenom": "",
        "nom": patientName,
        "age": "-",
        "genre": "-",
        "telephone": "-",
        "email": "-",
        "symptomes": "Non disponibles",
        "specialite": "-",
        "urgence": "-",
        "notes": [],
        "ordonnances": [],
      },
    );

    showDossierMedicalDialog(patient);
  }

  void showDossierMedicalDialog(Map<String, dynamic> patient) {
    patient["notes"] ??= [];
    patient["ordonnances"] ??= [];

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.85,
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1565C0),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.medical_services, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Dossier médical - ${patient["prenom"]} ${patient["nom"]}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      )
                    ],
                  ),
                ),
                const TabBar(
                  labelColor: Colors.blue,
                  tabs: [
                    Tab(icon: Icon(Icons.health_and_safety), text: "Résumé"),
                    Tab(icon: Icon(Icons.note_alt), text: "Notes"),
                    Tab(icon: Icon(Icons.receipt_long), text: "Ordonnance"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      resumeMedicalTab(patient),
                      notesMedicalesTab(patient),
                      ordonnanceTab(patient),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget resumeMedicalTab(Map<String, dynamic> patient) {
    final urgence = "${patient["urgence"]}";
    final color = urgenceColor(urgence);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        infoRow(Icons.person, "Patient", "${patient["prenom"]} ${patient["nom"]}"),
        infoRow(Icons.cake, "Âge", "${patient["age"]}"),
        infoRow(Icons.wc, "Genre", "${patient["genre"]}"),
        infoRow(Icons.phone, "Téléphone", "${patient["telephone"]}"),
        infoRow(Icons.health_and_safety, "Symptômes", "${patient["symptomes"]}"),
        infoRow(Icons.category, "Orientation", "${patient["specialite"]}"),
        infoRow(Icons.warning, "Urgence", urgence),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            "Ces données médicales sont confidentielles et visibles uniquement par le médecin.",
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget notesMedicalesTab(Map<String, dynamic> patient) {
    return StatefulBuilder(
      builder: (context, setDialogState) {
        final List notes = patient["notes"] ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => showAddNoteDialog(patient, setDialogState),
                icon: const Icon(Icons.add),
                label: const Text("Ajouter une note médicale"),
              ),
            ),
            const SizedBox(height: 16),
            if (notes.isEmpty)
              emptyState(
                Icons.note_alt,
                "Aucune note médicale",
                "Les observations du médecin apparaîtront ici.",
              )
            else
              ...notes.map(
                (n) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: whiteCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.note_alt, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${n["type"]}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            "${n["date"]}",
                            style: const TextStyle(color: Colors.black54, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text("${n["contenu"]}"),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void showAddNoteDialog(
    Map<String, dynamic> patient,
    void Function(void Function()) refreshDialog,
  ) {
    final contenu = TextEditingController();
    String type = "Observation clinique";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: const Text("Nouvelle note médicale"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: "Type de note"),
                    items: const [
                      DropdownMenuItem(value: "Observation clinique", child: Text("Observation clinique")),
                      DropdownMenuItem(value: "Compte rendu", child: Text("Compte rendu")),
                      DropdownMenuItem(value: "Suivi", child: Text("Suivi")),
                      DropdownMenuItem(value: "Recommandation", child: Text("Recommandation")),
                      DropdownMenuItem(value: "Remarque libre", child: Text("Remarque libre")),
                    ],
                    onChanged: (v) => setLocalState(() => type = v!),
                  ),
                  TextField(
                    controller: contenu,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: "Contenu",
                      hintText: "Rédiger la note médicale...",
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () {
                  if (contenu.text.trim().isEmpty) return;

                  setState(() {
                    patient["notes"].insert(0, {
                      "date": DateTime.now().toString().substring(0, 16),
                      "type": type,
                      "contenu": contenu.text.trim(),
                    });
                  });

                  refreshDialog(() {});
                  Navigator.pop(context);
                },
                child: const Text("Ajouter"),
              ),
            ],
          );
        },
      ),
    );
  }
List<String> generateOrdonnanceBySymptoms(String symptomes) {
  final s = symptomes.toLowerCase();

  final List<String> suggestions = [];

  if (s.contains("fièvre") || s.contains("fievre") || s.contains("température")) {
    suggestions.addAll([
      "Paracétamol 1000mg",
      "Hydratation",
      "Surveillance de la température",
    ]);
  }

  if (s.contains("toux") || s.contains("rhume") || s.contains("gorge")) {
    suggestions.addAll([
      "Sérum physiologique",
      "Miel ou boisson chaude",
      "Repos",
    ]);
  }

  if (s.contains("douleur") || s.contains("mal")) {
    suggestions.addAll([
      "Paracétamol 1000mg",
      "Repos",
    ]);
  }

  if (s.contains("thoracique") || s.contains("poitrine") || s.contains("essoufflement")) {
    suggestions.addAll([
      "Évaluation médicale urgente",
      "ECG recommandé",
      "Surveillance clinique",
    ]);
  }

  if (s.contains("diarrhée") || s.contains("diarrhee") || s.contains("vomissement")) {
    suggestions.addAll([
      "Smecta",
      "Sérum de réhydratation orale",
      "Hydratation",
      "Régime léger",
    ]);
  }

  if (s.contains("allergie") || s.contains("éruption") || s.contains("eruption")) {
    suggestions.addAll([
      "Cetirizine",
      "Éviter l’allergène suspecté",
      "Surveillance cutanée",
    ]);
  }

  if (suggestions.isEmpty) {
    suggestions.addAll([
      "Repos",
      "Hydratation",
      "Contrôle médical si aggravation",
    ]);
  }

  return suggestions.toSet().toList();
}
  Widget ordonnanceTab(Map<String, dynamic> patient) {
  final searchController = TextEditingController();
  final dosageController = TextEditingController();
  final dureeController = TextEditingController();
  final conseilController = TextEditingController();

  List<String> aiSuggestions = generateOrdonnanceBySymptoms(
  "${patient["symptomes"] ?? ""}",
);

  List<String> selectedItems = List.from(aiSuggestions);
  List<String> filtered = [];

  return StatefulBuilder(
    builder: (context, setDialogState) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              "Ordonnance générée automatiquement selon les symptômes déclarés. Le médecin doit vérifier, modifier et valider avant impression.",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            "Proposition initiale",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          ...selectedItems.map(
            (item) => CheckboxListTile(
              value: true,
              title: Text(item),
              onChanged: (_) {
                setDialogState(() {
                  selectedItems.remove(item);
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: "Ajouter un médicament",
              hintText: "Écrire le nom du médicament...",
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setDialogState(() {
                if (value.trim().isEmpty) {
                  filtered = [];
                } else {
                  filtered = medicaments
                      .where(
                        (m) => m.toLowerCase().contains(value.toLowerCase()),
                      )
                      .toList();

                  if (filtered.isEmpty) {
                    filtered = [value.trim()];
                  }
                }
              });
            },
          ),

          const SizedBox(height: 10),

          ...filtered.map(
            (m) => ListTile(
              leading: const Icon(Icons.add_circle, color: Colors.green),
              title: Text(m),
              onTap: () {
                setDialogState(() {
                  if (!selectedItems.contains(m)) {
                    selectedItems.add(m);
                  }
                  searchController.clear();
                  filtered = [];
                });
              },
            ),
          ),

          const Divider(),

          TextField(
            controller: dosageController,
            decoration: const InputDecoration(
              labelText: "Dosage / Posologie",
              hintText: "Ex: 1 comprimé matin et soir",
            ),
          ),

          TextField(
            controller: dureeController,
            decoration: const InputDecoration(
              labelText: "Durée",
              hintText: "Ex: 5 jours",
            ),
          ),

          TextField(
            controller: conseilController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Conseils complémentaires",
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
             onPressed: () async {
  if (selectedItems.isEmpty) return;

  final ordonnance = {
    "date": DateTime.now().toString().substring(0, 16),
    "elements": List<String>.from(selectedItems),
    "dosage": dosageController.text.trim(),
    "duree": dureeController.text.trim(),
    "conseils": conseilController.text.trim(),
    "statut": "VALIDÉE",
  };

  setState(() {
    patient["ordonnances"].insert(0, ordonnance);
  });

  await OrdonnancePdfService.printOrdonnance(
    patientName: "${patient["prenom"]} ${patient["nom"]}",
    medecinName:
        "Dr. ${AuthService.currentUser?["prenom"] ?? ""} ${AuthService.currentUser?["nom"] ?? ""}",
    elements: selectedItems,
    dosage: dosageController.text.trim(),
    duree: dureeController.text.trim(),
    conseils: conseilController.text.trim(),
  );

  setDialogState(() {
    selectedItems.clear();
    dosageController.clear();
    dureeController.clear();
    conseilController.clear();
  });

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        "Ordonnance validée. Elle sera disponible dans l’espace patient.",
      ),
    ),
  );
},
            icon: const Icon(Icons.print),
            label: const Text("Valider et imprimer"),
          ),

          const SizedBox(height: 20),

          const Text(
            "Ordonnances validées",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          if ((patient["ordonnances"] as List).isEmpty)
            const Text(
              "Aucune ordonnance validée",
              style: TextStyle(color: Colors.black54),
            )
          else
            ...(patient["ordonnances"] as List).map(
              (o) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: whiteCard(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ordonnance du ${o["date"]}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...(o["elements"] as List).map((e) => Text("- $e")),
                    if ("${o["dosage"]}".isNotEmpty)
                      Text("Posologie : ${o["dosage"]}"),
                    if ("${o["duree"]}".isNotEmpty)
                      Text("Durée : ${o["duree"]}"),
                    if ("${o["conseils"]}".isNotEmpty)
                      Text("Conseils : ${o["conseils"]}"),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
  Widget secretairePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: showAddSecretaireDialog,
            icon: const Icon(Icons.person_add),
            label: const Text("Ajouter secrétaire"),
          ),
        ),
        const SizedBox(height: 16),
        ...secretaires.map(secretaireCard),
      ],
    );
  }

  Widget secretaireCard(Map<String, dynamic> s) {
    final fullName = "${s["prenom"]} ${s["nom"]}";
    final active = s["actif"] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: whiteCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: active ? Colors.green.shade50 : Colors.red.shade50,
                child: Icon(Icons.support_agent, color: active ? Colors.green : Colors.red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              badge(active ? "ACTIVE" : "INACTIVE", active ? Colors.green : Colors.red),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.email, "Email", "${s["email"]}"),
          infoRow(Icons.phone, "Téléphone", "${s["telephone"]}"),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showEditSecretaireDialog(s),
                  icon: const Icon(Icons.edit),
                  label: const Text("Modifier"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => s["actif"] = !active),
                  icon: Icon(active ? Icons.block : Icons.check),
                  label: Text(active ? "Désactiver" : "Activer"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showAddSecretaireDialog() {
    final nom = TextEditingController();
    final prenom = TextEditingController();
    final email = TextEditingController();
    final telephone = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter secrétaire"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nom, decoration: const InputDecoration(labelText: "Nom")),
              TextField(controller: prenom, decoration: const InputDecoration(labelText: "Prénom")),
              TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: telephone, decoration: const InputDecoration(labelText: "Téléphone")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                secretaires.insert(0, {
                  "nom": nom.text,
                  "prenom": prenom.text,
                  "email": email.text,
                  "telephone": telephone.text,
                  "actif": true,
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Ajouter"),
          ),
        ],
      ),
    );
  }

  void showEditSecretaireDialog(Map<String, dynamic> s) {
    final nom = TextEditingController(text: "${s["nom"]}");
    final prenom = TextEditingController(text: "${s["prenom"]}");
    final email = TextEditingController(text: "${s["email"]}");
    final telephone = TextEditingController(text: "${s["telephone"]}");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifier secrétaire"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nom, decoration: const InputDecoration(labelText: "Nom")),
              TextField(controller: prenom, decoration: const InputDecoration(labelText: "Prénom")),
              TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: telephone, decoration: const InputDecoration(labelText: "Téléphone")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                s["nom"] = nom.text;
                s["prenom"] = prenom.text;
                s["email"] = email.text;
                s["telephone"] = telephone.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Widget profilPage() {
    final user = AuthService.currentUser ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: whiteCard(),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 42,
                child: Icon(Icons.medical_services, size: 42),
              ),
              const SizedBox(height: 14),
              Text(
                "Dr. ${user["prenom"] ?? ""} ${user["nom"] ?? ""}",
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const Text("MEDECIN", style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        infoTile(Icons.email, "Email", "${user["email"] ?? "-"}"),
        infoTile(Icons.phone, "Téléphone", "${user["telephone"] ?? "-"}"),
        infoTile(Icons.verified_user, "Rôle", "${user["role"] ?? "MEDECIN"}"),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: showEditProfileDialog,
            icon: const Icon(Icons.edit),
            label: const Text("Modifier mes informations"),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: OutlinedButton.icon(
            onPressed: showChangePasswordDialog,
            icon: const Icon(Icons.lock_reset),
            label: const Text("Changer mot de passe"),
          ),
        ),
      ],
    );
  }

  Widget infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: whiteCard(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue.shade50,
            child: Icon(icon, color: Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54)),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showEditProfileDialog() {
    final nom = TextEditingController(text: "${AuthService.currentUser?["nom"] ?? ""}");
    final prenom = TextEditingController(text: "${AuthService.currentUser?["prenom"] ?? ""}");
    final email = TextEditingController(text: "${AuthService.currentUser?["email"] ?? ""}");
    final tel = TextEditingController(text: "${AuthService.currentUser?["telephone"] ?? ""}");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifier profil"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nom, decoration: const InputDecoration(labelText: "Nom")),
              TextField(controller: prenom, decoration: const InputDecoration(labelText: "Prénom")),
              TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
              TextField(controller: tel, decoration: const InputDecoration(labelText: "Téléphone")),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                AuthService.currentUser?["nom"] = nom.text;
                AuthService.currentUser?["prenom"] = prenom.text;
                AuthService.currentUser?["email"] = email.text;
                AuthService.currentUser?["telephone"] = tel.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void showChangePasswordDialog() {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Changer mot de passe"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPass, obscureText: true, decoration: const InputDecoration(labelText: "Ancien mot de passe")),
            TextField(controller: newPass, obscureText: true, decoration: const InputDecoration(labelText: "Nouveau mot de passe")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Mot de passe modifié localement pour la démonstration.")),
              );
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  Widget bodyContent() {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    switch (selectedIndex) {
      case 1:
        return rendezVousPage();
      case 2:
        return patientsPage();
      case 3:
        return secretairePage();
      case 4:
        return profilPage();
      default:
        return dashboardPage();
    }
  }

  Widget emptyState(IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: whiteCard(),
      child: Column(
        children: [
          Icon(icon, size: 50, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: appDrawer(),
      appBar: AppBar(
        title: const Text("Espace Médecin"),
        actions: [
          IconButton(onPressed: fetchRendezVous, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          headerCard(),
          Expanded(child: bodyContent()),
        ],
      ),
    );
  }
}