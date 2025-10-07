import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';
import 'package:institutation_payment_system/services/receipt_service.dart';
import 'package:institutation_payment_system/widgets/responsive_dialog.dart';

class ReceiptViewDialog extends StatefulWidget {
  final String title;
  final Future<Uint8List> Function() buildPdf;
  const ReceiptViewDialog({super.key, required this.title, required this.buildPdf});

  factory ReceiptViewDialog.forPayment({Key? key, required String instId, required Map<String, dynamic> payment, String title = 'Payment Receipt'}) {
    return ReceiptViewDialog(
      key: key,
      title: title,
      buildPdf: () async {
        final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).get();
        final studentId = payment[PaymentSchema.studentId] as String?;
        Map<String, dynamic>? student;
        if (studentId != null && studentId.isNotEmpty) {
          final stuDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).get();
          student = stuDoc.data();
        }
        return ReceiptService().buildReceiptPdf(payment: payment, student: student, institution: instDoc.data());
      },
    );
  }

  @override
  State<ReceiptViewDialog> createState() => _ReceiptViewDialogState();
}

class _ReceiptViewDialogState extends State<ReceiptViewDialog> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final bytes = await widget.buildPdf();
      final fileName = 'receipt_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;

    if (isMobile) {
      // Fullscreen for mobile to avoid overflow and provide ample viewing area
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis), actions: [
            IconButton(onPressed: _downloading ? null : _download, icon: _downloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download, color: Colors.blue))
          ]),
          body: SafeArea(
            child: PdfPreview(
              build: (format) => widget.buildPdf(),
              allowPrinting: false,
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'receipt_preview.pdf',
              initialPageFormat: pdf.PdfPageFormat.standard,
              loadingWidget: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    final width = math.min(size.width - 32, 800.0);
    final height = math.min(size.height - 160, 720.0);

    return AppResponsiveDialog(
      titleWidget: Row(children: [
        Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis)),
        Tooltip(message: 'Download', child: IconButton(onPressed: _downloading ? null : _download, icon: _downloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download, color: Colors.blue)))
      ]),
      content: SizedBox(
        width: width,
        height: height,
        child: PdfPreview(
          build: (format) => widget.buildPdf(),
          allowPrinting: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          pdfFileName: 'receipt_preview.pdf',
          initialPageFormat: pdf.PdfPageFormat.standard,
          loadingWidget: const Center(child: CircularProgressIndicator()),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      maxWidth: 900,
      maxHeightFactor: 0.9,
    );
  }
}
