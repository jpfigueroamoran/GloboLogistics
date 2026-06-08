/**
 * ═══════════════════════════════════════════════════════
 * GLOBO LOGISTICS — Seed de Firestore
 * Uso: node seed_database.js <UID_ADMIN>
 *
 * Requiere: scripts/serviceAccountKey.json
 * Descarga desde: Firebase Console → Project Settings →
 *   Service accounts → Generate new private key
 * ═══════════════════════════════════════════════════════
 */

const admin = require('firebase-admin');
const path  = require('path');

// ── Validar argumentos ────────────────────────────────────────────────────────

const adminUid = process.argv[2];
if (!adminUid) {
  console.error('\n❌  Falta el UID del administrador.');
  console.error('    Uso: node seed_database.js <UID_ADMIN>\n');
  console.error('    Encuéntralo en: Firebase Console → Authentication → Users\n');
  process.exit(1);
}

// ── Inicializar Firebase Admin ────────────────────────────────────────────────

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
let serviceAccount;
try {
  serviceAccount = require(keyPath);
} catch {
  console.error('\n❌  No se encontró serviceAccountKey.json en la carpeta scripts/');
  console.error('    Descárgalo desde:');
  console.error('    Firebase Console → Project Settings → Service accounts → Generate new private key\n');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// ── Datos ────────────────────────────────────────────────────────────────────

const now = admin.firestore.Timestamp.now();

const usuarios = [
  {
    id: adminUid,
    data: {
      email:          'juanpablo@el-globo.net',
      nombre:         'Juan Pablo',
      rol:            'administrador',
      activo:         true,
      ultimo_acceso:  null,
    },
  },
  {
    id: 'demo-op001',
    data: {
      email:              'carlos.mendez@el-globo.net',
      nombre:             'Carlos Méndez',
      rol:                'operador',
      activo:             true,
      unidad_asignada_id: 'u001',
      ultimo_acceso:      null,
    },
  },
  {
    id: 'demo-op002',
    data: {
      email:              'sofia.ramirez@el-globo.net',
      nombre:             'Sofía Ramírez',
      rol:                'operador',
      activo:             true,
      unidad_asignada_id: 'u002',
      ultimo_acceso:      null,
    },
  },
  {
    id: 'demo-op003',
    data: {
      email:              'miguel.torres@el-globo.net',
      nombre:             'Miguel Torres',
      rol:                'operador',
      activo:             true,
      unidad_asignada_id: 'u003',
      ultimo_acceso:      null,
    },
  },
  {
    id: 'demo-op004',
    data: {
      email:              'ana.garcia@el-globo.net',
      nombre:             'Ana García',
      rol:                'supervisor',
      activo:             true,
      ultimo_acceso:      null,
    },
  },
];

const unidades = [
  {
    id: 'u001',
    data: {
      placas:                         'ABC-123-D',
      modelo:                         'Kenworth T680',
      anio:                           2021,
      estado:                         'activa',
      operador_asignado_id:           'demo-op001',
      ultima_posicion:                new admin.firestore.GeoPoint(22.1565, -100.9855),
      ultima_actualizacion_posicion:  now,
      odometro:                       148320,
      capacidad_tanque_litros:        800,
    },
  },
  {
    id: 'u002',
    data: {
      placas:                         'XYZ-456-E',
      modelo:                         'Freightliner Cascadia',
      anio:                           2022,
      estado:                         'activa',
      operador_asignado_id:           'demo-op002',
      ultima_posicion:                new admin.firestore.GeoPoint(20.6597, -103.3496),
      ultima_actualizacion_posicion:  now,
      odometro:                       89450,
      capacidad_tanque_litros:        750,
    },
  },
  {
    id: 'u003',
    data: {
      placas:                         'QRS-789-F',
      modelo:                         'Volvo FH',
      anio:                           2020,
      estado:                         'mantenimiento',
      operador_asignado_id:           'demo-op003',
      ultima_posicion:                new admin.firestore.GeoPoint(20.5881, -100.3899),
      ultima_actualizacion_posicion:  now,
      odometro:                       212100,
      capacidad_tanque_litros:        700,
    },
  },
  {
    id: 'u004',
    data: {
      placas:                         'TUV-012-G',
      modelo:                         'Peterbilt 579',
      anio:                           2023,
      estado:                         'activa',
      operador_asignado_id:           null,
      ultima_posicion:                new admin.firestore.GeoPoint(30.6995, -112.0887),
      ultima_actualizacion_posicion:  now,
      odometro:                       34780,
      capacidad_tanque_litros:        900,
    },
  },
];

const viajes = [
  {
    id: 'v001',
    data: {
      unidad_id:                    'u001',
      operador_id:                  'demo-op001',
      origen_descripcion:           'CDMX — Bodega Central Vallejo',
      destino_descripcion:          'Monterrey — Centro de Distribución',
      estado:                       'enCurso',
      litros_cargados:              280,
      litros_consumidos_telemetria: 143,
      litros_consumidos_tickets:    158,
      varianza_combustible:         0.095,
      nivel_alerta:                 'bandajaRoja',
      tco: {
        combustible:    14220,
        mantenimiento:  1800,
        peajes:         540,
        grua:           0,
        otros:          320,
        total:          16880,
      },
      fecha_inicio: admin.firestore.Timestamp.fromDate(new Date('2026-06-05T08:30:00')),
      created_at:   admin.firestore.Timestamp.fromDate(new Date('2026-06-05T07:45:00')),
      updated_at:   now,
    },
  },
  {
    id: 'v002',
    data: {
      unidad_id:                    'u002',
      operador_id:                  'demo-op002',
      origen_descripcion:           'Guadalajara — Planta Los Altos',
      destino_descripcion:          'CDMX — Bodega Sur Iztapalapa',
      estado:                       'enCurso',
      litros_cargados:              220,
      litros_consumidos_telemetria: 86,
      litros_consumidos_tickets:    87,
      varianza_combustible:         0.012,
      nivel_alerta:                 'ninguna',
      tco: {
        combustible:    9570,
        mantenimiento:  950,
        peajes:         480,
        grua:           0,
        otros:          150,
        total:          11150,
      },
      fecha_inicio: admin.firestore.Timestamp.fromDate(new Date('2026-06-05T06:00:00')),
      created_at:   admin.firestore.Timestamp.fromDate(new Date('2026-06-04T23:00:00')),
      updated_at:   now,
    },
  },
  {
    id: 'v003',
    data: {
      unidad_id:                    'u003',
      operador_id:                  'demo-op003',
      origen_descripcion:           'Querétaro — CEDIS Norte',
      destino_descripcion:          'León — Almacén Industrial',
      estado:                       'programado',
      litros_cargados:              0,
      litros_consumidos_telemetria: 0,
      litros_consumidos_tickets:    0,
      varianza_combustible:         0,
      nivel_alerta:                 'ninguna',
      tco: { combustible: 0, mantenimiento: 0, peajes: 0, grua: 0, otros: 0, total: 0 },
      created_at: now,
      updated_at: now,
    },
  },
  {
    id: 'v004',
    data: {
      unidad_id:                    'u004',
      operador_id:                  'demo-op004',
      origen_descripcion:           'Tijuana — Puerto de Entrada',
      destino_descripcion:          'Hermosillo — Planta Norte',
      estado:                       'enCurso',
      litros_cargados:              350,
      litros_consumidos_telemetria: 190,
      litros_consumidos_tickets:    191,
      varianza_combustible:         0.005,
      nivel_alerta:                 'ninguna',
      tco: {
        combustible:    18900,
        mantenimiento:  2100,
        peajes:         920,
        grua:           0,
        otros:          430,
        total:          22350,
      },
      fecha_inicio: admin.firestore.Timestamp.fromDate(new Date('2026-06-04T22:00:00')),
      created_at:   admin.firestore.Timestamp.fromDate(new Date('2026-06-04T20:30:00')),
      updated_at:   now,
    },
  },
];

const clientes = [
  {
    id: 'c001',
    data: {
      nombre:   'Bodega Norte — Monterrey',
      direccion: 'Av. Constitución 145, Monterrey, N.L.',
      posicion:  { lat: 25.6866, lng: -100.3161 },
      telefono:  '+52 81 8888 0001',
      contacto:  'Ing. Ramírez',
      activo:    true,
    },
  },
  {
    id: 'c002',
    data: {
      nombre:   'Centro Distribución GDL',
      direccion: 'Blvd. Adolfo López Mateos 340, Guadalajara, Jal.',
      posicion:  { lat: 20.6597, lng: -103.3496 },
      telefono:  '+52 33 7777 0002',
      contacto:  'Lic. Flores',
      activo:    true,
    },
  },
  {
    id: 'c003',
    data: {
      nombre:   'Almacén Industrial León',
      direccion: 'Blvd. López Mateos Nte. 2208, León, Gto.',
      posicion:  { lat: 21.1619, lng: -101.6824 },
      telefono:  '+52 47 7120 0003',
      contacto:  'Sr. Castro',
      activo:    true,
    },
  },
  {
    id: 'c004',
    data: {
      nombre:   'CEDIS Sur CDMX',
      direccion: 'Eje Central Lázaro Cárdenas 911, Iztapalapa, CDMX',
      posicion:  { lat: 19.3643, lng: -99.0862 },
      telefono:  '+52 55 5555 0004',
      contacto:  'Dra. Mendoza',
      activo:    true,
    },
  },
  {
    id: 'c005',
    data: {
      nombre:   'Planta Bajío Querétaro',
      direccion: 'Av. 5 de Febrero 102, Querétaro, Qro.',
      posicion:  { lat: 20.5888, lng: -100.3899 },
      telefono:  '+52 44 2200 0005',
      contacto:  'Ing. Ortega',
      activo:    true,
    },
  },
  {
    id: 'c006',
    data: {
      nombre:   'Puerto Seco San Luis',
      direccion: 'Carretera 57 Km. 3.5, San Luis Potosí, S.L.P.',
      posicion:  { lat: 22.1566, lng: -100.9855 },
      telefono:  '+52 44 4812 0006',
      contacto:  'C.P. Gutiérrez',
      activo:    true,
    },
  },
  {
    id: 'c007',
    data: {
      nombre:   'Centro Logístico Hermosillo',
      direccion: 'Blvd. Solidaridad 203, Hermosillo, Son.',
      posicion:  { lat: 29.0729, lng: -110.9559 },
      telefono:  '+52 66 2214 0007',
      contacto:  'Sr. Valenzuela',
      activo:    true,
    },
  },
  {
    id: 'c008',
    data: {
      nombre:   'Distribuidora Frontera',
      direccion: 'Av. Internacional 1401, Tijuana, B.C.',
      posicion:  { lat: 32.5340, lng: -116.9320 },
      telefono:  '+52 66 4680 0008',
      contacto:  'Lic. Morales',
      activo:    true,
    },
  },
];

const alertas = [
  {
    id: 'a001',
    data: {
      viaje_id:    'v001',
      operador_id: 'demo-op001',
      unidad_id:   'u001',
      tipo:        'sos',
      estado:      'activa',
      posicion:    new admin.firestore.GeoPoint(22.1565, -100.9855),
      timestamp:   now,
      metadata:    {},
    },
  },
  {
    id: 'a002',
    data: {
      viaje_id:    'v001',
      operador_id: 'demo-op001',
      unidad_id:   'u001',
      tipo:        'varianzaCombustible',
      estado:      'activa',
      posicion:    new admin.firestore.GeoPoint(22.1565, -100.9855),
      timestamp:   now,
      metadata: {
        varianza_pct:      '9.50',
        nivel:             'sospechoso',
        litros_telemetria: 143,
        litros_tickets:    158,
        delta_litros:      '-15.00',
        score_compuesto:   '45.0',
      },
    },
  },
];

// ── Seed ──────────────────────────────────────────────────────────────────────

async function seed() {
  console.log('\n🌱  Iniciando seed de Globo Logistics...\n');

  const batch = db.batch();

  // Usuarios
  for (const u of usuarios) {
    batch.set(db.collection('usuarios').doc(u.id), u.data);
  }
  console.log(`   ✅  ${usuarios.length} usuarios`);

  // Unidades
  for (const u of unidades) {
    batch.set(db.collection('unidades').doc(u.id), u.data);
  }
  console.log(`   ✅  ${unidades.length} unidades`);

  // Viajes
  for (const v of viajes) {
    batch.set(db.collection('viajes').doc(v.id), v.data);
  }
  console.log(`   ✅  ${viajes.length} viajes`);

  // Alertas
  for (const a of alertas) {
    batch.set(db.collection('alertas_seguridad').doc(a.id), a.data);
  }
  console.log(`   ✅  ${alertas.length} alertas de seguridad`);

  // Clientes
  for (const c of clientes) {
    batch.set(db.collection('clientes').doc(c.id), c.data);
  }
  console.log(`   ✅  ${clientes.length} clientes`);

  await batch.commit();

  console.log('\n🎉  Base de datos inicializada correctamente.');
  console.log(`\n   Admin UID registrado: ${adminUid}`);
  console.log('   Ya puedes iniciar sesión con juanpablo@el-globo.net\n');
  process.exit(0);
}

seed().catch((err) => {
  console.error('\n❌  Error durante el seed:', err.message);
  process.exit(1);
});
