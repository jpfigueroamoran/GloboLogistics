# Verificación Manual — Globo Logistics (por rol de usuario)

> Guion de QA visual para recorrer las 7 clases de usuario antes de soltar a
> usuarios reales. Marca cada paso y anota hallazgos al final de cada rol.
> Estado: ✅ OK | ❌ Error | ⚠️ Mejora | ⏭️ Pendiente

**Cómo ejecutar:** abre la app → en el login toca **"Probar Modo Demo"** →
verás un botón por cada rol. Recorre uno por uno. Para los flujos que escriben
datos (crear solicitud, registrar servicio, etc.) usa **modo producción** con
cuentas reales, porque en demo están deshabilitados a propósito.

---

## SETUP

- [ ] La app arranca en el **login de producción** (Acceso Seguro)
- [ ] "Probar Modo Demo" muestra los **7 botones de rol**
- [ ] "Volver a Modo Producción" regresa al login email/password

---

## 1. SOLICITANTE  (campo · móvil)

- [ ] Entra como Solicitante → ve la bandeja "Mis solicitudes" (en demo, 2 de ejemplo)
- [ ] Botón flotante **"Pedir transporte"** abre la hoja de nueva solicitud
- [ ] Form valida material, origen y destino obligatorios
- [ ] (Producción) Enviar solicitud → aparece en la lista en estado **Pendiente**
- [ ] El chip de estado usa color por estado (pendiente/asignada/en ruta/entregada/rechazada)
- [ ] Una solicitud rechazada muestra el motivo
- [ ] Cerrar sesión pide confirmación

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 2. OPERADOR  (campo · móvil)

- [ ] Entra como Operador → si no tiene vehículo, ve la puerta **"Escanea tu vehículo"**
- [ ] (Producción/Android) Escanear QR de la cabina asocia el vehículo
- [ ] Ícono QR en el app bar permite **cambiar de vehículo**
- [ ] Vista carga el viaje activo (o "Sin viaje activo")
- [ ] Banner offline aparece sin conexión; pull-to-refresh funciona
- [ ] Menú de estado cambia la fase (carga/tránsito/descarga) con viaje activo
- [ ] **SOS**: long-press activa (con vibración); un tap solo muestra la guía
- [ ] Con SOS activo: tomar foto / grabar audio → evidencia se guarda
- [ ] Cancelar SOS pide confirmación → alerta se cierra
- [ ] Combustible: capturar ticket con OCR pre-llena litros/precio/total
- [ ] "Finalizar Viaje" pide confirmación (dispara TCO + factura)
- [ ] Cerrar sesión pide confirmación y detiene el GPS

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 3. MANTENIMIENTO  (campo · tablet)

- [ ] Entra como Mantenimiento → ve el tablero de unidades que requieren servicio
- [ ] KPIs/encabezado muestran total y críticas
- [ ] Barra de progreso hacia el próximo servicio por unidad
- [ ] Botón **"Registrar servicio"** abre diálogo con próximo odómetro sugerido (actual + 20 000)
- [ ] (Producción) Confirmar → la unidad vuelve a **activa** y se fija el próximo servicio
- [ ] Cerrar sesión pide confirmación

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 4. DESPACHADOR  (control · tablet/web)

- [ ] Entra como Despachador → 3 pestañas: **Solicitudes / Asignar / Entregas**
- [ ] Pestaña Solicitudes muestra la cola; el badge cuenta las pendientes
- [ ] La cola ordena: activas primero, luego prioridad (urgente arriba), luego antigüedad
- [ ] Solicitud pendiente: botones **"Rechazar"** (pide motivo) y **"Crear viaje"**
- [ ] (Producción) "Crear viaje" → crea el viaje y marca la solicitud **Asignada**
- [ ] Pestaña **Asignar**: el viaje aparece en pendientes; asignar unidad + operador funciona
- [ ] Dropdown de operadores muestra solo operadores **activos**
- [ ] Pestaña **Entregas**: tablero en vivo con avance y ETA por entrega
- [ ] Cerrar sesión pide confirmación

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 5. SUPERVISOR  (control · web)  — Torre de Control (menú reducido)

