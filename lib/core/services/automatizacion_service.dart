import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/foundation.dart' show debugPrint;

import '../constants/app_constants.dart';

/// Reemplazo costo-cero de las Cloud Functions de ciclo de vida.
///
/// El plan Spark de Firebase no permite desplegar Functions, así que esta
/// lógica (portada de functions/src/index.ts) corre en Torre de Control:
/// se ejecuta al abrir el dashboard y cada 5 minutos mientras esté abierto.
/// Las escrituras están protegidas por las reglas de Firestore (requieren
/// rol supervisor/administrador) y cada pieza es idempotente mediante los
/// flags `lc_iniciado` / `lc_completado` en el documento del viaje.
///
/// Limitación inherente: si ningún supervisor tiene el dashboard abierto,
/// el procesamiento queda pendiente hasta la siguiente sesión.
class AutomatizacionService {
  final fs.FirebaseFirestore _db;

  Timer? _timer;
  bool _corriendo = false;

  AutomatizacionService(this._db);

  void iniciar() {
    ejecutar();
    _timer ??= Timer.periodic(
      const Duration(minutes: 5),
      (_) => ejecutar(),
    );
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> ejecutar() async {
    if (_corriendo) return;
    _corriendo = true;
    try {
      await _procesarViajesEnCurso();
      await _procesarViajesCompletados();
      await _supervisarTicketsCombustible();
      await _normalizarClientes();
      await _marcarFacturasProveedorVencidas();
      await _alertarPolizasPorVencer();
      await _alertarStockMinimo();
      await _cierreMensualSiFalta();
      await _recalculoSemanalVarianzas();
    } catch (e) {
      debugPrint('[Automatizacion] Error general: $e');
    } finally {
      _corriendo = false;
    }
  }

  // ── Viaje → enCurso ────────────────────────────────────────────────────────
  // fecha_inicio, unidad enTransito y log de actividad (ex lifecycleViajeEnCurso)

  Future<void> _procesarViajesEnCurso() async {
    final snap = await _db
        .collection(AppConstants.colViajes)
        .where('estado', isEqualTo: 'enCurso')
        .limit(50)
        .get();

    for (final doc in snap.docs) {
      final v = doc.data();
      if (v['lc_iniciado'] == true) continue;

      final unidadId = (v['unidad_id'] ?? '') as String;
      final batch = _db.batch();

      batch.update(doc.reference, {
        'lc_iniciado': true,
        if (v['fecha_inicio'] == null)
          'fecha_inicio': fs.FieldValue.serverTimestamp(),
        'updated_at': fs.FieldValue.serverTimestamp(),
      });

      if (unidadId.isNotEmpty) {
        // El estado "en ruta" se deriva de viaje_activo_id — el enum de la
        // app solo maneja activa/mantenimiento/baja
        batch.update(
            _db.collection(AppConstants.colUnidades).doc(unidadId), {
          'viaje_activo_id':      doc.id,
          'ultima_actualizacion': fs.FieldValue.serverTimestamp(),
        });
      }

      batch.set(
          _db.collection(AppConstants.colActividadOperativa).doc(), {
        'tipo':        'viaje_iniciado',
        'viaje_id':    doc.id,
        'operador_id': v['operador_id'] ?? '',
        'unidad_id':   unidadId,
        'timestamp':   fs.FieldValue.serverTimestamp(),
        'metadata': {
          'origen_descripcion':  v['origen_descripcion'] ?? '',
          'destino_descripcion': v['destino_descripcion'] ?? '',
          'operador_nombre':     v['operador_nombre'] ?? '',
        },
      });

      try {
        await batch.commit();
        debugPrint('[Automatizacion] Viaje iniciado procesado: ${doc.id}');
      } catch (e) {
        debugPrint('[Automatizacion] Error en viaje ${doc.id}: $e');
      }
    }
  }

  // ── Viaje → completado ─────────────────────────────────────────────────────
  // TCO, liberar unidad, cerrar alertas, score y factura (ex lifecycleViajeCompletado)

  Future<void> _procesarViajesCompletados() async {
    final snap = await _db
        .collection(AppConstants.colViajes)
        .where('estado', isEqualTo: 'completado')
        .orderBy('updated_at', descending: true)
        .limit(25)
        .get();

    for (final doc in snap.docs) {
      if (doc.data()['lc_completado'] == true) continue;

      // Lock idempotente — si otro dashboard lo tomó primero, saltar
      final tomado = await _db.runTransaction((tx) async {
        final fresh = await tx.get(doc.reference);
        if (fresh.data()?['lc_completado'] == true) return false;
        tx.update(doc.reference, {'lc_completado': true});
        return true;
      });
      if (!tomado) continue;

      try {
        await _completarViaje(doc.id, doc.data());
        debugPrint('[Automatizacion] Viaje completado procesado: ${doc.id}');
      } catch (e) {
        debugPrint('[Automatizacion] Error al completar ${doc.id}: $e');
        await doc.reference
            .update({'lc_completado': false}).catchError((_) {});
      }
    }
  }

  Future<void> _completarViaje(String viajeId, Map<String, dynamic> v) async {
    final unidadId       = (v['unidad_id'] ?? '') as String;
    final operadorId     = (v['operador_id'] ?? '') as String;
    final operadorNombre = (v['operador_nombre'] ?? operadorId) as String;
    final odometroFin    = ((v['odometro_fin'] ?? 0) as num).toDouble();
    final odometroInicio = ((v['odometro_inicio'] ?? 0) as num).toDouble();
    final tieneBanderaRoja = v['nivel_alerta'] == 'bandajaRoja';

    // 1. TCO final desde costos_operativos
    final costosSnap = await _db
        .collection(AppConstants.colCostosOperativos)
        .where('viaje_id', isEqualTo: viajeId)
        .get();

    double combustible = 0, mantenimiento = 0, peajes = 0, grua = 0, otros = 0;
    for (final c in costosSnap.docs) {
      final tipo  = c.data()['tipo'] as String? ?? '';
      final monto = ((c.data()['monto'] ?? 0) as num).toDouble();
      switch (tipo) {
        case 'diesel':
        case 'combustible':  combustible   += monto;
        case 'mantenimiento': mantenimiento += monto;
        case 'peaje':         peajes        += monto;
        case 'grua':          grua          += monto;
        default:              otros         += monto;
      }
    }
    final total = combustible + mantenimiento + peajes + grua + otros;
    final distanciaKm = (odometroFin - odometroInicio).clamp(0, double.infinity);
    final costoPorKm  = distanciaKm > 0 ? total / distanciaKm : 0.0;

    // 2. Actualizar viaje
    await _db.collection(AppConstants.colViajes).doc(viajeId).update({
      'tco': {
        'combustible':   combustible,
        'mantenimiento': mantenimiento,
        'peajes':        peajes,
        'grua':          grua,
        'otros':         otros,
        'total':         total,
      },
      'costo_por_km': costoPorKm,
      if (v['fecha_fin'] == null)
        'fecha_fin': fs.FieldValue.serverTimestamp(),
      'updated_at': fs.FieldValue.serverTimestamp(),
    });

    // 3. Liberar unidad (mantenimiento si alcanzó el odómetro programado)
    if (unidadId.isNotEmpty) {
      final unidadRef =
          _db.collection(AppConstants.colUnidades).doc(unidadId);
      final unidadSnap = await unidadRef.get();
      final proxMant =
          ((unidadSnap.data()?['proximo_mantenimiento_odometro'] ?? 0) as num)
              .toDouble();
      final necesitaMant =
          odometroFin > 0 && proxMant > 0 && odometroFin >= proxMant;
      await unidadRef.update({
        'estado':               necesitaMant ? 'mantenimiento' : 'activa',
        'viaje_activo_id':      null,
        if (odometroFin > 0) 'odometro': odometroFin,
        'ultima_actualizacion': fs.FieldValue.serverTimestamp(),
      });
    }

    // 4. Cerrar alertas activas del viaje
    final alertasSnap = await _db
        .collection(AppConstants.colAlertasSeguridad)
        .where('viaje_id', isEqualTo: viajeId)
        .where('estado', isEqualTo: 'activa')
        .get();
    if (alertasSnap.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final a in alertasSnap.docs) {
        batch.update(a.reference, {
          'estado':       'cerrada_automaticamente',
          'fecha_cierre': fs.FieldValue.serverTimestamp(),
          'notas':        'Cerrada automáticamente al completar el viaje.',
        });
      }
      await batch.commit();
    }

    // 5. Score del operador
    if (operadorId.isNotEmpty) {
      await _actualizarScoreOperador(
          operadorId, operadorNombre, tieneBanderaRoja);
    }

    // 6. Factura del cliente (idempotente, folio GL-YYYY-XXXX transaccional)
    await _generarFacturaSiFalta(viajeId, v, total);

    // 7. Log de actividad
    await _db.collection(AppConstants.colActividadOperativa).add({
      'tipo':        'viaje_completado',
      'viaje_id':    viajeId,
      'operador_id': operadorId,
      'unidad_id':   unidadId,
      'timestamp':   fs.FieldValue.serverTimestamp(),
      'metadata': {
        'tco_total':          total,
        'costo_por_km':       costoPorKm,
        'distancia_km':       distanciaKm,
        'operador_nombre':    operadorNombre,
        'tenia_bandera_roja': tieneBanderaRoja,
        'alertas_cerradas':   alertasSnap.size,
      },
    });
  }

