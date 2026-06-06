import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../services/password_service.dart';
import '../data/medicaments_data.dart';
import '../widgets/location_map_view.dart';
import '../widgets/ordonnance_tab.dart';
import '../widgets/doctor_avatar.dart';
import 'modifier_profil_medecin_screen.dart';
import 'public_navigation_screen.dart';
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
  String patientUrgenceFilter = "TOUS";

  List<Map<String, dynamic>> rendezvous = [];
  List<Map<String, dynamic>> demandes = [];
  List<Map<String, dynamic>> patients = [];
  List<Map<String, dynamic>> secretaires = [];
  Map<String, dynamic> stats = {};
  Map<String, dynamic>? medecinProfile;

  final List<String> medicaments = medicamentsData;

  final List<String> conseilsGeneraux = [
    "Repos",
    "Hydratation",
    "Surveillance de la température",
    "Contrôle médical si aggravation",
  ];

  @override
  void initState() {
    super.initState();
    loadAllData();
  }

  List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (raw is Map && raw['data'] is List) {
      return (raw['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<void> loadAllData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchDashboard(),
      fetchRendezVous(),
      fetchDemandes(),
      fetchPatients(),
      fetchSecretaires(),
      fetchProfile(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchDashboard() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/medecin/dashboard"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        setState(() {
          stats = Map<String, dynamic>.from(data['data']['stats'] ?? {});
          if (data['data']['rendezvous_recents'] != null) {
            final recents = _parseList(data['data']['rendezvous_recents']);
            if (recents.isNotEmpty && rendezvous.isEmpty) {
              rendezvous = recents;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> fetchRendezVous() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/rendezvous"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        rendezvous = _parseList(data['data']);
      });
    } catch (_) {
      if (mounted) setState(() => rendezvous = []);
    }
  }

  Future<void> fetchDemandes() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/medecin/demandes"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        demandes = _parseList(data['data']);
      });
    } catch (_) {
      if (mounted) setState(() => demandes = []);
    }
  }

  Future<void> fetchPatients() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/medecin/patients"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        patients = _parseList(data['data']).map((p) {
          p['ordonnances'] ??= [];
          p['notes'] ??= p['notes'] ?? [];
          return p;
        }).toList();
      });
    } catch (_) {
      if (mounted) setState(() => patients = []);
    }
  }

  Future<void> fetchSecretaires() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/medecin/secretaires"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        secretaires = _parseList(data['data']);
      });
    } catch (_) {
      if (mounted) setState(() => secretaires = []);
    }
  }

  Future<void> fetchProfile() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/medecin/profile"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (data['success'] == true && mounted) {
        final profile = Map<String, dynamic>.from(data['data'] as Map);
        setState(() {
          medecinProfile = profile;
          AuthService.currentUser = {
            ...?AuthService.currentUser,
            ...profile,
          };
        });
      }
    } catch (e) {
      // repli sur /me si l'endpoint dédié échoue
      try {
        final response = await http.get(
          Uri.parse("${AuthService.baseUrl}/me"),
          headers: _headers(),
        );
        final data = jsonDecode(response.body);
        if (data['success'] == true && mounted) {
          final profile = Map<String, dynamic>.from(data['data'] as Map);
          setState(() {
            medecinProfile = profile;
            AuthService.currentUser = profile;
          });
        }
      } catch (_) {}
    }
  }

  Map<String, String> _headers() => {
        "Accept": "application/json",
        "Authorization": "Bearer ${AuthService.token}",
      };

  Map<String, dynamic> get _medecinUser =>
      medecinProfile ?? AuthService.currentUser ?? {};

  Widget _medecinAvatar({
    double radius = 32,
    Color? backgroundColor,
  }) {
    final user = _medecinUser;
    final idMedecin =
        int.tryParse(user['id_medecin']?.toString() ?? '') ?? 0;

    return DoctorAvatar(
      doctor: user,
      photoUrl: user['photo_url']?.toString(),
      radius: radius,
      fallbackIndex: idMedecin,
      backgroundColor: backgroundColor,
    );
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
      final urgence = "${p["urgence"]}";
      if (patientUrgenceFilter == "URGENT") {
        if (urgence != "URGENT" && urgence != "CRITIQUE") {
          return false;
        }
      }

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
  final user = _medecinUser;

  return Drawer(
    child: SafeArea(
      child: Column(
        children: [
          // 👤 HEADER
          ListTile(
            leading: _medecinAvatar(radius: 26),
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
  void navigateToTab(
    int index, {
    String? patientUrgence,
    String? rdvSearchQuery,
  }) {
    setState(() {
      selectedIndex = index;
      if (index == 1) {
        if (rdvSearchQuery != null) {
          rdvSearch = rdvSearchQuery;
        } else {
          rdvSearch = '';
        }
      }
      if (index == 2) {
        patientUrgenceFilter = patientUrgence ?? 'TOUS';
        if (patientUrgence != null) {
          patientSearch = '';
        }
      }
    });
    if (index == 4) {
      fetchProfile();
    }
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
        navigateToTab(index);
      },
    );
  }

  Widget headerCard() {
    final user = _medecinUser;

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
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: _medecinAvatar(radius: 34, backgroundColor: Colors.white),
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

  Widget statCard(
    IconData icon,
    String title,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Material(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color),
                      if (onTap != null) ...[
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: color.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
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
          ),
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
            statCard(
              Icons.calendar_today,
              "RDV",
              "${stats['rendezvous'] ?? rendezvous.length}",
              Colors.blue,
              onTap: () => navigateToTab(1),
            ),
            statCard(
              Icons.people,
              "Patients",
              "${stats['patients'] ?? patients.length}",
              Colors.green,
              onTap: () => navigateToTab(2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statCard(
              Icons.warning,
              "Urgents",
              "${stats['urgents'] ?? patients.where((p) => p['urgence'] == 'URGENT' || p['urgence'] == 'CRITIQUE').length}",
              Colors.red,
              onTap: () => navigateToTab(2, patientUrgence: 'URGENT'),
            ),
            statCard(
              Icons.hourglass_top,
              "En attente",
              "${stats['demandes_en_attente'] ?? demandes.where((d) => d['statut'] == 'EN_ATTENTE').length}",
              Colors.orange,
              onTap: () => navigateToTab(1),
            ),
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

  List<Map<String, dynamic>> get demandesEnAttente {
    return demandes.where((d) => d['statut'] == 'EN_ATTENTE').toList();
  }

  Widget rendezVousPage() {
    final attente = demandesEnAttente;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        searchField(
          hint: "Rechercher par patient ou date...",
          onChanged: (v) => setState(() => rdvSearch = v),
        ),
        if (attente.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            "Demandes en attente",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...attente.map(demandeCard),
        ],
        const SizedBox(height: 16),
        const Text(
          "Rendez-vous confirmés",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (filteredRendezVous.isEmpty)
          emptyState(
            Icons.event_busy,
            "Aucun rendez-vous confirmé",
            "Les rendez-vous confirmés par la secrétaire apparaîtront ici.",
          )
        else
          ...filteredRendezVous.map(rdvCard),
      ],
    );
  }

  Widget demandeCard(Map<String, dynamic> d) {
    final patient =
        "${d['patient_prenom'] ?? ''} ${d['patient_nom'] ?? ''}".trim();
    final urgence = d['niveau_urgence']?.toString() ?? 'FAIBLE';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: whiteCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.schedule, color: Colors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  patient.isEmpty ? 'Patient' : patient,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
              badge('EN ATTENTE', Colors.orange),
              const SizedBox(width: 6),
              badge(urgence, urgenceColor(urgence)),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.date_range, 'Date souhaitée', '${d['date_souhaitee'] ?? '-'}'),
          infoRow(Icons.access_time, 'Heure', '${d['heure_souhaitee'] ?? '-'}'),
        ],
      ),
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
        if (patientUrgenceFilter == 'URGENT')
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Chip(
                  label: const Text('Patients urgents uniquement'),
                  deleteIcon: const Icon(Icons.close, size: 18),
                  onDeleted: () => setState(() => patientUrgenceFilter = 'TOUS'),
                ),
              ],
            ),
          ),
        searchField(
          hint: "Rechercher patient...",
          onChanged: (v) => setState(() => patientSearch = v),
        ),
        const SizedBox(height: 16),
        if (filteredPatients.isEmpty)
          emptyState(
            Icons.people,
            "Aucun patient trouvé",
            "Un patient apparaît ici uniquement après confirmation de son rendez-vous.",
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
          infoRow(Icons.event, "Dernier RDV", "${p["dernier_rdv"] ?? p["dernierRdv"] ?? "-"}"),
          if ("${p["symptomes"] ?? ""}".isNotEmpty)
            infoRow(Icons.healing, "Symptômes", "${p["symptomes"]}"),
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
    Map<String, dynamic> patient;

    try {
      patient = Map<String, dynamic>.from(
        patients.firstWhere(
          (p) =>
              "${p['prenom'] ?? ''} ${p['nom'] ?? ''}".trim() ==
              patientName.trim(),
        ),
      );
    } catch (_) {
      patient = {
        "prenom": "",
        "nom": patientName,
        "age": "-",
        "genre": "-",
        "telephone": "-",
        "email": "-",
        "symptomes": "Non disponibles",
        "specialite": "-",
        "urgence": "-",
        "notes": <Map<String, dynamic>>[],
        "ordonnances": <Map<String, dynamic>>[],
      };
    }

    patient["ordonnances"] ??= <Map<String, dynamic>>[];
    patient["notes"] ??= <Map<String, dynamic>>[];

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
                      OrdonnanceTab(
                        patient: patient,
                        onOrdonnanceSaved: () => setState(() {}),
                      ),
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

  double? _coord(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  Widget _cabinetMapSection(Map<String, dynamic> user) {
    final lat = _coord(user['latitude']);
    final lng = _coord(user['longitude']);
    if (lat == null || lng == null) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          "Carte non disponible : modifiez votre profil pour placer le cabinet sur la carte.",
          style: TextStyle(fontSize: 12),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Localisation du cabinet',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        LocationMapView(
          latitude: lat,
          longitude: lng,
          height: 220,
          markerLabel: user['adresse_cabinet']?.toString(),
        ),
      ],
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
            label: const Text('Ajouter une secrétaire'),
          ),
        ),
        const SizedBox(height: 16),
        if (secretaires.isEmpty)
          emptyState(
            Icons.support_agent,
            "Aucune secrétaire",
            "Les comptes secrétaire enregistrés dans le système apparaîtront ici.",
          )
        else
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
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajouter une secrétaire'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Un mot de passe sera généré et envoyé par email.',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nom,
                  decoration: const InputDecoration(
                    labelText: 'Nom *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: prenom,
                  decoration: const InputDecoration(
                    labelText: 'Prénom *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: telephone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (nom.text.trim().isEmpty ||
                          prenom.text.trim().isEmpty ||
                          email.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nom, prénom et email sont obligatoires'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);

                      try {
                        final response = await http.post(
                          Uri.parse('${AuthService.baseUrl}/medecin/secretaires'),
                          headers: {
                            ..._headers(),
                            'Content-Type': 'application/json',
                          },
                          body: jsonEncode({
                            'nom': nom.text.trim(),
                            'prenom': prenom.text.trim(),
                            'email': email.text.trim(),
                            'telephone': telephone.text.trim(),
                          }),
                        );

                        final data = jsonDecode(response.body);

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        if (data['success'] == true) {
                          await fetchSecretaires();
                          if (mounted) setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                data['message']?.toString() ??
                                    'Secrétaire créée',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                data['message']?.toString() ?? 'Erreur',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur : $e')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirmer'),
            ),
          ],
        ),
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
    final user = _medecinUser;
    final adresse = user['adresse_cabinet']?.toString().trim() ?? '';
    final ville = user['ville']?.toString().trim() ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: whiteCard(),
          child: Column(
            children: [
              _medecinAvatar(radius: 42),
              const SizedBox(height: 14),
              Text(
                "Dr. ${user["prenom"] ?? ""} ${user["nom"] ?? ""}",
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              Text(
                user["specialite"]?.toString() ?? "Médecin",
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        infoTile(Icons.email, "Email", "${user["email"] ?? "-"}"),
        infoTile(Icons.phone, "Téléphone", "${user["telephone"] ?? "-"}"),
        infoTile(Icons.medical_services, "Spécialité", "${user["specialite"] ?? "-"}"),
        infoTile(Icons.location_city, "Ville", ville.isEmpty ? "-" : ville),
        infoTile(Icons.location_on, "Adresse du cabinet", adresse.isEmpty ? "-" : adresse),
        infoTile(Icons.verified_user, "Rôle", "${user["role"] ?? "MEDECIN"}"),
        _cabinetMapSection(user),
        const SizedBox(height: 18),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ModifierProfilMedecinScreen(
                    user: Map<String, dynamic>.from(user),
                  ),
                ),
              );
              if (updated == true) {
                await fetchProfile();
                if (mounted) setState(() {});
              }
            },
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

  void showChangePasswordDialog() {
    final oldPass = TextEditingController();
    final newPass = TextEditingController();
    final confirmPass = TextEditingController();
    var obscureOld = true;
    var obscureNew = true;
    var obscureConfirm = true;
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Changer mot de passe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPass,
                  obscureText: obscureOld,
                  decoration: InputDecoration(
                    labelText: 'Ancien mot de passe *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureOld = !obscureOld),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPass,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nouveau mot de passe * (min. 6)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPass,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le nouveau mot de passe *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (oldPass.text.isEmpty ||
                          newPass.text.isEmpty ||
                          confirmPass.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tous les champs sont obligatoires'),
                          ),
                        );
                        return;
                      }
                      if (newPass.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le nouveau mot de passe doit contenir au moins 6 caractères'),
                          ),
                        );
                        return;
                      }
                      if (newPass.text != confirmPass.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Les mots de passe ne correspondent pas'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);

                      try {
                        final result = await PasswordService.changePassword(
                          ancienMotDePasse: oldPass.text,
                          nouveauMotDePasse: newPass.text,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              result['success'] == true
                                  ? result['message'] as String
                                  : PasswordService.formatErrors(
                                      result['errors'],
                                      result['message'] as String,
                                    ),
                            ),
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur : $e')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Valider'),
            ),
          ],
        ),
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
        title: Row(
          children: [
            _medecinAvatar(radius: 18, backgroundColor: Colors.white),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Espace Médecin",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: loadAllData, icon: const Icon(Icons.refresh)),
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