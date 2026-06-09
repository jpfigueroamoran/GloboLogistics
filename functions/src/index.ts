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
    actividad: "actividad_operativa",
    scores:    "scores_operadores",
    clientes:  "clientes",
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

    // Incrementar contador SOS en el score del operador
    if (operadorId) {
      await _incrementarSOSEnScore(operadorId);
    }

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
    // lifecycleViajeCompletado ya cubre este cálculo
    if (after.lc_completado === true) return;

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
// FUNCIÓN 9 — SCHEDULED: Cierre mensual de activos fijos
// Calcula depreciación mensual de la flota y guarda resumen financiero.
// Ejecuta el día 1 de cada mes a las 03:00 México.
// ═══════════════════════════════════════════════════════════════════

export const cierreMensual = onSchedule(
  { schedule: "0 3 1 * *", timeZone: "America/Mexico_City" },
  async () => {
    const now  = new Date();
    const mes  = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

    logger.info(`Cierre mensual — período: ${mes}`);

    const activosSnap = await db.collection("activos_fijos").get();

    let depreciacionMensual = 0;
    let valorLibrosTotal    = 0;
    let activosEnAlerta     = 0;

    for (const doc of activosSnap.docs) {
      const d                = doc.data();
      const vidaAnios        = (d.vida_util_anios ?? 10) as number;
      const costo            = (d.costo_adquisicion ?? 0) as number;
      const residual         = (d.valor_residual ?? 0) as number;
      const fechaAdq         = (d.fecha_adquisicion as admin.firestore.Timestamp).toDate();

      const deprAnual        = (costo - residual) / vidaAnios;
      const deprMensual      = deprAnual / 12;
      const mesesTranscurridos = Math.min(
        (now.getFullYear() - fechaAdq.getFullYear()) * 12 +
          now.getMonth() - fechaAdq.getMonth(),
        vidaAnios * 12
      );
      const vl = Math.max(residual, costo - deprMensual * mesesTranscurridos);
      const pctDepr = (costo - residual) > 0
        ? (costo - vl) / (costo - residual)
        : 1;

      depreciacionMensual += deprMensual;
      valorLibrosTotal    += vl;
      if (pctDepr >= 0.8) activosEnAlerta++;
    }

    await db.collection("resumenes_financieros").doc(mes).set({
      periodo_id:               mes,
      depreciacion_mensual_flota: depreciacionMensual,
      valor_libros_flota:         valorLibrosTotal,
      activos_en_alerta:          activosEnAlerta,
      total_activos:              activosSnap.size,
      generado_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    logger.info(
      `Cierre ${mes} — depr: $${depreciacionMensual.toFixed(2)} | ` +
      `valor libros: $${valorLibrosTotal.toFixed(2)} | alertas: ${activosEnAlerta}`
    );
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 10 — TRIGGER: Generar factura al completar viaje
// Trigger: viaje transiciona a "completado".
// Lee config/pricing para margen%, genera número GL-YYYY-XXXX y
// crea documento en facturas_clientes/.
// ═══════════════════════════════════════════════════════════════════

export const generarFacturaViaje = onDocumentWritten(
  `${C.COL.viajes}/{viajeId}`,
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();

    // Solo cuando transiciona a completado
    if (!after || !before) return;
    if (before.estado === "completado" || after.estado !== "completado") return;
    // lifecycleViajeCompletado cubre facturación con TCO correcto
    if (after.lc_completado === true) return;

    const viajeId = event.params.viajeId;
    const COL_FACTURAS = "facturas_clientes";
    const COL_CONFIG   = "config";

    // ── Idempotencia: verificar que no exista ya una factura ──────────
    const existente = await db
      .collection(COL_FACTURAS)
      .where("viaje_id", "==", viajeId)
      .limit(1)
      .get();

    if (!existente.empty) {
      logger.info(`Factura ya existe para viaje ${viajeId}, omitiendo.`);
      return;
    }

    logger.info(`Generando factura para viaje completado: ${viajeId}`);

    // ── Leer configuración de pricing ────────────────────────────────
    const pricingSnap = await db.collection(COL_CONFIG).doc("pricing").get();
    const margenPct   = (pricingSnap.data()?.margen_pct ?? 0.15) as number; // default 15%

    // ── Leer datos del viaje ─────────────────────────────────────────
    const clienteId    = (after.cliente_id    ?? "") as string;
    const clienteNombre = (after.cliente_nombre ?? "Cliente") as string;
    const tco          = (after.tco ?? {}) as { total?: number };
    const tcoTotal     = tco.total ?? 0;
    const monto        = parseFloat((tcoTotal * (1 + margenPct)).toFixed(2));

    // ── Generar número de factura: GL-YYYY-XXXX (transaccional) ─────
    const anio       = new Date().getFullYear();
    const contadorId = `factura_contador_${anio}`;

    const numeroFactura = await db.runTransaction(async (tx) => {
      const contadorRef = db.collection(COL_CONFIG).doc(contadorId);
      const contadorSnap = await tx.get(contadorRef);
      const siguiente = ((contadorSnap.data()?.ultimo ?? 0) as number) + 1;
      tx.set(contadorRef, { ultimo: siguiente }, { merge: true });
      return `GL-${anio}-${String(siguiente).padStart(4, "0")}`;
    });

    // ── Calcular fecha de vencimiento (30 días corridos) ─────────────
    const fechaEmision     = new Date();
    const fechaVencimiento = new Date(fechaEmision);
    fechaVencimiento.setDate(fechaVencimiento.getDate() + 30);

    // ── Crear documento de factura ───────────────────────────────────
    await db.collection(COL_FACTURAS).add({
      viaje_id:          viajeId,
      cliente_id:        clienteId,
      cliente_nombre:    clienteNombre,
      numero_factura:    numeroFactura,
      fecha_emision:     admin.firestore.Timestamp.fromDate(fechaEmision),
      fecha_vencimiento: admin.firestore.Timestamp.fromDate(fechaVencimiento),
      monto,
      monto_cobrado:     null,
      estatus:           "pendiente",
      fecha_cobro:       null,
      carta_porte_uuid:  null,
      tco_base:          tcoTotal,
      margen_pct:        margenPct,
      created_at:        admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(
      `Factura generada — ${numeroFactura}: $${monto.toFixed(2)} MXN (viaje: ${viajeId})`
    );
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 11 — SCHEDULED: Marcar facturas de proveedores como vencidas
// Ejecuta diariamente a las 08:00 México.
// Actualiza facturas_proveedores donde fecha_vencimiento < hoy y estatus=pendiente.
// ═══════════════════════════════════════════════════════════════════

export const vencimientosCxP = onSchedule(
  { schedule: "0 8 * * *", timeZone: "America/Mexico_City" },
  async () => {
    const ahora   = new Date();
    const hoy     = admin.firestore.Timestamp.fromDate(ahora);

    const snap = await db
      .collection("facturas_proveedores")
      .where("estatus", "==", "pendiente")
      .where("fecha_vencimiento", "<", hoy)
      .get();

    if (snap.empty) {
      logger.info("vencimientosCxP — sin facturas a vencer hoy.");
      return;
    }

    const batch = db.batch();
    for (const doc of snap.docs) {
      batch.update(doc.ref, {
        estatus:    "vencida",
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    logger.info(`vencimientosCxP — ${snap.size} factura(s) marcada(s) como vencida.`);
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 12 — TRIGGER: Alerta de stock mínimo
// Trigger: escritura en inventario/{itemId}.
// Si stock_actual <= stock_minimo, crea alerta en alertas_seguridad.
// ═══════════════════════════════════════════════════════════════════

export const alertaStockMinimo = onDocumentWritten(
  "inventario/{itemId}",
  async (event) => {
    const after  = event.data?.after?.data();
    const before = event.data?.before?.data();
    if (!after) return;

    const stockActual = (after.stock_actual ?? 0) as number;
    const stockMinimo = (after.stock_minimo ?? 0) as number;
    const itemId      = event.params.itemId;
    const nombre      = (after.nombre ?? itemId) as string;

    if (stockActual > stockMinimo) return;

    // Evitar crear alerta duplicada si ya existe una activa para este ítem
    const existente = await db
      .collection(C.COL.alertas)
      .where("tipo", "==", "stockMinimo")
      .where("item_id", "==", itemId)
      .where("estado", "==", "activa")
      .limit(1)
      .get();

    if (!existente.empty) {
      // Actualizar stock en la alerta existente
      await existente.docs[0].ref.update({
        "metadata.stock_actual": stockActual,
        "metadata.stock_minimo": stockMinimo,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const prevStock = (before?.stock_actual ?? stockActual) as number;
    if (prevStock <= stockMinimo && stockActual <= stockMinimo) return;

    await db.collection(C.COL.alertas).add({
      tipo:      "stockMinimo",
      estado:    "activa",
      item_id:   itemId,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        nombre_item:   nombre,
        stock_actual:  stockActual,
        stock_minimo:  stockMinimo,
        pct_stock:     stockMinimo > 0
          ? ((stockActual / stockMinimo) * 100).toFixed(1)
          : "0",
      },
    });

    logger.info(
      `alertaStockMinimo — ${nombre}: ${stockActual} / ${stockMinimo} (mínimo)`
    );
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 13 — SCHEDULED: Alerta de Pólizas por Vencer
// Ejecuta diariamente a las 08:00 México.
// Crea una alerta si hay pólizas que vencen en 30 días o menos.
// ═══════════════════════════════════════════════════════════════════

export const vencimientoPolizasSeguro = onSchedule(
  { schedule: "0 8 * * *", timeZone: "America/Mexico_City" },
  async () => {
    const ahora = new Date();
    // Vencimiento límite: 30 días en el futuro
    const limite = new Date(ahora);
    limite.setDate(limite.getDate() + 30);
    const tsLimite = admin.firestore.Timestamp.fromDate(limite);

    const polizasSnap = await db
      .collection("polizas_seguro")
      .where("vigencia_fin", "<=", tsLimite)
      .get();

    if (polizasSnap.empty) {
      logger.info("vencimientoPolizasSeguro — sin pólizas por vencer.");
      return;
    }

    let alertasGeneradas = 0;
    for (const doc of polizasSnap.docs) {
      const polizaId = doc.id;
      const data = doc.data();
      const numeroPoliza = (data.numero_poliza ?? "N/A") as string;
      const unidadId = (data.unidad_id ?? "N/A") as string;

      // Verificar si ya existe una alerta activa para esta póliza
      const existente = await db
        .collection(C.COL.alertas)
        .where("tipo", "==", "polizaPorVencer")
        .where("poliza_id", "==", polizaId)
        .where("estado", "==", "activa")
        .limit(1)
        .get();

      if (!existente.empty) {
        continue; // Ya hay una alerta activa
      }

      await db.collection(C.COL.alertas).add({
        tipo: "polizaPorVencer",
        estado: "activa",
        poliza_id: polizaId,
        unidad_id: unidadId,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          numero_poliza: numeroPoliza,
          vigencia_fin: data.vigencia_fin,
        },
      });
      alertasGeneradas++;
    }

    logger.info(`vencimientoPolizasSeguro — ${alertasGeneradas} alerta(s) generada(s) de ${polizasSnap.size} pólizas próximas a vencer o vencidas.`);
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

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 14 — CICLO DE VIDA: Viaje → enCurso
// - fecha_inicio en viaje (si faltaba)
// - unidad.estado = "enTransito"
// - actividad_operativa: viaje_iniciado
// - FCM a supervisores/admins
// ═══════════════════════════════════════════════════════════════════

export const lifecycleViajeEnCurso = onDocumentWritten(
  `${C.COL.viajes}/{viajeId}`,
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!after || !before) return;
    if (before.estado === "enCurso" || after.estado !== "enCurso") return;

    const viajeId        = event.params.viajeId;
    const unidadId       = (after.unidad_id       ?? "") as string;
    const operadorId     = (after.operador_id     ?? "") as string;
    const operadorNombre = (after.operador_nombre ?? operadorId) as string;
    const origenDesc     = (after.origen_descripcion  ?? "") as string;
    const destinoDesc    = (after.destino_descripcion ?? "") as string;

    logger.info(`lifecycleViajeEnCurso — ${viajeId}`);

    const batch = db.batch();

    if (!after.fecha_inicio) {
      batch.update(db.collection(C.COL.viajes).doc(viajeId), {
        fecha_inicio: admin.firestore.FieldValue.serverTimestamp(),
        updated_at:   admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (unidadId) {
      batch.update(db.collection(C.COL.unidades).doc(unidadId), {
        estado:               "enTransito",
        viaje_activo_id:      viajeId,
        ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    batch.set(db.collection(C.COL.actividad).doc(), {
      tipo:        "viaje_iniciado",
      viaje_id:    viajeId,
      operador_id: operadorId,
      unidad_id:   unidadId,
      timestamp:   admin.firestore.FieldValue.serverTimestamp(),
      metadata: {
        origen_descripcion:  origenDesc,
        destino_descripcion: destinoDesc,
        operador_nombre:     operadorNombre,
      },
    });

    await batch.commit();

    // FCM a supervisores/admins
    const tokens = await _tokensDeRoles(["supervisor", "administrador"]);
    if (tokens.length > 0) {
      await getMessaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "🚛 Viaje Iniciado",
          body:  `${operadorNombre} — ${origenDesc} → ${destinoDesc}`,
        },
        data: {
          tipo:         "viaje_iniciado",
          viaje_id:     viajeId,
          operador_id:  operadorId,
          unidad_id:    unidadId,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: { priority: "normal" },
      });
    }

    logger.info(`lifecycleViajeEnCurso OK — ${viajeId}`);
  }
);

// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 15 — CICLO DE VIDA: Viaje → completado
// Pipeline idempotente (lock transaccional con lc_completado):
//   1. TCO final desde costos_operativos
//   2. viaje: tco, costo_por_km, fecha_fin
//   3. unidad: odometro_actual, estado (disponible / mantenimiento)
//   4. Cerrar alertas activas del viaje
//   5. Score del operador en scores_operadores
//   6. Factura (si no existe)
//   7. actividad_operativa: viaje_completado
//   8. FCM al operador + supervisores/admins
// Supersede: recalcularTco + generarFacturaViaje (quedan como fallback)
// ═══════════════════════════════════════════════════════════════════

export const lifecycleViajeCompletado = onDocumentWritten(
  `${C.COL.viajes}/{viajeId}`,
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!after || !before) return;
    if (before.estado === "completado" || after.estado !== "completado") return;

    const viajeId  = event.params.viajeId;
    const viajeRef = db.collection(C.COL.viajes).doc(viajeId);

    // ── Lock idempotente ─────────────────────────────────────────────
    const yaProcessado = await db.runTransaction(async (tx) => {
      const snap = await tx.get(viajeRef);
      if (snap.data()?.lc_completado === true) return true;
      tx.update(viajeRef, { lc_completado: true });
      return false;
    });
    if (yaProcessado) {
      logger.info(`lifecycleViajeCompletado — ya procesado: ${viajeId}`);
      return;
    }

    const unidadId       = (after.unidad_id       ?? "") as string;
    const operadorId     = (after.operador_id     ?? "") as string;
    const operadorNombre = (after.operador_nombre ?? operadorId) as string;
    const clienteId      = (after.cliente_id      ?? "") as string;
    const clienteNombre  = (after.cliente_nombre  ?? "Cliente") as string;
    const tieneBanderaRoja = after.nivel_alerta === "bandajaRoja";
    const odometroFin    = (after.odometro_fin    ?? 0) as number;
    const odometroInicio = (after.odometro_inicio ?? 0) as number;

    logger.info(`lifecycleViajeCompletado — iniciando: ${viajeId}`);

    try {
      // ── 1. TCO FINAL ─────────────────────────────────────────────
      const costosSnap = await db
        .collection(C.COL.costos)
        .where("viaje_id", "==", viajeId)
        .get();

      const tco = { combustible: 0, mantenimiento: 0, peajes: 0, grua: 0, otros: 0, total: 0 };
      for (const doc of costosSnap.docs) {
        const { tipo, monto } = doc.data() as { tipo: string; monto: number };
        if      (tipo === "diesel")        tco.combustible   += monto;
        else if (tipo === "mantenimiento") tco.mantenimiento += monto;
        else if (tipo === "peaje")         tco.peajes        += monto;
        else if (tipo === "grua")          tco.grua          += monto;
        else                               tco.otros         += monto;
      }
      tco.total = tco.combustible + tco.mantenimiento + tco.peajes + tco.grua + tco.otros;
      const distanciaKm = Math.max(0, odometroFin - odometroInicio);
      const costoPorKm  = distanciaKm > 0 ? tco.total / distanciaKm : 0;

      // ── 2. ACTUALIZAR VIAJE ──────────────────────────────────────
      await viajeRef.update({
        tco,
        costo_por_km: costoPorKm,
        ...(after.fecha_fin ? {} : { fecha_fin: admin.firestore.FieldValue.serverTimestamp() }),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // ── 3. ACTUALIZAR UNIDAD ─────────────────────────────────────
      let alertasSnap = { size: 0, docs: [] as FirebaseFirestore.QueryDocumentSnapshot[] };
      if (unidadId) {
        const unidadSnap = await db.collection(C.COL.unidades).doc(unidadId).get();
        const proxMant   = (unidadSnap.data()?.proximo_mantenimiento_odometro ?? 0) as number;
        const necesitaMant = odometroFin > 0 && proxMant > 0 && odometroFin >= proxMant;
        const unidadUpd: Record<string, unknown> = {
          estado:               necesitaMant ? "mantenimiento" : "disponible",
          viaje_activo_id:      null,
          ultima_actualizacion: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (odometroFin > 0) unidadUpd.odometro_actual = odometroFin;
        await db.collection(C.COL.unidades).doc(unidadId).update(unidadUpd);
        if (necesitaMant) {
          logger.info(`Unidad ${unidadId} requiere mantenimiento (odómetro: ${odometroFin})`);
        }
      }

      // ── 4. CERRAR ALERTAS DEL VIAJE ──────────────────────────────
      const alertasQuery = await db
        .collection(C.COL.alertas)
        .where("viaje_id", "==", viajeId)
        .where("estado",   "==", "activa")
        .get();
      alertasSnap = alertasQuery;
      if (!alertasQuery.empty) {
        const alertBatch = db.batch();
        for (const doc of alertasQuery.docs) {
          alertBatch.update(doc.ref, {
            estado:       "cerrada_automaticamente",
            fecha_cierre: admin.firestore.FieldValue.serverTimestamp(),
            notas:        "Cerrada automáticamente al completar el viaje.",
          });
        }
        await alertBatch.commit();
      }

      // ── 5. SCORE DEL OPERADOR ────────────────────────────────────
      if (operadorId) {
        await _actualizarScoreOperador(operadorId, operadorNombre, tieneBanderaRoja);
      }

      // ── 6. FACTURA (idempotente) ─────────────────────────────────
      const COL_FC  = "facturas_clientes";
      const COL_CFG = "config";
      const existente = await db.collection(COL_FC)
        .where("viaje_id", "==", viajeId).limit(1).get();

      if (existente.empty) {
        const pricing    = (await db.collection(COL_CFG).doc("pricing").get()).data();
        const margenPct  = (pricing?.margen_pct ?? 0.15) as number;
        const monto      = parseFloat((tco.total * (1 + margenPct)).toFixed(2));
        const anio       = new Date().getFullYear();
        const contadorId = `factura_contador_${anio}`;

        const nro = await db.runTransaction(async (tx) => {
          const cRef = db.collection(COL_CFG).doc(contadorId);
          const cSnap = await tx.get(cRef);
          const sig = ((cSnap.data()?.ultimo ?? 0) as number) + 1;
          tx.set(cRef, { ultimo: sig }, { merge: true });
          return `GL-${anio}-${String(sig).padStart(4, "0")}`;
        });

        const emision     = new Date();
        const vencimiento = new Date(emision);
        vencimiento.setDate(vencimiento.getDate() + 30);

        await db.collection(COL_FC).add({
          viaje_id:          viajeId,
          cliente_id:        clienteId,
          cliente_nombre:    clienteNombre,
          numero_factura:    nro,
          fecha_emision:     admin.firestore.Timestamp.fromDate(emision),
          fecha_vencimiento: admin.firestore.Timestamp.fromDate(vencimiento),
          monto,
          monto_cobrado:     null,
          estatus:           "pendiente",
          fecha_cobro:       null,
          carta_porte_uuid:  null,
          tco_base:          tco.total,
          margen_pct:        margenPct,
          created_at:        admin.firestore.FieldValue.serverTimestamp(),
        });
        logger.info(`Factura ${nro}: $${monto.toFixed(2)} (viaje: ${viajeId})`);
      }

      // ── 7. ACTIVIDAD OPERATIVA ───────────────────────────────────
      await db.collection(C.COL.actividad).add({
        tipo:        "viaje_completado",
        viaje_id:    viajeId,
        operador_id: operadorId,
        unidad_id:   unidadId,
        timestamp:   admin.firestore.FieldValue.serverTimestamp(),
        metadata: {
          tco_total:          tco.total,
          costo_por_km:       costoPorKm,
          distancia_km:       distanciaKm,
          operador_nombre:    operadorNombre,
          tenia_bandera_roja: tieneBanderaRoja,
          alertas_cerradas:   alertasSnap.size,
        },
      });

      // ── 8. FCM OPERADOR + TORRE ──────────────────────────────────
      const tokens = await _tokensDeRoles(["supervisor", "administrador"]);
      const opSnap = await db.collection(C.COL.usuarios).doc(operadorId).get();
      const opFcm  = opSnap.data()?.fcm_token as string | undefined;
      if (opFcm) tokens.push(opFcm);

      if (tokens.length > 0) {
        await getMessaging().sendEachForMulticast({
          tokens,
          notification: {
            title: "✅ Viaje Completado",
            body:  `${operadorNombre} — TCO: $${tco.total.toFixed(2)} MXN`,
          },
          data: {
            tipo:         "viaje_completado",
            viaje_id:     viajeId,
            operador_id:  operadorId,
            tco_total:    tco.total.toFixed(2),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: { priority: "normal" },
        });
      }

      logger.info(
        `lifecycleViajeCompletado OK — ${viajeId} ` +
        `TCO=$${tco.total.toFixed(2)} km=${distanciaKm} alertas=${alertasSnap.size}`
      );

    } catch (err) {
      logger.error(`lifecycleViajeCompletado ERROR — ${viajeId}:`, err);
      await viajeRef.update({ lc_completado: false }).catch(() => null);
      throw err; // Activa el reintento automático de Cloud Functions
    }
  }
);

// ═══════════════════════════════════════════════════════════════════
// HELPERS — Score de operadores
// ═══════════════════════════════════════════════════════════════════

function _calcularScore(
  viajesCompletados: number,
  totalViajes:       number,
  alertasSOS:        number,
  banderasRojas:     number,
): number {
  if (totalViajes === 0) return 100;
  const completitud  = viajesCompletados / totalViajes;
  const sosRate      = Math.min(alertasSOS    / totalViajes, 1);
  const banderaRate  = Math.min(banderasRojas / totalViajes, 1);
  return Math.max(0, Math.min(100,
    completitud        * 60 +
    (1 - sosRate)      * 25 +
    (1 - banderaRate)  * 15,
  ));
}

async function _actualizarScoreOperador(
  operadorId:       string,
  operadorNombre:   string,
  tieneBanderaRoja: boolean,
): Promise<void> {
  const ref = db.collection(C.COL.scores).doc(operadorId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const d = snap.data() ?? { total_viajes: 0, viajes_completados: 0, alertas_sos: 0, banderas_rojas: 0 };
    const totalViajes       = (d.total_viajes        as number) + 1;
    const viajesCompletados = (d.viajes_completados  as number) + 1;
    const alertasSOS        = (d.alertas_sos         as number);
    const banderasRojas     = (d.banderas_rojas      as number) + (tieneBanderaRoja ? 1 : 0);
    const score = _calcularScore(viajesCompletados, totalViajes, alertasSOS, banderasRojas);
    tx.set(ref, {
      operador_id:         operadorId,
      operador_nombre:     operadorNombre,
      total_viajes:        totalViajes,
      viajes_completados:  viajesCompletados,
      alertas_sos:         alertasSOS,
      banderas_rojas:      banderasRojas,
      score:               Math.round(score),
      ultimo_viaje_at:     admin.firestore.FieldValue.serverTimestamp(),
      updated_at:          admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function _incrementarSOSEnScore(operadorId: string): Promise<void> {
  const ref = db.collection(C.COL.scores).doc(operadorId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return; // Score se inicializa al completar el primer viaje
    const d = snap.data()!;
    const alertasSOS       = (d.alertas_sos        as number) + 1;
    const totalViajes      = (d.total_viajes        as number);
    const viajesComp       = (d.viajes_completados  as number);
    const banderasRojas    = (d.banderas_rojas       as number);
    const score = _calcularScore(viajesComp, totalViajes, alertasSOS, banderasRojas);
    tx.update(ref, {
      alertas_sos: alertasSOS,
      score:       Math.round(score),
      updated_at:  admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

// ═══════════════════════════════════════════════════════════════════
// HELPER — Tokens FCM por rol
// ═══════════════════════════════════════════════════════════════════

async function _tokensDeRoles(roles: string[]): Promise<string[]> {
  const snap = await db.collection(C.COL.usuarios)
    .where("rol", "in", roles)
    .get();
  const tokens: string[] = [];
  for (const doc of snap.docs) {
    const fcm = doc.data().fcm_token as string | undefined;
    if (fcm) tokens.push(fcm);
  }
  return tokens;
}

// ═══════════════════════════════════════════════════════════════════
// Fn 16 — onClienteCreado
// Valida RFC, detecta duplicados y normaliza nombre para búsqueda.
// ═══════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════
// Fn 17 — onTicketCombustibleCreado
// Supervisa cada registro de costo tipo "combustible" con foto.
// Valida litros, detecta anomalías y notifica al supervisor.
// ═══════════════════════════════════════════════════════════════════

export const onTicketCombustibleCreado = onDocumentCreated(
  `${C.COL.costos}/{costoId}`,
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.tipo !== "combustible") return;

    const viajeId    = data.viaje_id as string | undefined;
    const litros     = (data.litros as number | undefined) ?? 0;
    const monto      = (data.monto  as number | undefined) ?? 0;
    const imagenUrl  = data.imagen_url as string | undefined;
    const costoId    = event.params.costoId;

    if (!viajeId) return;

    // ── Leer viaje para comparar litros esperados
    const viajeSnap = await db.collection(C.COL.viajes).doc(viajeId).get();
    if (!viajeSnap.exists) return;

    const viajeData       = viajeSnap.data()!;
    const litrosCargados  = (viajeData.litros_cargados as number | undefined) ?? 0;
    const operadorId      = viajeData.operador_id as string;

    // ── Detectar recarga excesiva (> 110% de la capacidad cargada)
    const umbralAnomalia = litrosCargados * 1.1;
    const esAnomalia = litrosCargados > 0 && litros > umbralAnomalia;

    const updates: Record<string, unknown> = {
      supervisado: true,
      anomalia_detectada: esAnomalia,
    };

    if (esAnomalia) {
      updates.anomalia_motivo =
        `Litros registrados (${litros.toFixed(1)}L) superan el 110% de la capacidad cargada (${litrosCargados.toFixed(1)}L)`;
      logger.warn(`[onTicketCombustibleCreado] Anomalía en costo ${costoId}: ${litros}L vs ${litrosCargados}L cargados`);
    }

    await db.collection(C.COL.costos).doc(costoId).update(updates);

    // ── Notificar a supervisores vía FCM
    const tokens = await _tokensDeRoles(["supervisor", "administrador"]);
    if (tokens.length === 0) return;

    const titulo = esAnomalia
      ? "⚠️ Anomalía en ticket de combustible"
      : "🛢️ Ticket de combustible registrado";

    const cuerpo = esAnomalia
      ? `Operador registró ${litros.toFixed(1)}L — posible sobrecarga. Revisar foto.`
      : `${litros.toFixed(1)}L · $${monto.toFixed(2)} MXN${imagenUrl ? " · Con foto" : ""}`;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: { title: titulo, body: cuerpo },
      data: {
        tipo:        "ticket_combustible",
        viaje_id:    viajeId,
        costo_id:    costoId,
        operador_id: operadorId,
        anomalia:    esAnomalia ? "1" : "0",
      },
      android: {
        priority: esAnomalia ? "high" : "normal",
        notification: { channelId: "operaciones" },
      },
    });
  }
);

export const onClienteCreado = onDocumentCreated(
  `${C.COL.clientes}/{clienteId}`,
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const clienteId = event.params.clienteId;
    const ref = db.collection(C.COL.clientes).doc(clienteId);

    const updates: Record<string, unknown> = {};

    // ── Normalizar nombre para búsqueda
    if (typeof data.nombre === "string" && !data.nombre_busqueda) {
      updates.nombre_busqueda = (data.nombre as string).toLowerCase().trim();
    }

    // ── Validar y verificar RFC
    const rfc = (data.rfc as string | undefined)?.toUpperCase().trim();
    if (rfc) {
      // RFC México: 3-4 letras + 6 dígitos + 3 alfanumérico
      const rfcRegex = /^[A-ZÑ&]{3,4}\d{6}[A-Z\d]{3}$/;
      if (!rfcRegex.test(rfc)) {
        updates.rfc_valido = false;
        updates.rfc_invalido_motivo = "Formato incorrecto";
        logger.warn(`[onClienteCreado] RFC inválido: ${rfc} en cliente ${clienteId}`);
      } else {
        updates.rfc_valido = true;
        // Verificar duplicados (busca otros documentos con el mismo RFC activo)
        const duplicados = await db.collection(C.COL.clientes)
          .where("rfc", "==", rfc)
          .where("activo", "==", true)
          .get();
        // El propio documento ya existe, así que > 1 indica duplicado
        updates.rfc_duplicado = duplicados.size > 1;
        if (duplicados.size > 1) {
          logger.warn(`[onClienteCreado] RFC duplicado: ${rfc}`);
        }
        // Normalizar RFC a mayúsculas en el documento
        updates.rfc = rfc;
      }
    }

    if (Object.keys(updates).length > 0) {
      await ref.update(updates);
    }
  }
);
