import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/auth_service.dart';
import '../services/password_service.dart';
import '../widgets/creneau_choice_grid.dart';
import 'public_navigation_screen.dart';

class SecretaireHome extends StatefulWidget {
  const SecretaireHome({super.key});

  @override
  State<SecretaireHome> createState() => _SecretaireHomeState();
}

class _SecretaireHomeState extends State<SecretaireHome> {
  int selectedIndex = 0;
  bool isLoading = true;

  String cabinetName = "Cabinet médical";
  String disponibiliteTexte = "";

  List<Map<String, dynamic>> demandes = [];
  List<Map<String, dynamic>> patients = [];
  List<Map<String, dynamic>> caisse = [];
  List<Map<String, dynamic>> horaires = [];
  List<Map<String, dynamic>> exceptions = [];
  Map<String, dynamic> stats = {};
  int dureeCreneauMinutes = 30;
  int? idMedecin;
  bool savingDisponibilites = false;

  String rdvSearch = "";
  String rdvStatutFilter = "TOUS";

  String patientSearch = "";

  String caisseSearch = "";
  String caisseStatutFilter = "TOUS";

  Map<String, String> _headers() => {
        "Accept": "application/json",
        "Authorization": "Bearer ${AuthService.token}",
        "Content-Type": "application/json",
      };

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

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user?['cabinet'] != null) {
      cabinetName = user!['cabinet'].toString();
    }
    loadAllData();
  }

  Future<void> loadAllData() async {
    setState(() => isLoading = true);
    await Future.wait([
      fetchDashboard(),
      fetchDemandes(),
      fetchPatients(),
      fetchCaisse(),
      fetchDisponibilites(),
    ]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchDashboard() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/secretaire/dashboard"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted || data['success'] != true) return;

      final payload = data['data'] as Map<String, dynamic>;
      setState(() {
        stats = Map<String, dynamic>.from(payload['stats'] ?? {});
        cabinetName = payload['cabinet']?['nom']?.toString() ?? cabinetName;
        idMedecin = int.tryParse('${payload['cabinet']?['id_medecin'] ?? ''}');
        disponibiliteTexte =
            payload['cabinet']?['disponibilite']?.toString() ?? '';
        if (payload['demandes_recentes'] != null) {
          final recents = _parseList(payload['demandes_recentes']);
          if (recents.isNotEmpty && demandes.isEmpty) {
            demandes = recents;
          }
        }
        if (payload['patients_recents'] != null && patients.isEmpty) {
          patients = _parseList(payload['patients_recents']).map((p) {
            return {
              'id_patient': p['id_patient'],
              'nom': p['nom'],
              'prenom': p['prenom'],
              'email': p['email'] ?? '',
              'telephone': p['telephone'] ?? '',
              'genre': p['genre'] ?? '-',
              'age': '${p['age'] ?? '-'}',
              'dernierRdv': p['dernier_rdv'] ?? p['dernierRdv'] ?? '-',
              'prochainRdv': p['prochain_rdv'] ?? p['prochainRdv'] ?? '-',
            };
          }).toList();
        }
      });
    } catch (_) {}
  }

  Future<void> fetchDemandes() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/secretaire/demandes"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        demandes = data['success'] == true ? _parseList(data['data']) : [];
      });
    } catch (_) {
      if (mounted) setState(() => demandes = []);
    }
  }

  Future<void> fetchPatients() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/secretaire/patients"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        patients = data['success'] == true ? _parseList(data['data']) : [];
      });
    } catch (_) {
      if (mounted) setState(() => patients = []);
    }
  }

  Future<void> fetchCaisse() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/secretaire/caisse"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        caisse = data['success'] == true ? _parseList(data['data']) : [];
      });
    } catch (_) {
      if (mounted) setState(() => caisse = []);
    }
  }

  Future<void> fetchDisponibilites() async {
    try {
      final response = await http.get(
        Uri.parse("${AuthService.baseUrl}/secretaire/disponibilites"),
        headers: _headers(),
      );
      final data = jsonDecode(response.body);
      if (!mounted || data['success'] != true) return;
      final payload = data['data'] as Map<String, dynamic>;
      setState(() {
        horaires = _parseList(payload['horaires']);
        disponibiliteTexte = payload['texte']?.toString() ?? disponibiliteTexte;
        dureeCreneauMinutes =
            int.tryParse('${payload['duree_creneau_minutes'] ?? 30}') ?? 30;
        exceptions = _parseList(payload['exceptions']);
      });
    } catch (_) {}
  }

  String formatHeureAffichage(dynamic heure) {
    final raw = heure?.toString() ?? '';
    if (raw.isEmpty || raw == '-') return '-';
    return raw.length >= 5 ? raw.substring(0, 5) : raw;
  }

  String libelleStatutConsultation(String? statut) {
    switch (statut) {
      case 'TERMINE':
        return 'Terminée';
      case 'ANNULE':
        return 'Annulée';
      case 'PLANIFIE':
      default:
        return 'Planifiée';
    }
  }

  Color couleurStatutConsultation(String? statut) {
    switch (statut) {
      case 'TERMINE':
        return Colors.green;
      case 'ANNULE':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Future<void> updateStatutConsultation(int idRendezvous, String statut) async {
    try {
      final response = await http.put(
        Uri.parse(
          '${AuthService.baseUrl}/secretaire/rendezvous/$idRendezvous/statut-consultation',
        ),
        headers: _headers(),
        body: jsonEncode({'statut_consultation': statut}),
      );
      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Statut mis à jour')),
        );
        loadAllData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Erreur')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur serveur')),
      );
    }
  }

  void showStatutConsultationDialog({
    required int idRendezvous,
    required String? statutActuel,
  }) {
    var selection = statutActuel ?? 'PLANIFIE';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Statut de la consultation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Indiquez si le patient est passé au cabinet.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ...['PLANIFIE', 'TERMINE', 'ANNULE'].map((s) {
                return RadioListTile<String>(
                  title: Text(libelleStatutConsultation(s)),
                  value: s,
                  groupValue: selection,
                  onChanged: (v) => setDialogState(() => selection = v!),
                );
              }),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                updateStatutConsultation(idRendezvous, selection);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> traiterDemande(
    int idDemande,
    String action, {
    String? dateRendezvous,
    String? heureRendezvous,
  }) async {
    final endpoint = action == "CONFIRMER" ? "confirmer" : "refuser";

    try {
      final Map<String, dynamic> body = {};
      if (action == "CONFIRMER" &&
          dateRendezvous != null &&
          heureRendezvous != null) {
        body['date_rendezvous'] = dateRendezvous;
        body['heure_rendezvous'] = heureRendezvous;
      }

      final response = await http.put(
        Uri.parse("${AuthService.baseUrl}/demandes-rendezvous/$idDemande/$endpoint"),
        headers: _headers(),
        body: body.isEmpty ? null : jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data["success"] == true) {
        final payload = data["data"];
        String message = data["message"]?.toString() ?? "Action effectuée";
        if (payload is Map) {
          if (action == "CONFIRMER" && payload["email_confirmation_envoye"] == false) {
            message =
                "$message\n(Aucun email envoyé : vérifiez l'adresse email du patient et les spams.)";
          }
          if (action == "REFUSER" && payload["email_refus_envoye"] == false) {
            message =
                "$message\n(Aucun email de refus envoyé : vérifiez l'adresse email du patient.)";
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        loadAllData();
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
    final fromStats = stats['caisse_total'];
    if (fromStats != null) return int.tryParse('$fromStats') ?? 0;
    return caisse
        .where((e) => e['statut'] == 'PAYÉ')
        .fold<int>(0, (sum, e) => sum + ((e['montant'] ?? 0) as num).toInt());
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
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
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
  void navigateToTab(
    int index, {
    String? rdvStatut,
    String? rdvSearchQuery,
    String? caisseStatut,
  }) {
    setState(() {
      selectedIndex = index;
      if (index == 1) {
        if (rdvStatut != null) rdvStatutFilter = rdvStatut;
        if (rdvSearchQuery != null) {
          rdvSearch = rdvSearchQuery;
        } else if (rdvStatut != null) {
          rdvSearch = '';
        }
      }
      if (index == 3 && caisseStatut != null) {
        caisseStatutFilter = caisseStatut;
      }
    });
  }

  String _todayIsoDate() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
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

  Widget statCard(
    IconData icon,
    String title,
    String value,
    Color color, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            if (onTap != null) ...[
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.7)),
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
    );

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
              child: content,
            ),
          ),
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
    final enAttente = stats['en_attente'] ?? countByStatut("EN_ATTENTE");
    final confirmees = stats['confirmees'] ??
        (countByStatut("CONFIRMEE") + countByStatut("CONFIRMÉE"));
    final refusees =
        stats['refusees'] ?? (countByStatut("REFUSEE") + countByStatut("REFUSÉE"));
    final patientsCount = stats['patients'] ?? patients.length;
    final rdvAujourdhui = stats['rdv_aujourdhui'] ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            statCard(
              Icons.pending_actions,
              "En attente",
              "$enAttente",
              Colors.orange,
              onTap: () => navigateToTab(1, rdvStatut: 'EN_ATTENTE'),
            ),
            statCard(
              Icons.check_circle,
              "Confirmés",
              "$confirmees",
              Colors.green,
              onTap: () => navigateToTab(1, rdvStatut: 'CONFIRMEE'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statCard(
              Icons.cancel,
              "Refusés",
              "$refusees",
              Colors.red,
              onTap: () => navigateToTab(1, rdvStatut: 'REFUSEE'),
            ),
            statCard(
              Icons.people,
              "Patients",
              "$patientsCount",
              Colors.blue,
              onTap: () => navigateToTab(2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            statCard(
              Icons.today,
              "RDV aujourd'hui",
              "$rdvAujourdhui",
              Colors.purple,
              onTap: () => navigateToTab(
                1,
                rdvStatut: 'CONFIRMEE',
                rdvSearchQuery: _todayIsoDate(),
              ),
            ),
            statCard(
              Icons.payments,
              "Caisse",
              "${totalCaisse()} DT",
              Colors.teal,
              onTap: () => navigateToTab(3),
            ),
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

  List<Map<String, dynamic>> get patientsSansProchainRdv {
    return patients.where((p) {
      final prochain = '${p['prochainRdv'] ?? '-'}';
      return prochain == '-' || p['peut_planifier_suivi'] == true;
    }).toList();
  }

  Widget suiviRdvSection() {
    final liste = patientsSansProchainRdv;
    if (liste.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suivi — prochain RDV à planifier',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Après la consultation, fixez ici le prochain rendez-vous du patient.',
          style: TextStyle(color: Colors.black54, fontSize: 13),
        ),
        const SizedBox(height: 10),
        ...liste.take(8).map((p) {
          final name = '${p['prenom'] ?? ''} ${p['nom'] ?? ''}'.trim();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: whiteCard(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name.isEmpty ? 'Patient' : name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dernier RDV : ${p['dernierRdv'] ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => showPlanifierProchainRdvDialog(p),
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Planifier le prochain RDV'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          );
        }),
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
        suiviRdvSection(),
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
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: badge(statut, color)),
            ],
          ),
          const SizedBox(height: 12),
          if (statut == "CONFIRMEE" && demande["date_rendezvous"] != null) ...[
            infoRow(Icons.date_range, "Date RDV", demande["date_rendezvous"] ?? "-"),
            infoRow(
              Icons.access_time,
              "Créneau",
              formatHeureAffichage(demande["heure_rendezvous"] ?? demande["heure_souhaitee"]),
            ),
          ] else ...[
            infoRow(Icons.date_range, "Date souhaitée", demande["date_souhaitee"] ?? "-"),
            infoRow(
              Icons.access_time,
              "Créneau demandé",
              formatHeureAffichage(demande["heure_souhaitee"]),
            ),
          ],
          if (!compact)
            infoRow(Icons.history, "Date demande", demande["date_demande"]?.toString() ?? "-"),
          if (!compact && statut == "CONFIRMEE" && demande["id_rendezvous"] != null) ...[
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Icon(
                  Icons.medical_services,
                  size: 20,
                  color: couleurStatutConsultation(
                    demande["statut_consultation"]?.toString(),
                  ),
                ),
                Text(
                  'Consultation : ${libelleStatutConsultation(demande["statut_consultation"]?.toString())}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () {
                    final idRdv = int.tryParse('${demande['id_rendezvous']}');
                    if (idRdv == null) return;
                    showStatutConsultationDialog(
                      idRendezvous: idRdv,
                      statutActuel: demande['statut_consultation']?.toString(),
                    );
                  },
                  child: const Text('Modifier le statut'),
                ),
              ],
            ),
          ],
          if (!compact) ...[
            const SizedBox(height: 12),
            fullWidthOutlinedButton(
              onPressed: () => showEditRdvDialog(demande),
              icon: Icons.edit,
              label: 'Modifier',
            ),
            if (isPending) ...[
              const SizedBox(height: 8),
              pairedActionButtons(
                first: fullWidthOutlinedButton(
                  onPressed: () => confirmAction(
                    idDemande,
                    "REFUSER",
                    "Refuser la demande",
                    Colors.red,
                    Icons.cancel,
                  ),
                  icon: Icons.close,
                  label: 'Refuser',
                ),
                second: fullWidthElevatedButton(
                  onPressed: () => showPlanifierRdvDialog(demande),
                  icon: Icons.check,
                  label: 'Confirmer',
                ),
              ),
            ],
            if (!isPending && statut == "CONFIRMEE" && demande["statut_consultation"] == "TERMINE") ...[
              const SizedBox(height: 8),
              fullWidthOutlinedButton(
                  onPressed: () {
                    final idPatient = int.tryParse('${demande['id_patient']}');
                    if (idPatient == null) return;
                    Map<String, dynamic> fiche;
                    try {
                      fiche = patients.firstWhere(
                        (x) => x['id_patient'] == idPatient,
                      );
                    } catch (_) {
                      fiche = {
                        'id_patient': idPatient,
                        'nom': demande['patient_nom'],
                        'prenom': demande['patient_prenom'],
                        'dernierRdv': demande['date_rendezvous'] ?? demande['date_souhaitee'],
                        'prochainRdv': '-',
                        'peut_planifier_suivi': true,
                      };
                    }
                    showPlanifierProchainRdvDialog(fiche);
                  },
                icon: Icons.event_available,
                label: 'Planifier le prochain RDV',
              ),
            ],
          ],
        ],
      ),
    );
  }

  String formatDateApi(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String formatHeureApi(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:00';
  }

  String formatDateTimeDisplay(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} '
        'à ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  int calculateAgeFromBirthDate(DateTime dob) {
    final today = DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<DateTime?> pickConsultationDateTime(
    BuildContext dialogContext,
    DateTime initial,
  ) async {
    final pickedDate = await showDatePicker(
      context: dialogContext,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (pickedDate == null) return null;

    if (!dialogContext.mounted) return null;

    final pickedTime = await showTimePicker(
      context: dialogContext,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void safeDialogSetState(
    BuildContext dialogContext,
    void Function(void Function()) setDialogState,
    VoidCallback update,
  ) {
    if (dialogContext.mounted) {
      setDialogState(update);
    }
  }

  /// Deux boutons côte à côte si la place suffit, sinon empilés pleine largeur.
  Widget pairedActionButtons({
    required Widget first,
    required Widget second,
    double breakpoint = 420,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: 8),
              second,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: first),
            const SizedBox(width: 8),
            Expanded(child: second),
          ],
        );
      },
    );
  }

  Widget fullWidthOutlinedButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          alignment: Alignment.center,
        ),
      ),
    );
  }

  Widget fullWidthElevatedButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          alignment: Alignment.center,
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
        ),
      ),
    );
  }

  Future<void> showPlanifierRdvDialog(Map<String, dynamic> demande) async {
    final idDemande = int.tryParse('${demande['id_demande']}') ?? 0;
    final medecinId = idMedecin;
    if (idDemande == 0 || medecinId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de charger les créneaux (médecin non identifié).'),
        ),
      );
      return;
    }

    DateTime? selectedDate;
    final dateSouhaitee = demande['date_souhaitee']?.toString();
    if (dateSouhaitee != null && dateSouhaitee.length >= 10) {
      selectedDate = DateTime.tryParse(dateSouhaitee.substring(0, 10));
    }
    selectedDate ??= DateTime.now();

    String? selectedHeure = demande['heure_souhaitee']?.toString();
    List<Map<String, dynamic>> creneaux = [];
    bool loadingCreneaux = true;
    String? creneauxMessage;

    Future<void> loadCreneaux(
      DateTime date,
      BuildContext dialogCtx,
      void Function(void Function()) setDialogState,
    ) async {
      safeDialogSetState(dialogCtx, setDialogState, () {
        loadingCreneaux = true;
        creneauxMessage = null;
      });

      try {
        final dateStr = formatDateApi(date);
        final response = await http.get(
          Uri.parse(
            '${AuthService.baseUrl}/medecins/$medecinId/creneaux?date=$dateStr&exclude_demande=$idDemande',
          ),
          headers: _headers(),
        );
        final data = jsonDecode(response.body);

        if (!dialogCtx.mounted) return;

        if (response.statusCode == 200 && data['success'] == true) {
          final payload = data['data'] as Map<String, dynamic>;
          final list = (payload['creneaux'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final libres =
              list.where((s) => s['disponible'] != false && s['occupe'] != true);

          safeDialogSetState(dialogCtx, setDialogState, () {
            creneaux = list;
            loadingCreneaux = false;
            if (list.isEmpty) {
              creneauxMessage = 'Aucun créneau ce jour-là.';
            } else if (libres.isEmpty) {
              creneauxMessage = 'Tous les créneaux sont pris (rouge).';
            } else {
              creneauxMessage = null;
            }
            if (selectedHeure != null &&
                list.any((s) => s['heure'] == selectedHeure && s['occupe'] == true)) {
              selectedHeure = null;
            }
          });
        } else {
          safeDialogSetState(dialogCtx, setDialogState, () {
            creneaux = [];
            loadingCreneaux = false;
            creneauxMessage = data['message']?.toString() ?? 'Erreur créneaux';
          });
        }
      } catch (_) {
        if (!dialogCtx.mounted) return;
        safeDialogSetState(dialogCtx, setDialogState, () {
          creneaux = [];
          loadingCreneaux = false;
          creneauxMessage = 'Erreur réseau';
        });
      }
    }

    if (!mounted) return;

    var creneauxLoaded = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          if (!creneauxLoaded) {
            creneauxLoaded = true;
            Future.microtask(
              () => loadCreneaux(selectedDate!, dialogCtx, setDialogState),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fixer le rendez-vous',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Souhait patient : ${demande['date_souhaitee']} à ${formatHeureAffichage(demande['heure_souhaitee'])}',
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate!,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                              selectedHeure = null;
                              creneaux = [];
                              loadingCreneaux = true;
                            });
                            await loadCreneaux(picked, dialogCtx, setDialogState);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(formatDateApi(selectedDate!)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Choisir le créneau définitif',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    
                    const SizedBox(height: 8),
                    if (loadingCreneaux)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ))
                    else ...[
                      if (creneauxMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            creneauxMessage!,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      if (creneaux.isNotEmpty)
                        CreneauChoiceGrid(
                          creneaux: creneaux,
                          selectedHeure: selectedHeure,
                          onHeureSelected: (h) => setDialogState(() => selectedHeure = h),
                        ),
                    ],
                    const SizedBox(height: 20),
                    pairedActionButtons(
                      first: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Annuler'),
                      ),
                      second: ElevatedButton(
                        onPressed: selectedHeure == null
                            ? null
                            : () {
                                Navigator.pop(dialogContext);
                                traiterDemande(
                                  idDemande,
                                  'CONFIRMER',
                                  dateRendezvous: formatDateApi(selectedDate!),
                                  heureRendezvous: selectedHeure,
                                );
                              },
                        child: const Text('Confirmer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> planifierProchainRdv(
    int idPatient,
    String dateRendezvous,
    String heureRendezvous,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${AuthService.baseUrl}/secretaire/patients/$idPatient/prochain-rendezvous',
        ),
        headers: _headers(),
        body: jsonEncode({
          'date_rendezvous': dateRendezvous,
          'heure_rendezvous': heureRendezvous,
        }),
      );
      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        var message = data['message']?.toString() ?? 'Prochain RDV planifié';
        final payload = data['data'];
        if (payload is Map && payload['email_confirmation_envoye'] == false) {
          message =
              '$message\n(Aucun email envoyé : vérifiez la configuration mail.)';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        loadAllData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Erreur')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur serveur')),
      );
    }
  }

  Future<void> showPlanifierProchainRdvDialog(Map<String, dynamic> patient) async {
    final idPatient = int.tryParse('${patient['id_patient']}') ?? 0;
    final medecinId = idMedecin;
    if (idPatient == 0 || medecinId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de planifier (médecin non identifié).')),
      );
      return;
    }

    DateTime selectedDate = DateTime.now();
    String? selectedHeure;
    List<Map<String, dynamic>> creneaux = [];
    bool loadingCreneaux = true;
    String? creneauxMessage;

    Future<void> loadCreneaux(
      DateTime date,
      BuildContext dialogCtx,
      void Function(void Function()) setDialogState,
    ) async {
      safeDialogSetState(dialogCtx, setDialogState, () {
        loadingCreneaux = true;
        creneauxMessage = null;
      });

      try {
        final dateStr = formatDateApi(date);
        final response = await http.get(
          Uri.parse(
            '${AuthService.baseUrl}/medecins/$medecinId/creneaux?date=$dateStr',
          ),
          headers: _headers(),
        );
        final data = jsonDecode(response.body);

        if (!dialogCtx.mounted) return;

        if (response.statusCode == 200 && data['success'] == true) {
          final payload = data['data'] as Map<String, dynamic>;
          final list = (payload['creneaux'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final libres =
              list.where((s) => s['disponible'] != false && s['occupe'] != true);

          safeDialogSetState(dialogCtx, setDialogState, () {
            creneaux = list;
            loadingCreneaux = false;
            creneauxMessage = list.isEmpty
                ? 'Aucun créneau ce jour-là.'
                : libres.isEmpty
                    ? 'Tous les créneaux sont pris (rouge).'
                    : null;
          });
        } else {
          safeDialogSetState(dialogCtx, setDialogState, () {
            creneaux = [];
            loadingCreneaux = false;
            creneauxMessage = data['message']?.toString() ?? 'Erreur créneaux';
          });
        }
      } catch (_) {
        if (!dialogCtx.mounted) return;
        safeDialogSetState(dialogCtx, setDialogState, () {
          creneaux = [];
          loadingCreneaux = false;
          creneauxMessage = 'Erreur réseau';
        });
      }
    }

    if (!mounted) return;

    var creneauxLoaded = false;
    final patientName = '${patient['prenom'] ?? ''} ${patient['nom'] ?? ''}'.trim();

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          if (!creneauxLoaded) {
            creneauxLoaded = true;
            Future.microtask(
              () => loadCreneaux(selectedDate, dialogCtx, setDialogState),
            );
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Planifier le prochain rendez-vous',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      patientName.isEmpty ? 'Patient suivi' : patientName,
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    if ((patient['dernierRdv'] ?? '-') != '-')
                      Text(
                        'Dernier RDV : ${patient['dernierRdv']}',
                        style: const TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                              selectedHeure = null;
                              creneaux = [];
                              loadingCreneaux = true;
                            });
                            await loadCreneaux(picked, dialogCtx, setDialogState);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(formatDateApi(selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Créneau du prochain RDV',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    
                    const SizedBox(height: 8),
                    if (loadingCreneaux)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else ...[
                      if (creneauxMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            creneauxMessage!,
                            style: const TextStyle(color: Colors.orange),
                          ),
                        ),
                      if (creneaux.isNotEmpty)
                        CreneauChoiceGrid(
                          creneaux: creneaux,
                          selectedHeure: selectedHeure,
                          onHeureSelected: (h) => setDialogState(() => selectedHeure = h),
                        ),
                    ],
                    const SizedBox(height: 20),
                    pairedActionButtons(
                      first: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Annuler'),
                      ),
                      second: ElevatedButton(
                        onPressed: selectedHeure == null
                            ? null
                            : () {
                                Navigator.pop(dialogContext);
                                planifierProchainRdv(
                                  idPatient,
                                  formatDateApi(selectedDate),
                                  selectedHeure!,
                                );
                              },
                        child: const Text('Enregistrer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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
              pairedActionButtons(
                first: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                second: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    traiterDemande(idDemande, action);
                  },
                  child: const Text('Valider'),
                ),
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
        fullWidthElevatedButton(
          onPressed: showAddPatientDialog,
          icon: Icons.person_add_alt_1,
          label: 'Ajouter patient',
        ),
        const SizedBox(height: 16),
        searchField(
          hint: "Rechercher patient...",
          onChanged: (v) => setState(() => patientSearch = v),
        ),
        const SizedBox(height: 16),
        if (filteredPatients.isEmpty)
          emptyState(
            Icons.people,
            "Aucun patient suivi",
            "Enregistrez un patient arrivé directement au cabinet ou confirmez une demande de RDV.",
          )
        else
          ...filteredPatients.map(patientCard),
      ],
    );
  }

  void showAddPatientDialog() {
    final nomCtrl = TextEditingController();
    final prenomCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final adresseCtrl = TextEditingController();
    var genre = 'M';
    DateTime? dateNaissance;
    DateTime consultationDateTime = DateTime.now();
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Passage sans rendez-vous'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                 
                  const SizedBox(height: 16),
                  TextField(
                    controller: prenomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prénom *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nomCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: genre,
                    decoration: const InputDecoration(
                      labelText: 'Genre *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'M', child: Text('Homme')),
                      DropdownMenuItem(value: 'F', child: Text('Femme')),
                    ],
                    onChanged: (v) => setDialogState(() => genre = v ?? 'M'),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      dateNaissance == null
                          ? 'Date de naissance *'
                          : 'Naissance : ${formatDateApi(dateNaissance!)}',
                    ),
                    subtitle: dateNaissance == null
                        ? null
                        : Text('Âge : ${calculateAgeFromBirthDate(dateNaissance!)} ans'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: dateNaissance ?? DateTime(1990),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(() => dateNaissance = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: adresseCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Adresse (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date et heure de consultation *'),
                    subtitle: Text(formatDateTimeDisplay(consultationDateTime)),
                    trailing: const Icon(Icons.event),
                    onTap: () async {
                      final picked = await pickConsultationDateTime(
                        ctx,
                        consultationDateTime,
                      );
                      if (picked != null) {
                        setDialogState(() => consultationDateTime = picked);
                      }
                    },
                  ),
                ],
              ),
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
                      final nom = nomCtrl.text.trim();
                      final prenom = prenomCtrl.text.trim();
                      final email = emailCtrl.text.trim();

                      if (nom.isEmpty ||
                          prenom.isEmpty ||
                          email.isEmpty ||
                          dateNaissance == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Nom, prénom, email et date de naissance sont obligatoires',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);

                      try {
                        final payload = <String, dynamic>{
                          'nom': nom,
                          'prenom': prenom,
                          'email': email,
                          'telephone': telCtrl.text.trim(),
                          'genre': genre,
                          'date_naissance': formatDateApi(dateNaissance!),
                          'date_rendezvous': formatDateApi(consultationDateTime),
                          'heure_rendezvous': formatHeureApi(consultationDateTime),
                        };
                        if (adresseCtrl.text.trim().isNotEmpty) {
                          payload['adresse'] = adresseCtrl.text.trim();
                        }

                        final response = await http.post(
                          Uri.parse('${AuthService.baseUrl}/secretaire/patients'),
                          headers: _headers(),
                          body: jsonEncode(payload),
                        );
                        final data = jsonDecode(response.body);

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        if (response.statusCode >= 200 &&
                            response.statusCode < 300 &&
                            data['success'] == true) {
                          await fetchPatients();
                          await fetchDashboard();

                          final message = data['message']?.toString() ?? 'Patient enregistré';

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(message)),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(data['message']?.toString() ?? 'Erreur'),
                              ),
                            );
                          }
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
                  : const Text('Enregistrer'),
            ),
          ],
        ),
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
                child: Text(
                  fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => showReclamationDialog(p),
                icon: const Icon(Icons.report_problem, color: Colors.orange, size: 22),
                tooltip: 'Reclamer',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => showEditPatientDialog(p),
                icon: const Icon(Icons.edit, color: Colors.blue, size: 22),
                tooltip: 'Modifier',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => showAddPaymentDialog(
                  fullName,
                  idPatient: p['id_patient'] as int?,
                ),
                icon: const Icon(Icons.payments, color: Colors.green, size: 22),
                tooltip: 'Paiement',
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
          if (p["id_rendezvous"] != null) ...[
            const SizedBox(height: 4),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Icon(
                  Icons.medical_services,
                  size: 20,
                  color: couleurStatutConsultation(p["dernierRdvStatut"]?.toString()),
                ),
                Text(
                  'Consultation : ${libelleStatutConsultation(p["dernierRdvStatut"]?.toString())}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                TextButton(
                  onPressed: () {
                    final idRdv = int.tryParse('${p['id_rendezvous']}');
                    if (idRdv == null) return;
                    showStatutConsultationDialog(
                      idRendezvous: idRdv,
                      statutActuel: p['dernierRdvStatut']?.toString(),
                    );
                  },
                  child: const Text('Modifier le statut'),
                ),
              ],
            ),
          ],
          if ((p["prochainRdv"] ?? "-") == "-" || p["peut_planifier_suivi"] == true) ...[
            const SizedBox(height: 12),
            fullWidthElevatedButton(
              onPressed: () => showPlanifierProchainRdvDialog(p),
              icon: Icons.calendar_month,
              label: 'Planifier le prochain RDV',
            ),
          ],
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

  void showReclamationDialog(Map<String, dynamic> p) {
    final note = TextEditingController();
    var saving = false;
    final fullName = "${p['prenom']} ${p['nom']}";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Reclamer $fullName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Decrivez le probleme pour l\'administrateur (comportement, fraude, abus, etc.) :',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                maxLines: 5,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Note de reclamation *',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: saving
                  ? null
                  : () async {
                      final message = note.text.trim();
                      if (message.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('La note doit contenir au moins 10 caracteres'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => saving = true);
                      try {
                        final id = p['id_patient'];
                        final response = await http.post(
                          Uri.parse('${AuthService.baseUrl}/secretaire/patients/$id/reclamation'),
                          headers: _headers(),
                          body: jsonEncode({'message': message}),
                        );
                        final data = jsonDecode(response.body);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (response.statusCode >= 200 &&
                            response.statusCode < 300 &&
                            data['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                data['message']?.toString() ??
                                    'Reclamation envoyee a l\'administrateur',
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(data['message']?.toString() ?? 'Erreur'),
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
                  : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  void showEditPatientDialog(Map<String, dynamic> p) {
    final tel = TextEditingController(text: p["telephone"]);
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Modifier patient"),
          content: TextField(
            controller: tel,
            decoration: const InputDecoration(labelText: "Téléphone"),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final id = p['id_patient'];
                        final response = await http.put(
                          Uri.parse("${AuthService.baseUrl}/secretaire/patients/$id"),
                          headers: _headers(),
                          body: jsonEncode({'telephone': tel.text}),
                        );
                        final data = jsonDecode(response.body);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (response.statusCode == 200 && data['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(data['message'] ?? 'Mis à jour')),
                          );
                          fetchPatients();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(data['message'] ?? 'Erreur')),
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
                  : const Text("Enregistrer"),
            ),
          ],
        ),
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
            statCard(
              Icons.payments,
              "Total",
              "${totalCaisse()} DT",
              Colors.blue,
              onTap: () => navigateToTab(3, caisseStatut: 'TOUS'),
            ),
            statCard(
              Icons.check_circle,
              "Payés",
              "${caisse.where((e) => e["statut"] == "PAYÉ").length}",
              Colors.green,
              onTap: () => navigateToTab(3, caisseStatut: 'PAYÉ'),
            ),
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

  void showAddPaymentDialog(String patientName, {int? idPatient}) {
    final montant = TextEditingController(text: '50');
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text("Ajouter paiement - $patientName"),
          content: TextField(
            controller: montant,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Montant (DT)"),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final response = await http.post(
                          Uri.parse("${AuthService.baseUrl}/secretaire/caisse"),
                          headers: _headers(),
                          body: jsonEncode({
                            'patient': patientName,
                            if (idPatient != null) 'id_patient': idPatient,
                            'montant': int.tryParse(montant.text) ?? 50,
                            'statut': 'PAYÉ',
                          }),
                        );
                        final data = jsonDecode(response.body);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (response.statusCode >= 200 &&
                            response.statusCode < 300 &&
                            data['success'] == true) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(data['message'] ?? 'Paiement ajouté')),
                          );
                          fetchCaisse();
                          fetchDashboard();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(data['message'] ?? 'Erreur')),
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
                  : const Text("Ajouter"),
            ),
          ],
        ),
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
                child: Text(
                  c["patient"],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(child: badge(c["statut"], color)),
            ],
          ),
          const SizedBox(height: 12),
          infoRow(Icons.date_range, "Date", c["date"]),
          infoRow(Icons.payments, "Montant", "${c["montant"]} DT"),
          const SizedBox(height: 10),
          pairedActionButtons(
            first: fullWidthOutlinedButton(
              onPressed: () => showEditMontantDialog(c),
              icon: Icons.edit,
              label: 'Modifier',
            ),
            second: fullWidthElevatedButton(
              onPressed: () => showRecuDialog(c),
              icon: Icons.print,
              label: 'Reçu',
            ),
          ),
        ],
      ),
    );
  }

  void showEditMontantDialog(Map<String, dynamic> c) {
    final montant = TextEditingController(text: c["montant"].toString());
    final id = c['id_paiement'] ?? c['id_rendezvous'];
    var saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Modifier paiement"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: montant,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Montant (DT)"),
              ),
              const SizedBox(height: 12),
              pairedActionButtons(
                first: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            await _updatePaiementStatut(ctx, id, 'NON_PAYÉ');
                          },
                    child: const Text('Non payé'),
                  ),
                ),
                second: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            await _updatePaiementStatut(ctx, id, 'PAYÉ');
                          },
                    child: const Text('Payé'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final response = await http.put(
                          Uri.parse("${AuthService.baseUrl}/secretaire/caisse/$id"),
                          headers: _headers(),
                          body: jsonEncode({
                            'montant': int.tryParse(montant.text) ?? c['montant'],
                          }),
                        );
                        final data = jsonDecode(response.body);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (response.statusCode == 200 && data['success'] == true) {
                          fetchCaisse();
                          fetchDashboard();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(data['message'] ?? 'Erreur')),
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
                  : const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePaiementStatut(
    BuildContext ctx,
    dynamic id,
    String statut,
  ) async {
    try {
      final response = await http.put(
        Uri.parse("${AuthService.baseUrl}/secretaire/caisse/$id"),
        headers: _headers(),
        body: jsonEncode({'statut': statut}),
      );
      final data = jsonDecode(response.body);
      if (!mounted) return;
      Navigator.pop(ctx);
      if (response.statusCode == 200 && data['success'] == true) {
        fetchCaisse();
        fetchDashboard();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Erreur')),
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
        if (disponibiliteTexte.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: whiteCard(),
            child: Text(
              disponibiliteTexte,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        if (horaires.isEmpty)
          emptyState(
            Icons.schedule,
            'Horaires non définis',
            'Le médecin n\'a pas encore configuré ses disponibilités.',
          )
        else
          ...horaires.map(horaireCard),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: whiteCard(),
          child: Row(
            children: [
              const Icon(Icons.timelapse, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Durée d\'un créneau : $dureeCreneauMinutes min',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: showDureeCreneauDialog,
                icon: const Icon(Icons.edit),
                tooltip: 'Modifier la durée',
              ),
            ],
          ),
        ),
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
          Flexible(
            child: Text(
              actif ? "${h["debut"]} - ${h["fin"]}" : "Fermé",
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
          IconButton(
            onPressed: () => showEditHoraireDialog(h),
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
    );
  }

  Future<void> saveDisponibilites({int? nouvelleDuree}) async {
    if (horaires.isEmpty) return;

    setState(() => savingDisponibilites = true);

    try {
      final body = {
        'texte': disponibiliteTexte,
        'duree_creneau_minutes': nouvelleDuree ?? dureeCreneauMinutes,
        'horaires': horaires
            .map((h) => {
                  'jour': h['jour'],
                  'debut': h['debut'],
                  'fin': h['fin'],
                  'actif': h['actif'] == true,
                })
            .toList(),
      };

      final response = await http.put(
        Uri.parse('${AuthService.baseUrl}/secretaire/disponibilites'),
        headers: _headers(),
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        final payload = data['data'] as Map<String, dynamic>;
        setState(() {
          horaires = _parseList(payload['horaires']);
          disponibiliteTexte = payload['texte']?.toString() ?? disponibiliteTexte;
          dureeCreneauMinutes =
              int.tryParse('${payload['duree_creneau_minutes'] ?? dureeCreneauMinutes}') ??
                  dureeCreneauMinutes;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horaires enregistrés')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message']?.toString() ?? 'Erreur')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de l\'enregistrement')),
        );
      }
    }

    if (mounted) setState(() => savingDisponibilites = false);
  }

  void showDureeCreneauDialog() {
    final controller = TextEditingController(text: '$dureeCreneauMinutes');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Durée des créneaux'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minutes (15 à 120)',
            suffixText: 'min',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final value = int.tryParse(controller.text.trim());
              if (value == null || value < 15 || value > 120) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Durée invalide (15-120 min)')),
                );
                return;
              }
              Navigator.pop(context);
              setState(() => dureeCreneauMinutes = value);
              await saveDisponibilites(nouvelleDuree: value);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void showEditHoraireDialog(Map<String, dynamic> h) {
    final debutController = TextEditingController(
      text: h['debut']?.toString() == '-' ? '09:00' : '${h['debut']}',
    );
    final finController = TextEditingController(
      text: h['fin']?.toString() == '-' ? '17:00' : '${h['fin']}',
    );
    var actif = h['actif'] == true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Horaires — ${h['jour']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Ouvert ce jour'),
                value: actif,
                onChanged: (v) => setDialogState(() => actif = v),
              ),
              if (actif) ...[
                TextField(
                  controller: debutController,
                  decoration: const InputDecoration(
                    labelText: 'Heure de début',
                    hintText: '09:00',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: finController,
                  decoration: const InputDecoration(
                    labelText: 'Heure de fin',
                    hintText: '17:00',
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: savingDisponibilites
                  ? null
                  : () async {
                      final index = horaires.indexWhere((x) => x['jour'] == h['jour']);
                      if (index < 0) return;

                      horaires[index] = {
                        'jour': h['jour'],
                        'debut': actif ? debutController.text.trim() : '-',
                        'fin': actif ? finController.text.trim() : '-',
                        'actif': actif,
                      };

                      Navigator.pop(context);
                      setState(() {});
                      await saveDisponibilites();
                    },
              child: savingDisponibilites
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
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
        fullWidthElevatedButton(
          onPressed: showEditProfileDialog,
          icon: Icons.edit,
          label: 'Modifier mes informations',
        ),
        const SizedBox(height: 12),
        fullWidthOutlinedButton(
          onPressed: showChangePasswordDialog,
          icon: Icons.lock_reset,
          label: 'Changer mot de passe',
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
          onPressed: () async {
            try {
              final response = await http.put(
                Uri.parse("${AuthService.baseUrl}/secretaire/profile"),
                headers: _headers(),
                body: jsonEncode({
                  'nom': nom.text,
                  'prenom': prenom.text,
                  'email': email.text,
                  'telephone': tel.text,
                }),
              );
              final data = jsonDecode(response.body);
              if (!mounted) return;
              Navigator.pop(context);
              if (response.statusCode == 200 && data['success'] == true) {
                final updated = data['data'] as Map<String, dynamic>;
                setState(() {
                  AuthService.currentUser?['nom'] = updated['nom'];
                  AuthService.currentUser?['prenom'] = updated['prenom'];
                  AuthService.currentUser?['email'] = updated['email'];
                  AuthService.currentUser?['telephone'] = updated['telephone'];
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? 'Profil mis à jour')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['message'] ?? 'Erreur')),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur : $e')),
                );
              }
            }
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
    final confirmPass = TextEditingController();
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
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Ancien mot de passe *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau mot de passe * (min. 6)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPass,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer *',
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
                      if (newPass.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Minimum 6 caractères')),
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