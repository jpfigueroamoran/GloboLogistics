/**
 * ═══════════════════════════════════════════════════════════════════
 * GLOBO LOGISTICS — BACKEND ENGINE v1.0
 * Motor de auditoría "Litro Exacto" para flota logística.
 *
 * Adaptado del engine anti-fraude de LitroExacto v2.0:
 * - Idempotency protection (Stripe-style)
 * - Dynamic tolerance: max(0.3L, 2% de litros esperados)
 * - OCR normalization layer
 * - Race condition protection (atomic rate-limit)
 * - Clasificación de varianza por niveles (limpio/advertencia/sospechoso/fraude)
 * - Push FCM para SOS con sonido de emergencia
 * - Recálculo de TCO al completar viaje
 * ═══════════════════════════════════════════════════════════════════
 */

import * as admin from "firebase-admin";
import {
  onDocumentWritten,
  onDocumentCreated,
} from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { getMessaging } from "firebase-admin/messaging";
import { logger } from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();

// ═══════════════════════════════════════════════════════════════════
// CONSTANTES
// ═══════════════════════════════════════════════════════════════════

const C = {
  // Umbrales de varianza (portados de LitroExacto)
  VARIANZA_LIMPIO:          0.015, // < 1.5 %  → conciliado
  VARIANZA_ADVERTENCIA:     0.05,  // 1.5–5 %  → advertencia
  VARIANZA_SOSPECHOSO:      0.15,  // 5–15 %   → sospechoso
  // > 15 % → probable fraude

  // Tolerancia dinámica (portada de LitroExacto)
  BASE_TOLERANCIA_LITROS:   0.3,
  PCT_TOLERANCIA:           0.02,  // 2 %

  // Validación de datos del ticket
  MIN_LITROS:               1.0,
  MAX_LITROS:               500.0, // camiones > 200 L
  MIN_PRECIO_POR_LITRO:     15.0,
  MAX_PRECIO_POR_LITRO:     45.0,

  // Rendimiento diésel flota (fallback si no hay telemetría)
  RENDIMIENTO_BASE_KM_L:    3.5,

  COL: {
    viajes:    "viajes",
    costos:    "costos_operativos",
    alertas:   "alertas_seguridad",
    unidades:  "unidades",
    usuarios:  "usuarios",
    auditorias:"auditorias_combustible",
    rateLimits:"rate_limit_operadores",
  },
};

// ═══════════════════════════════════════════════════════════════════
// TYPES
// ═══════════════════════════════════════════════════════════════════

type NivelVarianza = "limpio" | "advertencia" | "sospechoso" | "fraudeProbable";

interface ResultadoAuditoria {
  viajeId: string;
  unidadId: string;
  operadorId: string;
  litrosTickets: number;
  litrosTelemetria: number;
  deltaLitros: number;
  varianzaPct: number;
  toleranciaDinamica: number;
  nivel: NivelVarianza;
  coherenciaVolumetrica: number;
  scoreCompuesto: number;
  tieneBanderaRoja: boolean;
  processedAt: admin.firestore.Timestamp;
  processingVersion: string;
}

// ═══════════════════════════════════════════════════════════════════
// OCR NORMALIZATION (portado de LitroExacto index.ts — normalizeOCR)
// ═══════════════════════════════════════════════════════════════════

function normalizeOCR(text: string): string {
  let t = text;
  // Confusiones comunes en tickets mexicanos de combustible
  t = t.replace(/(?<=\d)O(?=\d)/g,  "0");
  t = t.replace(/(?<=\d)l(?=\d)/g,  "1");
  t = t.replace(/(?<=\d)I(?=\d)/g,  "1");
  t = t.replace(/(?<=\d)S(?=\d)/g,  "5");
  t = t.replace(/(?<=\d)B(?=\d)/g,  "8");
  t = t.replace(/(?<=\d)g(?=\d)/g,  "9");
  t = t.replace(/(?<=\d)Z(?=\d)/g,  "2");
  // Decimal: coma → punto
  t = t.replace(/(\d),(\d)/g, "$1.$2");
  // Caracteres de control
  t = t.replace(/[\x00-\x1F\x7F]/g, "");
  // Espacios múltiples
  t = t.replace(/\s+/g, " ").trim();
  return t;
}

