/**
 * ═══════════════════════════════════════════════════════════════
 * GLOBO LOGISTICS — Importador de datos reales desde CSV
 *
 * Uso:
 *   node import_from_csv.js [--dry-run]
 *
 * Requiere:
 *   - scripts/serviceAccountKey.json  (Firebase Admin SDK key)
 *   - Carpeta scripts/data/ con los CSV de tus datos reales:
 *       data/usuarios.csv
 *       data/unidades.csv
 *       data/clientes.csv
 *       data/viajes.csv        (opcional)
 *
 * Copia la plantilla correcta desde scripts/templates/ a scripts/data/
 * y reemplaza las filas de ejemplo con tus datos reales.
 *
 * --dry-run: muestra lo que se importaría sin escribir en Firestore
 * ═══════════════════════════════════════════════════════════════
 */

'use strict';

const admin   = require('firebase-admin');
const fs      = require('fs');
const path    = require('path');
const https   = require('https');
const { parse } = require('csv-parse/sync');

// ── Configuración ─────────────────────────────────────────────────────────────

const DRY_RUN  = process.argv.includes('--dry-run');
const DATA_DIR = path.join(__dirname, 'data');

// ── Firebase Admin ────────────────────────────────────────────────────────────

const keyPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) {
  console.error('\n❌  No se encontró serviceAccountKey.json en scripts/');
  console.error('    Descárgalo desde:');
  console.error('    Firebase Console → Project Settings → Service accounts → Generate new private key\n');
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(require(keyPath)) });
const db   = admin.firestore();
const auth = admin.auth();

// ── Utilidades ────────────────────────────────────────────────────────────────

function readCsv(filename) {
  const file = path.join(DATA_DIR, filename);
  if (!fs.existsSync(file)) return null;
  const content = fs.readFileSync(file, 'utf-8');
  return parse(content, {
    columns:          true,
    skip_empty_lines: true,
    trim:             true,
  });
}

function log(icon, msg) {
  console.log(`   ${icon}  ${msg}`);
}

function logSection(title) {
  console.log(`\n── ${title} ${'─'.repeat(Math.max(0, 50 - title.length))}`);
}

/** Geocodifica una dirección con Nominatim (OpenStreetMap, gratis). */
function geocode(direccion) {
  return new Promise((resolve) => {
    const query   = encodeURIComponent(direccion);
    const options = {
      hostname: 'nominatim.openstreetmap.org',
      path:     `/search?q=${query}&format=json&limit=1`,
      headers:  { 'User-Agent': 'GloboLogistics-Importer/1.0' },
    };
    const req = https.get(options, (res) => {
      let body = '';
      res.on('data', (d) => (body += d));
      res.on('end', () => {
        try {
          const results = JSON.parse(body);
          if (results.length > 0) {
            resolve({ lat: parseFloat(results[0].lat), lng: parseFloat(results[0].lon) });
          } else {
            resolve(null);
          }
        } catch {
          resolve(null);
        }
      });
    });
    req.on('error', () => resolve(null));
    req.setTimeout(8000, () => { req.destroy(); resolve(null); });
  });
}

/** Pausa entre llamadas a Nominatim (máximo 1 req/seg por su política de uso). */
function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

// ── Importar Usuarios ─────────────────────────────────────────────────────────

async function importarUsuarios() {
  logSection('USUARIOS');

  const rows = readCsv('usuarios.csv');
  if (!rows) { log('⚠️', 'data/usuarios.csv no encontrado — omitiendo'); return {}; }

  const uidPorEmail = {};   // email → UID (para mapear en unidades)
  let creados = 0, actualizados = 0, errores = 0;

  for (const row of rows) {
    const email    = (row.email    || '').trim().toLowerCase();
    const nombre   = (row.nombre   || '').trim();
    const rol      = (row.rol      || 'operador').trim();
    const password = (row.password_temporal || '').trim();
    const unidadId = (row.unidad_asignada_id || '').trim() || null;
    const activo   = row.activo !== 'false';

    if (!email) { log('⚠️', `Fila sin email — omitida`); errores++; continue; }

    try {
      // 1. Crear o recuperar usuario en Firebase Auth
      let uid;
      let esNuevo = false;

      try {
        const existente = await auth.getUserByEmail(email);
        uid = existente.uid;
      } catch {
        // No existe → crear
        if (!password) {
          log('⚠️', `${email} — sin password_temporal, no se puede crear en Auth`);
          errores++;
          continue;
        }
        if (!DRY_RUN) {
          const created = await auth.createUser({ email, password, displayName: nombre });
          uid = created.uid;
        } else {
          uid = `dry-run-${email.replace(/[^a-z0-9]/g, '-')}`;
        }
        esNuevo = true;
      }

      uidPorEmail[email] = uid;

      // 2. Crear/actualizar perfil en Firestore
      const perfil = {
        email,
        nombre,
        rol,
        activo,
        ...(unidadId ? { unidad_asignada_id: unidadId } : {}),
        ultimo_acceso: null,
      };

      if (!DRY_RUN) {
        await db.collection('usuarios').doc(uid).set(perfil, { merge: true });
      }

      const accion = esNuevo ? 'creado' : 'actualizado';
      log('✅', `${nombre} <${email}> — ${accion} (UID: ${uid})`);
      esNuevo ? creados++ : actualizados++;

    } catch (err) {
      log('❌', `${email} — ${err.message}`);
      errores++;
    }
  }

  log('📊', `Creados: ${creados}  Actualizados: ${actualizados}  Errores: ${errores}`);
  return uidPorEmail;
}

