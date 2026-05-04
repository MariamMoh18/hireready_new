import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/pdf_service.dart';

class PdfPreviewPage extends StatelessWidget {
  final PdfService pdfService;
  final int score;
  final int voiceScore;
  final int facialScore;
  final int contentScore;
  final List<String> strengths;
  final List<String> improvements;
  final List<Map<String, String>> qaList;

  const PdfPreviewPage({
    super.key,
    required this.pdfService,
    required this.score,
    required this.voiceScore,
    required this.facialScore,
    required this.contentScore,
    required this.strengths,
    required this.improvements,
    required this.qaList,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Preview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: PdfPreview(
        build: (format) => pdfService.generateHistoryReport(
          format: format,
          score: score,
          voiceScore: voiceScore,
          facialScore: facialScore,
          contentScore: contentScore,
          strengths: strengths,
          improvements: improvements,
          qaList: qaList,
        ),
        // functionality: print, save/share are default
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
