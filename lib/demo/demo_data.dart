import '../domain/entities/cliente.dart';
import '../domain/entities/unidad.dart';
import '../domain/entities/viaje.dart';

abstract final class DemoData {
  // ── Viajes ────────────────────────────────────────────────────────────────

  static final List<Viaje> viajes = [
    Viaje(
      id: 'v001',
      unidadId: 'u001',
      operadorId: 'op001',
      origenDescripcion: 'CDMX — Bodega Central Vallejo',
      destinoDescripcion: 'Monterrey — Centro de Distribución',
      estado: EstadoViaje.enCurso,
      litrosCargados: 280,
      litrosConsumiidosTelemetria: 143,
      litrosConsumiidosTickets: 158,
      varianzaCombustible: 0.095,
      nivelAlerta: NivelAlertaViaje.bandajaRoja,
      tco: const TcoViaje(
        combustible:   14220,
        mantenimiento: 1800,
        peajes:        540,
        otros:         320,
      ),
      fechaInicio: DateTime(2026, 6, 5, 8, 30),
      createdAt:   DateTime(2026, 6, 5, 7, 45),
      updatedAt:   DateTime(2026, 6, 5, 11, 20),
    ),
    Viaje(
      id: 'v002',
      unidadId: 'u002',
      operadorId: 'op002',
      origenDescripcion: 'Guadalajara — Planta Los Altos',
      destinoDescripcion: 'CDMX — Bodega Sur Iztapalapa',
      estado: EstadoViaje.enCurso,
      litrosCargados: 220,
      litrosConsumiidosTelemetria: 86,
      litrosConsumiidosTickets: 87,
      varianzaCombustible: 0.012,
      nivelAlerta: NivelAlertaViaje.ninguna,
      tco: const TcoViaje(
        combustible:   9570,
        mantenimiento: 950,
        peajes:        480,
        otros:         150,
      ),
      fechaInicio: DateTime(2026, 6, 5, 6, 0),
      createdAt:   DateTime(2026, 6, 4, 23, 0),
      updatedAt:   DateTime(2026, 6, 5, 10, 45),
    ),
    Viaje(
      id: 'v003',
      unidadId: 'u003',
      operadorId: 'op003',
      origenDescripcion: 'Querétaro — CEDIS Norte',
      destinoDescripcion: 'León — Almacén Industrial',
      estado: EstadoViaje.programado,
      litrosCargados: 0,
      litrosConsumiidosTelemetria: 0,
      litrosConsumiidosTickets: 0,
      nivelAlerta: NivelAlertaViaje.ninguna,
      tco: const TcoViaje(),
      createdAt: DateTime(2026, 6, 5, 9, 0),
      updatedAt: DateTime(2026, 6, 5, 9, 0),
    ),
    Viaje(
      id: 'v004',
      unidadId: 'u004',
      operadorId: 'op004',
      origenDescripcion: 'Tijuana — Puerto de Entrada',
      destinoDescripcion: 'Hermosillo — Planta Norte',
      estado: EstadoViaje.enCurso,
      litrosCargados: 350,
      litrosConsumiidosTelemetria: 190,
      litrosConsumiidosTickets: 191,
      varianzaCombustible: 0.005,
      nivelAlerta: NivelAlertaViaje.ninguna,
      tco: const TcoViaje(
        combustible:   18900,
        mantenimiento: 2100,
        peajes:        920,
        otros:         430,
      ),
      fechaInicio: DateTime(2026, 6, 4, 22, 0),
      createdAt:   DateTime(2026, 6, 4, 20, 30),
      updatedAt:   DateTime(2026, 6, 5, 8, 15),
    ),
  ];

  // ── Unidades ─────────────────────────────────────────────────────────────

  static final List<Unidad> unidades = [
    Unidad(
      id: 'u001',
      placas: 'ABC-123-D',
      modelo: 'Kenworth T680',
      anio: 2021,
      estado: EstadoUnidad.activa,
      operadorAsignadoId: 'op001',
      ultimaPosicion:
          const GeoPoint(lat: 22.1565, lng: -100.9855), // SLP
      odometro: 148320,
      proximoMantenimientoOdometro: 150000,
      capacidadTanqueLitros: 800,
    ),
    Unidad(
      id: 'u002',
      placas: 'XYZ-456-E',
      modelo: 'Freightliner Cascadia',
      anio: 2022,
      estado: EstadoUnidad.activa,
      operadorAsignadoId: 'op002',
      ultimaPosicion:
          const GeoPoint(lat: 20.6597, lng: -103.3496), // GDL
      odometro: 89450,
      proximoMantenimientoOdometro: 90000,
      capacidadTanqueLitros: 750,
    ),
    Unidad(
      id: 'u003',
      placas: 'QRS-789-F',
      modelo: 'Volvo FH',
      anio: 2020,
      estado: EstadoUnidad.mantenimiento,
      operadorAsignadoId: 'op003',
      ultimaPosicion:
          const GeoPoint(lat: 20.5881, lng: -100.3899), // QRO
      odometro: 212100,
      proximoMantenimientoOdometro: 212500, // Requiere servicio! (< 500)
      capacidadTanqueLitros: 700,
    ),
    Unidad(
      id: 'u004',
      placas: 'TUV-012-G',
      modelo: 'Peterbilt 579',
      anio: 2023,
      estado: EstadoUnidad.activa,
      operadorAsignadoId: 'op004',
      ultimaPosicion:
          const GeoPoint(lat: 30.6995, lng: -112.0887), // Hermosillo
      odometro: 34780,
      proximoMantenimientoOdometro: 40000,
      capacidadTanqueLitros: 900,
    ),
  ];