// ── Importar Unidades ─────────────────────────────────────────────────────────

async function importarUnidades(uidPorEmail) {
  logSection('UNIDADES');

  const rows = readCsv('unidades.csv');
  if (!rows) { log('⚠️', 'data/unidades.csv no encontrado — omitiendo'); return; }

  let ok = 0, errores = 0;

  for (const row of rows) {
    const id      = (row.id     || '').trim();
    const placas  = (row.placas || '').trim().toUpperCase();
    const modelo  = (row.modelo || '').trim();
    const anio    = parseInt(row.anio, 10) || new Date().getFullYear();
    const estado  = (row.estado || 'activa').trim();
    const email   = (row.operador_email || '').trim().toLowerCase();
    const odometro = parseFloat(row.odometro_km) || 0;
    const capacidad = parseFloat(row.capacidad_tanque_litros) || 0;

    if (!placas) { log('⚠️', `Fila sin placas — omitida`); errores++; continue; }

    const docId = id || placas.replace(/[^A-Z0-9]/g, '').toLowerCase();
    const operadorId = email ? (uidPorEmail[email] || null) : null;

    if (email && !operadorId) {
      log('⚠️', `${placas} — operador_email "${email}" no encontrado en usuarios (se importará sin asignar)`);
    }

    const data = {
      placas,
      modelo,
      anio,
      estado,
      operador_asignado_id:          operadorId,
      odometro,
      capacidad_tanque_litros:       capacidad,
      ultima_posicion:               null,
      ultima_actualizacion_posicion: null,
    };

    try {
      if (!DRY_RUN) {
        await db.collection('unidades').doc(docId).set(data, { merge: true });
      }
      log('✅', `${placas} — ${modelo} (${anio}) [${docId}]${operadorId ? ` → ${email}` : ''}`);
      ok++;
    } catch (err) {
      log('❌', `${placas} — ${err.message}`);
      errores++;
    }
  }

  log('📊', `Importadas: ${ok}  Errores: ${errores}`);
}

// ── Importar Clientes ─────────────────────────────────────────────────────────

async function importarClientes() {
  logSection('CLIENTES');

  const rows = readCsv('clientes.csv');
  if (!rows) { log('⚠️', 'data/clientes.csv no encontrado — omitiendo'); return; }

  let ok = 0, geocodificados = 0, sinGeo = 0, errores = 0;

  for (const row of rows) {
    const nombre    = (row.nombre    || '').trim();
    const direccion = (row.direccion || '').trim();
    const telefono  = (row.telefono  || '').trim();
    const contacto  = (row.contacto  || '').trim();
    const activo    = row.activo !== 'false';

    if (!nombre) { log('⚠️', 'Fila sin nombre — omitida'); errores++; continue; }

    let lat = parseFloat(row.lat);
    let lng = parseFloat(row.lng);
    let posicion = null;

    if (!isNaN(lat) && !isNaN(lng)) {
      posicion = { lat, lng };
    } else if (direccion) {
      // Intentar geocodificar con Nominatim (gratis, OpenStreetMap)
      process.stdout.write(`   🌐  Geocodificando "${nombre}"...`);
      const geo = await geocode(direccion);
      if (geo) {
        posicion = geo;
        process.stdout.write(` ✓ (${geo.lat.toFixed(4)}, ${geo.lng.toFixed(4)})\n`);
        geocodificados++;
      } else {
        process.stdout.write(` ⚠️ no encontrado\n`);
        sinGeo++;
      }
      await sleep(1100); // Nominatim: máx 1 req/seg
    } else {
      sinGeo++;
    }

    const data = { nombre, direccion, telefono, contacto, activo, posicion };

    try {
      if (!DRY_RUN) {
        const ref = db.collection('clientes').doc();
        await ref.set({ ...data, created_at: admin.firestore.FieldValue.serverTimestamp() });
      }
      log('✅', `${nombre}${posicion ? '' : ' (sin coordenadas)'}`);
      ok++;
    } catch (err) {
      log('❌', `${nombre} — ${err.message}`);
      errores++;
    }
  }

  log('📊', `Importados: ${ok}  Geocodificados: ${geocodificados}  Sin geo: ${sinGeo}  Errores: ${errores}`);
}

