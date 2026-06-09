import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/entities/factura_cliente.dart';

class PdfGenerator {
  static Future<Uint8List> generateFacturaPdf(FacturaCliente factura) async {
    final pdf = pw.Document();
    final fmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final fmtFecha = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'GLOBO LOGISTICS',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Transporte y Logística de Excelencia', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('RFC: GLO123456789', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                      pw.Text('Av. Transportistas 123, Ciudad de México', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FACTURA', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('Folio: ${factura.numeroFactura}'),
                        pw.Text('Emisión: ${fmtFecha.format(factura.fechaEmision)}'),
                        pw.Text('Vence: ${fmtFecha.format(factura.fechaVencimiento)}'),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // CLIENT INFO
              pw.Text('Receptor:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(factura.clienteNombre, style: const pw.TextStyle(fontSize: 14)),
              pw.Text('ID Cliente: ${factura.clienteId}'),
              pw.SizedBox(height: 32),

              // CONCEPT TABLE
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1),
                  1: const pw.FlexColumnWidth(4),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FlexColumnWidth(2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Cant.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Concepto', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Precio U.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Importe', style: pw.TextStyle(fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('1', textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Servicio de Autotransporte Federal\n(Viaje ID: ${factura.viajeId})')),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmt.format(factura.monto / 1.16), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(fmt.format(factura.monto / 1.16), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),

              // TOTALS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: ${fmt.format(factura.monto / 1.16)}'),
                      pw.Text('IVA (16%): ${fmt.format(factura.monto - (factura.monto / 1.16))}'),
                      pw.Container(width: 150, child: pw.Divider()),
                      pw.Text('Total: ${fmt.format(factura.monto)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 32),

              // CARTA PORTE SECTION
              if (factura.cartaPorteUuid != null) ...[
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('COMPLEMENTO CARTA PORTE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 8),
                pw.Text('UUID CFDI: ${factura.cartaPorteUuid}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Certificación: ${fmtFecha.format(factura.fechaEmision)}', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Tipo de Comprobante: I - Ingreso', style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 16),
                pw.Text('Este documento es una representación impresa de un CFDI con complemento Carta Porte válido para el tránsito de mercancías en territorio nacional según las disposiciones vigentes del SAT.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
              
              pw.Spacer(),
              pw.Center(
                child: pw.Text(
                  'Este documento es una simulación generada por Globo Logistics.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }
}
