import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  Future<Uint8List> generateHistoryReport({
    required PdfPageFormat format,
    required int score,
    required int voiceScore,
    required int facialScore,
    required int contentScore,
    required List<String> strengths,
    required List<String> improvements,
    required List<Map<String, String>> qaList,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: fontBold,
        ),
        build: (context) => [
          _buildHeader(score),
          pw.SizedBox(height: 20),
          _buildMetricsRow(voiceScore, facialScore, contentScore),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Key Strengths', PdfColors.green),
          ...strengths.map((s) => _buildBulletPoint(s)),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Improvement Suggestions', PdfColors.blue),
          ...improvements.map((s) => _buildBulletPoint(s)),
          pw.SizedBox(height: 20),
          _buildSectionTitle('Response Evaluation', PdfColors.black),
          ...qaList.map((qa) => _buildQAItem(qa)),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(int score) {
    return pw.Column(
      children: [
        pw.Text(
          'Interview Session Report',
          style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueAccent),
        ),
        pw.SizedBox(height: 10),
        pw.Stack(
          alignment: pw.Alignment.center,
          children: [
            pw.Container(
              width: 100,
              height: 100,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColors.blue100,
              ),
            ),
            pw.Container(
              width: 80,
              height: 80,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                color: PdfColors.white,
              ),
              child: pw.Center(
                child: pw.Text(
                  '$score',
                  style: pw.TextStyle(
                      fontSize: 32,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildMetricsRow(int voice, int facial, int content) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        _buildMetricItem(voice, 'Voice & Tone'),
        _buildMetricItem(facial, 'Facial Expression'),
        _buildMetricItem(content, 'Content Quality'),
      ],
    );
  }

  pw.Widget _buildMetricItem(int score, String label) {
    return pw.Column(
      children: [
        pw.Container(
          width: 60,
          height: 60,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(color: PdfColors.blue, width: 2),
          ),
          child: pw.Center(
            child: pw.Text('$score%',
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title, PdfColor color) {
    PdfColor bgColor = PdfColors.grey200;
    if (color == PdfColors.green) bgColor = PdfColors.green100;
    if (color == PdfColors.blue) bgColor = PdfColors.blue100;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(color: color, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5, left: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontSize: 12)),
          pw.Expanded(child: pw.Text(text, style: pw.TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  pw.Widget _buildQAItem(Map<String, String> qa) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Q: ${qa['question']}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.SizedBox(height: 4),
          pw.Text('A: ${qa['answer']}', style: pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}
