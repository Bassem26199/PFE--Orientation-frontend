import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import 'public_navigation_screen.dart';

class SecretaireHome extends StatefulWidget {
  const SecretaireHome({super.key});

  @override
  State<SecretaireHome> createState() => _SecretaireHomeState();
}

class _SecretaireHomeState extends State<SecretaireHome> {
  int selectedIndex = 0;
  bool isLoading = true;

  final String cabinetName = "Cabinet du Dr. Trabelsi Sami";

  List<Map<String, dynamic>> demandes = [];

  String rdvSearch = "";
  String rdvStatutFilter = "TOUS";

  String patientSearch = "";

  String caisseSearch = "";
  String caisseStatutFilter = "TOUS";

  final List<Map<String, dynamic>> patients = [
    {
      "nom": "Ben Salah",
      "prenom": "Ali",
      "email": "ali.patient@gmail.com",
      "telephone": "20111222",
      "genre": "M",
      "age": "32",
      "dernierRdv": "2026-04-27",
      "prochainRdv": "2026-05-04 à 10:00",
    },
    {
      "nom": "Test",
      "prenom": "User",
      "email": "test@test.com",
      "telephone": "20111222",
      "genre": "M",
      "age": "28",
      "dernierRdv": "2026-04-29",
      "prochainRdv": "-",
    },
  ];

  final List<Map<String, dynamic>> caisse = [
    {
      "patient": "Ali Ben Salah",
      "date": "2026-04-27",
      "montant": 50,
      "statut": "PAYÉ",
    },
    {
      "patient": "User Test",
      "date": "2026-04-29",
      "montant": 50,
      "statut": "NON_PAYÉ",
    },
  ];

  final List<Map<String, dynamic>> horaires = [
    {"jour": "Lundi", "debut": "09:00", "fin": "13:00", "actif": true},
    {"jour": "Mardi", "debut": "09:00", "fin": "13:00", "actif": true},
    {"jour": "Mercredi", "debut": "09:00", "fin": "13:00", "actif": true},
    {"jour": "Jeudi", "debut": "09:00", "fin": "13:00", "actif": true},
    {"jour": "Vendredi", "debut": "09:00", "fin": "12:00", "actif": true},
    {"jour": "Samedi", "debut": "-", "fin": "-", "actif": false},
    {"jour": "Dimanche", "debut": "-", "fin": "-", "actif": false},
  ];

  final List<Map<String, dynamic>> exceptions = [];

  @override
  void initState() {
    super.initState();
    fetchDemandes();
  }

