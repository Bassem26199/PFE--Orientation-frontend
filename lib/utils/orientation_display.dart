/// Helpers pour afficher les résultats d'orientation côté patient.
class OrientationDisplay {
  static String? maladieSuspectee(Map<dynamic, dynamic> data) {
    final direct = data['maladie_suspectee']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }

    final analyse = data['analyse_ia']?.toString() ?? '';
    final fromAnalyse = _extractFromAnalyse(analyse);
    if (fromAnalyse != null) {
      return fromAnalyse;
    }

    final remarque = data['remarque']?.toString() ?? '';
    return _extractFromAnalyse(remarque);
  }

  static String? _extractFromAnalyse(String text) {
    if (text.isEmpty) return null;

    final lower = text.toLowerCase();
    const prefix = 'maladie suspectee :';
    final idx = lower.indexOf(prefix);
    if (idx < 0) return null;

    var slice = text.substring(idx + prefix.length).trim();
    final pipe = slice.indexOf('|');
    if (pipe >= 0) {
      slice = slice.substring(0, pipe).trim();
    }

    return slice.isEmpty ? null : slice;
  }

  static String urgenceLabel(String? urgence) {
    switch (urgence?.toUpperCase()) {
      case 'URGENT':
        return 'Urgent';
      case 'MODERE':
      case 'MODÉRÉ':
        return 'Modéré';
      case 'FAIBLE':
        return 'Faible';
      default:
        return urgence ?? '-';
    }
  }
}
