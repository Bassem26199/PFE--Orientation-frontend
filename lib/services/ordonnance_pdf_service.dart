import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OrdonnancePdfService {
  static Future<void> printOrdonnance({
    required String patientName,
    required String medecinName,
    required List<dynamic> elements,
    required String dosage,
    required String duree,
    required String conseils,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Ordonnance médicale",
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text("Médecin : $medecinName"),
              pw.Text("Patient : $patientName"),
              pw.Text("Date : ${DateTime.now().toString().substring(0, 10)}"),
              pw.Divider(),
              pw.Text("Traitement :", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              ...elements.map((e) => pw.Text("- $e")),
              pw.SizedBox(height: 15),
              if (dosage.isNotEmpty) pw.Text("Posologie : $dosage"),
              if (duree.isNotEmpty) pw.Text("Durée : $duree"),
              if (conseils.isNotEmpty) pw.Text("Conseils : $conseils"),
              pw.Spacer(),
              pw.Text("Signature du médecin"),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}