// ── Importar Viajes ───────────────────────────────────────────────────────────

async function importarViajes(uidPorEmail) {
  logSection('VIAJES HISTÓRICOS');

  const rows = readCsv('viajes.csv');
  if (!rows) { log('⚠️', 'data/viajes.csv no encontrado — omitiendo'); return; }

  let ok = 0, errores = 0;

  for (const row of rows) {
    const unidadId   = (row.unidad_id          || '').trim();
    const email      = (row.operador_email      || '').trim().toLowerCase();
    const origen     = (row.origen_descripcion  || '').trim();
    const destino    = (row.destino_descripcion || '').trim();
    const estado     = (row.estado              || 'completado').trim();
    const litrosCarg = parseFloat(row.litros_cargados) || 0;
    const litrosTick = parseFloat(row.litros_consumidos_tickets) || 0;

    const tco = {
      combustible:  parseFloat(row.tco_combustible)  || 0,
      mantenimiento: parseFloat(row.tco_mantenimiento) || 0,
      peajes:       parseFloat(row.tco_peajes)       || 0,
      grua:         parseFloat(row.tco_grua)         || 0,
      otros:        parseFloat(row.tco_otros)        || 0,
    };
    tco.total = Object.values(tco).reduce((a, b) => a + b, 0);

    if (!unidadId || !origen) {
      log('⚠️', `Fila incompleta — unidad_id u origen vacíos, omitida`);
      errores++;
      continue;
    }

    const operadorId = email ? (uidPorEmail[email] || null) : null;

    let fechaInicio = null;
    let fechaFin    = null;
    if (row.fecha_inicio) {
      const d = new Date(row.fecha_inicio);
      if (!isNaN(d)) fechaInicio = admin.firestore.Timestamp.fromDate(d);
    }
    if (row.fecha_fin) {
      const d = new Date(row.fecha_fin);
      if (!isNaN(d)) fechaFin = admin.firestore.Timestamp.fromDate(d);
    }

    const varianza = litrosCarg > 0
      ? Math.abs(litrosTick - litrosCarg) / litrosCarg
      : 0;

    const data = {
      unidad_id:                    unidadId,
      operador_id:                  operadorId,
      origen_descripcion:           origen,
      destino_descripcion:          destino,
      estado,
      litros_cargados:              litrosCarg,
      litros_consumidos_tickets:    litrosTick,
      litros_consumidos_telemetria: 0,
      varianza_combustible:         varianza,
      nivel_alerta:                 varianza > 0.05 ? 'bandajaRoja' : 'ninguna',
      tco,
      fecha_inicio: fechaInicio,
      fecha_fin:    fechaFin,
      created_at:   fechaInicio ?? admin.firestore.FieldValue.serverTimestamp(),
      updated_at:   admin.firestore.FieldValue.serverTimestamp(),
    };

    try {
      if (!DRY_RUN) {
        await db.collection('viajes').doc().set(data);
      }
      log('✅', `${origen.split('—')[0].trim()} → ${destino.split('—')[0].trim()} [${estado}]`);
      ok++;
    } catch (err) {
      log('❌', `${origen} — ${err.message}`);
      errores++;
    }
  }

  log('📊', `Importados: ${ok}  Errores: ${errores}`);
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('\n════════════════════════════════════════════════════');
  console.log('  GLOBO LOGISTICS — Importador de datos reales');
  if (DRY_RUN) console.log('  ⚡ MODO DRY-RUN — no se escribirá nada en Firestore');
  console.log('════════════════════════════════════════════════════');

  if (!fs.existsSync(DATA_DIR)) {
    console.error('\n❌  No se encontró la carpeta scripts/data/');
    console.error('    Crea la carpeta y copia tus CSVs ahí:');
    console.error('    cp scripts/templates/*.csv scripts/data/');
    console.error('    Luego edita los archivos con tus datos reales.\n');
    process.exit(1);
  }

  const uidPorEmail = await importarUsuarios();
  await importarUnidades(uidPorEmail);
  await importarClientes();
  await importarViajes(uidPorEmail);

  console.log('\n════════════════════════════════════════════════════');
  if (DRY_RUN) {
    console.log('  Dry-run completado. Ejecuta sin --dry-run para importar.');
  } else {
    console.log('  ✅  Importación completada.');
    console.log('      Los usuarios pueden iniciar sesión con sus passwords temporales.');
  }
  console.log('════════════════════════════════════════════════════\n');

  process.exit(0);
}

main().catch((err) => {
  console.error('\n❌  Error inesperado:', err.message);
  process.exit(1);
});