  // ── Score de operadores (ex _actualizarScoreOperador) ─────────────────────

  double _calcularScore(int viajesCompletados, int totalViajes,
      int alertasSOS, int banderasRojas) {
    if (totalViajes == 0) return 100;
    final completitud = viajesCompletados / totalViajes;
    final sosRate     = (alertasSOS / totalViajes).clamp(0.0, 1.0);
    final banderaRate = (banderasRojas / totalViajes).clamp(0.0, 1.0);
    return (completitud * 60 + (1 - sosRate) * 25 + (1 - banderaRate) * 15)
        .clamp(0.0, 100.0);
  }

  Future<void> _actualizarScoreOperador(String operadorId,
      String operadorNombre, bool tieneBanderaRoja) async {
    final ref = _db.collection('scores_operadores').doc(operadorId);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data() ?? {};
      final totalViajes       = ((d['total_viajes'] ?? 0) as num).toInt() + 1;
      final viajesCompletados =
          ((d['viajes_completados'] ?? 0) as num).toInt() + 1;
      final alertasSOS    = ((d['alertas_sos'] ?? 0) as num).toInt();
      final banderasRojas = ((d['banderas_rojas'] ?? 0) as num).toInt() +
          (tieneBanderaRoja ? 1 : 0);
      final score = _calcularScore(
          viajesCompletados, totalViajes, alertasSOS, banderasRojas);
      tx.set(ref, {
        'operador_id':        operadorId,
        'operador_nombre':    operadorNombre,
        'total_viajes':       totalViajes,
        'viajes_completados': viajesCompletados,
        'alertas_sos':        alertasSOS,
        'banderas_rojas':     banderasRojas,
        'score':              score.round(),
        'ultimo_viaje_at':    fs.FieldValue.serverTimestamp(),
        'updated_at':         fs.FieldValue.serverTimestamp(),
      });
    });
  }

  // ── Facturación automática (ex generarFacturaViaje) ───────────────────────

  Future<void> _generarFacturaSiFalta(
      String viajeId, Map<String, dynamic> v, double tcoTotal) async {
    final existente = await _db
        .collection('facturas_clientes')
        .where('viaje_id', isEqualTo: viajeId)
        .limit(1)
        .get();
    if (existente.docs.isNotEmpty) return;

    // Parámetros configurados en el wizard de onboarding (config/pricing)
    final pricing = (await _db.collection('config').doc('pricing').get()).data();
    final margenPct   = ((pricing?['margen_pct']   ?? 0.15) as num).toDouble();
    final ivaPct      = ((pricing?['iva_pct']      ?? 0) as num).toDouble();
    final diasCredito = ((pricing?['dias_credito'] ?? 30) as num).toInt();
    final serie       = (pricing?['serie_folio']   ?? 'GL') as String;

    final subtotal = tcoTotal * (1 + margenPct);
    final total    = double.parse((subtotal * (1 + ivaPct)).toStringAsFixed(2));

    final anio = DateTime.now().year;
    final numeroFactura = await _db.runTransaction((tx) async {
      final contadorRef =
          _db.collection('config').doc('factura_contador_$anio');
      final contadorSnap = await tx.get(contadorRef);
      final siguiente =
          ((contadorSnap.data()?['ultimo'] ?? 0) as num).toInt() + 1;
      tx.set(contadorRef, {'ultimo': siguiente}, fs.SetOptions(merge: true));
      return '$serie-$anio-${siguiente.toString().padLeft(4, '0')}';
    });

    final emision     = DateTime.now();
    final vencimiento = emision.add(Duration(days: diasCredito));

    await _db.collection('facturas_clientes').add({
      'viaje_id':          viajeId,
      'cliente_id':        v['cliente_id'] ?? '',
      'cliente_nombre':    v['cliente_nombre'] ?? 'Cliente',
      'numero_factura':    numeroFactura,
      'fecha_emision':     fs.Timestamp.fromDate(emision),
      'fecha_vencimiento': fs.Timestamp.fromDate(vencimiento),
      'monto':             total,
      'subtotal':          double.parse(subtotal.toStringAsFixed(2)),
      'iva_pct':           ivaPct,
      'monto_cobrado':     null,
      'estatus':           'pendiente',
      'fecha_cobro':       null,
      'carta_porte_uuid':  null,
      'tco_base':          tcoTotal,
      'margen_pct':        margenPct,
      'created_at':        fs.FieldValue.serverTimestamp(),
    });
  }

  // ── Cuentas por pagar vencidas (ex vencimientosCxP) ───────────────────────

  Future<void> _marcarFacturasProveedorVencidas() async {
    final hoy = fs.Timestamp.now();
    final snap = await _db
        .collection('facturas_proveedores')
        .where('estatus', isEqualTo: 'pendiente')
        .where('fecha_vencimiento', isLessThan: hoy)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'estatus':    'vencida',
        'updated_at': fs.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    debugPrint(
        '[Automatizacion] ${snap.size} factura(s) de proveedor vencida(s)');
  }

  // ── Supervisión de tickets de combustible (ex onTicketCombustibleCreado) ──
  // Detecta recargas que exceden el 110 % de los litros cargados del viaje.

  Future<void> _supervisarTicketsCombustible() async {
    final snap = await _db
        .collection(AppConstants.colCostosOperativos)
        .where('tipo', isEqualTo: 'combustible')
        .orderBy('created_at', descending: true)
        .limit(50)
        .get();

    for (final doc in snap.docs) {
      final c = doc.data();
      if (c['supervisado'] == true) continue;

      final viajeId = c['viaje_id'] as String? ?? '';
      final litros  = ((c['litros'] ?? 0) as num).toDouble();
      if (viajeId.isEmpty) continue;

      final viajeSnap =
          await _db.collection(AppConstants.colViajes).doc(viajeId).get();
      if (!viajeSnap.exists) continue;
      final v = viajeSnap.data()!;
      final litrosCargados = ((v['litros_cargados'] ?? 0) as num).toDouble();

      final esAnomalia = litrosCargados > 0 && litros > litrosCargados * 1.1;

      await doc.reference.update({
        'supervisado':        true,
        'anomalia_detectada': esAnomalia,
        if (esAnomalia)
          'anomalia_motivo':
              'Litros registrados (${litros.toStringAsFixed(1)} L) superan el '
              '110% de la carga del viaje (${litrosCargados.toStringAsFixed(1)} L)',
      });

      if (esAnomalia) {
        await _db.collection(AppConstants.colAlertasSeguridad).add({
          'tipo':        'ticketAnomalo',
          'estado':      'activa',
          'viaje_id':    viajeId,
          'operador_id': v['operador_id'] ?? '',
          'unidad_id':   v['unidad_id'] ?? '',
          'timestamp':   fs.FieldValue.serverTimestamp(),
          'metadata': {
            'costo_id':        doc.id,
            'litros_ticket':   litros,
            'litros_cargados': litrosCargados,
          },
        });
        debugPrint(
            '[Automatizacion] Ticket anómalo en viaje $viajeId: $litros L');
      }
    }
  }

  // ── Normalización y validación de clientes (ex onClienteCreado) ───────────
  // RFC en mayúsculas + formato SAT + duplicados; nombre_busqueda para filtros.

  static final _rfcRegex = RegExp(r'^[A-ZÑ&]{3,4}\d{6}[A-Z\d]{3}$');

  Future<void> _normalizarClientes() async {
    final snap =
        await _db.collection(AppConstants.colClientes).limit(50).get();

    for (final doc in snap.docs) {
      final c = doc.data();
      final updates = <String, dynamic>{};

      final nombre = c['nombre'] as String? ?? '';
      if (nombre.isNotEmpty && c['nombre_busqueda'] == null) {
        updates['nombre_busqueda'] = nombre.toLowerCase().trim();
      }

      final rfc = (c['rfc'] as String? ?? '').toUpperCase().trim();
      if (rfc.isNotEmpty && c['rfc_valido'] == null) {
        if (!_rfcRegex.hasMatch(rfc)) {
          updates['rfc_valido'] = false;
          updates['rfc_invalido_motivo'] = 'Formato incorrecto';
        } else {
          updates['rfc_valido'] = true;
          updates['rfc'] = rfc;
          final duplicados = await _db
              .collection(AppConstants.colClientes)
              .where('rfc', isEqualTo: rfc)
              .where('activo', isEqualTo: true)
              .get();
          updates['rfc_duplicado'] = duplicados.size > 1;
        }
      }

      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
      }
    }
  }

  // ── Pólizas por vencer (ex vencimientoPolizasSeguro) ──────────────────────

  Future<void> _alertarPolizasPorVencer() async {
    final limite = fs.Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)));
    final polizasSnap = await _db
        .collection('polizas_seguro')
        .where('vigencia_fin', isLessThanOrEqualTo: limite)
        .get();

    for (final doc in polizasSnap.docs) {
      final d = doc.data();
      final existente = await _db
          .collection(AppConstants.colAlertasSeguridad)
          .where('tipo', isEqualTo: 'polizaPorVencer')
          .where('poliza_id', isEqualTo: doc.id)
          .where('estado', isEqualTo: 'activa')
          .limit(1)
          .get();
      if (existente.docs.isNotEmpty) continue;

      await _db.collection(AppConstants.colAlertasSeguridad).add({
        'tipo':      'polizaPorVencer',
        'estado':    'activa',
        'poliza_id': doc.id,
        'unidad_id': d['unidad_id'] ?? 'N/A',
        'timestamp': fs.FieldValue.serverTimestamp(),
        'metadata': {
          'numero_poliza': d['numero_poliza'] ?? 'N/A',
          'vigencia_fin':  d['vigencia_fin'],
        },
      });
    }
  }

  // ── Stock mínimo de inventario (ex alertaStockMinimo) ─────────────────────

  Future<void> _alertarStockMinimo() async {
    final snap = await _db.collection('inventario').get();

    for (final doc in snap.docs) {
      final d = doc.data();
      final stockActual = ((d['stock_actual'] ?? 0) as num).toDouble();
      final stockMinimo = ((d['stock_minimo'] ?? 0) as num).toDouble();
      if (stockMinimo <= 0 || stockActual > stockMinimo) continue;

      final existente = await _db
          .collection(AppConstants.colAlertasSeguridad)
          .where('tipo', isEqualTo: 'stockMinimo')
          .where('item_id', isEqualTo: doc.id)
          .where('estado', isEqualTo: 'activa')
          .limit(1)
          .get();

      if (existente.docs.isNotEmpty) {
        // Mantener actualizado el stock en la alerta existente
        await existente.docs.first.reference.update({
          'metadata.stock_actual': stockActual,
          'metadata.stock_minimo': stockMinimo,
        });
        continue;
      }

      await _db.collection(AppConstants.colAlertasSeguridad).add({
        'tipo':      'stockMinimo',
        'estado':    'activa',
        'item_id':   doc.id,
        'timestamp': fs.FieldValue.serverTimestamp(),
        'metadata': {
          'nombre_item':  d['nombre'] ?? doc.id,
          'stock_actual': stockActual,
          'stock_minimo': stockMinimo,
        },
      });
    }
  }

  // ── Cierre mensual de activos fijos (ex cierreMensual scheduled) ──────────
  // Genera el resumen del mes anterior una sola vez (idempotente por doc id).

  Future<void> _cierreMensualSiFalta() async {
    final ahora = DateTime.now();
    final prev  = DateTime(ahora.year, ahora.month - 1, 1);
    final mes   = '${prev.year}-${prev.month.toString().padLeft(2, '0')}';

    final resumenRef =
        _db.collection('resumenes_financieros').doc(mes);
    if ((await resumenRef.get()).exists) return;

    final activosSnap = await _db.collection('activos_fijos').get();

    double deprMensualTotal = 0;
    double valorLibrosTotal = 0;
    int activosEnAlerta = 0;

    for (final doc in activosSnap.docs) {
      final d = doc.data();
      final vidaAnios = ((d['vida_util_anios'] ?? 10) as num).toInt();
      final costo     = ((d['costo_adquisicion'] ?? 0) as num).toDouble();
      final residual  = ((d['valor_residual'] ?? 0) as num).toDouble();
      final fechaAdq  = (d['fecha_adquisicion'] as fs.Timestamp?)?.toDate();
      if (fechaAdq == null || vidaAnios <= 0) continue;

      final deprMensual = (costo - residual) / vidaAnios / 12;
      final mesesTranscurridos = ((ahora.year - fechaAdq.year) * 12 +
              ahora.month -
              fechaAdq.month)
          .clamp(0, vidaAnios * 12);
      final valorLibros =
          (costo - deprMensual * mesesTranscurridos).clamp(residual, costo);
      final pctDepr = (costo - residual) > 0
          ? (costo - valorLibros) / (costo - residual)
          : 1.0;

      deprMensualTotal += deprMensual;
      valorLibrosTotal += valorLibros;
      if (pctDepr >= 0.8) activosEnAlerta++;
    }

    await resumenRef.set({
      'periodo_id':                 mes,
      'depreciacion_mensual_flota': deprMensualTotal,
      'valor_libros_flota':         valorLibrosTotal,
      'activos_en_alerta':          activosEnAlerta,
      'total_activos':              activosSnap.size,
      'generado_at':                fs.FieldValue.serverTimestamp(),
    });
    debugPrint('[Automatizacion] Cierre mensual generado: $mes');
  }

  // ── Recálculo semanal anti-drift (ex recalcularAuditoriasSemanales) ───────
  // Reaudita la varianza de viajes con bandera desde los costos originales.

  Future<void> _recalculoSemanalVarianzas() async {
    final cfgRef = _db.collection('config').doc('automatizacion');
    final cfg = (await cfgRef.get()).data();
    final ultimo =
        (cfg?['recalculo_varianzas_at'] as fs.Timestamp?)?.toDate();
    if (ultimo != null &&
        DateTime.now().difference(ultimo).inDays < 7) {
      return;
    }

    final snap = await _db
        .collection(AppConstants.colViajes)
        .where('estado', isEqualTo: 'completado')
        .orderBy('updated_at', descending: true)
        .limit(50)
        .get();

    for (final doc in snap.docs) {
      final v = doc.data();
      // Solo viajes que quedaron marcados con alerta
      final nivel = v['nivel_alerta'] as String? ?? '';
      if (nivel != 'bandajaRoja' &&
          nivel != 'sospechoso' &&
          nivel != 'fraudeProbable') {
        continue;
      }

      final costosSnap = await _db
          .collection(AppConstants.colCostosOperativos)
          .where('viaje_id', isEqualTo: doc.id)
          .get();

      double litrosTickets = 0;
      for (final c in costosSnap.docs) {
        final d = c.data();
        if (d['tipo'] != 'diesel' && d['tipo'] != 'combustible') continue;
        litrosTickets +=
            ((d['datos_ocr']?['litros_detectados'] ?? d['litros'] ?? 0) as num)
                .toDouble();
      }
      if (litrosTickets <= 0) continue;

      final rendimiento =
          ((v['rendimiento_base'] ?? 3.5) as num).toDouble();
      final distanciaKm = (((v['odometro_fin'] ?? 0) as num) -
              ((v['odometro_inicio'] ?? 0) as num))
          .toDouble()
          .clamp(0.0, double.infinity);
      final litrosTelemetria =
          distanciaKm > 0 ? distanciaKm / rendimiento : litrosTickets;

      final tolerancia =
          [0.3, litrosTelemetria * 0.02].reduce((a, b) => a > b ? a : b);
      final delta = litrosTelemetria - litrosTickets;
      final varianzaPct = litrosTelemetria > 0
          ? (delta.abs() / litrosTelemetria) * 100
          : 0.0;

      // Vocabulario del app: ninguna / advertencia / bandajaRoja
      final String nuevoNivel;
      if (delta.abs() <= tolerancia || varianzaPct <= 1.5) {
        nuevoNivel = 'ninguna';
      } else if (varianzaPct <= 5.0) {
        nuevoNivel = 'advertencia';
      } else {
        nuevoNivel = 'bandajaRoja';
      }

      if (nuevoNivel != nivel) {
        await doc.reference.update({
          'varianza_combustible': varianzaPct / 100,
          'nivel_alerta':         nuevoNivel,
          'updated_at':           fs.FieldValue.serverTimestamp(),
        });
        debugPrint(
            '[Automatizacion] Varianza recalculada ${doc.id}: $nivel → $nuevoNivel');
      }
    }

    await cfgRef.set(
        {'recalculo_varianzas_at': fs.FieldValue.serverTimestamp()},
        fs.SetOptions(merge: true));
  }
}
