// Portado del engine anti-fraude de LitroExacto (index.ts — normalizeOCR v2.0).
// Corrige confusiones típicas de OCR en tickets mexicanos de diésel.

abstract final class OcrNormalizationService {
  /// Limpia y normaliza texto OCR de tickets de combustible.
  static String normalize(String raw) {
    var text = raw;

    // Caracteres típicamente confundidos en contexto numérico
    text = text.replaceAllMapped(
      RegExp(r'(\d)[OoQq](\d)'),
      (m) => '${m[1]}0${m[2]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d)[lI|](\d)'),
      (m) => '${m[1]}1${m[2]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d)[Ss](\d)'),
      (m) => '${m[1]}5${m[2]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d)[Bb](\d)'),
      (m) => '${m[1]}8${m[2]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d)[Zz](\d)'),
      (m) => '${m[1]}2${m[2]}',
    );
    text = text.replaceAllMapped(
      RegExp(r'(\d)[Gg](\d)'),
      (m) => '${m[1]}9${m[2]}',
    );

    // Decimal: coma → punto solo en contexto numérico
    text = text.replaceAllMapped(
      RegExp(r'(\d),(\d)'),
      (m) => '${m[1]}.${m[2]}',
    );

    // Símbolo de moneda
    text = text.replaceAll(RegExp(r'[€£¥₱]'), '\$');

    // Espacios múltiples
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Caracteres de control invisibles
    text = text.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');

    return text;
  }

  /// Extrae monto total ($XXX.XX o similar) del texto normalizado.
  /// Las etiquetas se buscan sin distinguir mayúsculas: los tickets de
  /// combustible mexicanos suelen imprimirse TODO EN MAYÚSCULAS.
  static double? extractMonto(String normalizedText) {
    final patterns = [
      RegExp(r'\$\s*([0-9]{1,6}\.?[0-9]{0,2})'),       // $1234.56
      RegExp(r'total[:\s]*\$?\s*([0-9]{1,6}\.[0-9]{2})', caseSensitive: false),
      RegExp(r'importe[:\s]*\$?\s*([0-9]{1,6}\.[0-9]{2})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(normalizedText);
      if (m != null) {
        return double.tryParse(m.group(1)!.replaceAll(',', ''));
      }
    }
    return null;
  }

  /// Extrae litros del texto normalizado.
  static double? extractLitros(String normalizedText) {
    final patterns = [
      RegExp(r'([0-9]+\.?[0-9]{0,3})\s*(?:lts?|litros?)', caseSensitive: false),
      RegExp(r'cantidad[:\s]*([0-9]+\.?[0-9]{0,3})', caseSensitive: false),
      RegExp(r'volumen[:\s]*([0-9]+\.?[0-9]{0,3})', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(normalizedText);
      if (m != null) return double.tryParse(m.group(1)!);
    }
    return null;
  }

  /// Extrae precio por litro.
  static double? extractPrecioPorLitro(String normalizedText) {
    final patterns = [
      RegExp(r'precio[:\s]*\$?\s*([0-9]+\.[0-9]{2,4})\s*(?:/l|xl|por\s*l)?',
          caseSensitive: false),
      RegExp(r'\$\s*([0-9]{2}\.[0-9]{2,4})\s*/l', caseSensitive: false),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(normalizedText);
      if (m != null) {
        final val = double.tryParse(m.group(1)!);
        // Validar rango razonable para diésel en México
        if (val != null && val >= 15.0 && val <= 45.0) return val;
      }
    }
    return null;
  }

  /// Extrae folio/número de ticket.
  static String? extractFolio(String normalizedText) {
    final patterns = [
      RegExp(r'(?:folio|ticket|factura|no\.?)[:\s]*([A-Z0-9\-]{4,20})',
          caseSensitive: false),
      RegExp(r'#([A-Z0-9\-]{4,20})'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(normalizedText);
      if (m != null) return m.group(1);
    }
    return null;
  }

  /// Extrae fecha en formatos comunes mexicanos.
  static DateTime? extractFecha(String normalizedText) {
    // DD/MM/YYYY o DD-MM-YYYY
    final p = RegExp(r'(\d{2})[/\-](\d{2})[/\-](\d{4})');
    final m = p.firstMatch(normalizedText);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      final month = int.tryParse(m.group(2)!);
      final year = int.tryParse(m.group(3)!);
      if (day != null && month != null && year != null) {
        return DateTime.tryParse('$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}');
      }
    }
    return null;
  }

  /// Coherencia matemática básica: precio × litros ≈ total.
  static bool validarCoherenciaMatematica({
    required double monto,
    required double litros,
    required double precioPorLitro,
    double tolerancia = 0.02,
  }) {
    if (precioPorLitro <= 0 || litros <= 0) return false;
    final calculado = precioPorLitro * litros;
    final delta = (calculado - monto).abs() / monto;
    return delta <= tolerancia;
  }
}
