import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/avis_service.dart';
import '../screens/login_screen.dart';

class DoctorReviewsSection extends StatefulWidget {
  final int idMedecin;
  final String? medecinLabel;
  final bool compact;
  final bool showAddForm;

  const DoctorReviewsSection({
    super.key,
    required this.idMedecin,
    this.medecinLabel,
    this.compact = false,
    this.showAddForm = true,
  });

  @override
  State<DoctorReviewsSection> createState() => _DoctorReviewsSectionState();
}

class _DoctorReviewsSectionState extends State<DoctorReviewsSection> {
  List<Map<String, dynamic>> avis = [];
  int nbAvis = 0;
  String? noteMoyenne;
  bool loading = true;
  bool expanded = false;
  bool submitting = false;

  final commentController = TextEditingController();
  int selectedNote = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await AvisService.fetchByMedecin(widget.idMedecin);
      final list = data['avis'];
      final stats = data['stats'];

      if (!mounted) return;
      setState(() {
        avis = list is List
            ? list.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : [];
        nbAvis = stats is Map
            ? int.tryParse(stats['nb_avis']?.toString() ?? '') ?? avis.length
            : avis.length;
        noteMoyenne = stats is Map ? stats['note_moyenne']?.toString() : null;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _submit() async {
    if (commentController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commentaire trop court (3 caractères min).')),
      );
      return;
    }

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
              'Seuls les patients connectés peuvent laisser un avis.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => submitting = true);
    final error = await AvisService.submit(
      idMedecin: widget.idMedecin,
      note: selectedNote,
      commentaire: commentController.text.trim(),
    );
    if (!mounted) return;

    setState(() => submitting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    commentController.clear();
    selectedNote = 5;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Avis enregistré. Merci !')),
    );
    await _load();
  }

  void _openFullReviews(BuildContext context) {
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
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: ListView(
            controller: controller,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DoctorReviewsSection(
                idMedecin: widget.idMedecin,
                medecinLabel: widget.medecinLabel,
                compact: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stars(int note, {double size = 18}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < note ? Icons.star : Icons.star_border,
          color: Colors.orange,
          size: size,
        );
      }),
    );
  }

  Widget _avisTile(Map<String, dynamic> a) {
    final note = int.tryParse(a['note']?.toString() ?? '') ?? 0;
    final auteur = a['patient_label']?.toString() ?? 'Patient';
    final texte = a['commentaire']?.toString() ?? '';
    final date = a['date_avis']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  auteur,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              _stars(note, size: 16),
            ],
          ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              date.length >= 10 ? date.substring(0, 10) : date,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
          const SizedBox(height: 6),
          Text(texte),
        ],
      ),
    );
  }

  Widget _addForm() {
    if (!widget.showAddForm) return const SizedBox.shrink();

    if (!AuthService.isPatient) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AuthService.isLoggedIn
                    ? 'Seuls les patient peuvent laisser un avis.'
                    : 'Connectez-vous en tant que patient pour laisser un avis.',
                style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
              ),
            ),
            if (!AuthService.isLoggedIn)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                  );
                },
                child: const Text('Connexion'),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Laisser un avis',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                onPressed: () => setState(() => selectedNote = value),
                icon: Icon(
                  value <= selectedNote ? Icons.star : Icons.star_border,
                  color: Colors.orange,
                ),
              );
            }),
          ),
          TextField(
            controller: commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Votre expérience avec ce médecin...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: submitting ? null : _submit,
              child: submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Publier'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final visible = widget.compact && !expanded
        ? avis.take(2).toList()
        : avis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rate_review, size: 20, color: Colors.blue),
            const SizedBox(width: 6),
            Text(
              nbAvis > 0
                  ? 'Avis ($nbAvis)${noteMoyenne != null ? ' • ⭐ $noteMoyenne' : ''}'
                  : 'Aucun avis pour le moment',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
        if (widget.medecinLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.medecinLabel!,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        if (avis.isEmpty)
          const Text(
            'Soyez le premier à partager votre expérience.',
            style: TextStyle(color: Colors.black54),
          )
        else
          ...visible.map(_avisTile),
        if (widget.compact && avis.length > 2)
          TextButton(
            onPressed: () => setState(() => expanded = !expanded),
            child: Text(
              expanded
                  ? 'Réduire'
                  : 'Voir les ${avis.length} avis',
            ),
          ),
        if ((!widget.compact || expanded) && widget.showAddForm) _addForm(),
        if (widget.compact && !expanded)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openFullReviews(context),
              icon: Icon(
                AuthService.isPatient ? Icons.edit_note : Icons.rate_review,
              ),
              label: Text(
                AuthService.isPatient
                    ? 'Voir / laisser un avis'
                    : 'Voir les avis',
              ),
            ),
          ),
      ],
    );
  }
}
