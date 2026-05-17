import 'package:flutter/material.dart';
import '../services/ordonnance_service.dart';

class MesOrdonnancesScreen extends StatefulWidget {
  const MesOrdonnancesScreen({super.key});

  @override
  State<MesOrdonnancesScreen> createState() => _MesOrdonnancesScreenState();
}

class _MesOrdonnancesScreenState extends State<MesOrdonnancesScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _ordonnances = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await OrdonnanceService.mesOrdonnances();
      if (mounted) setState(() => _ordonnances = list);
    } catch (_) {
      if (mounted) setState(() => _ordonnances = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes ordonnances'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ordonnances.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        const Text(
                          'Aucune ordonnance',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Vos ordonnances validées par le médecin apparaîtront ici.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _ordonnances.length,
                    itemBuilder: (context, index) {
                      final o = _ordonnances[index];
                      return _ordonnanceCard(o);
                    },
                  ),
                ),
    );
  }

  Widget _ordonnanceCard(Map<String, dynamic> o) {
    final elements = o['elements'] as List? ?? [];
    final medecin =
        'Dr. ${o['medecin_prenom'] ?? ''} ${o['medecin_nom'] ?? ''}'.trim();
    final date = o['date']?.toString().substring(0, 16) ?? '';
    final urgence = o['niveau_urgence']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade700, Colors.teal.shade400],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medecin.isEmpty ? 'Ordonnance médicale' : medecin,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (o['nom_specialite'] != null)
                        Text(
                          '${o['nom_specialite']}',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (urgence != null && urgence.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: urgence == 'URGENT' ? Colors.red : Colors.white24,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      urgence,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date : $date', style: const TextStyle(color: Colors.black54)),
                if (o['symptomes_source'] != null &&
                    '${o['symptomes_source']}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Symptômes : ${o['symptomes_source']}',
                      style: const TextStyle(fontSize: 13)),
                ],
                const Divider(height: 20),
                const Text('Traitement',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...elements.map((e) {
                  final m = e as Map;
                  final pos = '${m['posologie'] ?? ''}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          (m['type'] ?? '') == 'CONSEIL'
                              ? Icons.lightbulb_outline
                              : Icons.medication,
                          size: 18,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${m['libelle']}${pos.isNotEmpty ? '\n$pos' : ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if ('${o['dosage_global'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Posologie : ${o['dosage_global']}'),
                ],
                if ('${o['duree'] ?? ''}'.isNotEmpty)
                  Text('Durée : ${o['duree']}'),
                if ('${o['conseils'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Conseils : ${o['conseils']}',
                      style: const TextStyle(color: Colors.black87)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
