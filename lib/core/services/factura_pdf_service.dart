import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/entities/factura_cliente.dart';

class FacturaPdfService {
  // ── Punto de entrada público ──────────────────────────────────────────────

  static Future<void> exportar(FacturaCliente factura) async {
    final bytes = await _buildBytes(factura);
    await Printing.layoutPdf(
      onLayout: (_) => bytes,
      name: '${factura.numeroFactura}.pdf',
    );
  }

  // ── Construcción del documento ────────────────────────────────────────────

  static Future<Uint8List> _buildBytes(FacturaCliente factura) async {
    final doc      = pw.Document();
    final dateFmt  = DateFormat('dd/MM/yyyy');
    final moneyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    final subtotal = factura.monto / 1.16;
    final iva      = factura.monto - subtotal;

    const primary = PdfColor(0.043, 0.145, 0.271); // #0B2545
    const accent  = PdfColor(0.098, 0.463, 0.824); // #1976D2

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(48),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Encabezado ──────────────────────────────────────
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'GLOBO LOGISTICS S.A. de C.V.',
                      style: pw.TextStyle(
                          fontSize: 15, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('RFC: GLO010101AAA',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                    pw.Text('Servicio de transporte de carga nacional',
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('FACTURA',
                        style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: primary)),
                    pw.Text(factura.numeroFactura,
                        style: pw.TextStyle(fontSize: 14, color: accent)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.SizedBox(height: 14),

            // ── Cliente + fechas ────────────────────────────────
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CLIENTE',
                          style: pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey500)),
                      pw.SizedBox(height: 3),
                      pw.Text(factura.clienteNombre,
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _infoRow('Emisión:', dateFmt.format(factura.fechaEmision)),
                    _infoRow('Vencimiento:',
                        dateFmt.format(factura.fechaVencimiento)),
                    if (factura.fechaCobro != null)
                      _infoRow('Cobrado:', dateFmt.format(factura.fechaCobro!)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // ── Tabla de conceptos ──────────────────────────────
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: pw.FlexColumnWidth(2),
                1: pw.FlexColumnWidth(5),
                2: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: primary),
                  children: [
                    _th('Concepto'),
                    _th('Descripción'),
                    _th('Importe', align: pw.TextAlign.right),
                  ],
                ),
                pw.TableRow(children: [
                  _td('Servicio de flete'),
                  _td('Transporte de carga — ${factura.viajeId}'),
                  _td(moneyFmt.format(subtotal),
                      align: pw.TextAlign.right),
                ]),
              ],
            ),
            pw.SizedBox(height: 12),

            // ── Totales ─────────────────────────────────────────
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.SizedBox(
                width: 210,
                child: pw.Column(children: [
                  _totalRow('Subtotal:', moneyFmt.format(subtotal)),
                  _totalRow('IVA 16%:', moneyFmt.format(iva)),
                  pw.Divider(thickness: 0.5),
                  _totalRow('Total:', moneyFmt.format(factura.monto),
                      bold: true),
                ]),
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Estatus ─────────────────────────────────────────
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: pw.BoxDecoration(
                color: _estatusBg(factura.estatus),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                'ESTATUS: ${factura.estatus.name.toUpperCase()}',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _estatusFg(factura.estatus)),
              ),
            ),

            pw.Spacer(),
            pw.Divider(thickness: 0.5, color: PdfColors.grey300),
            pw.Text(
              'Generado electrónicamente — Globo Logistics S.A. de C.V.',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400),
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  // ── Helpers internos ──────────────────────────────────────────────────────

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(children: [
          pw.Text(label,
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(width: 6),
          pw.Text(value, style: pw.TextStyle(fontSize: 9)),
        ]),
      );

  static pw.Widget _th(String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _td(String text,
          {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(text,
            textAlign: align, style: pw.TextStyle(fontSize: 10)),
      );

  static pw.Widget _totalRow(String label, String value,
          {bool bold = false}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  static PdfColor _estatusBg(EstatusFactura s) => switch (s) {
        EstatusFactura.cobrada   => PdfColors.green50,
        EstatusFactura.pendiente => PdfColors.orange50,
        EstatusFactura.vencida   => PdfColors.red50,
        EstatusFactura.cancelada => PdfColors.grey200,
      };

  static PdfColor _estatusFg(EstatusFactura s) => switch (s) {
        EstatusFactura.cobrada   => PdfColors.green800,
        EstatusFactura.pendiente => PdfColors.orange800,
        EstatusFactura.vencida   => PdfColors.red800,
        EstatusFactura.cancelada => PdfColors.grey700,
      };
}
