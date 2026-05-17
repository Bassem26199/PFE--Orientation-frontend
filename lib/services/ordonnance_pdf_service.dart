import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrdonnancePdfService {
  static const PdfColor _primary = PdfColor.fromInt(0xFF1565C0);
  static const PdfColor _primaryLight = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _accent = PdfColor.fromInt(0xFF00897B);
  static const PdfColor _textMuted = PdfColor.fromInt(0xFF546E7A);

  static Future<void> printOrdonnance({
    required String patientName,
    required String medecinName,
    String? specialite,
    required List<dynamic> elements,
    required String dosage,
    required String duree,
    required String conseils,
    String? niveauUrgence,
    List<String>? symptomes,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateTime.now().toString().substring(0, 10);
    final medicaments = elements
        .where((e) => e is Map && (e['type'] ?? 'MEDICAMENT') != 'CONSEIL')
        .toList();
    final conseilsList = elements
        .where((e) => e is Map && (e['type'] ?? '') == 'CONSEIL')
        .toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _header(medecinName, specialite, dateStr),
              pw.SizedBox(height: 20),
              _infoBoxes(patientName, niveauUrgence, symptomes),
              pw.SizedBox(height: 18),
              pw.Text(
                'PRESCRIPTION',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                  letterSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 10),
              if (medicaments.isNotEmpty) _medicamentsTable(medicaments),
              if (conseilsList.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                pw.Text(
                  'Conseils & recommandations',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                    color: _accent,
                  ),
                ),
                pw.SizedBox(height: 6),
                ...conseilsList.map((e) {
                  final m = e as Map;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('- ', style: const pw.TextStyle(color: _accent)),
                        pw.Expanded(
                          child: pw.Text(
                            '${m['libelle']}${(m['posologie'] ?? '').toString().isNotEmpty ? ' - ${m['posologie']}' : ''}',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (dosage.isNotEmpty || duree.isNotEmpty || conseils.isNotEmpty) ...[
                pw.SizedBox(height: 14),
                _extraBlock(dosage, duree, conseils),
              ],
              pw.Spacer(),
              _footer(),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static pw.Widget _header(String medecinName, String? specialite, String date) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _primary,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 44,
            height: 44,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Center(
              child: pw.Text(
                'OM',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: _primary,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ORDONNANCE MÉDICALE',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  medecinName,
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                ),
                if (specialite != null && specialite.isNotEmpty)
                  pw.Text(
                    specialite,
                    style: pw.TextStyle(
                      color: PdfColor.fromInt(0xBBDEFB),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Date',
                style: pw.TextStyle(color: PdfColor.fromInt(0xBBDEFB), fontSize: 9),
              ),
              pw.Text(
                date,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoBoxes(
    String patientName,
    String? urgence,
    List<String>? symptomes,
  ) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: _primaryLight,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColor.fromInt(0xFF90CAF9), width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PATIENT', style: _labelStyle()),
                pw.SizedBox(height: 4),
                pw.Text(
                  patientName,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                if (symptomes != null && symptomes.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text('Symptômes : ${symptomes.join(', ')}', style: _smallStyle()),
                ],
              ],
            ),
          ),
        ),
        if (urgence != null && urgence.isNotEmpty) ...[
          pw.SizedBox(width: 10),
          pw.Container(
            width: 100,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: urgence == 'URGENT'
                  ? const PdfColor.fromInt(0xFFFFEBEE)
                  : const PdfColor.fromInt(0xFFF3E5F5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text('URGENCE', style: _labelStyle()),
                pw.SizedBox(height: 4),
                pw.Text(
                  urgence,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: urgence == 'URGENT'
                        ? const PdfColor.fromInt(0xFFC62828)
                        : _textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static pw.Widget _medicamentsTable(List<dynamic> medicaments) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColor.fromInt(0xFFE0E0E0), width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _primaryLight),
          children: [
            _tableCell('Médicament / Traitement', bold: true),
            _tableCell('Posologie', bold: true),
          ],
        ),
        ...medicaments.map((e) {
          final m = e as Map;
          return pw.TableRow(
            children: [
              _tableCell('${m['libelle'] ?? ''}'),
              _tableCell('${m['posologie'] ?? 'Selon avis médical'}'),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _extraBlock(String dosage, String duree, String conseils) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromInt(0xFFE0E0E0)),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (dosage.isNotEmpty)
            pw.Text('Posologie générale : $dosage', style: const pw.TextStyle(fontSize: 9)),
          if (duree.isNotEmpty)
            pw.Text('Durée : $duree', style: const pw.TextStyle(fontSize: 9)),
          if (conseils.isNotEmpty)
            pw.Text('Notes : $conseils', style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  static pw.Widget _footer() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColor.fromInt(0xFFE0E0E0)),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Document généré par Orientation Médicale',
                  style: _smallStyle(),
                ),
                pw.Text(
                  'À utiliser conformément à la réglementation en vigueur.',
                  style: _smallStyle(),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Signature et cachet du médecin', style: _smallStyle()),
                pw.SizedBox(height: 28),
                pw.Container(
                  width: 140,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _textMuted, width: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.TextStyle _labelStyle() => pw.TextStyle(
        fontSize: 8,
        color: _textMuted,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.5,
      );

  static pw.TextStyle _smallStyle() => const pw.TextStyle(fontSize: 8, color: _textMuted);
}