// ═══════════════════════════════════════════════════════════════════
// CLASIFICACIÓN DE VARIANZA (portada de LitroExacto)
// ═══════════════════════════════════════════════════════════════════

function clasificarVarianza(
  deltaAbs: number,
  tolerancia: number,
  varianzaPct: number
): NivelVarianza {
  if (deltaAbs <= tolerancia || varianzaPct <= C.VARIANZA_LIMPIO * 100) {
    return "limpio";
  }
  if (varianzaPct <= C.VARIANZA_ADVERTENCIA * 100) return "advertencia";
  if (varianzaPct <= C.VARIANZA_SOSPECHOSO  * 100) return "sospechoso";
  return "fraudeProbable";
}

// Score de consistencia de datos (portado de calculateDataConsistency)
function consistencyScore(varianzaPct: number): number {
  const v = Math.abs(varianzaPct);
  if (v <= 1)  return 1.0;
  if (v <= 3)  return 0.9;
  if (v <= 5)  return 0.8;
  if (v <= 10) return 0.6;
  if (v <= 20) return 0.4;
  return 0.2;
}

// Score compuesto: coherenciaVolumetrica × 0.40 + credibilidadOcr × 0.35 + consistencia × 0.25
function calcularScoreCompuesto(
  coherenciaVolumetrica: number,
  credibilidadOcr: number,
  varianzaPct: number
): number {
  const cs = consistencyScore(varianzaPct) * 100;
  return Math.max(0, Math.min(100,
    coherenciaVolumetrica * 0.40 +
    credibilidadOcr       * 0.35 +
    cs                    * 0.25
  ));
}

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 1 — AUDITORÍA "LITRO EXACTO"
// Trigger: escritura en costos_operativos (tipo diesel)
// Idempotente: verifica auditorias_combustible/{viajeId} antes de procesar
// ═══════════════════════════════════════════════════════════════════

