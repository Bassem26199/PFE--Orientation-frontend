import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../widgets/address_map_picker.dart';
import 'login_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int selectedIndex = 0;
  bool isLoading = true;

  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> medecins = [];
  List<Map<String, dynamic>> specialites = [];
  List<Map<String, dynamic>> patients = [];

  final _formKey = GlobalKey<FormState>();
  final _mapKey = GlobalKey<AddressMapPickerState>();
  final nom = TextEditingController();
  final prenom = TextEditingController();
  final email = TextEditingController();
  final telephone = TextEditingController();
  final telPro = TextEditingController();
  final adresse = TextEditingController();
  final ville = TextEditingController();
  final disponibilite = TextEditingController(
    text: 'Lundi - Vendredi, 09:00 - 17:00',
  );
  String genre = 'M';
  int? idSpecialite;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    setState(() => isLoading = true);
    try {
      final results = await Future.wait([
        AdminService.fetchDashboard(),
        AdminService.fetchMedecins(),
        AdminService.fetchSpecialites(),
        AdminService.fetchPatients(),
      ]);
      if (!mounted) return;
      setState(() {
        stats = results[0] as Map<String, dynamic>;
        medecins = results[1] as List<Map<String, dynamic>>;
        specialites = results[2] as List<Map<String, dynamic>>;
        patients = results[3] as List<Map<String, dynamic>>;
        if (idSpecialite == null && specialites.isNotEmpty) {
          final raw = specialites.first['id_specialite'];
          idSpecialite = raw is int ? raw : int.tryParse('$raw');
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _clearMedecinForm() {
    nom.clear();
    prenom.clear();
    email.clear();
    telephone.clear();
    telPro.clear();
    adresse.clear();
    ville.clear();
    disponibilite.text = 'Lundi - Vendredi, 09:00 - 17:00';
    genre = 'M';
    _mapKey.currentState?.reset();
    _formKey.currentState?.reset();
    setState(() {});
  }

  Future<void> _createMedecin() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = _mapKey.currentState?.latitude;
    final lng = _mapKey.currentState?.longitude;
    if (lat == null || lng == null || adresse.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectionnez le cabinet sur la carte')),
      );
      return;
    }

    if (idSpecialite == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une specialite')),
      );
      return;
    }

    setState(() => saving = true);
    try {
      final result = await AdminService.createMedecin({
        'nom': nom.text.trim(),
        'prenom': prenom.text.trim(),
        'email': email.text.trim(),
        'telephone': telephone.text.trim(),
        'genre': genre,
        'id_specialite': idSpecialite,
        'adresse_cabinet': adresse.text.trim(),
        'ville': ville.text.trim(),
        'latitude': lat,
        'longitude': lng,
        'telephone_professionnel': telPro.text.trim(),
        'disponibilite': disponibilite.text.trim(),
      });

      if (!mounted) return;
      _clearMedecinForm();
      await loadData();
      setState(() => selectedIndex = 1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Medecin cree')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dashboardPage() {
    final reclamations = stats['reclamations'] is List
        ? (stats['reclamations'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : <Map<String, dynamic>>[];
    final reclamationsCount = stats['reclamations_en_attente'] ?? reclamations.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Bienvenue, ${AuthService.displayName}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(children: [
          _statCard('Medecins', '${stats['medecins'] ?? 0}', Icons.medical_services, Colors.blue),
          const SizedBox(width: 10),
          _statCard('Patients', '${stats['patients'] ?? 0}', Icons.people, Colors.teal),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _statCard('Secretaires', '${stats['secretaires'] ?? 0}', Icons.support_agent, Colors.orange),
          const SizedBox(width: 10),
          _statCard('RDV attente', '${stats['demandes_en_attente'] ?? 0}', Icons.pending_actions, Colors.red),
        ]),
        if (reclamationsCount > 0) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Icons.report_problem, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'Reclamations en attente ($reclamationsCount)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...reclamations.map(_reclamationCard),
        ],
      ],
    );
  }

  Widget _reclamationCard(Map<String, dynamic> r) {
    final patient = '${r['patient_prenom'] ?? ''} ${r['patient_nom'] ?? ''}'.trim();
    final secretaire = '${r['secretaire_prenom'] ?? ''} ${r['secretaire_nom'] ?? ''}'.trim();
    final medecin = 'Dr. ${r['medecin_prenom'] ?? ''} ${r['medecin_nom'] ?? ''}'.trim();
    final idRec = _idFrom(r['id_reclamation']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(patient, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Cabinet : $medecin', style: const TextStyle(color: Colors.black54)),
            Text('Par : $secretaire', style: const TextStyle(color: Colors.black54)),
            Text('Date : ${r['date_reclamation'] ?? '-'}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${r['message'] ?? ''}'),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _traiterReclamation(idRec),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Marquer traitee'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _traiterReclamation(int id) async {
    try {
      final result = await AdminService.traiterReclamation(id);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Reclamation traitee')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  int _idFrom(dynamic v) => v is int ? v : int.parse('$v');

  Widget _patientsListPage() {
    if (patients.isEmpty) {
      return const Center(child: Text('Aucun patient enregistre'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: patients.length,
      itemBuilder: (_, i) {
        final p = patients[i];
        final actif = p['actif'] == 1 || p['actif'] == true;
        final id = _idFrom(p['id_patient']);
        final name = '${p['prenom']} ${p['nom']}';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: actif ? Colors.teal.shade50 : Colors.grey.shade200,
              child: Icon(Icons.person, color: actif ? Colors.teal : Colors.grey),
            ),
            title: Text(name),
            subtitle: Text(
              '${p['email']}\n${p['telephone'] ?? ''}${actif ? '' : '\n(Banni)'}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (actif)
                  IconButton(
                    icon: const Icon(Icons.block, color: Colors.orange),
                    tooltip: 'Bannir',
                    onPressed: () => _confirmBanPatient(p),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    tooltip: 'Reactiver',
                    onPressed: () => _unbanPatient(id),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Supprimer',
                  onPressed: () => _confirmDeletePatient(p),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmBanPatient(Map<String, dynamic> p) async {
    final id = _idFrom(p['id_patient']);
    final name = '${p['prenom']} ${p['nom']}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bannir le patient ?'),
        content: Text(
          'Le compte de $name sera desactive.\n'
          'Il ne pourra plus se connecter.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Bannir'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      final result = await AdminService.banPatient(id);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Patient banni')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _unbanPatient(int id) async {
    try {
      final result = await AdminService.unbanPatient(id);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Patient reactive')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _confirmDeletePatient(Map<String, dynamic> p) async {
    final id = _idFrom(p['id_patient']);
    final name = '${p['prenom']} ${p['nom']}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le patient ?'),
        content: Text(
          'Confirmer la suppression définitive de $name ?\n\n'
          'Le compte, les rendez-vous, orientations, ordonnances, avis '
          'et paiements associés seront supprimés. Cette action est irréversible.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      final result = await AdminService.deletePatient(id);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Operation effectuee')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _medecinsListPage() {
    if (medecins.isEmpty) {
      return const Center(child: Text('Aucun medecin enregistre'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medecins.length,
      itemBuilder: (_, i) {
        final m = medecins[i];
        final actif = m['actif'] == 1 || m['actif'] == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: actif ? Colors.blue.shade50 : Colors.grey.shade200,
              child: Icon(
                Icons.medical_services,
                color: actif ? Colors.blue : Colors.grey,
              ),
            ),
            title: Text('Dr. ${m['prenom']} ${m['nom']}'),
            subtitle: Text(
              '${m['nom_specialite']}\n${m['ville']} - ${m['email']}${actif ? '' : '\n(Inactif)'}',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditMedecinDialog(m),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteMedecin(m),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteMedecin(Map<String, dynamic> m) async {
    final id = _idFrom(m['id_medecin']);
    final name = 'Dr. ${m['prenom']} ${m['nom']}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le medecin ?'),
        content: Text(
          'Confirmer la suppression de $name ?\n'
          'S\'il a des rendez-vous ou secretaires, le compte sera desactive.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      final result = await AdminService.deleteMedecin(id);
      await loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? 'Suppression effectuee')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _showEditMedecinDialog(Map<String, dynamic> m) {
    final editFormKey = GlobalKey<FormState>();
    final editMapKey = GlobalKey<AddressMapPickerState>();

    final eNom = TextEditingController(text: '${m['nom']}');
    final ePrenom = TextEditingController(text: '${m['prenom']}');
    final eEmail = TextEditingController(text: '${m['email']}');
    final eTel = TextEditingController(text: '${m['telephone'] ?? ''}');
    final eTelPro = TextEditingController(text: '${m['telephone_professionnel'] ?? ''}');
    final eAdresse = TextEditingController(text: '${m['adresse_cabinet'] ?? ''}');
    final eVille = TextEditingController(text: '${m['ville'] ?? ''}');
    final eDispo = TextEditingController(text: '${m['disponibilite'] ?? ''}');
    String eGenre = '${m['genre'] ?? 'M'}';
    int? eSpecialite = _idFrom(m['id_specialite']);
    bool eActif = m['actif'] == 1 || m['actif'] == true;
    var savingEdit = false;

    final lat = double.tryParse('${m['latitude']}');
    final lng = double.tryParse('${m['longitude']}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text('Modifier Dr. ${m['prenom']} ${m['nom']}'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: editFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: eNom,
                        decoration: const InputDecoration(labelText: 'Nom *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: ePrenom,
                        decoration: const InputDecoration(labelText: 'Prenom *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: eEmail,
                        decoration: const InputDecoration(labelText: 'Email *'),
                        validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: eTel,
                        decoration: const InputDecoration(labelText: 'Telephone'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: eGenre,
                        decoration: const InputDecoration(labelText: 'Genre'),
                        items: const [
                          DropdownMenuItem(value: 'M', child: Text('Homme')),
                          DropdownMenuItem(value: 'F', child: Text('Femme')),
                        ],
                        onChanged: (v) => setDialogState(() => eGenre = v!),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: eSpecialite,
                        decoration: const InputDecoration(labelText: 'Specialite *'),
                        items: specialites.map((s) {
                          final id = _idFrom(s['id_specialite']);
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text('${s['nom_specialite']}'),
                          );
                        }).toList(),
                        onChanged: (v) => setDialogState(() => eSpecialite = v),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: eTelPro,
                        decoration: const InputDecoration(labelText: 'Tel. professionnel *'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: eVille,
                        decoration: const InputDecoration(labelText: 'Ville *'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: eDispo,
                        decoration: const InputDecoration(labelText: 'Disponibilite'),
                      ),
                      SwitchListTile(
                        value: eActif,
                        title: const Text('Compte actif'),
                        onChanged: (v) => setDialogState(() => eActif = v),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: AddressMapPicker(
                          key: editMapKey,
                          addressController: eAdresse,
                          initialLatitude: lat,
                          initialLongitude: lng,
                          onAddressUpdated: () => setDialogState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: eAdresse,
                        readOnly: true,
                        enabled: false,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Adresse cabinet'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: savingEdit ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: savingEdit
                    ? null
                    : () async {
                        if (!editFormKey.currentState!.validate()) return;
                        if (eSpecialite == null) return;

                        final eLat = editMapKey.currentState?.latitude ?? lat;
                        final eLng = editMapKey.currentState?.longitude ?? lng;
                        if (eLat == null || eLng == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Position carte requise')),
                          );
                          return;
                        }

                        setDialogState(() => savingEdit = true);
                        try {
                          final result = await AdminService.updateMedecin(
                            _idFrom(m['id_medecin']),
                            {
                              'nom': eNom.text.trim(),
                              'prenom': ePrenom.text.trim(),
                              'email': eEmail.text.trim(),
                              'telephone': eTel.text.trim(),
                              'genre': eGenre,
                              'actif': eActif,
                              'id_specialite': eSpecialite,
                              'adresse_cabinet': eAdresse.text.trim(),
                              'ville': eVille.text.trim(),
                              'latitude': eLat,
                              'longitude': eLng,
                              'telephone_professionnel': eTelPro.text.trim(),
                              'disponibilite': eDispo.text.trim(),
                            },
                          );
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          await loadData();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result['message']?.toString() ?? 'Medecin mis a jour',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        } finally {
                          setDialogState(() => savingEdit = false);
                        }
                      },
                child: savingEdit
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _createMedecinPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Creer un compte medecin',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nom,
              decoration: const InputDecoration(labelText: 'Nom *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: prenom,
              decoration: const InputDecoration(labelText: 'Prenom *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *', border: OutlineInputBorder()),
              validator: (v) => v == null || !v.contains('@') ? 'Email invalide' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: telephone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telephone', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: genre,
              decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('Homme')),
                DropdownMenuItem(value: 'F', child: Text('Femme')),
              ],
              onChanged: (v) => setState(() => genre = v!),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<int>(
              value: idSpecialite,
              decoration: const InputDecoration(labelText: 'Specialite *', border: OutlineInputBorder()),
              items: specialites
                  .map(
                    (s) {
                      final id = s['id_specialite'];
                      final idInt = id is int ? id : int.parse('$id');
                      return DropdownMenuItem<int>(
                        value: idInt,
                        child: Text('${s['nom_specialite']}'),
                      );
                    },
                  )
                  .toList(),
              onChanged: (v) => setState(() => idSpecialite = v),
              validator: (v) => v == null ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: telPro,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Tel. professionnel *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: ville,
              decoration: const InputDecoration(labelText: 'Ville *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: disponibilite,
              decoration: const InputDecoration(labelText: 'Disponibilite', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Localisation du cabinet', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 260,
              child: AddressMapPicker(
                key: _mapKey,
                addressController: adresse,
                onAddressUpdated: () => setState(() {}),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: adresse,
              readOnly: true,
              enabled: false,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Adresse cabinet *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Carte requise' : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: saving ? null : _createMedecin,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.person_add),
              label: Text(saving ? 'Creation...' : 'Creer et envoyer les identifiants'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          IconButton(onPressed: loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(AuthService.displayName),
              accountEmail: Text(AuthService.currentUser?['email'] ?? ''),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Tableau de bord'),
              selected: selectedIndex == 0,
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedIndex = 0);
              },
            ),
            ListTile(
              leading: const Icon(Icons.medical_services),
              title: const Text('Medecins'),
              selected: selectedIndex == 1,
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedIndex = 1);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Creer medecin'),
              selected: selectedIndex == 2,
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedIndex = 2);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Patients'),
              selected: selectedIndex == 3,
              onTap: () {
                Navigator.pop(context);
                setState(() => selectedIndex = 3);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Deconnexion', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await AuthService.logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: selectedIndex,
              children: [
                _dashboardPage(),
                _medecinsListPage(),
                _createMedecinPage(),
                _patientsListPage(),
              ],
            ),
    );
  }

  @override
  void dispose() {
    nom.dispose();
    prenom.dispose();
    email.dispose();
    telephone.dispose();
    telPro.dispose();
    adresse.dispose();
    ville.dispose();
    disponibilite.dispose();
    super.dispose();
  }
}
