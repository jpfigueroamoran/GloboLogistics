import 'package:flutter_test/flutter_test.dart';
import 'package:globo_logistics/core/services/ocr_normalization_service.dart';

/// Característica: OCR de tickets de combustible (carga_combustible_page).
/// Verifica la normalización y extracción de campos del motor "Litro Exacto".
void main() {
  group('OCR — normalización', () {
    test('corrige O→0 en contexto numérico', () {
      expect(OcrNormalizationService.normalize('1O0'), '100');
    });

    test('corrige l/I→1 entre dígitos', () {
      expect(OcrNormalizationService.normalize('1l0'), '110');
    });

    test('corrige S→5, B→8, Z→2, G→9 entre dígitos', () {
      expect(OcrNormalizationService.normalize('1S0'), '150');
      expect(OcrNormalizationService.normalize('1B0'), '180');
      expect(OcrNormalizationService.normalize('1Z0'), '120');
      expect(OcrNormalizationService.normalize('1G0'), '190');
    });

    test('convierte coma decimal a punto', () {
      expect(OcrNormalizationService.normalize('10,50'), '10.50');
    });

    test('normaliza símbolos de moneda a \$', () {
      expect(OcrNormalizationService.normalize('€100'), '\$100');
    });

    test('colapsa espacios múltiples', () {
      expect(OcrNormalizationService.normalize('TOTAL    100'), 'TOTAL 100');
    });
  });

  group('OCR — extracción de campos', () {
    test('extrae litros con sufijo Lts', () {
      expect(OcrNormalizationService.extractLitros('45.5 Lts'), 45.5);
    });

    test('extrae litros desde "Cantidad:"', () {
      expect(OcrNormalizationService.extractLitros('CANTIDAD: 320.0'), 320.0);
    });

    test('extrae monto total con \$', () {
      expect(OcrNormalizationService.extractMonto('TOTAL: \$1234.56'),
          closeTo(1234.56, 0.001));
    });

    test('extrae precio por litro dentro de rango diésel MX', () {
      expect(OcrNormalizationService.extractPrecioPorLitro('PRECIO: \$23.50/L'),
          closeTo(23.50, 0.001));
    });

    test('rechaza precio por litro fuera de rango (>45)', () {
      // 99.00 no es un precio de diésel válido → null
      expect(OcrNormalizationService.extractPrecioPorLitro('PRECIO: \$99.00/L'),
          isNull);
    });

    test('extrae folio del ticket', () {
      expect(OcrNormalizationService.extractFolio('FOLIO: ABC-12345'),
          'ABC-12345');
    });

    test('extrae fecha DD/MM/YYYY', () {
      final f = OcrNormalizationService.extractFecha('Fecha 15/03/2026');
      expect(f, DateTime(2026, 3, 15));
    });
  });

  group('OCR — coherencia matemática (anti-fraude)', () {
    test('acepta cuando precio × litros ≈ total', () {
      expect(
        OcrNormalizationService.validarCoherenciaMatematica(
            monto: 235.0, litros: 10.0, precioPorLitro: 23.5),
        isTrue,
      );
    });

    test('rechaza cuando el total no cuadra', () {
      expect(
        OcrNormalizationService.validarCoherenciaMatematica(
            monto: 300.0, litros: 10.0, precioPorLitro: 23.5),
        isFalse,
      );
    });

    test('rechaza valores no positivos', () {
      expect(
        OcrNormalizationService.validarCoherenciaMatematica(
            monto: 100.0, litros: 0.0, precioPorLitro: 23.5),
        isFalse,
      );
    });
  });
}