- [ ] Entra como Supervisor → dashboard con menú **operativo + finanzas de lectura**
- [ ] NO ve: Finanzas/activos, Proveedores, Cierre Mensual, Auditoría, Usuarios
- [ ] **Overview**: mapa por estado operativo (en ruta/disponible/taller) + KPIs + accesos rápidos
- [ ] Click en unidad en ruta → tooltip con destino + fase + ETA
- [ ] **Entregas**: tablero con avance/ETA (badge de en ruta en el menú)
- [ ] **Despacho**, **Flota** (con QR), **Clientes**, **Score**, **Mantto.**, **Docs.** cargan
- [ ] **Alertas**: "Nueva Regla" abre el editor; tap en una regla la edita; eliminar funciona
- [ ] Resumen / Facturación / Reportes cargan (consulta)
- [ ] SOS nuevo dispara overlay con alarma; "Atender" funciona
- [ ] Responsive: en ventana angosta, navegación pasa a Drawer
- [ ] Cerrar sesión pide confirmación

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 6. DIRECCIÓN  (gestión · escritorio · solo lectura)

- [ ] Entra como Dirección → 2 pestañas: **Resumen** y **Reportes**
- [ ] Resumen ejecutivo carga con indicadores
- [ ] Reportes muestra gráficas; "Exportar PDF" genera el PDF
- [ ] No hay controles de edición (solo lectura)
- [ ] Cerrar sesión pide confirmación

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 7. ADMINISTRADOR  (gestión · escritorio)  — Torre completa

- [ ] Primer login real de admin sin configurar → **wizard de onboarding** (6 pasos)
- [ ] Un no-admin que navegue a /configuracion-inicial es rebotado al dashboard
- [ ] Dashboard muestra **todas** las secciones, incluidas las exclusivas:
  - [ ] Finanzas (activos/pólizas), Proveedores e Inventario, Cierre Mensual
  - [ ] **Auditoría**: filtro **"Periodo"** (Hoy/7 días/30 días/Todo) filtra la lista
  - [ ] **Usuarios**: crear usuario, cambiar rol (los 7), activar/desactivar
- [ ] Cerrar sesión pide confirmación

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 8. CICLO COMPLETO  (extremo a extremo, requiere producción + un supervisor en línea)

> Verifica que el ciclo cierra solo entre roles.

- [ ] Solicitante crea solicitud → estado **Pendiente**
- [ ] Despachador "Crear viaje" → solicitud pasa a **Asignada**
- [ ] Despachador asigna unidad + operador en "Asignar"
- [ ] Operador inicia el viaje → (con Torre abierta) la solicitud pasa a **En ruta**
- [ ] Operador finaliza → la solicitud pasa a **Entregada** y se genera factura
- [ ] El Solicitante ve los cambios de estado **sin que nadie toque su pantalla**

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 9. AUTOMATIZACIÓN CLIENT-SIDE  (motor costo-cero)

- [ ] Al abrir el dashboard (supervisor/admin) corre el motor (consola: `[Automatizacion]`)
- [ ] Viaje completado → TCO, unidad liberada, factura, score actualizado
- [ ] Unidad alcanza odómetro de servicio → pasa a "En taller"
- [ ] Pólizas a ≤30 días → alerta; CxP vencidas → marcadas; stock bajo → alerta

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 10. DEMO ↔ PRODUCCIÓN

- [ ] La app arranca en producción
- [ ] Demo: todos los datos son mock (sin llamadas Firestore reales)
- [ ] Cambiar demo↔producción **sin reiniciar la app**
- [ ] FCM y GPS silenciados en demo, activos en producción
- [ ] Escritura (solicitudes, servicio, viajes) deshabilitada en demo con aviso

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## RESUMEN DE HALLAZGOS

| # | Rol / Sección | Descripción | Severidad | Estado |
|---|---------------|-------------|-----------|--------|
|   |               |             |           |        |
|   |               |             |           |        |
|   |               |             |           |        |
|   |               |             |           |        |
|   |               |             |           |        |