  Future<void> fetchDemandes() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/demandes-rendezvous"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      setState(() {
        if (data["data"] is Map && data["data"]["data"] != null) {
          demandes = List<Map<String, dynamic>>.from(
            data["data"]["data"].map((e) => Map<String, dynamic>.from(e)),
          );
        } else if (data["data"] is List) {
          demandes = List<Map<String, dynamic>>.from(
            data["data"].map((e) => Map<String, dynamic>.from(e)),
          );
        } else {
          demandes = [];
        }

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> traiterDemande(int idDemande, String action) async {
    final endpoint = action == "CONFIRMER" ? "confirmer" : "refuser";

    try {
      final response = await http.put(
        Uri.parse("${AuthService.baseUrl}/demandes-rendezvous/$idDemande/$endpoint"),
        headers: {
          "Accept": "application/json",
          "Authorization": "Bearer ${AuthService.token}",
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data["success"] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Action effectuée")),
        );
        fetchDemandes();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data["message"] ?? "Erreur")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur serveur")),
      );
    }
  }

  List<Map<String, dynamic>> get filteredDemandes {
    return demandes.where((d) {
      final patient =
          "${d["patient_prenom"] ?? ""} ${d["patient_nom"] ?? ""}".toLowerCase();

      final date = "${d["date_souhaitee"] ?? ""}".toLowerCase();
      final statut = "${d["statut"] ?? ""}";

      final matchSearch =
          patient.contains(rdvSearch.toLowerCase()) || date.contains(rdvSearch.toLowerCase());

      final matchStatut = rdvStatutFilter == "TOUS" || statut == rdvStatutFilter;

      return matchSearch && matchStatut;
    }).toList();
  }

  List<Map<String, dynamic>> get filteredPatients {
    return patients.where((p) {
      final text =
          "${p["nom"]} ${p["prenom"]} ${p["email"]} ${p["telephone"]}".toLowerCase();

      return text.contains(patientSearch.toLowerCase());
    }).toList();
  }

  List<Map<String, dynamic>> get filteredCaisse {
    return caisse.where((c) {
      final patient = "${c["patient"]}".toLowerCase();
      final statut = "${c["statut"]}";

      final matchSearch = patient.contains(caisseSearch.toLowerCase());
      final matchStatut = caisseStatutFilter == "TOUS" || statut == caisseStatutFilter;

      return matchSearch && matchStatut;
    }).toList();
  }

  int countByStatut(String statut) {
    return demandes.where((d) => d["statut"] == statut).length;
  }

  int totalCaisse() {
    return caisse.fold<int>(0, (sum, e) => sum + ((e["montant"] ?? 0) as int));
  }

  Color statutColor(String statut) {
    switch (statut) {
      case "CONFIRMEE":
      case "CONFIRMÉE":
        return Colors.green;
      case "REFUSEE":
      case "REFUSÉE":
        return Colors.red;
      case "ANNULEE":
      case "ANNULÉE":
        return Colors.grey;
      default:
        return Colors.orange;
    }
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

  Widget badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
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
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  String sectionTitle() {
    switch (selectedIndex) {
      case 1:
        return "Gestion des rendez-vous";
      case 2:
        return "Liste des patients";
      case 3:
        return "Caisse";
      case 4:
        return "Disponibilités";
      case 5:
        return "Mon profil";
      default:
        return "Tableau de bord secrétaire";
    }
  }

Widget appDrawer() {
  return Drawer(
    child: SafeArea(
      child: Column(
        children: [
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.support_agent)),
            title: Text(
              "Secrétaire",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Gestion du cabinet"),
          ),

          drawerItem(0, Icons.dashboard, "Tableau de bord"),
          drawerItem(1, Icons.calendar_month, "Rendez-vous"),
          drawerItem(2, Icons.people, "Patients"),
          drawerItem(3, Icons.payments, "Caisse"),
          drawerItem(4, Icons.schedule, "Disponibilités"),
          drawerItem(5, Icons.person, "Mon profil"),

          const Spacer(),

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

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              "Déconnexion",
              style: TextStyle(color: Colors.red),
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
            child: Icon(Icons.support_agent, color: Colors.blue, size: 38),
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
                  cabinetName,
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

  Widget dashboardPage() {
    final enAttente = countByStatut("EN_ATTENTE");
    final confirmees = countByStatut("CONFIRMEE") + countByStatut("CONFIRMÉE");
    final refusees = countByStatut("REFUSEE") + countByStatut("REFUSÉE");

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            statCard(Icons.pending_actions, "En attente", "$enAttente", Colors.orange),
            statCard(Icons.check_circle, "Confirmés", "$confirmees", Colors.green),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statCard(Icons.cancel, "Refusés", "$refusees", Colors.red),
            statCard(Icons.people, "Patients", "${patients.length}", Colors.blue),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statCard(Icons.today, "RDV aujourd'hui", "2", Colors.purple),
            statCard(Icons.payments, "Caisse", "${totalCaisse()} DT", Colors.teal),
          ],
        ),
        const SizedBox(height: 22),
        const Text("Activité récente", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...demandes.take(2).map((e) => demandeCard(e, compact: true)),
        const SizedBox(height: 14),
        const Text("Derniers patients ajoutés", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: rdvStatutFilter,
          decoration: const InputDecoration(labelText: "Statut"),
          items: const [
            DropdownMenuItem(value: "TOUS", child: Text("Tous")),
            DropdownMenuItem(value: "EN_ATTENTE", child: Text("En attente")),
            DropdownMenuItem(value: "CONFIRMEE", child: Text("Confirmés")),
            DropdownMenuItem(value: "REFUSEE", child: Text("Refusés")),
          ],
          onChanged: (v) => setState(() => rdvStatutFilter = v!),
        ),
        const SizedBox(height: 16),
        if (filteredDemandes.isEmpty)
          emptyState(
            Icons.inbox,
            "Aucune demande trouvée",
            "Les demandes de rendez-vous apparaîtront ici.",
          )
        else
          ...filteredDemandes.map((e) => demandeCard(e)),
      ],
    );
  }

  Widget demandeCard(Map<String, dynamic> demande, {bool compact = false}) {
    final idDemande = demande["id_demande"];
    final statut = demande["statut"] ?? "EN_ATTENTE";
    final color = statutColor(statut);
    final isPending = statut == "EN_ATTENTE";

    final patientPrenom = "${demande["patient_prenom"] ?? ""}";
    final patientNom = "${demande["patient_nom"] ?? ""}";
    final patientName = "$patientPrenom $patientNom".trim();

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
                child: Icon(Icons.calendar_month, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  patientName.isEmpty ? "Patient" : patientName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              badge(statut, color),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.date_range, "Date souhaitée", demande["date_souhaitee"] ?? "-"),
          infoRow(Icons.access_time, "Heure souhaitée", demande["heure_souhaitee"] ?? "-"),
          if (!compact)
            infoRow(Icons.history, "Date demande", demande["date_demande"]?.toString() ?? "-"),
          if (!compact) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => showEditRdvDialog(demande),
                    icon: const Icon(Icons.edit),
                    label: const Text("Modifier"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => addPatientFromRdv(demande),
                    icon: const Icon(Icons.person_add),
                    label: const Text("Patient"),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => confirmAction(
                        idDemande,
                        "REFUSER",
                        "Refuser la demande",
                        Colors.red,
                        Icons.cancel,
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text("Refuser"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => confirmAction(
                        idDemande,
                        "CONFIRMER",
                        "Confirmer la demande",
                        Colors.green,
                        Icons.check_circle,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text("Confirmer"),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  void addPatientFromRdv(Map<String, dynamic> demande) {
    final prenom = "${demande["patient_prenom"] ?? ""}";
    final nom = "${demande["patient_nom"] ?? ""}";

    final exists = patients.any((p) =>
        "${p["prenom"]}".toLowerCase() == prenom.toLowerCase() &&
        "${p["nom"]}".toLowerCase() == nom.toLowerCase());

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Patient déjà présent dans la liste")),
      );
      return;
    }

    setState(() {
      patients.insert(0, {
        "nom": nom.isEmpty ? "Non défini" : nom,
        "prenom": prenom.isEmpty ? "Patient" : prenom,
        "email": "non.defini@email.com",
        "telephone": "-",
        "genre": "-",
        "age": "-",
        "dernierRdv": demande["date_souhaitee"] ?? "-",
        "prochainRdv": "-",
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Patient ajouté à la liste")),
    );
  }

  void confirmAction(
    int idDemande,
    String action,
    String title,
    Color color,
    IconData icon,
  ) {
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
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Annuler"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        traiterDemande(idDemande, action);
                      },
                      child: const Text("Valider"),
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

  void showEditRdvDialog(Map<String, dynamic> rdv) {
    final dateController = TextEditingController(text: rdv["date_souhaitee"] ?? "");
    final heureController = TextEditingController(text: rdv["heure_souhaitee"] ?? "");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifier le rendez-vous"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: dateController, decoration: const InputDecoration(labelText: "Date")),
            TextField(controller: heureController, decoration: const InputDecoration(labelText: "Heure")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                rdv["date_souhaitee"] = dateController.text;
                rdv["heure_souhaitee"] = heureController.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: showAddPatientDialog,
            icon: const Icon(Icons.person_add),
            label: const Text("Ajouter patient"),
          ),
        ),
        const SizedBox(height: 16),
        if (filteredPatients.isEmpty)
          emptyState(Icons.people, "Aucun patient trouvé", "La liste des patients apparaîtra ici.")
        else
          ...filteredPatients.map(patientCard),
      ],
    );
  }

  void showAddPatientDialog() {
    final nom = TextEditingController();
    final prenom = TextEditingController();
    final email = TextEditingController();
    final tel = TextEditingController();
    final age = TextEditingController();
    final dernier = TextEditingController();
    final prochain = TextEditingController();
    String genre = "M";

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Ajouter patient"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: nom, decoration: const InputDecoration(labelText: "Nom")),
                  TextField(controller: prenom, decoration: const InputDecoration(labelText: "Prénom")),
                  TextField(controller: email, decoration: const InputDecoration(labelText: "Email")),
                  TextField(controller: tel, decoration: const InputDecoration(labelText: "Téléphone")),
                  TextField(controller: age, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Âge")),
                  DropdownButtonFormField<String>(
                    value: genre,
                    decoration: const InputDecoration(labelText: "Genre"),
                    items: const [
                      DropdownMenuItem(value: "M", child: Text("Homme")),
                      DropdownMenuItem(value: "F", child: Text("Femme")),
                    ],
                    onChanged: (v) => setDialogState(() => genre = v!),
                  ),
                  TextField(controller: dernier, decoration: const InputDecoration(labelText: "Dernier RDV")),
                  TextField(controller: prochain, decoration: const InputDecoration(labelText: "Prochain RDV")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    patients.insert(0, {
                      "nom": nom.text,
                      "prenom": prenom.text,
                      "email": email.text,
                      "telephone": tel.text,
                      "genre": genre,
                      "age": age.text,
                      "dernierRdv": dernier.text.isEmpty ? "-" : dernier.text,
                      "prochainRdv": prochain.text.isEmpty ? "-" : prochain.text,
                    });
                  });
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

  Widget patientCard(Map<String, dynamic> p) {
    final fullName = "${p["prenom"]} ${p["nom"]}";

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
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              IconButton(
                onPressed: () => showEditPatientDialog(p),
                icon: const Icon(Icons.edit, color: Colors.blue),
              ),
              IconButton(
                onPressed: () => showAddPaymentDialog(fullName),
                icon: const Icon(Icons.payments, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.email, "Email", p["email"]),
          infoRow(Icons.phone, "Téléphone", p["telephone"]),
          infoRow(Icons.wc, "Genre", p["genre"]),
          infoRow(Icons.cake, "Âge", "${p["age"]}"),
          infoRow(Icons.event, "Dernier RDV", p["dernierRdv"]),
          infoRow(Icons.event_available, "Prochain RDV", p["prochainRdv"]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              "Données médicales masquées : symptômes, diagnostic et traitement sont visibles uniquement par le médecin.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  void showEditPatientDialog(Map<String, dynamic> p) {
    final tel = TextEditingController(text: p["telephone"]);
    final prochain = TextEditingController(text: p["prochainRdv"]);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifier patient"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tel, decoration: const InputDecoration(labelText: "Téléphone")),
            TextField(controller: prochain, decoration: const InputDecoration(labelText: "Prochain RDV")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                p["telephone"] = tel.text;
                p["prochainRdv"] = prochain.text;
              });
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  Widget caissePage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        searchField(
          hint: "Rechercher paiement...",
          onChanged: (v) => setState(() => caisseSearch = v),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: caisseStatutFilter,
          decoration: const InputDecoration(labelText: "Statut paiement"),
          items: const [
            DropdownMenuItem(value: "TOUS", child: Text("Tous")),
            DropdownMenuItem(value: "PAYÉ", child: Text("Payé")),
            DropdownMenuItem(value: "NON_PAYÉ", child: Text("Non payé")),
          ],
          onChanged: (v) => setState(() => caisseStatutFilter = v!),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            statCard(Icons.payments, "Total", "${totalCaisse()} DT", Colors.blue),
            statCard(Icons.check_circle, "Payés", "${caisse.where((e) => e["statut"] == "PAYÉ").length}", Colors.green),
          ],
        ),
        const SizedBox(height: 18),
        if (filteredCaisse.isEmpty)
          emptyState(Icons.payments, "Aucun paiement trouvé", "Les paiements apparaîtront ici.")
        else
          ...filteredCaisse.map(caisseCard),
      ],
    );
  }

  void showAddPaymentDialog(String patientName) {
    final montant = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Ajouter paiement - $patientName"),
        content: TextField(
          controller: montant,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Montant (DT)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                caisse.insert(0, {
                  "patient": patientName,
                  "date": DateTime.now().toString().substring(0, 10),
                  "montant": int.tryParse(montant.text) ?? 0,
                  "statut": "PAYÉ",
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

  Widget caisseCard(Map<String, dynamic> c) {
    final paye = c["statut"] == "PAYÉ";
    final color = paye ? Colors.green : Colors.orange;

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
                child: Icon(Icons.receipt_long, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(c["patient"], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
              badge(c["statut"], color),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.date_range, "Date", c["date"]),
          infoRow(Icons.payments, "Montant", "${c["montant"]} DT"),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showEditMontantDialog(c),
                  icon: const Icon(Icons.edit),
                  label: const Text("Modifier"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => showRecuDialog(c),
                  icon: const Icon(Icons.print),
                  label: const Text("Reçu"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showEditMontantDialog(Map<String, dynamic> c) {
    final montant = TextEditingController(text: c["montant"].toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Modifier montant"),
        content: TextField(
          controller: montant,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Montant (DT)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              setState(() {
                c["montant"] = int.tryParse(montant.text) ?? c["montant"];
              });
              Navigator.pop(context);
            },
            child: const Text("Enregistrer"),
          ),
        ],
      ),
    );
  }

  void showRecuDialog(Map<String, dynamic> c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reçu de paiement"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Patient : ${c["patient"]}"),
            Text("Date : ${c["date"]}"),
            Text("Montant : ${c["montant"]} DT"),
            Text("Statut : ${c["statut"]}"),
            const SizedBox(height: 12),
            const Text("Reçu généré pour la démonstration PFE."),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
        ],
      ),
    );
  }

  Widget disponibilitesPage() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...horaires.map(horaireCard),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: showAddExceptionDialog,
            icon: const Icon(Icons.block),
            label: const Text("Ajouter une exception"),
          ),
        ),
        const SizedBox(height: 16),
        const Text("Jours indisponibles", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (exceptions.isEmpty)
          const Text("Aucune exception ajoutée", style: TextStyle(color: Colors.black54))
        else
          ...exceptions.map(exceptionCard),
      ],
    );
  }

  Widget horaireCard(Map<String, dynamic> h) {
    final actif = h["actif"] == true;
    final color = actif ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: whiteCard(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(Icons.schedule, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(h["jour"], style: const TextStyle(fontWeight: FontWeight.bold))),
          Text(
            actif ? "${h["debut"]} - ${h["fin"]}" : "Fermé",
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => showEditHoraireDialog(h),
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
    );
  }

  void showEditHoraireDialog(Map<String, dynamic> h) {
    final debut = TextEditingController(text: h["debut"]);
    final fin = TextEditingController(text: h["fin"]);
    bool actif = h["actif"] == true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Modifier ${h["jour"]}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: actif,
                  title: const Text("Jour disponible"),
                  onChanged: (v) => setDialogState(() => actif = v),
                ),
                TextField(controller: debut, decoration: const InputDecoration(labelText: "Heure début")),
                TextField(controller: fin, decoration: const InputDecoration(labelText: "Heure fin")),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    h["actif"] = actif;
                    h["debut"] = actif ? debut.text : "-";
                    h["fin"] = actif ? fin.text : "-";
                  });
                  Navigator.pop(context);
                },
                child: const Text("Enregistrer"),
              ),
            ],
          );
        },
      ),
    );
  }

  void showAddExceptionDialog() {
    final dateController = TextEditingController();
    final motifController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Ajouter une exception"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              decoration: const InputDecoration(labelText: "Date indisponible", hintText: "2026-05-01"),
            ),
            TextField(
              controller: motifController,
              decoration: const InputDecoration(labelText: "Motif", hintText: "Congé, urgence, fermeture..."),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              if (dateController.text.trim().isEmpty) return;

              setState(() {
                exceptions.add({
                  "date": dateController.text.trim(),
                  "motif": motifController.text.trim().isEmpty
                      ? "Indisponible"
                      : motifController.text.trim(),
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

  Widget exceptionCard(Map<String, dynamic> e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: whiteCard(),
      child: Row(
        children: [
          const Icon(Icons.block, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text("${e["date"]} - ${e["motif"]}")),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => setState(() => exceptions.remove(e)),
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
                child: Icon(Icons.support_agent, size: 42),
              ),
              const SizedBox(height: 14),
              Text(
                "${user["prenom"] ?? "User"} ${user["nom"] ?? "Test"}",
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const Text("SECRETAIRE", style: TextStyle(color: Colors.black54)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        infoTile(Icons.email, "Email", "${user["email"] ?? "test@test.com"}"),
        infoTile(Icons.phone, "Téléphone", "${user["telephone"] ?? "20111222"}"),
        infoTile(Icons.verified_user, "Rôle", "${user["role"] ?? "SECRETAIRE"}"),
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
        return caissePage();
      case 4:
        return disponibilitesPage();
      case 5:
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
        title: const Text("Espace Secrétaire"),
        actions: [
          IconButton(onPressed: fetchDemandes, icon: const Icon(Icons.refresh)),
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