  // ── Clientes ─────────────────────────────────────────────────────────────

  static final List<Cliente> clientes = [
    const Cliente(
      id: 'c001',
      nombre: 'Bodega Norte — Monterrey',
      direccion: 'Av. Constitución 145, Monterrey, N.L.',
      posicion: GeoPoint(lat: 25.6866, lng: -100.3161),
      telefono: '+52 81 8888 0001',
      contacto: 'Ing. Ramírez',
    ),
    const Cliente(
      id: 'c002',
      nombre: 'Centro Distribución GDL',
      direccion: 'Blvd. Adolfo López Mateos 340, Guadalajara, Jal.',
      posicion: GeoPoint(lat: 20.6597, lng: -103.3496),
      telefono: '+52 33 7777 0002',
      contacto: 'Lic. Flores',
    ),
    const Cliente(
      id: 'c003',
      nombre: 'Almacén Industrial León',
      direccion: 'Blvd. López Mateos Nte. 2208, León, Gto.',
      posicion: GeoPoint(lat: 21.1619, lng: -101.6824),
      telefono: '+52 47 7120 0003',
      contacto: 'Sr. Castro',
    ),
    const Cliente(
      id: 'c004',
      nombre: 'CEDIS Sur CDMX',
      direccion: 'Eje Central Lázaro Cárdenas 911, Iztapalapa, CDMX',
      posicion: GeoPoint(lat: 19.3643, lng: -99.0862),
      telefono: '+52 55 5555 0004',
      contacto: 'Dra. Mendoza',
    ),
    const Cliente(
      id: 'c005',
      nombre: 'Planta Bajío Querétaro',
      direccion: 'Av. 5 de Febrero 102, Querétaro, Qro.',
      posicion: GeoPoint(lat: 20.5888, lng: -100.3899),
      telefono: '+52 44 2200 0005',
      contacto: 'Ing. Ortega',
    ),
    const Cliente(
      id: 'c006',
      nombre: 'Puerto Seco San Luis',
      direccion: 'Carretera 57 Km. 3.5, San Luis Potosí, S.L.P.',
      posicion: GeoPoint(lat: 22.1566, lng: -100.9855),
      telefono: '+52 44 4812 0006',
      contacto: 'C.P. Gutiérrez',
    ),
    const Cliente(
      id: 'c007',
      nombre: 'Centro Logístico Hermosillo',
      direccion: 'Blvd. Solidaridad 203, Hermosillo, Son.',
      posicion: GeoPoint(lat: 29.0729, lng: -110.9559),
      telefono: '+52 66 2214 0007',
      contacto: 'Sr. Valenzuela',
    ),
    const Cliente(
      id: 'c008',
      nombre: 'Distribuidora Frontera',
      direccion: 'Av. Internacional 1401, Tijuana, B.C.',
      posicion: GeoPoint(lat: 32.5340, lng: -116.9320),
      telefono: '+52 66 4680 0008',
      contacto: 'Lic. Morales',
    ),
  ];

  // ── Alertas ───────────────────────────────────────────────────────────────

  static final List<Map<String, dynamic>> alertas = [
    {
      'id':          'a001',
      'tipo':        'sos',
      'estado':      'activa',
      'viaje_id':    'v001',
      'operador_id': 'Carlos M. (op001)',
      'unidad_id':   'u001',
      'posicion':    {'lat': 22.1565, 'lng': -100.9855},
    },
    {
      'id':          'a002',
      'tipo':        'varianzaCombustible',
      'estado':      'activa',
      'viaje_id':    'v001',
      'operador_id': 'Carlos M. (op001)',
      'unidad_id':   'u001',
      'posicion':    {'lat': 22.1565, 'lng': -100.9855},
    },
  ];
}
