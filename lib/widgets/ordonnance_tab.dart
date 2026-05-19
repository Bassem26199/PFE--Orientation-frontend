import 'package:flutter/material.dart';
import '../data/medicaments_data.dart';
import '../services/auth_service.dart';
import '../services/ordonnance_pdf_service.dart';
import '../services/ordonnance_service.dart';

class OrdonnanceTab extends StatefulWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onOrdonnanceSaved;

  const OrdonnanceTab({
    super.key,
    required this.patient,
    required this.onOrdonnanceSaved,
  });

  @override
  State<OrdonnanceTab> createState() => _OrdonnanceTabState();
}

class _OrdonnanceTabState extends State<OrdonnanceTab> {
  final _searchController = TextEditingController();
  final _dosageController = TextEditingController();
  final _dureeController = TextEditingController();
  final _conseilController = TextEditingController();

  Map<String, dynamic>? _proposal;
  List<Map<String, dynamic>> _selected = [];
  List<Map<String, dynamic>> _historique = [];
  List<String> _filteredMeds = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  int? get _idPatient {
    final id = widget.patient['id_patient'];
    if (id is int) return id;
    return int.tryParse('$id');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dosageController.dispose();
    _dureeController.dispose();
    _conseilController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _idPatient;
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Identifiant patient manquant';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        OrdonnanceService.generer(id),
        OrdonnanceService.listByPatient(id),
      ]);

      final proposal = results[0] as Map<String, dynamic>;
      final historique = results[1] as List<Map<String, dynamic>>;

      final suggestions = (proposal['suggestions'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        _proposal = proposal;
        _selected = List.from(suggestions);
        _historique = historique;
        _dosageController.text = proposal['dosage_suggere']?.toString() ?? '';
        _dureeController.text = proposal['duree_suggeree']?.toString() ?? '';
        _conseilController.text = proposal['conseils_suggerees']?.toString() ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _valider() async {
    final id = _idPatient;
    if (id == null || _selected.isEmpty) return;

    setState(() => _saving = true);

    try {
      final saved = await OrdonnanceService.valider(
        idPatient: id,
        idOrientation: _proposal?['id_orientation'] as int?,
        elements: _selected,
        dosageGlobal: _dosageController.text.trim(),
        duree: _dureeController.text.trim(),
        conseils: _conseilController.text.trim(),
        niveauUrgence: _proposal?['niveau_urgence']?.toString(),
        symptomesSource: (_proposal?['symptomes'] as List?)?.join(', '),
      );

      final medecin = _proposal?['medecin'] as Map? ?? {};
      final specialite = medecin['specialite']?.toString();

      await OrdonnancePdfService.printOrdonnance(
        patientName: '${widget.patient['prenom']} ${widget.patient['nom']}',
        medecinName:
            'Dr. ${medecin['prenom'] ?? AuthService.currentUser?['prenom']} ${medecin['nom'] ?? AuthService.currentUser?['nom']}',
        specialite: specialite,
        elements: _selected,
        dosage: _dosageController.text.trim(),
        duree: _dureeController.text.trim(),
        conseils: _conseilController.text.trim(),
        niveauUrgence: _proposal?['niveau_urgence']?.toString(),
        symptomes: (_proposal?['symptomes'] as List?)?.map((e) => e.toString()).toList(),
      );

      if (!mounted) return;

      widget.patient['ordonnances'] ??= <Map<String, dynamic>>[];
      (widget.patient['ordonnances'] as List).insert(0, saved);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ordonnance enregistrée et disponible pour le patient.'),
        ),
      );

      widget.onOrdonnanceSaved();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleItem(Map<String, dynamic> item, bool selected) {
    setState(() {
      if (selected) {
        if (!_selected.any((e) => e['libelle'] == item['libelle'])) {
          _selected.add(Map<String, dynamic>.from(item));
        }
      } else {
        _selected.removeWhere((e) => e['libelle'] == item['libelle']);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    final urgence = _proposal?['niveau_urgence']?.toString() ?? '';
    final symptomes = (_proposal?['symptomes'] as List?)?.join(', ') ?? '';
    final specialite = _proposal?['specialite']?.toString();
    final source = _proposal?['source']?.toString() ?? 'rules';
    final analyseIa = _proposal?['analyse_ia']?.toString();
    final geminiMessage = _proposal?['gemini_message']?.toString();
    final isGemini = source == 'gemini';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade400],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white, size: 22),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Génération intelligente',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Basée sur les symptômes, l\'orientation et le profil patient.',
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
              ),
              if (symptomes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Symptômes : $symptomes',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
              if (specialite != null) ...[
                const SizedBox(height: 4),
                Text('Spécialité : $specialite',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isGemini
                      ? 'Source : Gemini IA'
                      : 'Source : moteur de regles',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              if (!isGemini &&
                  geminiMessage != null &&
                  geminiMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  geminiMessage,
                  style: TextStyle(
                    color: Colors.amber.shade100,
                    fontSize: 11,
                  ),
                ),
              ],
              if (analyseIa != null && analyseIa.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  analyseIa,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (urgence == 'URGENT') ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Urgence $urgence — vérification médicale prioritaire',
                    style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Text('Proposition (cochez / décochez)',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._buildSuggestionTiles(),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Ajouter un médicament',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) {
            setState(() {
              if (value.trim().isEmpty) {
                _filteredMeds = [];
              } else {
                _filteredMeds = medicamentsData
                    .where((m) => m.toLowerCase().contains(value.toLowerCase()))
                    .toList();
                if (_filteredMeds.isEmpty) _filteredMeds = [value.trim()];
              }
            });
          },
        ),
        ..._filteredMeds.map(
          (m) => ListTile(
            leading: const Icon(Icons.add_circle, color: Colors.green),
            title: Text(m),
            onTap: () {
              setState(() {
                final item = {
                  'libelle': m,
                  'type': 'MEDICAMENT',
                  'posologie': '',
                  'source': 'Ajout manuel',
                };
                if (!_selected.any((e) => e['libelle'] == m)) {
                  _selected.add(item);
                }
                _searchController.clear();
                _filteredMeds = [];
              });
            },
          ),
        ),
        const Divider(height: 28),
        TextField(
          controller: _dosageController,
          decoration: const InputDecoration(
            labelText: 'Posologie générale',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _dureeController,
          decoration: const InputDecoration(
            labelText: 'Durée',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _conseilController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Conseils complémentaires',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _saving || _selected.isEmpty ? null : _valider,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print),
            label: Text(_saving ? 'Enregistrement...' : 'Valider, enregistrer & imprimer'),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Historique validé',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (_historique.isEmpty)
          const Text('Aucune ordonnance enregistrée', style: TextStyle(color: Colors.black54))
        else
          ..._historique.map(_historiqueCard),
      ],
    );
  }

  List<Widget> _buildSuggestionTiles() {
    final all = (( _proposal?['suggestions'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final extras = _selected
        .where((s) => !all.any((a) => a['libelle'] == s['libelle']))
        .toList();

    return [...all, ...extras].map((item) {
      final checked = _selected.any((e) => e['libelle'] == item['libelle']);
      final isMed = (item['type'] ?? 'MEDICAMENT') != 'CONSEIL';
      final priorite = item['priorite'] ?? 0;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: CheckboxListTile(
          value: checked,
          onChanged: (v) => _toggleItem(item, v == true),
          title: Text(item['libelle'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((item['posologie'] ?? '').toString().isNotEmpty)
                Text(item['posologie'].toString()),
              Text(
                '${isMed ? 'Médicament' : 'Conseil'} • ${item['source'] ?? ''}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          secondary: priorite >= 10
              ? Chip(
                  label: Text('$priorite', style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.orange.shade100,
                  padding: EdgeInsets.zero,
                )
              : null,
        ),
      );
    }).toList();
  }

  Widget _historiqueCard(Map<String, dynamic> o) {
    final elements = o['elements'] as List? ?? [];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ordonnance du ${o['date']?.toString().substring(0, 16) ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...elements.map((e) {
              final m = e as Map;
              final pos = '${m['posologie'] ?? ''}';
              return Text(
                '- ${m['libelle']}${pos.isNotEmpty ? ' - $pos' : ''}',
              );
            }),
          ],
        ),
      ),
    );
  }
}
