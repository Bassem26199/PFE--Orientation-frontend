import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/medecin_service.dart';
import '../widgets/doctor_avatar.dart';
import '../widgets/doctors_map_view.dart';
import '../widgets/doctor_reviews_section.dart';
import '../services/avis_service.dart';
import 'welcome_screen.dart';
import 'analyser_symptomes_screen.dart';
import 'login_screen.dart';
import 'create_rendezvous_screen.dart';

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
  int? selectedSpecialiteId;
  List<Map<String, dynamic>> allDoctors = [];
  List<Map<String, dynamic>> specialites = [];
  bool isLoading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        MedecinService.fetchMedecins(),
        MedecinService.fetchSpecialites(),
      ]);

      if (!mounted) return;

      setState(() {
        allDoctors = results[0];
        specialites = results[1];
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadError = "Impossible de charger les médecins. Vérifiez l'API.";
      });
    }
  }

  List<Map<String, dynamic>> get filteredDoctors {
    return allDoctors.where((d) {
      final matchVille =
          selectedVille == "Toutes" || d["ville"]?.toString() == selectedVille;
      final specId = d["id_specialite"];
      final matchSpecialite = selectedSpecialiteId == null ||
          specId == selectedSpecialiteId ||
          specId?.toString() == selectedSpecialiteId.toString();
      return matchVille && matchSpecialite;
    }).toList();
  }

  List<String> get villes {
    final values = allDoctors
        .map((d) => d["ville"]?.toString())
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    return ["Toutes", ...values];
  }

  Future<void> openMap(Map<String, dynamic> d) async {
    final lat = double.tryParse(d["latitude"]?.toString() ?? '');
    final lng = double.tryParse(d["longitude"]?.toString() ?? '');

    final Uri url;
    if (lat != null && lng != null) {
      url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
      );
    } else {
      final adresse = d["adresse"]?.toString() ?? d["adresse_cabinet"] ?? '';
      final ville = d["ville"]?.toString() ?? '';
      final query = Uri.encodeComponent("$adresse $ville".trim());
      url = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$query",
      );
    }

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
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            child: const Text("Se connecter"),
          ),
        ],
      ),
    );
  }

  Future<void> openRdvForDoctor(Map<String, dynamic> d) async {
    if (!AuthService.isLoggedIn) {
      requireLoginForRdv();
      return;
    }

    if (!AuthService.isPatient) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Seul un compte patient peut prendre rendez-vous. '
            'Déconnectez-vous et reconnectez-vous avec un compte patient.',
          ),
        ),
      );
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/orientations/patient'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer ${AuthService.token}',
        },
      );

      final data = jsonDecode(response.body);

      if (!mounted) return;

      if (response.statusCode == 401) {
        await AuthService.logout();
        requireLoginForRdv();
        return;
      }

      if (response.statusCode != 200 || data['success'] != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['message']?.toString() ?? 'Impossible de charger votre orientation.',
            ),
          ),
        );
        return;
      }

      final rawList = data['data'];
      final list = rawList is List ? rawList : [];

      if (list.isEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Orientation requise'),
            content: const Text(
              'Pour prendre rendez-vous, commencez par analyser vos symptômes. '
              'L\'application vous orientera vers la bonne spécialité.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AnalyserSymptomesScreen(),
                    ),
                  );
                },
                child: const Text('Analyser mes symptômes'),
              ),
            ],
          ),
        );
        return;
      }

      final latest = Map<String, dynamic>.from(list.first as Map);
      final idOrientation = int.tryParse('${latest['id_orientation']}') ?? 0;

      if (idOrientation == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Orientation invalide.')),
        );
        return;
      }

      final doctorSpec = int.tryParse('${d['id_specialite']}');
      final orientSpec = int.tryParse('${latest['id_specialite']}');

      if (doctorSpec != null &&
          orientSpec != null &&
          doctorSpec != orientSpec) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ce médecin ne correspond pas à votre orientation '
              '(${latest['nom_specialite'] ?? 'spécialité recommandée'}).',
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreateRendezvousScreen(
            doctor: d,
            idOrientation: idOrientation,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur réseau lors de la prise de rendez-vous.')),
      );
    }
  }

  Widget doctorCard(Map<String, dynamic> d, int index) {
    final idMedecin = int.tryParse(d['id_medecin']?.toString() ?? '') ?? index;

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
              DoctorAvatar(
                doctor: d,
                radius: 32,
                fallbackIndex: idMedecin,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d["nom_complet"] ??
                          "Dr. ${d["prenom"]} ${d["nom"]}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${d["specialite"] ?? d["nom_specialite"]} • ${d["ville"]}",
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
                            d["adresse"]?.toString() ??
                                d["adresse_cabinet"]?.toString() ??
                                '',
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          (d["note"] ?? d["note_moyenne"] ?? '-').toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if ((d['nb_avis'] ?? 0) != 0)
                          Text(
                            '${d['nb_avis']} avis',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                      ],
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
                  onPressed: () => callDoctor(
                    d["telephone"]?.toString() ??
                        d["telephone_professionnel"]?.toString() ??
                        '',
                  ),
                  icon: const Icon(Icons.call),
                  label: const Text("Appel"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => openRdvForDoctor(d),
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
              onPressed: () => whatsappDoctor(
                d["telephone"]?.toString() ??
                    d["telephone_professionnel"]?.toString() ??
                    '',
              ),
              icon: const Icon(Icons.chat),
              label: const Text("Contacter via WhatsApp"),
            ),
          ),
          if (int.tryParse(d['id_medecin']?.toString() ?? '') != null) ...[
            const Divider(height: 24),
            DoctorReviewsSection(
              idMedecin: int.parse(d['id_medecin'].toString()),
              medecinLabel: d['nom_complet']?.toString() ??
                  'Dr. ${d['prenom']} ${d['nom']}',
              compact: true,
              showAddForm: true,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Médecins"),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Trouver un médecin",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loadError ??
                          "${allDoctors.length} médecin(s) enregistré(s) — données réelles.",
                      style: TextStyle(
                        color: loadError != null
                            ? Colors.red
                            : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (MedecinService.withMapCoordinates(filteredDoctors)
                        .isNotEmpty) ...[
                      DoctorsMapView(
                        doctors: filteredDoctors,
                        height: 220,
                        initialZoom: 9,
                      ),
                      const SizedBox(height: 18),
                    ],
                    DropdownButtonFormField<String>(
                      value: villes.contains(selectedVille)
                          ? selectedVille
                          : "Toutes",
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Ville",
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      items: villes
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(v),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => selectedVille = value!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      value: selectedSpecialiteId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: "Spécialité",
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text("Toutes"),
                        ),
                        ...specialites.map((s) {
                          final id = s['id_specialite'] is int
                              ? s['id_specialite'] as int
                              : int.tryParse(
                                      s['id_specialite']?.toString() ?? '') ??
                                  0;
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(
                              s['nom_specialite']?.toString() ?? 'Spécialité',
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) =>
                          setState(() => selectedSpecialiteId = value),
                    ),
                    const SizedBox(height: 18),
                    if (filteredDoctors.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text("Aucun médecin trouvé"),
                        ),
                      )
                    else
                      ...filteredDoctors.asMap().entries.map(
                            (e) => doctorCard(e.value, e.key),
                          ),
                  ],
                ),
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
  final avisController = TextEditingController();
  final medecinSearchController = TextEditingController();
  List<Map<String, dynamic>> allAvis = [];
  List<Map<String, dynamic>> medecins = [];
  List<Map<String, dynamic>> specialites = [];
  int? selectedMedecinId;
  int note = 5;
  bool loading = true;
  bool submitting = false;
  int? filterMedecinId;
  int? pickerSpecialiteId;
  String medecinSearchQuery = '';

  @override
  void initState() {
    super.initState();
    medecinSearchController.addListener(() {
      setState(() => medecinSearchQuery = medecinSearchController.text.trim());
    });
    _load();
  }

  @override
  void dispose() {
    avisController.dispose();
    medecinSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        AvisService.fetchAll(),
        MedecinService.fetchMedecins(),
        MedecinService.fetchSpecialites(),
      ]);
      if (!mounted) return;
      setState(() {
        allAvis = results[0];
        medecins = results[1];
        specialites = results[2];
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get filteredMedecinsForPicker {
    final q = medecinSearchQuery.toLowerCase();
    return medecins.where((m) {
      final specId = int.tryParse(m['id_specialite']?.toString() ?? '');
      if (pickerSpecialiteId != null && specId != pickerSpecialiteId) {
        return false;
      }
      if (q.isEmpty) return true;
      final nom = (m['nom_complet'] ??
              'Dr. ${m['prenom']} ${m['nom']}')
          .toString()
          .toLowerCase();
      final spec =
          (m['specialite'] ?? m['nom_specialite'] ?? '').toString().toLowerCase();
      final ville = (m['ville'] ?? '').toString().toLowerCase();
      return nom.contains(q) || spec.contains(q) || ville.contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredAvis {
    if (filterMedecinId == null) return allAvis;
    return allAvis.where((a) {
      final id = int.tryParse(a['id_medecin']?.toString() ?? '');
      return id == filterMedecinId;
    }).toList();
  }

  Future<void> _submit() async {
    if (selectedMedecinId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez un médecin.')),
      );
      return;
    }
    if (avisController.text.trim().length < 3) return;

    if (!AuthService.isPatient) {
      if (!AuthService.isLoggedIn) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Seuls les patients connectés peuvent publier un avis.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => submitting = true);
    final error = await AvisService.submit(
      idMedecin: selectedMedecinId!,
      note: note,
      commentaire: avisController.text.trim(),
    );
    if (!mounted) return;
    setState(() => submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    avisController.clear();
    note = 5;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avis publié.')),
      );
    }
  }

  Widget _medecinPickerTile(Map<String, dynamic> m) {
    final id = int.tryParse(m['id_medecin']?.toString() ?? '') ?? 0;
    final selected = selectedMedecinId == id;
    final nom =
        m['nom_complet'] ?? 'Dr. ${m['prenom']} ${m['nom']}';
    final spec = m['specialite'] ?? m['nom_specialite'] ?? '';
    final ville = m['ville'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? Colors.blue.shade50 : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? Colors.blue : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: selected ? Colors.blue : Colors.blue.shade50,
          child: Icon(
            Icons.medical_services,
            color: selected ? Colors.white : Colors.blue,
          ),
        ),
        title: Text(
          nom,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
        subtitle: Text('$spec • $ville'),
        trailing: selected
            ? const Icon(Icons.check_circle, color: Colors.blue)
            : null,
        onTap: () => setState(() => selectedMedecinId = id),
      ),
    );
  }

  Widget _buildAvisFormCard() {
    if (!AuthService.isPatient) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Laisser un avis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                AuthService.isLoggedIn
                    ? 'Seuls les comptes patient peuvent publier un avis sur un médecin.'
                    : 'Connectez-vous avec un compte patient pour publier un avis.',
                style: const TextStyle(color: Colors.black54),
              ),
              if (!AuthService.isLoggedIn) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Connexion patient'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laisser un avis sur un médecin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Connecté en tant que ${AuthService.displayName}',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: medecinSearchController,
              decoration: InputDecoration(
                labelText: 'Rechercher un médecin',
                hintText: 'Nom, spécialité ou ville...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: medecinSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          medecinSearchController.clear();
                          setState(() => medecinSearchQuery = '');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              value: pickerSpecialiteId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Spécialité',
                prefixIcon: Icon(Icons.category),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Toutes les spécialités'),
                ),
                ...specialites.map((s) {
                  final id = int.tryParse(
                        s['id_specialite']?.toString() ?? '',
                      ) ??
                      0;
                  return DropdownMenuItem<int?>(
                    value: id,
                    child: Text(s['nom_specialite']?.toString() ?? ''),
                  );
                }),
              ],
              onChanged: (v) => setState(() => pickerSpecialiteId = v),
            ),
            const SizedBox(height: 8),
            Text(
              '${filteredMedecinsForPicker.length} médecin(s) — sélectionnez un médecin',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (filteredMedecinsForPicker.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('Aucun médecin trouvé.')),
              )
            else
              ...filteredMedecinsForPicker.take(8).map(_medecinPickerTile),
            if (filteredMedecinsForPicker.length > 8)
              TextButton(
                onPressed: () => _showAllMedecinsPicker(),
                child: Text(
                  'Voir les ${filteredMedecinsForPicker.length} médecins',
                ),
              ),
            const SizedBox(height: 14),
            TextField(
              controller: avisController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Votre avis',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
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
                onPressed: submitting ? null : _submit,
                child: submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Publier l\'avis'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAllMedecinsPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            const Text(
              'Choisir un médecin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: medecinSearchController,
                decoration: const InputDecoration(
                  labelText: 'Rechercher',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredMedecinsForPicker.length,
                itemBuilder: (_, i) =>
                    _medecinPickerTile(filteredMedecinsForPicker[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget avisCard(Map<String, dynamic> a) {
    final medecin =
        'Dr. ${a['medecin_prenom']} ${a['medecin_nom']}';
    final specialite = a['nom_specialite']?.toString() ?? '';
    final ville = a['medecin_ville']?.toString() ?? '';
    final auteur = a['patient_label']?.toString() ?? 'Patient';
    final date = a['date_avis']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rate_review, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    medecin,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('⭐ ${a['note']}'),
              ],
            ),
            Text(
              '$specialite • $ville',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              auteur,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            if (date.isNotEmpty)
              Text(
                date.length >= 10 ? date.substring(0, 10) : date,
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            const SizedBox(height: 6),
            Text(a['commentaire']?.toString() ?? ''),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Avis"),
        actions: [
          IconButton(
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvisFormCard(),
                    const SizedBox(height: 20),
                    const Text(
                      'Tous les avis',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: filterMedecinId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Filtrer par médecin',
                        prefixIcon: Icon(Icons.filter_list),
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Tous les médecins'),
                        ),
                        ...medecins.map((m) {
                          final id = int.tryParse(
                                m['id_medecin']?.toString() ?? '',
                              ) ??
                              0;
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text(
                              m['nom_complet'] ??
                                  'Dr. ${m['prenom']} ${m['nom']}',
                            ),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => filterMedecinId = v),
                    ),
                    const SizedBox(height: 14),
                    if (filteredAvis.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('Aucun avis pour le moment.'),
                        ),
                      )
                    else
                      ...filteredAvis.map(avisCard),
                  ],
                ),
              ),
            ),
    );
  }
}