import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfService {
  static Future<File?> generateAndSave({
    required String tenantName,
    required String propertyAddress,
    required double rentAmount,
    required double chargesAmount,
    required double totalAmount,
    required String month,
    required String paymentDate,
    required String paymentMethod,
    required String reference,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'QUITTANCE DE LOYER',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 30),
                pw.Text('Date : $paymentDate'),
                pw.Text('Référence : $reference'),
                pw.SizedBox(height: 20),
                pw.Text('Locataire : $tenantName'),
                pw.Text('Adresse du bien : $propertyAddress'),
                pw.SizedBox(height: 20),
                pw.Text('Quittance pour le mois de : $month'),
                pw.SizedBox(height: 20),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Loyer :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${rentAmount.toStringAsFixed(2)} €'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Charges :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${chargesAmount.toStringAsFixed(2)} €'),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total :', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      '${totalAmount.toStringAsFixed(2)} €',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Text('Règlement effectué par : $paymentMethod'),
                pw.SizedBox(height: 50),
                pw.Text('Signature du bailleur : _________________'),
              ],
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'quittance_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      debugPrint('✅ PDF généré : $filePath');
      debugPrint('📏 Taille : ${await file.length()} bytes');
      return file;
    } catch (e) {
      debugPrint('❌ Erreur génération PDF : $e');
      return null;
    }
  }

  static Future<bool> sharePDF(File file) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Quittance de loyer',
      );
      return true;
    } catch (e) {
      debugPrint('Erreur partage : $e');
      return false;
    }
  }

  static Future<void> openPDF(File file) async {
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      debugPrint("Ouverture échouée : ${result.message}");
    }
  }

  static Future<void> deletePDF(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('Fichier supprimé : ${file.path}');
      }
    } catch (e) {
      debugPrint('Erreur suppression : $e');
    }
  }
}