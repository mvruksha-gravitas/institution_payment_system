import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:institutation_payment_system/firestore/firestore_data_schema.dart';

class ReceiptService {
  Future<Uint8List> buildReceiptPdf({
    required Map<String, dynamic> payment,
    Map<String, dynamic>? student,
    Map<String, dynamic>? institution,
  }) async {
    final pdf = pw.Document();
    final amount = (payment[PaymentSchema.amount] as num? ?? 0).toStringAsFixed(2);
    final date = (payment[PaymentSchema.paidAt] as Timestamp?)?.toDate() ?? DateTime.now();
    final fmt = DateFormat('dd MMM yyyy, HH:mm');

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) {
          return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(institution?[InstitutionRegistrationSchema.institutionName] as String? ?? 'Institution', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('InstId: ${institution?[InstitutionRegistrationSchema.id] ?? payment[PaymentSchema.instId]}'),
            pw.SizedBox(height: 16),
            pw.Text('Payment Receipt', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            _row('Receipt No', payment[PaymentSchema.receiptNo] as String? ?? ''),
            _row('Student', student?['first_name'] != null ? '${student?['first_name']} ${student?['last_name'] ?? ''}' : (student?[StudentSchema.phoneNumber] as String? ?? '')),
            _row('Student ID', payment[PaymentSchema.studentId] as String? ?? ''),
            _row('Room', payment[PaymentSchema.roomNumber] as String? ?? '-'),
            if (payment[PaymentSchema.feeLabel] != null) _row('Fee', payment[PaymentSchema.feeLabel] as String),
            _row('Amount', '₹ $amount'),
            _row('Method', payment[PaymentSchema.method] as String? ?? ''),
            _row('Paid At', fmt.format(date)),
            pw.SizedBox(height: 16),
            pw.Text('Thank you for your payment.', style: const pw.TextStyle(fontSize: 12)),
          ]);
        },
      ),
    );
    return pdf.save();
  }

  // Payments report PDF (for multiple records with filters)
  Future<Uint8List> buildPaymentsReportPdf({
    required List<Map<String, dynamic>> payments,
    required Map<String, Map<String, dynamic>> studentById,
    Map<String, dynamic>? institution,
    String? title,
    String? filtersDescription,
    String? selectedStudentId,
  }) async {
    final pdfDoc = pw.Document();
    final df = DateFormat('dd MMM yyyy');
    final hdrTitle = title ?? 'Payments Report';
    final isDeviceSmall = false; // We'll make this responsive in final render
    
    // Determine if this is a single student report
    final isSingleStudent = selectedStudentId != null && selectedStudentId.isNotEmpty;
    
    pdfDoc.addPage(
      pw.MultiPage(
        margin: pw.EdgeInsets.all(isDeviceSmall ? 12 : 24),
        build: (ctx) {
          final List<pw.Widget> content = [];
          
          // Institution header
          content.add(pw.Text(
            institution?[InstitutionRegistrationSchema.institutionName] as String? ?? 'Institution', 
            style: pw.TextStyle(fontSize: isDeviceSmall ? 16 : 20, fontWeight: pw.FontWeight.bold)
          ));
          if (institution != null) {
            content.add(pw.Text(
              'InstId: ${institution[InstitutionRegistrationSchema.id] ?? ''}',
              style: pw.TextStyle(fontSize: isDeviceSmall ? 10 : 12)
            ));
          }
          content.add(pw.SizedBox(height: 12));
          
          // Report title
          content.add(pw.Text(
            hdrTitle, 
            style: pw.TextStyle(fontSize: isDeviceSmall ? 14 : 18, fontWeight: pw.FontWeight.bold)
          ));
          
          // Report subtitle based on type
          if (isSingleStudent) {
            final student = studentById[selectedStudentId];
            if (student != null) {
              final studentName = ((student[StudentSchema.firstName] as String? ?? '').trim() + ' ' + 
                                 (student[StudentSchema.lastName] as String? ?? '').trim()).trim();
              final room = student[StudentSchema.roomNumber] as String?;
              final bed = student[StudentSchema.bedNumber] as int?;
              final roomBed = room != null ? (bed != null ? 'Room $room, Bed $bed' : 'Room $room') : '';
              
              content.add(pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  '$studentName${roomBed.isNotEmpty ? ' - $roomBed' : ''}',
                  style: pw.TextStyle(fontSize: isDeviceSmall ? 10 : 12, fontWeight: pw.FontWeight.bold)
                ),
              ));
            }
          } else {
            content.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Report for all students',
                style: pw.TextStyle(fontSize: isDeviceSmall ? 10 : 12, fontWeight: pw.FontWeight.bold)
              ),
            ));
          }
          
          // Date range
          if (filtersDescription != null && filtersDescription.isNotEmpty) {
            content.add(pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2, bottom: 8),
              child: pw.Text(
                filtersDescription,
                style: pw.TextStyle(fontSize: isDeviceSmall ? 8 : 10)
              ),
            ));
          }
          
          content.add(pw.SizedBox(height: 8));
          
          // Table with dynamic headers based on report type
          final headers = isSingleStudent 
            ? ['Date', 'Amount', 'Status', 'Mode']
            : ['Date', 'Student', 'Amount', 'Status', 'Mode'];
          
          final data = payments.map((p) {
            final sid = p[PaymentSchema.studentId] as String?;
            final s = sid != null ? studentById[sid] : null;
            final name = s != null ? (((s[StudentSchema.firstName] as String? ?? '').trim() + ' ' + 
                                     (s[StudentSchema.lastName] as String? ?? '').trim()).trim()) : (sid ?? '-');
            final method = (p[PaymentSchema.status] as String? ?? 'paid').toLowerCase() == 'paid' 
              ? (p[PaymentSchema.method] as String? ?? '').toUpperCase()
              : '';
            final status = (p[PaymentSchema.status] as String? ?? 'paid').toUpperCase();
            final amt = '₹ ${(p[PaymentSchema.amount] as num? ?? 0).toStringAsFixed(2)}';
            final paidAt = (p[PaymentSchema.paidAt] as Timestamp?)?.toDate();
            final created = (p[PaymentSchema.createdAt] as Timestamp?)?.toDate();
            final date = paidAt ?? created ?? DateTime.now();
            
            return isSingleStudent 
              ? [df.format(date), amt, status, method]
              : [df.format(date), name.isEmpty ? (s?[StudentSchema.phoneNumber] as String? ?? '-') : name, amt, status, method];
          }).toList();
          
          content.add(pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isDeviceSmall ? 8 : 10),
            cellStyle: pw.TextStyle(fontSize: isDeviceSmall ? 7 : 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
            headers: headers,
            data: data,
          ));
          
          return content;
        },
      ),
    );
    return pdfDoc.save();
  }

  // Students list report PDF (Name, Phone, Room/Bed, Rent Amount)
  Future<Uint8List> buildStudentsReportPdf({
    required List<Map<String, dynamic>> students,
    required String instId,
    Map<String, dynamic>? institution,
    String? title,
  }) async {
    final pdfDoc = pw.Document();
    final hdrTitle = title ?? 'Students Report';

    // Fetch pricing once
    final pricingSnap = await FirebaseFirestore.instance
        .collection(InstitutionRegistrationSchema.collectionName)
        .doc(instId)
        .collection(AccommodationPricingSchema.collectionName)
        .doc(AccommodationPricingSchema.pricingDocId)
        .get();
    final pricingData = pricingSnap.data() ?? {};
    final Map<String, num> withFood = {};
    final Map<String, num> withoutFood = {};
    final wfRaw = pricingData[AccommodationPricingSchema.withFood] as Map<String, dynamic>?;
    final woRaw = pricingData[AccommodationPricingSchema.withoutFood] as Map<String, dynamic>?;
    if (wfRaw != null) {
      wfRaw.forEach((k, v) { final num? n = v is num ? v : num.tryParse('$v'); if (n != null) withFood[k] = n; });
    }
    if (woRaw != null) {
      woRaw.forEach((k, v) { final num? n = v is num ? v : num.tryParse('$v'); if (n != null) withoutFood[k] = n; });
    }

    // Sort by first name then last name for consistency
    final data = [...students];
    data.sort((a, b) {
      final an = ((a[StudentSchema.firstName] as String? ?? '').trim() + ' ' + (a[StudentSchema.lastName] as String? ?? '').trim()).trim().toLowerCase();
      final bn = ((b[StudentSchema.firstName] as String? ?? '').trim() + ' ' + (b[StudentSchema.lastName] as String? ?? '').trim()).trim().toLowerCase();
      return an.compareTo(bn);
    });

    String amountFor(Map<String, dynamic> s) {
      final room = s[StudentSchema.roomNumber] as String?;
      if (room == null || room.isEmpty) return '-';
      final plan = (s[StudentSchema.foodPlan] as String?) ?? 'with';
      final category = (s[StudentSchema.roomCategory] as String?) ?? 'two_sharing';
      final num? amt = (plan == 'with' ? withFood[category] : withoutFood[category]);
      return amt == null ? '-' : 'Rs. ${amt.toString()}';
    }

    pdfDoc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text(institution?[InstitutionRegistrationSchema.institutionName] as String? ?? 'Institution', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (institution != null) pw.Text('InstId: ${institution[InstitutionRegistrationSchema.id] ?? instId}'),
          pw.SizedBox(height: 12),
          pw.Text(hdrTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
            headers: ['Student Name', 'Phone', 'Room/Bed', 'Rent Amount'],
            data: [
              for (final s in data)
                () {
                  final first = (s[StudentSchema.firstName] as String? ?? '').trim();
                  final last = (s[StudentSchema.lastName] as String? ?? '').trim();
                  final name = ('$first $last').trim();
                  final phone = (s[StudentSchema.phoneNumber] as String? ?? '').trim();
                  final room = (s[StudentSchema.roomNumber] as String?);
                  final bed = s[StudentSchema.bedNumber] as int?;
                  final roomBed = (room == null || room.isEmpty) ? '-' : (bed == null ? 'Room $room' : 'Room $room, Bed $bed');
                  final amt = amountFor(s);
                  return [name.isEmpty ? '-' : name, phone.isEmpty ? '-' : phone, roomBed, amt];
                }(),
            ],
          )
        ],
      ),
    );
    return pdfDoc.save();
  }

  // Accommodation rooms report PDF (Room Number, Sharing Category, Occupied Beds, Available Beds)
  Future<Uint8List> buildAccommodationRoomsReportPdf({
    required String instId,
    required List<Map<String, dynamic>> rows,
    Map<String, dynamic>? institution,
    String? title,
    String? filtersDescription,
  }) async {
    String labelForCategory(String category) {
      switch (category) {
        case 'single':
          return 'Single';
        case 'two_sharing':
          return 'Two Sharing';
        case 'three_sharing':
          return 'Three Sharing';
        case 'four_sharing':
          return 'Four Sharing';
        default:
          return category;
      }
    }

    // Sort naturally by room number for readability
    final data = [...rows];
    int naturalCompare(String a, String b) {
      final reg = RegExp(r"(\d+|\D+)");
      final ta = reg.allMatches(a).map((m) => m.group(0)!).toList();
      final tb = reg.allMatches(b).map((m) => m.group(0)!).toList();
      final len = ta.length < tb.length ? ta.length : tb.length;
      for (int i = 0; i < len; i++) {
        final xa = ta[i];
        final xb = tb[i];
        final na = int.tryParse(xa);
        final nb = int.tryParse(xb);
        if (na != null && nb != null) {
          final c = na.compareTo(nb);
          if (c != 0) return c;
        } else {
          final c = xa.toLowerCase().compareTo(xb.toLowerCase());
          if (c != 0) return c;
        }
      }
      return ta.length.compareTo(tb.length);
    }
    data.sort((a, b) => naturalCompare('${a['roomNumber'] ?? ''}', '${b['roomNumber'] ?? ''}'));

    final pdfDoc = pw.Document();
    final hdrTitle = title ?? 'Accommodation Report';

    pdfDoc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text(institution?[InstitutionRegistrationSchema.institutionName] as String? ?? 'Institution', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (institution != null) pw.Text('InstId: ${institution[InstitutionRegistrationSchema.id] ?? instId}'),
          pw.SizedBox(height: 12),
          pw.Text(hdrTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (filtersDescription != null && filtersDescription.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 4, bottom: 8), child: pw.Text(filtersDescription, style: const pw.TextStyle(fontSize: 10))),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: pdf.PdfColors.grey300),
            headers: ['Room Number', 'Sharing Category', 'Occupied Beds', 'Available Beds'],
            data: [
              for (final r in data)
                [
                  '${r['roomNumber'] ?? '-'}',
                  labelForCategory('${r['category'] ?? '-'}'),
                  '${r['occupied'] ?? 0}',
                  '${r['available'] ?? 0}',
                ],
            ],
          )
        ],
      ),
    );
    return pdfDoc.save();
  }

  pw.Widget _row(String a, String b) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.SizedBox(width: 120, child: pw.Text(a, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(b)),
        ]),
      );

  Future<void> previewOrShare(BuildContext context, Map<String, dynamic> payment) async {
    // Try to fetch student and institution details for richer receipt
    final instId = payment[PaymentSchema.instId] as String;
    final studentId = payment[PaymentSchema.studentId] as String;
    final instDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).get();
    final stuDoc = await FirebaseFirestore.instance.collection(InstitutionRegistrationSchema.collectionName).doc(instId).collection(InstitutionRegistrationSchema.studentsSubcollection).doc(studentId).get();
    final data = await buildReceiptPdf(payment: payment, student: stuDoc.data(), institution: instDoc.data());
    await Printing.layoutPdf(onLayout: (_) async => data);
  }
}
