import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/services/geocoding_service.dart';
import '../../../../core/utils/download_helper.dart';
import '../../../../data/datasources/remote/firestore_datasource.dart';
import '../../../../domain/repositories/i_cliente_repository.dart';
import '../../../../injection_container.dart';

enum TipoImportacion { unidades, clientes }

class ResultadoImportacion {
  final int creados;
  final int omitidos;
  final List<String> errores;

  const ResultadoImportacion({
    required this.creados,
    required this.omitidos,
    required this.errores,
  });
}

/// Importación masiva costo-cero: el CSV se parsea en el dispositivo y cada
/// fila se escribe con los permisos del administrador (sin Admin SDK).
class CsvImportService {
  /// Abre el selector de archivos y devuelve las filas como mapas
  /// `encabezado -> valor`. Devuelve null si el usuario cancela.
  static Future<List<Map<String, String>>?> elegirYParsear() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final bytes = picked.files.first.bytes;
    if (bytes == null) return null;

    final contenido = utf8.decode(bytes, allowMalformed: true);
    final filas = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(contenido);

    if (filas.isEmpty) return [];

    final encabezados = filas.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList();

    final resultado = <Map<String, String>>[];
    for (var i = 1; i < filas.length; i++) {
      final fila = filas[i];
      if (fila.every((c) => c.toString().trim().isEmpty)) continue;
      final mapa = <String, String>{};
      for (var j = 0; j < encabezados.length && j < fila.length; j++) {
        mapa[encabezados[j]] = fila[j].toString().trim();
      }
      resultado.add(mapa);
    }
    return resultado;
  }

  /// Genera y descarga un machote CSV de ejemplo
  static void descargarMachote(TipoImportacion tipo) {
    String csvContent;
    String filename;

    if (tipo == TipoImportacion.unidades) {
      csvContent = 'placas,modelo,anio,odometro,capacidad_tanque\n'
          'XYZ123,Kenworth T680,2022,150000,450\n'
          'ABC987,Freightliner Cascadia,2021,220000,400\n';
      filename = 'machote_unidades.csv';
    } else {
      csvContent = 'nombre,direccion,rfc,telefono,contacto\n'
          'Acme Corp,Av Reforma 222 CDMX,ACM123456789,5551234567,Juan Perez\n'
          'Logistica Sur,Periferico Sur 1000 CDMX,LOG987654321,5559876543,Maria Garcia\n';
      filename = 'machote_clientes.csv';
    }

    final bytes = utf8.encode(csvContent);
    descargar(bytes, filename);
  }

  /// Importa unidades. Columnas esperadas: placas, modelo, anio, odometro,
  /// capacidad_tanque (placas es obligatoria).
  static Future<ResultadoImportacion> importarUnidades(
      List<Map<String, String>> filas) async {
    final db = sl<FirestoreDatasource>();
    var creados = 0, omitidos = 0;
    final errores = <String>[];

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      final placas = (f['placas'] ?? f['placa'] ?? '').toUpperCase();
      if (placas.isEmpty) {
        omitidos++;
        errores.add('Fila ${i + 2}: sin placas, omitida');
        continue;
      }
      try {
        await db.crearUnidad({
          'placas': placas,
          'modelo': f['modelo'] ?? '',
          'anio': int.tryParse(f['anio'] ?? '') ?? 0,
          'estado': 'activa',
          'odometro': double.tryParse(f['odometro'] ?? '') ?? 0,
          'capacidad_tanque':
              double.tryParse(f['capacidad_tanque'] ?? f['tanque'] ?? '') ?? 0,
        });
        creados++;
      } catch (e) {
        omitidos++;
        errores.add('Fila ${i + 2} ($placas): $e');
      }
    }
    return ResultadoImportacion(
        creados: creados, omitidos: omitidos, errores: errores);
  }

  /// Importa clientes. Columnas esperadas: nombre, direccion, rfc, telefono,
  /// contacto (nombre es obligatorio). Geocodifica la dirección con Nominatim.
  static Future<ResultadoImportacion> importarClientes(
      List<Map<String, String>> filas) async {
    final repo = sl<IClienteRepository>();
    final geo = sl<GeocodingService>();
    var creados = 0, omitidos = 0;
    final errores = <String>[];

    for (var i = 0; i < filas.length; i++) {
      final f = filas[i];
      final nombre = f['nombre'] ?? f['razon_social'] ?? '';
      if (nombre.isEmpty) {
        omitidos++;
        errores.add('Fila ${i + 2}: sin nombre, omitida');
        continue;
      }
      final direccion = f['direccion'] ?? f['dirección'] ?? '';

      Map<String, dynamic>? posicion;
      if (direccion.isNotEmpty) {
        try {
          final res = await geo.buscarDireccion(direccion);
          if (res.isNotEmpty) {
            posicion = {'lat': res.first.lat, 'lng': res.first.lng};
          }
        } catch (_) {
          // Sin coordenadas — el cliente se crea igual
        }
        // Respetar el límite de 1 req/seg de Nominatim
        await Future.delayed(const Duration(milliseconds: 1100));
      }

      final data = <String, dynamic>{
        'nombre': nombre,
        'direccion': direccion,
        'rfc': (f['rfc'] ?? '').toUpperCase(),
        'telefono': f['telefono'] ?? f['teléfono'] ?? '',
        'contacto': f['contacto'] ?? '',
        'activo': true,
        if (posicion != null) 'posicion': posicion,
      };

      final result = await repo.crearCliente(data);
      result.fold(
        (failure) {
          omitidos++;
          errores.add('Fila ${i + 2} ($nombre): ${failure.message}');
        },
        (_) => creados++,
      );
    }
    return ResultadoImportacion(
        creados: creados, omitidos: omitidos, errores: errores);
  }
}
