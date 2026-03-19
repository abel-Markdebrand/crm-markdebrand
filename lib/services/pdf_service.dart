import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import '../utils/odoo_utils.dart';

class PdfService {
  static final PdfService instance = PdfService._();
  PdfService._();

  final PdfColor maroon = PdfColor.fromInt(0xFF9B3232);
  final PdfColor lightGray = PdfColor.fromInt(0xFFF1F5F9);
  final PdfColor darkSlate = PdfColor.fromInt(0xFF1E293B);

  Future<String> generateQuotePdf({
    required String orderName,
    required String partnerName,
    required String partnerAddress,
    required String date,
    required String expirationDate,
    required String salesperson,
    required String notes,
    required List<Map<String, dynamic>> lines,
    required double subtotal,
    required double taxes,
    required double total,
  }) async {
    final pdf = pw.Document();

    // Load Logo asset if exists
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/image/logo_mdb.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint("Error loading logo for PDF: $e");
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header: Logo and Company Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      partnerName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.Text(
                      partnerAddress,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (logo != null) pw.Image(logo, width: 120),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "Markdebrand",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      "66 West Flagler Street",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      "Suite 900",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      "Miami FL 33130",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      "United States",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Title
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Quotation # $orderName",
                style: pw.TextStyle(
                  color: maroon,
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),

            // Info Box
            pw.Container(
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _infoColumn("Quotation Date", date),
                  _infoColumn("Expiration", expirationDate),
                  _infoColumn("Salesperson", salesperson),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Main Table
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Table Header
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: maroon),
                  children: [
                    _tableHeaderCell("DESCRIPTION"),
                    _tableHeaderCell("QUANTITY"),
                    _tableHeaderCell("UNIT PRICE"),
                    _tableHeaderCell("TAXES"),
                    _tableHeaderCell("AMOUNT"),
                  ],
                ),
                // The "Description will be the notes part" - We can add it as a special first row or just lines
                // User said: "La descripción va a ser la parte de notas"
                if (notes.isNotEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          OdooUtils.stripHtml(notes),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Container(),
                      pw.Container(),
                      pw.Container(),
                      pw.Container(),
                    ],
                  ),
                // Real Order Lines
                ...lines.map(
                  (line) => pw.TableRow(
                    children: [
                      _tableCell(line['name'] ?? ''),
                      _tableCell("${line['quantity']} Units"),
                      _tableCell("\$ ${line['price_unit']}"),
                      _tableCell("${line['tax']}%"),
                      _tableCell("\$ ${line['amount']}"),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Totals
            pw.Row(
              children: [
                pw.Spacer(flex: 2),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    children: [
                      _totalRow("Untaxed Amount", subtotal),
                      _totalRow("Tax 5%", taxes),
                      pw.Divider(color: PdfColors.grey),
                      pw.Container(
                        color: maroon,
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Total",
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              "\$ ${total.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "+1 (305) 464-0011 info@markdebrand.com",
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    "Page ${context.pageNumber} / ${context.pagesCount}",
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/quotation_$orderName.pdf");
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  pw.Widget _infoColumn(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
      ],
    );
  }

  pw.Widget _tableHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      alignment: pw.Alignment.centerLeft,
    );
  }

  pw.Widget _tableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 9)),
    );
  }

  pw.Widget _totalRow(String label, double amount) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
          pw.Text(
            "\$ ${amount.toStringAsFixed(2)}",
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  Future<String> generateInvoicePdf({
    required String invoiceName,
    required String partnerName,
    required String partnerAddress,
    required String date,
    required String dueDate,
    required String origin,
    required String notes,
    required List<Map<String, dynamic>> lines,
    required double subtotal,
    required double taxes,
    required double total,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/image/logo_mdb.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {
      debugPrint("Error loading logo for PDF: $e");
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      partnerName,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.Text(
                      partnerAddress,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (logo != null) pw.Image(logo, width: 120),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      "Markdebrand",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      "66 West Flagler Street",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      "Suite 900",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      "Miami FL 33130",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      "United States",
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                "Invoice # $invoiceName",
                style: pw.TextStyle(
                  color: maroon,
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              decoration: pw.BoxDecoration(
                color: lightGray,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _infoColumn("Invoice Date", date),
                  _infoColumn("Due Date", dueDate),
                  _infoColumn("Source", origin),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1),
                4: const pw.FlexColumnWidth(1),
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: maroon),
                  children: [
                    _tableHeaderCell("DESCRIPTION"),
                    _tableHeaderCell("QUANTITY"),
                    _tableHeaderCell("UNIT PRICE"),
                    _tableHeaderCell("TAXES"),
                    _tableHeaderCell("AMOUNT"),
                  ],
                ),
                if (notes.isNotEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          OdooUtils.stripHtml(notes),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                      pw.Container(),
                      pw.Container(),
                      pw.Container(),
                      pw.Container(),
                    ],
                  ),
                ...lines.map(
                  (line) => pw.TableRow(
                    children: [
                      _tableCell(line['name'] ?? ''),
                      _tableCell("${line['quantity']} Units"),
                      _tableCell("\$ ${line['price_unit']}"),
                      _tableCell("${line['tax']}%"),
                      _tableCell("\$ ${line['amount']}"),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Row(
              children: [
                pw.Spacer(flex: 2),
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    children: [
                      _totalRow("Untaxed Amount", subtotal),
                      _totalRow("Tax 5%", taxes),
                      pw.Divider(color: PdfColors.grey),
                      pw.Container(
                        color: maroon,
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                              "Total",
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.Text(
                              "\$ ${total.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "Terms of Use: markdebrand.com/terms",
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    "  •  ",
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                  pw.Text(
                    "Privacy Policy: markdebrand.com/privacy",
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    "+1 (305) 464-0011 info@markdebrand.com",
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  pw.Text(
                    "Page ${context.pageNumber} / ${context.pagesCount}",
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/invoice_$invoiceName.pdf");
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
