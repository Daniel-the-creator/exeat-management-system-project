import 'package:exeat_system/model/request_model.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateAndPrintExeat(dynamic request) async {
    final pdf = pw.Document();

    // Mapping fields since the two models are slightly different
    final String requestId =
        request is RequestModel ? request.requestId : (request.id ?? 'N/A');
    final String studentName = request.studentName;
    final String studentMatric = request.studentMatric;
    final String studentEmail = request.studentEmail;
    final String studentPhone = request.studentPhone;
    final String destination = request.destination;
    final String leaveDate = request.leaveDate;
    final String leaveTime = request.leaveTime;
    final String returnDate = request.returnDate;
    final String returnTime = request.returnTime;
    final String reason = request.reason;
    final String contactPerson = request.contactPerson;
    final String contactNumber = request.contactNumber;
    final String priorityLevel = request.priorityLevel;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: pw.BoxDecoration(
              border:
                  pw.Border.all(color: PdfColor.fromHex('#000000'), width: 2),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'DOMINION UNIVERSITY EXEAT PASS',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'OFFICIAL APPROVED DOCUMENT',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColor.fromHex('#424242'),
                          letterSpacing: 1.2,
                        ),
                      ),
                      pw.SizedBox(height: 16),
                      pw.Divider(
                          thickness: 1.5, color: PdfColor.fromHex('#000000')),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Exeat Status & Details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: pw.BoxDecoration(
                              color: PdfColor.fromHex('#4CAF50')),
                          child: pw.Text('STATUS: APPROVED',
                              style: pw.TextStyle(
                                  color: PdfColor.fromHex('#FFFFFF'),
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text('Request ID: $requestId',
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            'Date Issued: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
                            style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 8),
                        pw.Text('Priority Level: $priorityLevel',
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color:
                                    priorityLevel.toUpperCase() == 'EMERGENCY'
                                        ? PdfColor.fromHex('#F44336')
                                        : PdfColor.fromHex('#000000'))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Student Information
                _buildPdfHeader('STUDENT INFORMATION'),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildPdfField('Name:', studentName)),
                    pw.Expanded(
                        child: _buildPdfField('Matric No:', studentMatric)),
                  ],
                ),
                pw.Row(
                  children: [
                    pw.Expanded(child: _buildPdfField('Email:', studentEmail)),
                    pw.Expanded(child: _buildPdfField('Phone:', studentPhone)),
                  ],
                ),
                pw.SizedBox(height: 12),

                // Trip Information
                _buildPdfHeader('TRIP DETAILS'),
                pw.SizedBox(height: 8),
                _buildPdfField('Destination:', destination),
                pw.Row(
                  children: [
                    pw.Expanded(
                        child: _buildPdfField(
                            'Departure:', '$leaveDate, $leaveTime')),
                    pw.Expanded(
                        child: _buildPdfField(
                            'Return:', '$returnDate, $returnTime')),
                  ],
                ),
                _buildPdfField('Reason for Leave:', reason),
                pw.SizedBox(height: 12),

                // Emergency & Security
                _buildPdfHeader('EMERGENCY CONTACT & SECURITY'),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: [
                    pw.Expanded(
                        child:
                            _buildPdfField('Contact Person:', contactPerson)),
                    pw.Expanded(
                        child: _buildPdfField('Contact Phone:', contactNumber)),
                  ],
                ),
                pw.SizedBox(height: 16),

                // Verification Area
                _buildPdfHeader('VERIFICATION & CLEARANCE'),
                pw.SizedBox(height: 16),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                            width: 160,
                            height: 1,
                            color: PdfColor.fromHex('#000000')),
                        pw.SizedBox(height: 3),
                        pw.Text('Authorized Signature / Stamp',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('library officer',
                            style: const pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                            width: 160,
                            height: 1,
                            color: PdfColor.fromHex('#000000')),
                        pw.SizedBox(height: 3),
                        pw.Text('Security Gate (Departure)',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Signature & Exit Time',
                            style: const pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 20),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                            width: 160,
                            height: 1,
                            color: PdfColor.fromHex('#000000')),
                        pw.SizedBox(height: 3),
                        pw.Text('Parent / Guardian Signature',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Confirms student arrived home',
                            style: const pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Container(
                            width: 160,
                            height: 1,
                            color: PdfColor.fromHex('#000000')),
                        pw.SizedBox(height: 3),
                        pw.Text('Date & Time of Arrival',
                            style: pw.TextStyle(
                                fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text('To be filled by Parent/Guardian',
                            style: const pw.TextStyle(fontSize: 6)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'This document is an officially generated exeat pass for the student named above.',
                        style: pw.TextStyle(
                            fontSize: 10, fontStyle: pw.FontStyle.italic),
                      ),
                      pw.Text(
                        'Security officers may verify this pass by scanning the student\'s ID in the Exeat System app.',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColor.fromHex('#424242')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    // Prompt user to print/save
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Exeat_Pass_${studentMatric.replaceAll("/", "_")}.pdf',
    );
  }

  static pw.Widget _buildPdfHeader(String title) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EEEEEE')),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Text(title,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
    );
  }

  static pw.Widget _buildPdfField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColor.fromHex('#757575'),
                  fontWeight: pw.FontWeight.bold)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
