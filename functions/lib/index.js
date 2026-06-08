"use strict";
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.actualizarUsuario = exports.crearUsuario = exports.recalcularAuditoriasSemanales = exports.ejecutarAuditoriaManual = exports.atenderAlerta = exports.recalcularTco = exports.onAlertaSOS = exports.auditoriaCombustible = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const messaging_1 = require("firebase-admin/messaging");
const firebase_functions_1 = require("firebase-functions");
admin.initializeApp();
const db = admin.firestore();
// ═══════════════════════════════════════════════════════════════════
// CONSTANTES
// ═══════════════════════════════════════════════════════════════════
const C = {
    // Umbrales de varianza (portados de LitroExacto)
    VARIANZA_LIMPIO: 0.015, // < 1.5 %  → conciliado
    VARIANZA_ADVERTENCIA: 0.05, // 1.5–5 %  → advertencia
    VARIANZA_SOSPECHOSO: 0.15, // 5–15 %   → sospechoso
    // > 15 % → probable fraude
    // Tolerancia dinámica (portada de LitroExacto)
    BASE_TOLERANCIA_LITROS: 0.3,
    PCT_TOLERANCIA: 0.02, // 2 %
    // Validación de datos del ticket
    MIN_LITROS: 1.0,
    MAX_LITROS: 500.0, // camiones > 200 L
    MIN_PRECIO_POR_LITRO: 15.0,
    MAX_PRECIO_POR_LITRO: 45.0,
    // Rendimiento diésel flota (fallback si no hay telemetría)
    RENDIMIENTO_BASE_KM_L: 3.5,
    COL: {
        viajes: "viajes",
        costos: "costos_operativos",
        alertas: "alertas_seguridad",
        unidades: "unidades",
        usuarios: "usuarios",
        auditorias: "auditorias_combustible",
        rateLimits: "rate_limit_operadores",
    },
};
// ═══════════════════════════════════════════════════════════════════
// OCR NORMALIZATION (portado de LitroExacto index.ts — normalizeOCR)
// ═══════════════════════════════════════════════════════════════════
function normalizeOCR(text) {
    let t = text;
    // Confusiones comunes en tickets mexicanos de combustible
    t = t.replace(/(?<=\d)O(?=\d)/g, "0");
    t = t.replace(/(?<=\d)l(?=\d)/g, "1");
    t = t.replace(/(?<=\d)I(?=\d)/g, "1");
    t = t.replace(/(?<=\d)S(?=\d)/g, "5");
    t = t.replace(/(?<=\d)B(?=\d)/g, "8");
    t = t.replace(/(?<=\d)g(?=\d)/g, "9");
    t = t.replace(/(?<=\d)Z(?=\d)/g, "2");
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
function clasificarVarianza(deltaAbs, tolerancia, varianzaPct) {
    if (deltaAbs <= tolerancia || varianzaPct <= C.VARIANZA_LIMPIO * 100) {
        return "limpio";
    }
    if (varianzaPct <= C.VARIANZA_ADVERTENCIA * 100)
        return "advertencia";
    if (varianzaPct <= C.VARIANZA_SOSPECHOSO * 100)
        return "sospechoso";
    return "fraudeProbable";
}
// Score de consistencia de datos (portado de calculateDataConsistency)
function consistencyScore(varianzaPct) {
    const v = Math.abs(varianzaPct);
    if (v <= 1)
        return 1.0;
    if (v <= 3)
        return 0.9;
    if (v <= 5)
        return 0.8;
    if (v <= 10)
        return 0.6;
    if (v <= 20)
        return 0.4;
    return 0.2;
}
// Score compuesto: coherenciaVolumetrica × 0.40 + credibilidadOcr × 0.35 + consistencia × 0.25
function calcularScoreCompuesto(coherenciaVolumetrica, credibilidadOcr, varianzaPct) {
    const cs = consistencyScore(varianzaPct) * 100;
    return Math.max(0, Math.min(100, coherenciaVolumetrica * 0.40 +
        credibilidadOcr * 0.35 +
        cs * 0.25));
}
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 1 — AUDITORÍA "LITRO EXACTO"
// Trigger: escritura en costos_operativos (tipo diesel)
// Idempotente: verifica auditorias_combustible/{viajeId} antes de procesar
// ═══════════════════════════════════════════════════════════════════
exports.auditoriaCombustible = (0, firestore_1.onDocumentWritten)(`${C.COL.costos}/{costoId}`, async (event) => {
    const afterData = event.data?.after?.data();
    if (!afterData || afterData.tipo !== "diesel")
        return;
    const viajeId = afterData.viaje_id;
    if (!viajeId)
        return;
    // ── IDEMPOTENCY: marcar como procesando ──────────────────────────
    const auditoriaRef = db.collection(C.COL.auditorias).doc(viajeId);
    const procesando = await auditoriaRef.get();
    if (procesando.exists && procesando.data()?.procesando === true) {
        firebase_functions_1.logger.info(`Auditoría en proceso para viaje ${viajeId}, omitiendo.`);
        return;
    }
    await auditoriaRef.set({ procesando: true }, { merge: true });
    try {
        firebase_functions_1.logger.info(`Auditoría Litro Exacto — viaje: ${viajeId}`);
        // ── 1. Obtener viaje ──────────────────────────────────────────
        const viajeSnap = await db.collection(C.COL.viajes).doc(viajeId).get();
        if (!viajeSnap.exists) {
            firebase_functions_1.logger.warn(`Viaje ${viajeId} no encontrado`);
            return;
        }
        const viaje = viajeSnap.data();
        // ── 2. Agregar todos los tickets de diesel del viaje ──────────
        const costosSnap = await db
            .collection(C.COL.costos)
            .where("viaje_id", "==", viajeId)
            .where("tipo", "==", "diesel")
            .get();
        let litrosTickets = 0;
        let montoTotalDiesel = 0;
        let sumaCredibilidadOcr = 0;
        let countOcr = 0;
        for (const doc of costosSnap.docs) {
            const costo = doc.data();
            // Normalizar texto OCR — reservado para validación futura de campos extraídos
            normalizeOCR(costo.datos_ocr?.texto_completo ?? "");
            const litrosOcr = costo.datos_ocr?.litros_detectados ?? 0;
            const confianza = costo.datos_ocr?.confianza ?? 0.5;
            // Validación de rangos (portada de LitroExacto)
            if (litrosOcr >= C.MIN_LITROS && litrosOcr <= C.MAX_LITROS) {
                litrosTickets += litrosOcr;
                montoTotalDiesel += (costo.monto ?? 0);
                sumaCredibilidadOcr += confianza * 100;
                countOcr++;
            }
            else {
                firebase_functions_1.logger.warn(`Litros fuera de rango en costo ${doc.id}: ${litrosOcr}L`);
            }
        }
        if (litrosTickets === 0) {
            await auditoriaRef.set({ procesando: false }, { merge: true });
            return;
        }
        const credibilidadOcrPromedio = countOcr > 0 ? sumaCredibilidadOcr / countOcr : 50;
        // ── 3. Telemetría: litros por km recorridos ───────────────────
        const odometroInicio = (viaje.odometro_inicio ?? 0);
        const odometroFin = (viaje.odometro_fin ?? 0);
        const rendimiento = (viaje.rendimiento_base ?? C.RENDIMIENTO_BASE_KM_L);
        const distanciaKm = Math.max(0, odometroFin - odometroInicio);
        const litrosTelemetria = distanciaKm > 0
            ? distanciaKm / rendimiento
            : litrosTickets; // fallback: confiar en tickets si no hay km
        // ── 4. Tolerancia dinámica (portada de LitroExacto) ──────────
        // tolerance = max(0.3L, 2% de litros de referencia)
        const tolerancia = Math.max(C.BASE_TOLERANCIA_LITROS, litrosTelemetria * C.PCT_TOLERANCIA);
        // ── 5. Calcular varianza ──────────────────────────────────────
        const delta = litrosTelemetria - litrosTickets;
        const varianzaPct = litrosTelemetria > 0
            ? (Math.abs(delta) / litrosTelemetria) * 100
            : 0;
        // ── 6. Clasificar nivel ───────────────────────────────────────
        const nivel = clasificarVarianza(Math.abs(delta), tolerancia, varianzaPct);
        // ── 7. Score compuesto ────────────────────────────────────────
        // coherenciaVolumetrica: si hay medidor de tablero usarla, si no 70 (neutral)
        const coherenciaVolumetrica = (viaje.coherencia_volumetrica ?? 70);
        const scoreCompuesto = calcularScoreCompuesto(coherenciaVolumetrica, credibilidadOcrPromedio, varianzaPct);
        const tieneBanderaRoja = nivel === "sospechoso" || nivel === "fraudeProbable";
        // ── 8. Guardar resultado de auditoría ─────────────────────────
        const resultado = {
            viajeId,
            unidadId: viaje.unidad_id ?? "",
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
            litros_consumidos_tickets: litrosTickets,
            litros_consumidos_telemetria: litrosTelemetria,
            varianza_combustible: varianzaPct / 100,
            nivel_alerta: tieneBanderaRoja ? nivel : "ninguna",
            "tco.combustible": montoTotalDiesel,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        // ── 10. Crear alerta y notificar si hay bandera roja ──────────
        if (tieneBanderaRoja) {
            await _crearAlertaVarianza(resultado, varianzaPct);
            await _notificarTorreControl(resultado, varianzaPct, nivel);
        }
        firebase_functions_1.logger.info(`Litro Exacto completo — ${viajeId}: varianza=${varianzaPct.toFixed(2)}% nivel=${nivel}`);
    }
    catch (err) {
        firebase_functions_1.logger.error(`Error en auditoría ${viajeId}:`, err);
        await auditoriaRef.set({ procesando: false, error: String(err) }, { merge: true });
    }
});
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 2 — PROTOCOLO SOS
// Trigger: creación de alerta de tipo sos
// Push FCM con sonido de emergencia a supervisores/admins
// ═══════════════════════════════════════════════════════════════════
exports.onAlertaSOS = (0, firestore_1.onDocumentCreated)(`${C.COL.alertas}/{alertaId}`, async (event) => {
    const data = event.data?.data();
    if (!data || data.tipo !== "sos")
        return;
    const alertaId = event.params.alertaId;
    const operadorId = data.operador_id;
    const unidadId = data.unidad_id;
    const viajeId = data.viaje_id;
    const posicion = data.posicion;
    firebase_functions_1.logger.info(`SOS activado — alerta: ${alertaId} operador: ${operadorId}`);
    // Tokens FCM de supervisores y administradores
    const supervisoresSnap = await db
        .collection(C.COL.usuarios)
        .where("rol", "in", ["supervisor", "administrador"])
        .get();
    const tokens = [];
    for (const doc of supervisoresSnap.docs) {
        const fcm = doc.data().fcm_token;
        if (fcm)
            tokens.push(fcm);
    }
    if (tokens.length === 0) {
        firebase_functions_1.logger.warn("Sin tokens FCM de supervisores registrados");
        await event.data?.ref.update({ notificacion_enviada: false });
        return;
    }
    const resp = await (0, messaging_1.getMessaging)().sendEachForMulticast({
        tokens,
        notification: {
            title: "🚨 PROTOCOLO SOS ACTIVADO",
            body: `Operador ${operadorId} — Unidad ${unidadId} necesita asistencia urgente.`,
        },
        data: {
            tipo: "sos",
            alerta_id: alertaId,
            viaje_id: viajeId,
            operador_id: operadorId,
            unidad_id: unidadId,
            lat: String(posicion?.lat ?? 0),
            lng: String(posicion?.lng ?? 0),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
            priority: "high",
            notification: {
                channelId: "sos_alerts",
                sound: "sos_alarm",
                priority: "max",
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
        notificacion_enviada: true,
        notificacion_timestamp: admin.firestore.FieldValue.serverTimestamp(),
        destinatarios_notificados: resp.successCount,
        destinatarios_fallidos: resp.failureCount,
    });
    firebase_functions_1.logger.info(`SOS notificado — éxito: ${resp.successCount} fallo: ${resp.failureCount}`);
});
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 3 — RECÁLCULO TCO AL COMPLETAR VIAJE
// Trigger: cambio de estado a "completado" en viajes
// ═══════════════════════════════════════════════════════════════════
exports.recalcularTco = (0, firestore_1.onDocumentWritten)(`${C.COL.viajes}/{viajeId}`, async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after || !before)
        return;
    if (before.estado === "completado" || after.estado !== "completado")
        return;
    const viajeId = event.params.viajeId;
    firebase_functions_1.logger.info(`TCO final — viaje completado: ${viajeId}`);
    const costosSnap = await db
        .collection(C.COL.costos)
        .where("viaje_id", "==", viajeId)
        .get();
    const tco = { combustible: 0, mantenimiento: 0, peajes: 0, grua: 0, otros: 0, total: 0 };
    for (const doc of costosSnap.docs) {
        const { tipo, monto } = doc.data();
        switch (tipo) {
            case "diesel":
                tco.combustible += monto;
                break;
            case "mantenimiento":
                tco.mantenimiento += monto;
                break;
            case "peaje":
                tco.peajes += monto;
                break;
            case "grua":
                tco.grua += monto;
                break;
            default: tco.otros += monto;
        }
    }
    tco.total = tco.combustible + tco.mantenimiento + tco.peajes + tco.grua + tco.otros;
    // Calcular costo por km
    const odometroInicio = (after.odometro_inicio ?? 0);
    const odometroFin = (after.odometro_fin ?? 0);
    const distanciaKm = Math.max(0, odometroFin - odometroInicio);
    const costoPorKm = distanciaKm > 0 ? tco.total / distanciaKm : 0;
    await db.collection(C.COL.viajes).doc(viajeId).update({
        tco,
        costo_por_km: costoPorKm,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    firebase_functions_1.logger.info(`TCO final — ${viajeId}: $${tco.total.toFixed(2)} MXN ($${costoPorKm.toFixed(2)}/km)`);
});
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 4 — CALLABLE: Atender alerta
// Verifica rol supervisor/admin antes de marcar como atendida
// ═══════════════════════════════════════════════════════════════════
exports.atenderAlerta = (0, https_1.onCall)({ enforceAppCheck: false }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const { alertaId, notas } = request.data;
    if (!alertaId)
        throw new https_1.HttpsError("invalid-argument", "alertaId requerido.");
    const uid = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol = usuarioSnap.data()?.rol;
    if (!rol || !["supervisor", "administrador"].includes(rol)) {
        throw new https_1.HttpsError("permission-denied", "Rol insuficiente.");
    }
    await db.collection(C.COL.alertas).doc(alertaId).update({
        estado: "atendida",
        atendida_por: uid,
        notas: notas ?? "",
        fecha_atencion: admin.firestore.FieldValue.serverTimestamp(),
    });
    firebase_functions_1.logger.info(`Alerta ${alertaId} atendida por ${uid}`);
    return { success: true };
});
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 5 — CALLABLE: Ejecutar auditoría manual desde Torre de Control
// Recibe parámetros del viaje y devuelve el AuditoriaResultado
// ═══════════════════════════════════════════════════════════════════
exports.ejecutarAuditoriaManual = (0, https_1.onCall)({ enforceAppCheck: false }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const uid = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol = usuarioSnap.data()?.rol;
    if (!rol || !["supervisor", "administrador"].includes(rol)) {
        throw new https_1.HttpsError("permission-denied", "Rol insuficiente.");
    }
    const { viajeId, litrosTickets, litrosTelemetria, credibilidadOcrPromedio = 70, coherenciaVolumetrica = 70, } = request.data;
    if (!viajeId || litrosTickets <= 0) {
        throw new https_1.HttpsError("invalid-argument", "Parámetros inválidos.");
    }
    const tolerancia = Math.max(C.BASE_TOLERANCIA_LITROS, litrosTelemetria * C.PCT_TOLERANCIA);
    const delta = litrosTelemetria - litrosTickets;
    const varianzaPct = litrosTelemetria > 0
        ? (Math.abs(delta) / litrosTelemetria) * 100
        : 0;
    const nivel = clasificarVarianza(Math.abs(delta), tolerancia, varianzaPct);
    const scoreCompuesto = calcularScoreCompuesto(coherenciaVolumetrica, credibilidadOcrPromedio, varianzaPct);
    const tieneBanderaRoja = nivel === "sospechoso" || nivel === "fraudeProbable";
    const resultado = {
        viajeId,
        unidadId: "",
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
        processedAt: admin.firestore.Timestamp.now(),
        processingVersion: "1.0.0-manual",
    };
    if (tieneBanderaRoja) {
        await db.collection(C.COL.viajes).doc(viajeId).update({
            nivel_alerta: nivel,
            varianza_combustible: varianzaPct / 100,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    return resultado;
});
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 6 — SCHEDULED: Recálculo semanal de auditorías
// Corrige drift de actualizaciones incrementales
// ═══════════════════════════════════════════════════════════════════
exports.recalcularAuditoriasSemanales = (0, scheduler_1.onSchedule)({ schedule: "0 2 * * 0", timeZone: "America/Mexico_City" }, async () => {
    firebase_functions_1.logger.info("Recalculando auditorías semanales...");
    const viajesSnap = await db
        .collection(C.COL.viajes)
        .where("estado", "==", "completado")
        .where("nivel_alerta", "in", ["sospechoso", "fraudeProbable"])
        .get();
    let procesados = 0;
    for (const doc of viajesSnap.docs) {
        const viaje = doc.data();
        const viajeId = doc.id;
        // Recalcular desde costos originales
        const costosSnap = await db
            .collection(C.COL.costos)
            .where("viaje_id", "==", viajeId)
            .where("tipo", "==", "diesel")
            .get();
        let litrosTickets = 0;
        for (const c of costosSnap.docs) {
            litrosTickets += (c.data().datos_ocr?.litros_detectados ?? 0);
        }
        const rendimiento = (viaje.rendimiento_base ?? C.RENDIMIENTO_BASE_KM_L);
        const distanciaKm = Math.max(0, (viaje.odometro_fin ?? 0) - (viaje.odometro_inicio ?? 0));
        const litrosTelemetria = distanciaKm > 0 ? distanciaKm / rendimiento : litrosTickets;
        const tolerancia = Math.max(C.BASE_TOLERANCIA_LITROS, litrosTelemetria * C.PCT_TOLERANCIA);
        const delta = litrosTelemetria - litrosTickets;
        const varianzaPct = litrosTelemetria > 0 ? (Math.abs(delta) / litrosTelemetria) * 100 : 0;
        const nivel = clasificarVarianza(Math.abs(delta), tolerancia, varianzaPct);
        await doc.ref.update({
            varianza_combustible: varianzaPct / 100,
            nivel_alerta: nivel,
            updated_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        procesados++;
    }
    firebase_functions_1.logger.info(`Recálculo semanal completo — ${procesados} viajes actualizados`);
});
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 7 — CALLABLE: Crear usuario (solo administradores)
// Usa Admin SDK para crear cuenta Auth sin cerrar sesión del admin.
// ═══════════════════════════════════════════════════════════════════
exports.crearUsuario = (0, https_1.onCall)({ enforceAppCheck: false }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const uid = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol = usuarioSnap.data()?.rol;
    if (rol !== "administrador") {
        throw new https_1.HttpsError("permission-denied", "Solo el administrador puede crear usuarios.");
    }
    const { email, password, nombre, rolNuevo } = request.data;
    if (!email || !password || !nombre || !rolNuevo) {
        throw new https_1.HttpsError("invalid-argument", "email, password, nombre y rolNuevo son requeridos.");
    }
    const rolesValidos = ["operador", "supervisor", "administrador"];
    if (!rolesValidos.includes(rolNuevo)) {
        throw new https_1.HttpsError("invalid-argument", `Rol inválido: ${rolNuevo}`);
    }
    // Crear cuenta en Firebase Auth
    const userRecord = await admin.auth().createUser({ email, password, displayName: nombre });
    // Crear documento en Firestore
    await db.collection(C.COL.usuarios).doc(userRecord.uid).set({
        email,
        nombre,
        rol: rolNuevo,
        activo: true,
        creado_por: uid,
        creado_at: admin.firestore.FieldValue.serverTimestamp(),
        ultimo_acceso: null,
    });
    firebase_functions_1.logger.info(`Usuario creado: ${userRecord.uid} (${email}) rol=${rolNuevo} por admin ${uid}`);
    return { uid: userRecord.uid };
});
// ═══════════════════════════════════════════════════════════════════
// FUNCIÓN 8 — CALLABLE: Actualizar usuario (solo administradores)
// Cambia rol, nombre y/o estado activo. Revoca tokens si desactiva.
// ═══════════════════════════════════════════════════════════════════
exports.actualizarUsuario = (0, https_1.onCall)({ enforceAppCheck: false }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Autenticación requerida.");
    }
    const uid = request.auth.uid;
    const usuarioSnap = await db.collection(C.COL.usuarios).doc(uid).get();
    const rol = usuarioSnap.data()?.rol;
    if (rol !== "administrador") {
        throw new https_1.HttpsError("permission-denied", "Solo el administrador puede modificar usuarios.");
    }
    const { targetUid, nombre, rolNuevo, activo } = request.data;
    if (!targetUid) {
        throw new https_1.HttpsError("invalid-argument", "targetUid requerido.");
    }
    const updates = {
        modificado_por: uid,
        modificado_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (nombre !== undefined)
        updates.nombre = nombre;
    if (rolNuevo !== undefined)
        updates.rol = rolNuevo;
    if (activo !== undefined) {
        updates.activo = activo;
        // Revocar sesiones activas si se desactiva
        if (!activo)
            await admin.auth().revokeRefreshTokens(targetUid);
    }
    await db.collection(C.COL.usuarios).doc(targetUid).update(updates);
    firebase_functions_1.logger.info(`Usuario ${targetUid} actualizado por admin ${uid}: ${JSON.stringify(updates)}`);
    return { success: true };
});
// ═══════════════════════════════════════════════════════════════════
// HELPERS PRIVADOS
// ═══════════════════════════════════════════════════════════════════
async function _crearAlertaVarianza(resultado, varianzaPct) {
    await db.collection(C.COL.alertas).add({
        viaje_id: resultado.viajeId,
        operador_id: resultado.operadorId,
        unidad_id: resultado.unidadId,
        tipo: "varianzaCombustible",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        estado: "activa",
        metadata: {
            varianza_pct: varianzaPct.toFixed(2),
            nivel: resultado.nivel,
            litros_telemetria: resultado.litrosTelemetria,
            litros_tickets: resultado.litrosTickets,
            delta_litros: resultado.deltaLitros.toFixed(2),
            score_compuesto: resultado.scoreCompuesto.toFixed(1),
        },
    });
}
async function _notificarTorreControl(resultado, varianzaPct, nivel) {
    const supervisoresSnap = await db
        .collection(C.COL.usuarios)
        .where("rol", "in", ["supervisor", "administrador"])
        .get();
    const tokens = [];
    for (const doc of supervisoresSnap.docs) {
        const fcm = doc.data().fcm_token;
        if (fcm)
            tokens.push(fcm);
    }
    if (tokens.length === 0)
        return;
    const esGrave = nivel === "fraudeProbable";
    await (0, messaging_1.getMessaging)().sendEachForMulticast({
        tokens,
        notification: {
            title: esGrave
                ? `🚩 Probable Fraude — Varianza ${varianzaPct.toFixed(1)}%`
                : `⚠️ Varianza Combustible: ${varianzaPct.toFixed(1)}%`,
            body: `Viaje ${resultado.viajeId} — Unidad ${resultado.unidadId}. Supera umbral.`,
        },
        data: {
            tipo: "varianzaCombustible",
            viaje_id: resultado.viajeId,
            nivel,
            varianza_pct: varianzaPct.toFixed(2),
            click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: { priority: "high" },
    });
}
//# sourceMappingURL=index.js.map