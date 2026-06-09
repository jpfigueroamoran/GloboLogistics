import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfReportGenerator {
  static Future<void> generateAndPrint() async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final formattedDate = formatter.format(now);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        pageTheme: pw.PageTheme(
          buildBackground: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Watermark(
              child: pw.Transform.rotateBox(
                angle: 0.5,
                child: pw.Text(
                  'GLOBO LOGISTICS',
                  style: pw.TextStyle(
                    color: PdfColors.grey200,
                    fontSize: 80,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('GLOBO LOGISTICS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text('Reporte Ejecutivo de Operaciones', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColors.blue900),
              pw.SizedBox(height: 20),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Generado el: $formattedDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  pw.Text('Página ${context.pageNumber} de ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Resumen Ejecutivo
            pw.Text('Resumen Ejecutivo (Últimos 6 meses)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(
              'Este reporte presenta un resumen analítico del desempeño operativo, distribución de gastos y rendimiento del capital humano en Globo Logistics. Durante el último semestre, la flota ha mantenido un nivel de actividad estable, con un incremento sostenido en la eficiencia de entregas.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),
            pw.SizedBox(height: 30),

            // Tabla de KPIs
            pw.Text('Indicadores Clave de Rendimiento (KPIs)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildKpiTable(),
            pw.SizedBox(height: 30),

            // Desglose Financiero
            pw.Text('Desglose Financiero - Gastos Operativos', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            _buildFinancialTable(),
            pw.SizedBox(height: 30),

            // Score de Operadores
            pw.Text('Rendimiento del Personal Operativo', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text(
              'El programa de incentivos "Score Global" ha resultado en un incremento promedio de 10 puntos en el rendimiento de los operadores, situando la métrica global en 95/100 para el mes en curso. La reducción de incidentes graves ha disminuido los costos en pólizas de seguro en un 12%.',
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5),
            ),
          ];
        },
      ),
    );

    // Usa printing para lanzar el visor de impresión nativo (Web/Desktop/Mobile)
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'GloboLogistics_Reporte_$formattedDate.pdf',
    );
  }

  static pw.Widget _buildKpiTable() {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.all(8),
      headers: <String>['Métrica', 'Valor Promedio', 'Tendencia (vs Mes Ant.)', 'Estado'],
      data: <List<String>>[
        ['Viajes Completados', '105 / mes', '+12%', 'Óptimo'],
        ['Entregas a Tiempo (OTIF)', '92%', '+3%', 'Aceptable'],
        ['Alertas Críticas (S.O.S)', '2 / mes', '-50%', 'Mejorando'],
        ['Consumo de Combustible', '3.8 km/l', '-2%', 'Atención'],
      ],
    );
  }

  static pw.Widget _buildFinancialTable() {
    return pw.TableHelper.fromTextArray(
      context: null,
      border: pw.TableBorder.all(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.all(8),
      headers: <String>['Categoría de Gasto', 'Presupuesto Asignado', 'Gasto Real (MXN)', 'Variación'],
      data: <List<String>>[
        ['Combustible', '\$500,000', '\$450,000', '-10% (Ahorro)'],
        ['Mantenimiento Correctivo', '\$200,000', '\$250,000', '+25% (Excedido)'],
        ['Llantas', '\$150,000', '\$150,000', '0% (Alineado)'],
        ['Peajes / Casetas', '\$100,000', '\$95,000', '-5% (Ahorro)'],
      ],
    );
  }
}