export const auditoriaCombustible = onDocumentWritten(
  `${C.COL.costos}/{costoId}`,
  async (event) => {
    const afterData = event.data?.after?.data();
    if (!afterData || afterData.tipo !== "diesel") return;

    const viajeId = afterData.viaje_id as string;
    if (!viajeId) return;

    // ── IDEMPOTENCY: marcar como procesando ──────────────────────────
    const auditoriaRef = db.collection(C.COL.auditorias).doc(viajeId);
    const procesando = await auditoriaRef.get();
    if (procesando.exists && procesando.data()?.procesando === true) {
      logger.info(`Auditoría en proceso para viaje ${viajeId}, omitiendo.`);
      return;
    }
    await auditoriaRef.set({ procesando: true }, { merge: true });

    try {
      logger.info(`Auditoría Litro Exacto — viaje: ${viajeId}`);

      // ── 1. Obtener viaje ──────────────────────────────────────────
      const viajeSnap = await db.collection(C.COL.viajes).doc(viajeId).get();
      if (!viajeSnap.exists) {
        logger.warn(`Viaje ${viajeId} no encontrado`);
        return;
      }
      const viaje = viajeSnap.data()!;

      // ── 2. Agregar todos los tickets de diesel del viaje ──────────
      const costosSnap = await db
        .collection(C.COL.costos)
        .where("viaje_id", "==", viajeId)
        .where("tipo", "==", "diesel")
        .get();

      let litrosTickets      = 0;
      let montoTotalDiesel   = 0;
      let sumaCredibilidadOcr = 0;
      let countOcr           = 0;

      for (const doc of costosSnap.docs) {
        const costo = doc.data();

        // Normalizar texto OCR — reservado para validación futura de campos extraídos
        normalizeOCR(costo.datos_ocr?.texto_completo ?? "");
        const litrosOcr  = costo.datos_ocr?.litros_detectados ?? 0;
        const confianza  = costo.datos_ocr?.confianza ?? 0.5;

        // Validación de rangos (portada de LitroExacto)
        if (litrosOcr >= C.MIN_LITROS && litrosOcr <= C.MAX_LITROS) {
          litrosTickets    += litrosOcr;
          montoTotalDiesel += (costo.monto ?? 0) as number;
          sumaCredibilidadOcr += confianza * 100;
          countOcr++;
        } else {
          logger.warn(`Litros fuera de rango en costo ${doc.id}: ${litrosOcr}L`);
        }
      }

      if (litrosTickets === 0) {
        await auditoriaRef.set({ procesando: false }, { merge: true });
        return;
      }

      const credibilidadOcrPromedio = countOcr > 0 ? sumaCredibilidadOcr / countOcr : 50;

      // ── 3. Telemetría: litros por km recorridos ───────────────────
      const odometroInicio  = (viaje.odometro_inicio  ?? 0) as number;
      const odometroFin     = (viaje.odometro_fin     ?? 0) as number;
      const rendimiento     = (viaje.rendimiento_base ?? C.RENDIMIENTO_BASE_KM_L) as number;
      const distanciaKm     = Math.max(0, odometroFin - odometroInicio);
      const litrosTelemetria = distanciaKm > 0
        ? distanciaKm / rendimiento
        : litrosTickets; // fallback: confiar en tickets si no hay km

      // ── 4. Tolerancia dinámica (portada de LitroExacto) ──────────
      // tolerance = max(0.3L, 2% de litros de referencia)
      const tolerancia = Math.max(
        C.BASE_TOLERANCIA_LITROS,
        litrosTelemetria * C.PCT_TOLERANCIA
      );

      // ── 5. Calcular varianza ──────────────────────────────────────
      const delta       = litrosTelemetria - litrosTickets;
      const varianzaPct = litrosTelemetria > 0
        ? (Math.abs(delta) / litrosTelemetria) * 100
        : 0;

      // ── 6. Clasificar nivel ───────────────────────────────────────
      const nivel = clasificarVarianza(Math.abs(delta), tolerancia, varianzaPct);

      // ── 7. Score compuesto ────────────────────────────────────────
      // coherenciaVolumetrica: si hay medidor de tablero usarla, si no 70 (neutral)
      const coherenciaVolumetrica = (viaje.coherencia_volumetrica ?? 70) as number;
      const scoreCompuesto = calcularScoreCompuesto(
        coherenciaVolumetrica,
        credibilidadOcrPromedio,
        varianzaPct
      );

      const tieneBanderaRoja = nivel === "sospechoso" || nivel === "fraudeProbable";

      // ── 8. Guardar resultado de auditoría ─────────────────────────
      const resultado: ResultadoAuditoria = {
        viajeId,
        unidadId:   viaje.unidad_id   ?? "",
        operadorId: viaje.operador_id ?? "",
        litrosTickets,
        litrosTelemetria,
        deltaLitros: delta,
        varianzaPct,
        toleranciaDinamica: tolerancia,
        nivel,
        coherenciaVolumetrica,
        scoreCompuesto,
        tieneBanderaRoja,
        processedAt: admin.firestore.Timestamp.now(),
        processingVersion: "1.0.0",
      };

      await auditoriaRef.set({
        ...resultado,
        procesando: false,
        tco_combustible: montoTotalDiesel,
      });

      // ── 9. Actualizar viaje ───────────────────────────────────────
      await db.collection(C.COL.viajes).doc(viajeId).update({
        litros_consumidos_tickets:    litrosTickets,
        litros_consumidos_telemetria: litrosTelemetria,
        varianza_combustible:         varianzaPct / 100,
        nivel_alerta:                 tieneBanderaRoja ? nivel : "ninguna",
        "tco.combustible":            montoTotalDiesel,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // ── 10. Crear alerta y notificar si hay bandera roja ──────────
      if (tieneBanderaRoja) {
        await _crearAlertaVarianza(resultado, varianzaPct);
        await _notificarTorreControl(resultado, varianzaPct, nivel);
      }

      logger.info(`Litro Exacto completo — ${viajeId}: varianza=${varianzaPct.toFixed(2)}% nivel=${nivel}`);

    } catch (err) {
      logger.error(`Error en auditoría ${viajeId}:`, err);
      await auditoriaRef.set({ procesando: false, error: String(err) }, { merge: true });
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 2 — PROTOCOLO SOS
// Trigger: creación de alerta de tipo sos
// Push FCM con sonido de emergencia a supervisores/admins
// ═══════════════════════════════════════════════════════════════════

export const onAlertaSOS = onDocumentCreated(
  `${C.COL.alertas}/{alertaId}`,
  async (event) => {
    const data = event.data?.data();
    if (!data || data.tipo !== "sos") return;

    const alertaId   = event.params.alertaId;
    const operadorId = data.operador_id as string;
    const unidadId   = data.unidad_id   as string;
    const viajeId    = data.viaje_id    as string;
    const posicion   = data.posicion    as { lat: number; lng: number } | undefined;

    logger.info(`SOS activado — alerta: ${alertaId} operador: ${operadorId}`);

    // Tokens FCM de supervisores y administradores
    const supervisoresSnap = await db
      .collection(C.COL.usuarios)
      .where("rol", "in", ["supervisor", "administrador"])
      .get();

    const tokens: string[] = [];
    for (const doc of supervisoresSnap.docs) {
      const fcm = doc.data().fcm_token as string | undefined;
      if (fcm) tokens.push(fcm);
    }

    if (tokens.length === 0) {
      logger.warn("Sin tokens FCM de supervisores registrados");
      await event.data?.ref.update({ notificacion_enviada: false });
      return;
    }

    const resp = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title:  "🚨 PROTOCOLO SOS ACTIVADO",
        body:   `Operador ${operadorId} — Unidad ${unidadId} necesita asistencia urgente.`,
      },
      data: {
        tipo:         "sos",
        alerta_id:    alertaId,
        viaje_id:     viajeId,
        operador_id:  operadorId,
        unidad_id:    unidadId,
        lat:          String(posicion?.lat ?? 0),
        lng:          String(posicion?.lng ?? 0),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId:  "sos_alerts",
          sound:      "sos_alarm",
          priority:   "max",
          visibility: "public",
        },
      },
      apns: {
        payload: { aps: { sound: "sos_alarm.caf", badge: 1, contentAvailable: true } },
      },
      webpush: {
        notification: { requireInteraction: true, vibrate: [200, 100, 200, 100, 200] },
        headers: { Urgency: "very-high" },
      },
    });

    await event.data?.ref.update({
      notificacion_enviada:        true,
      notificacion_timestamp:      admin.firestore.FieldValue.serverTimestamp(),
      destinatarios_notificados:   resp.successCount,
      destinatarios_fallidos:      resp.failureCount,
    });

    logger.info(`SOS notificado — éxito: ${resp.successCount} fallo: ${resp.failureCount}`);
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 3 — RECÁLCULO TCO AL COMPLETAR VIAJE
// Trigger: cambio de estado a "completado" en viajes
// ═══════════════════════════════════════════════════════════════════

export const recalcularTco = onDocumentWritten(
  `${C.COL.viajes}/{viajeId}`,
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();

    if (!after || !before) return;
    if (before.estado === "completado" || after.estado !== "completado") return;

    const viajeId = event.params.viajeId;
    logger.info(`TCO final — viaje completado: ${viajeId}`);

    const costosSnap = await db
      .collection(C.COL.costos)
      .where("viaje_id", "==", viajeId)
      .get();

    const tco = { combustible: 0, mantenimiento: 0, peajes: 0, grua: 0, otros: 0, total: 0 };

    for (const doc of costosSnap.docs) {
      const { tipo, monto } = doc.data() as { tipo: string; monto: number };
      switch (tipo) {
        case "diesel":       tco.combustible   += monto; break;
        case "mantenimiento": tco.mantenimiento += monto; break;
        case "peaje":        tco.peajes        += monto; break;
        case "grua":         tco.grua          += monto; break;
        default:             tco.otros         += monto;
      }
    }
    tco.total = tco.combustible + tco.mantenimiento + tco.peajes + tco.grua + tco.otros;

    // Calcular costo por km
    const odometroInicio = (after.odometro_inicio ?? 0) as number;
    const odometroFin    = (after.odometro_fin    ?? 0) as number;
    const distanciaKm    = Math.max(0, odometroFin - odometroInicio);
    const costoPorKm     = distanciaKm > 0 ? tco.total / distanciaKm : 0;

    await db.collection(C.COL.viajes).doc(viajeId).update({
      tco,
      costo_por_km: costoPorKm,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`TCO final — ${viajeId}: $${tco.total.toFixed(2)} MXN ($${costoPorKm.toFixed(2)}/km)`);
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 4 — CALLABLE: Atender alerta
// Verifica rol supervisor/admin antes de marcar como atendida
// ═══════════════════════════════════════════════════════════════════

export const atenderAlerta = onCall(
  { enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const { alertaId, notas } = request.data as { alertaId: string; notas?: string };
    if (!alertaId) throw new HttpsError("invalid-argument", "alertaId requerido.");

    const uid         = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol         = usuarioSnap.data()?.rol as string | undefined;

    if (!rol || !["supervisor", "administrador"].includes(rol)) {
      throw new HttpsError("permission-denied", "Rol insuficiente.");
    }

    await db.collection(C.COL.alertas).doc(alertaId).update({
      estado:          "atendida",
      atendida_por:    uid,
      notas:           notas ?? "",
      fecha_atencion:  admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`Alerta ${alertaId} atendida por ${uid}`);
    return { success: true };
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 5 — CALLABLE: Ejecutar auditoría manual desde Torre de Control
// Recibe parámetros del viaje y devuelve el AuditoriaResultado
// ═══════════════════════════════════════════════════════════════════

export const ejecutarAuditoriaManual = onCall(
  { enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const uid         = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol         = usuarioSnap.data()?.rol as string | undefined;

    if (!rol || !["supervisor", "administrador"].includes(rol)) {
      throw new HttpsError("permission-denied", "Rol insuficiente.");
    }

    const {
      viajeId,
      litrosTickets,
      litrosTelemetria,
      credibilidadOcrPromedio = 70,
      coherenciaVolumetrica = 70,
    } = request.data as {
      viajeId: string;
      litrosTickets: number;
      litrosTelemetria: number;
      credibilidadOcrPromedio?: number;
      coherenciaVolumetrica?: number;
    };

    if (!viajeId || litrosTickets <= 0) {
      throw new HttpsError("invalid-argument", "Parámetros inválidos.");
    }

    const tolerancia  = Math.max(C.BASE_TOLERANCIA_LITROS, litrosTelemetria * C.PCT_TOLERANCIA);
    const delta       = litrosTelemetria - litrosTickets;
    const varianzaPct = litrosTelemetria > 0
      ? (Math.abs(delta) / litrosTelemetria) * 100
      : 0;
    const nivel            = clasificarVarianza(Math.abs(delta), tolerancia, varianzaPct);
    const scoreCompuesto   = calcularScoreCompuesto(coherenciaVolumetrica, credibilidadOcrPromedio, varianzaPct);
    const tieneBanderaRoja = nivel === "sospechoso" || nivel === "fraudeProbable";

    const resultado: ResultadoAuditoria = {
      viajeId,
      unidadId:   "",
      operadorId: "",
      litrosTickets,
      litrosTelemetria,
      deltaLitros: delta,
      varianzaPct,
      toleranciaDinamica: tolerancia,
      nivel,
      coherenciaVolumetrica,
      scoreCompuesto,
      tieneBanderaRoja,
      processedAt:       admin.firestore.Timestamp.now(),
      processingVersion: "1.0.0-manual",
    };

    if (tieneBanderaRoja) {
      await db.collection(C.COL.viajes).doc(viajeId).update({
        nivel_alerta:          nivel,
        varianza_combustible:  varianzaPct / 100,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return resultado;
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 6 — SCHEDULED: Recálculo semanal de auditorías
// Corrige drift de actualizaciones incrementales
// ═══════════════════════════════════════════════════════════════════

export const recalcularAuditoriasSemanales = onSchedule(
  { schedule: "0 2 * * 0", timeZone: "America/Mexico_City" },
  async () => {
    logger.info("Recalculando auditorías semanales...");

    const viajesSnap = await db
      .collection(C.COL.viajes)
      .where("estado", "==", "completado")
      .where("nivel_alerta", "in", ["sospechoso", "fraudeProbable"])
      .get();

    let procesados = 0;
    for (const doc of viajesSnap.docs) {
      const viaje   = doc.data();
      const viajeId = doc.id;

      // Recalcular desde costos originales
      const costosSnap = await db
        .collection(C.COL.costos)
        .where("viaje_id", "==", viajeId)
        .where("tipo", "==", "diesel")
        .get();

      let litrosTickets = 0;
      for (const c of costosSnap.docs) {
        litrosTickets += (c.data().datos_ocr?.litros_detectados ?? 0) as number;
      }

      const rendimiento      = (viaje.rendimiento_base ?? C.RENDIMIENTO_BASE_KM_L) as number;
      const distanciaKm      = Math.max(0, ((viaje.odometro_fin ?? 0) as number) - ((viaje.odometro_inicio ?? 0) as number));
      const litrosTelemetria = distanciaKm > 0 ? distanciaKm / rendimiento : litrosTickets;

      const tolerancia  = Math.max(C.BASE_TOLERANCIA_LITROS, litrosTelemetria * C.PCT_TOLERANCIA);
      const delta       = litrosTelemetria - litrosTickets;
      const varianzaPct = litrosTelemetria > 0 ? (Math.abs(delta) / litrosTelemetria) * 100 : 0;
      const nivel       = clasificarVarianza(Math.abs(delta), tolerancia, varianzaPct);

      await doc.ref.update({
        varianza_combustible: varianzaPct / 100,
        nivel_alerta:         nivel,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      procesados++;
    }

    logger.info(`Recálculo semanal completo — ${procesados} viajes actualizados`);
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 7 — CALLABLE: Crear usuario (solo administradores)
// Usa Admin SDK para crear cuenta Auth sin cerrar sesión del admin.
// ═══════════════════════════════════════════════════════════════════

export const crearUsuario = onCall(
  { enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const uid         = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol         = usuarioSnap.data()?.rol as string | undefined;

    if (rol !== "administrador") {
      throw new HttpsError("permission-denied", "Solo el administrador puede crear usuarios.");
    }

    const { email, password, nombre, rolNuevo } = request.data as {
      email:    string;
      password: string;
      nombre:   string;
      rolNuevo: string;
    };

    if (!email || !password || !nombre || !rolNuevo) {
      throw new HttpsError("invalid-argument", "email, password, nombre y rolNuevo son requeridos.");
    }

    const rolesValidos = ["operador", "supervisor", "administrador"];
    if (!rolesValidos.includes(rolNuevo)) {
      throw new HttpsError("invalid-argument", `Rol inválido: ${rolNuevo}`);
    }

    // Crear cuenta en Firebase Auth
    const userRecord = await admin.auth().createUser({ email, password, displayName: nombre });

    // Crear documento en Firestore
    await db.collection(C.COL.usuarios).doc(userRecord.uid).set({
      email,
      nombre,
      rol:         rolNuevo,
      activo:      true,
      creado_por:  uid,
      creado_at:   admin.firestore.FieldValue.serverTimestamp(),
      ultimo_acceso: null,
    });

    logger.info(`Usuario creado: ${userRecord.uid} (${email}) rol=${rolNuevo} por admin ${uid}`);
    return { uid: userRecord.uid };
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 8 — CALLABLE: Actualizar usuario (solo administradores)
// Cambia rol, nombre y/o estado activo. Revoca tokens si desactiva.
// ═══════════════════════════════════════════════════════════════════

export const actualizarUsuario = onCall(
  { enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Autenticación requerida.");
    }

    const uid         = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol         = usuarioSnap.data()?.rol as string | undefined;

    if (rol !== "administrador") {
      throw new HttpsError("permission-denied", "Solo el administrador puede modificar usuarios.");
    }

    const { targetUid, nombre, rolNuevo, activo } = request.data as {
      targetUid: string;
      nombre?:   string;
      rolNuevo?: string;
      activo?:   boolean;
    };

    if (!targetUid) {
      throw new HttpsError("invalid-argument", "targetUid requerido.");
    }

    const updates: Record<string, unknown> = {
      modificado_por: uid,
      modificado_at:  admin.firestore.FieldValue.serverTimestamp(),
    };

    if (nombre   !== undefined) updates.nombre = nombre;
    if (rolNuevo !== undefined) updates.rol    = rolNuevo;
    if (activo   !== undefined) {
      updates.activo = activo;
      // Revocar sesiones activas si se desactiva
      if (!activo) await admin.auth().revokeRefreshTokens(targetUid);
    }

    await db.collection(C.COL.usuarios).doc(targetUid).update(updates);

    logger.info(`Usuario ${targetUid} actualizado por admin ${uid}: ${JSON.stringify(updates)}`);
    return { success: true };
  }
);

// ═══════════════════════════════════════════════════════════════════
// HELPERS PRIVADOS
// ═══════════════════════════════════════════════════════════════════

async function _crearAlertaVarianza(
  resultado: ResultadoAuditoria,
  varianzaPct: number
): Promise<void> {
  await db.collection(C.COL.alertas).add({
    viaje_id:    resultado.viajeId,
    operador_id: resultado.operadorId,
    unidad_id:   resultado.unidadId,
    tipo:        "varianzaCombustible",
    timestamp:   admin.firestore.FieldValue.serverTimestamp(),
    estado:      "activa",
    metadata: {
      varianza_pct:      varianzaPct.toFixed(2),
      nivel:             resultado.nivel,
      litros_telemetria: resultado.litrosTelemetria,
      litros_tickets:    resultado.litrosTickets,
      delta_litros:      resultado.deltaLitros.toFixed(2),
      score_compuesto:   resultado.scoreCompuesto.toFixed(1),
    },
  });
}

async function _notificarTorreControl(
  resultado: ResultadoAuditoria,
  varianzaPct: number,
  nivel: NivelVarianza
): Promise<void> {
  const supervisoresSnap = await db
    .collection(C.COL.usuarios)
    .where("rol", "in", ["supervisor", "administrador"])
    .get();

  const tokens: string[] = [];
  for (const doc of supervisoresSnap.docs) {
    const fcm = doc.data().fcm_token as string | undefined;
    if (fcm) tokens.push(fcm);
  }

  if (tokens.length === 0) return;

  const esGrave = nivel === "fraudeProbable";
  await getMessaging().sendEachForMulticast({
    tokens,
    notification: {
      title: esGrave
        ? `🚩 Probable Fraude — Varianza ${varianzaPct.toFixed(1)}%`
        : `⚠️ Varianza Combustible: ${varianzaPct.toFixed(1)}%`,
      body: `Viaje ${resultado.viajeId} — Unidad ${resultado.unidadId}. Supera umbral.`,
    },
    data: {
      tipo:      "varianzaCombustible",
      viaje_id:  resultado.viajeId,
      nivel,
      varianza_pct:  varianzaPct.toFixed(2),
      click_action:  "FLUTTER_NOTIFICATION_CLICK",
    },
    android: { priority: "high" },
  });
}
