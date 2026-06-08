# GLOBO LOGISTICS — PLAN DE IMPLEMENTACIÓN ERP
## Control de Activos y Pasivos: Diagnóstico y Hoja de Ruta

**Versión:** 1.0  
**Fecha:** 2026-06-08  
**Arquitecto:** Claude — Rol: Arquitecto de Software Empresarial + Auditor Financiero + Especialista UX/UI  
**Estado:** PENDIENTE DE APROBACIÓN — No implementar hasta autorización explícita

---

## PARTE 1 — GAP ANALYSIS: BRECHAS FINANCIERAS Y OPERATIVAS

### 1.1 Lo que el sistema SÍ tiene hoy

| Área | Cobertura actual |
|---|---|
| Costos por viaje | `TcoViaje` (combustible, mantenimiento, peajes, otros) |
| Costos transaccionales | `CostoOperativo` + OCR de tickets |
| Mantenimiento | `MantenimientoPrevisto` — predictivo por odómetro |
| Documentos | `DocumentoVencimiento` — semáforo de vencimientos |
| Clientes | `Cliente` — entidad básica (nombre, dirección, teléfono) |
| Unidades | `Unidad` — estado, odómetro, capacidad |
| Backend | Cloud Functions: auditoría diesel, TCO final, recálculo semanal |

### 1.2 BRECHA 1 — Activos Fijos: Flotilla sin valor contable

**Diagnóstico:** La entidad `Unidad` modela el tractocamión como un recurso operativo (placas, modelo, odómetro), pero **no existe ninguna representación de su valor patrimonial**. La empresa no sabe:
- ¿Cuánto valen sus camiones en libros hoy?
- ¿Cuánto se está depreciando la flota por mes?
- ¿Cuándo conviene vender una unidad vs. seguir manteniéndola?
- ¿Cuál es el porcentaje de depreciación acumulada por unidad?

**Entidad faltante: `ActivoFijo`**
```
costoAdquisicion   (MXN, ej. $2,800,000)
fechaAdquisicion   (DateTime)
vidaUtilAnios      (int, ej. 10)
valorResidual      (MXN, ej. $280,000)
metodoDepreciacion (lineal | acelerada)

Calculados:
  depreciacionAnual()   = (costo - residual) / vidaUtil
  depreciacionMensual() = depreciacionAnual / 12
  valorLibros(hoy)      = costo - (depreciacionAnual × añosTranscurridos)
  vidaRestanteAnios()   = vidaUtil - añosTranscurridos
```

**Impacto en estados financieros:**
- El costo real por km **no es solo TCO operativo** — falta sumar la fracción de depreciación del viaje.
- Ejemplo real: Si un camión cuesta $2.8M MXN con vida útil de 10 años, su depreciación es $280,000/año = $767/día = ~$38/viaje de 12h. Ese costo es invisible actualmente.

---

### 1.3 BRECHA 2 — Activos Circulantes: Sin Cuentas por Cobrar

**Diagnóstico:** El módulo de clientes (`Cliente`) existe con dirección y teléfono, pero **no hay ningún flujo de facturación**. Cuando un viaje se completa (estado `completado`), no se genera ningún cobro al cliente. La empresa no sabe:
- ¿Cuánto le deben los clientes en total?
- ¿Qué facturas tienen más de 30/60/90 días vencidas?
- ¿Cuál es el flujo de caja esperado del mes próximo?

**Entidades faltantes:**
```
FacturaCliente
  id, viajeId, clienteId, numeroFactura
  fechaEmision, fechaVencimiento (normalmente 30-60 días)
  monto (= TCO total + margen de la empresa)
  estatus: pendiente | cobrada | vencida | cancelada
  fechaCobro?

CuentaPorCobrar (vista consolidada por cliente)
  clienteId, nombreCliente
  facturasPendientes[]
  montoPendienteTotal
  diasMayorAncianidad  (aging: cuántos días lleva sin pagar)
```

**Flujo de integración con lo existente:**
```
Viaje → estado:completado
  → Cloud Function generarFacturaViaje
      → crea FacturaCliente con monto = TCO + margenConfig%
      → actualiza CuentaPorCobrar del cliente
```

---

### 1.4 BRECHA 3 — Pasivos: Sin Cuentas por Pagar

**Diagnóstico:** `CostoOperativo` registra el gasto, pero **no modela la obligación de pago**. En transporte logístico los principales pasivos son:

#### 1.4.1 Líneas de Crédito de Combustible (Edenred / Sodexo / OXXO Fleet)
La empresa típicamente opera con tarjetas de crédito de flota (línea de $200,000-$500,000 MXN mensual). Actualmente:
- No se sabe cuánto del límite de crédito está consumido
- No se sabe cuándo vence el corte mensual
- No hay alerta cuando se acerca al 80% del límite

#### 1.4.2 Talleres Mecánicos
Cuando `MantenimientoPrevisto` se convierte en trabajo real, genera una deuda a taller. No existe `OrdenServicio` ni `CuentaPorPagar` al taller.

#### 1.4.3 Nómina de Operadores
Los operadores tienen score de desempeño pero no hay ningún campo de salario ni cálculo de nómina quincenal.

**Entidades faltantes:**
```
Proveedor
  id, nombre, tipo: (combustible | taller | seguro | otro)
  limiteCredito, saldoDisponible, corte (día del mes)
  contacto, rfc

CuentaPorPagar
  id, proveedorId, tipoOrigen: (combustible | mantenimiento | seguro | nomina)
  monto, fechaEmision, fechaVencimiento
  estatus: pendiente | programado | pagado | vencido
  referencia (viajeId o mantenimientoId)
```

---

### 1.5 BRECHA 4 — Pólizas de Seguros: Solo vencimiento, sin financiero

**Diagnóstico:** `DocumentoVencimiento` con tipo `polizaTransporte` y `segurovehiculo` **solo rastrea si está vigente o vencido**. Falta el componente financiero y de cobertura:
- Prima mensual/anual (¿cuánto le cuesta el seguro a la empresa?)
- Monto de cobertura (¿hasta cuánto cubre la aseguradora?)
- Deducible (¿cuánto paga la empresa en caso de siniestro?)
- Historial de siniestros

**Entidad faltante: `PolizaSeguro`**
```
id, unidadId (o 'flota' para póliza flotilla)
tipoPoliza: (responsabilidadCivil | dañosTerceros | cargoTransportado | todo_riesgo)
aseguradora, numeroPoliza
vigenciaInicio, vigenciaFin
primaMensual (MXN), primaModosPago (mensual | semestral | anual)
coberturaMaxima (MXN), deducible (MXN o %)
```

**Integración con TCO:** La `primaMensual / viajesPromMes` es un costo fijo por viaje que actualmente no se incluye en ningún TCO.

---

### 1.6 BRECHA 5 — Inventario: Sin control de refacciones y llantas

**Diagnóstico:** El módulo de mantenimiento predictivo notifica que una unidad necesita servicio, pero **no hay control de si hay refacciones disponibles en almacén**. En una flota de tractocamiones, las llantas y filtros son activos circulantes significativos (una llanta para tractocamión cuesta $12,000–$18,000 MXN).

**Entidades faltantes:**
```
ItemInventario
  id, nombre, codigoInterno, tipo: (llanta | filtro | aceite | refaccion | herramienta)
  stockActual, stockMinimo (umbral de alerta)
  precioUnitario, proveedorId
  ubicacion (almacén)

MovimientoInventario
  id, itemId, tipo: (entrada | salida | ajuste)
  cantidad, fecha
  motivo, referenciaId (mantenimientoId | viajeId | null)
```

**Integración:** Cuando `MantenimientoPrevisto.estado` cambia a `enProceso`, se consume stock de los items relacionados.

---

### 1.7 BRECHA 6 — Cierre Contable: Sin catálogo de cuentas

**Diagnóstico:** `TcoViaje` es un excelente agregador de costos operativos por viaje, pero **no mapea a un catálogo de cuentas contable** (SAT México exige un catálogo mínimo para facturación y declaraciones). La empresa no puede:
- Generar un Estado de Resultados mensual
- Producir un Balance General
- Hacer la conciliación bancaria

**Propuesta mínima viable (no contabilidad completa, sí cierre operativo):**
```
PeriodoContable
  id (YYYY-MM), estado: (abierto | cerrado)
  
ResumenFinanciero
  periodoId
  ingresos: { totalFacturado, totalCobrado }
  egresos: { combustible, mantenimiento, seguros, nomina, otros }
  margenBruto: ingresos.totalCobrado - egresos.total
  activosFijosValorLibros: suma(ActivoFijo.valorLibros)
  pasivosTotales: suma(CuentaPorPagar.pendientes)
```

---

## PARTE 2 — AUDITORÍA UX/UI

### 2.1 Hallazgos Críticos: Torre de Control (Web/Windows)

#### PROBLEMA 1: Sidebar icónico sin expansión — cognitivamente opaco
**Hallazgo:** El sidebar actual es de ancho fijo 72px y muestra íconos sin texto. Para un sistema con 9+ secciones, el usuario debe memorizar qué ícono corresponde a qué módulo. Los tooltips aparecen solo en hover (web/Windows) y no en tap (móvil futuro).

**Impacto:** Con la adición de 4 módulos financieros, el sidebar tendrá ~13 ítems icónicos — inmanejable.

**Propuesta:** Sidebar expandible 72px ↔ 240px con animación `AnimatedContainer`. Estado persistido en memoria local. Modo expandido muestra ícono + label completo. Secciones agrupadas visualmente con separadores y encabezados.

```
OPERACIONES
  ◉ Overview
  ◉ Despacho
  ◉ Score Operadores
  ◉ Mantenimiento  [!3]
  ◉ Documentos      [!1]

FINANZAS
  ◉ Cuentas x Cobrar  [!2]
  ◉ Cuentas x Pagar
  ◉ Activos e Inventario
  ◉ Historial y TCO

ADMINISTRACIÓN
  ◉ Auditoría
  ◉ Reglas de Alerta
  ◉ Usuarios
```

#### PROBLEMA 2: Top Bar estática — el reloj no actualiza
**Hallazgo:** `_DateTimeDisplay` se construye una sola vez (`DateTime.now()` en `build`). El reloj muestra la hora en que se renderizó por última vez, no la hora actual en tiempo real.

**Propuesta:** Envolver en `StreamBuilder<DateTime>` alimentado por `Stream.periodic(Duration(seconds: 30))`. Costo CPU: mínimo.

#### PROBLEMA 3: KPI chips en Top Bar — sin datos financieros
**Hallazgo:** Los chips del Top Bar (viajes en ruta, alertas, banderas) solo muestran estado operativo. Con los nuevos módulos financieros, el usuario necesita ver de un vistazo si hay CxC vencidas o CxP por pagar hoy.

**Propuesta:** Agregar hasta 2 chips financieros opcionales al Top Bar:
- `[$ 3 CxC vencidas]` — solo visible si hay facturas vencidas
- `[↑ Pago hoy: $45,000]` — solo visible si hay CxP con vencimiento en 48h

#### PROBLEMA 4: Overview sobrecargado — mapa + tabla + panel colapsados
**Hallazgo:** La vista Overview apila FleetMapWidget, ViajesTable y el panel lateral de Alertas+TCO en una sola pantalla. En monitores de 1280px, el mapa queda con ~300px de altura, insuficiente para mostrar una flota de forma útil.

**Propuesta:** Rediseñar Overview con tres zonas claramente delimitadas:

```
┌─────────────────────────────────────────────────────────────┐
│  KPI ROW: [Viajes en ruta] [CxC pendiente] [TCO mes] [...]  │ ← 88px
├─────────────────────────────┬───────────────────────────────┤
│                             │                               │
│       MAPA DE FLOTA         │   PANEL LATERAL               │
│       (flex: 3)             │   (320px fijo)                │
│                             │   Tabs: Alertas | TCO | CxC   │
│                             │                               │
├─────────────────────────────┴───────────────────────────────┤
│  TABLA VIAJES ACTIVOS (collapsible, altura máx 240px)        │
└─────────────────────────────────────────────────────────────┘
```

El panel lateral gana un `TabBar` con 3 pestañas: **Alertas**, **TCO Diario** y **CxC Pendiente** — sin agregar espacio, solo cambia el contenido del panel.

#### PROBLEMA 5: HistorialViajesPage con datos hardcodeados
**Hallazgo (código real):**
- Línea 271: `final kmAprox = 450.0; // Distancia hardcodeada para ejemplo`
- Línea 159: `'UNIDAD-002 (Ejemplo)'` en Top Offenders

**Propuesta:** Usar `distanciaKm` real calculado desde `odometroFin - odometroInicio` (datos ya almacenados en Firestore por el Cloud Function `recalcularTco`). Top Offenders calculado desde datos reales del stream.

#### PROBLEMA 6: Sidebar no tiene modo oscuro aunque GloboTheme.dark existe
**Hallazgo:** `app.dart` tiene `themeMode: ThemeMode.light` hardcoded. El tema oscuro ya está definido en `GloboTheme.dark` pero es inaccesible.

**Propuesta:** Agregar `themeModeProvider = StateProvider<ThemeMode>` y un toggle en el Top Bar (ícono sol/luna).

---

### 2.2 Hallazgos: App Operador (Móvil Android / Windows)

#### PROBLEMA 7: Estado de viaje activo no es prominente
**Hallazgo:** En `OperadorHomePage`, el estado del viaje actual se muestra en una card pero no hay una barra de estado persistente en toda la app que muestre "EN RUTA hacia [cliente]".

**Propuesta:** Agregar un `PersistentBottomSheetContent` o una `Banner` anclada arriba en el Scaffold que muestre el destino actual y el tiempo estimado cuando hay un viaje activo.

#### PROBLEMA 8: Wizard de Iniciar Viaje sin retroalimentación de pasos
**Hallazgo:** `IniciarViajePage` tiene 3 pasos (origen → destinos → confirmar) pero no hay indicador visual de progreso tipo stepper.

**Propuesta:** `StepIndicator` horizontal en el AppBar del wizard con los 3 pasos, el actual resaltado en `GloboColors.accentBright`.

---

### 2.3 Propuestas de Modernización Visual "Premium"

#### VISUAL 1: Rediseño de cards KPI con tendencia
Las métricas del dashboard (viajes en ruta, TCO, alertas) deberían mostrar `↑ +12%` o `↓ -3%` comparado con el mismo período del mes anterior. Usar `fl_chart` (ya instalado) para sparklines de 7 días en cada card.

#### VISUAL 2: Estados de carga con Shimmer
`shimmer` ya está en `pubspec.yaml` pero no se usa en ningún lugar visible. Los listados y tablas deben mostrar placeholders de shimmer mientras cargan datos, en lugar de `CircularProgressIndicator` centrado.

#### VISUAL 3: Animación de transición entre secciones
Actualmente `setState(() => _seccion = x)` cambia el contenido sin transición. Envolver el `_buildContent()` en `AnimatedSwitcher` con duración de 180ms y `FadeTransition` daría sensación premium sin impacto en performance.

#### VISUAL 4: Gráficas financieras con fl_chart
Los módulos financieros deben incluir:
- **BarChart:** Ingresos vs Egresos por mes (últimos 6 meses)
- **PieChart:** Composición del TCO total (combustible/mantenimiento/seguros)
- **LineChart:** Flujo de caja proyectado (CxC por cobrar vs CxP por pagar, 90 días)

---

## PARTE 3 — PLAN DE IMPLEMENTACIÓN

### 3.1 Nuevas Entidades de Dominio

```
lib/domain/entities/
  ├── activo_fijo.dart           NUEVO
  ├── poliza_seguro.dart         NUEVO
  ├── proveedor.dart             NUEVO
  ├── factura_cliente.dart       NUEVO
  ├── cuenta_por_cobrar.dart     NUEVO
  ├── cuenta_por_pagar.dart      NUEVO
  ├── item_inventario.dart       NUEVO
  ├── movimiento_inventario.dart NUEVO
  └── resumen_financiero.dart    NUEVO
```

**Detalle por entidad:**

```
ActivoFijo
  String id, unidadId
  String descripcion          // ej. "Kenworth T680 2022"
  DateTime fechaAdquisicion
  double costoAdquisicion     // MXN
  double valorResidual        // MXN
  int vidaUtilAnios
  MetodoDepreciacion metodo   // lineal | aceleradaDobleSaldoDecreciente
  // Calculados (no persistidos):
  double depreciaciónAnual()
  double valorLibros(DateTime ahora)
  double porcentajeDepreciado(DateTime ahora)

PolizaSeguro
  String id
  String? unidadId            // null = póliza de flotilla
  TipoPoliza tipo             // rcCivil | danosTerceros | cargoTransportado | todoRiesgo
  String aseguradora
  String numeroPoliza
  DateTime vigenciaInicio, vigenciaFin
  double primaMensual
  ModosPagoSeguro modoPago    // mensual | semestral | anual
  double coberturaMaxima
  double deducible
  // Computed:
  SemaforoDocumento semaforo(DateTime ahora)  // reutiliza lógica de DocumentoVencimiento

Proveedor
  String id, nombre, rfc
  TipoProveedor tipo          // combustible | taller | seguro | otro
  double? limiteCredito       // para líneas de crédito (Edenred)
  double? saldoUsado          // actualizado por CostoOperativo
  int? diaCorte               // día del mes de corte (ej. 25)
  String contacto, telefono, email

FacturaCliente
  String id, viajeId, clienteId
  String numeroFactura        // auto-generado (GL-2026-XXXX)
  DateTime fechaEmision
  DateTime fechaVencimiento   // fechaEmision + diasCreditoConfig (30 por defecto)
  double monto                // TCO viaje + margen%
  double? montoCobrado
  EstatusFactura estatus      // pendiente | cobrada | vencida | cancelada
  DateTime? fechaCobro

CuentaPorCobrar  (vista consolidada, calculada)
  String clienteId, nombreCliente
  List<FacturaCliente> facturasPendientes
  double montoPendienteTotal
  int diasMayorAncianidad     // aging: días de la factura más vieja sin cobrar
  NivelRiesgo nivelRiesgo     // ok | atencion | critico (basado en aging)

CuentaPorPagar
  String id, proveedorId, nombreProveedor
  TipoObligacion tipo         // combustible | mantenimiento | seguro | nomina | otro
  double monto
  DateTime fechaEmision
  DateTime fechaVencimiento
  EstatusPago estatus         // pendiente | programado | pagado | vencido
  String? referenciaId        // viajeId | mantenimientoId | null

ItemInventario
  String id, nombre, codigoInterno
  TipoItem tipo               // llanta | filtroAceite | filtroAire | aceite | refaccion | herramienta
  int stockActual
  int stockMinimo             // umbral de alerta
  double precioUnitario
  String? proveedorId
  String ubicacion            // "Almacén Norte" | "Almacén Sur"

MovimientoInventario
  String id, itemId
  TipoMovimiento tipo         // entrada | salida | ajuste
  int cantidad
  DateTime fecha
  String motivo
  String? referenciaId        // mantenimientoId | viajeId

ResumenFinanciero
  String periodoId            // "2026-06"
  double ingresosFacturados
  double ingresosCobrados
  double egresosCombustible
  double egresosMantenimiento
  double egresosSeguros
  double egresosNomina
  double egresosOtros
  double activosFijosValorLibros
  double pasivosTotales
  // Computed:
  double get margenBruto => ingresosCobrados - egresosTotal
  double get egresosTotal => egresosCombustible + egresosMantenimiento + ...
```

---

### 3.2 Nuevos Repositorios e Interfaces

```
lib/domain/repositories/
  ├── i_activo_fijo_repository.dart       CRUD + watchActivosFijos()
  ├── i_poliza_seguro_repository.dart     CRUD + watchPolizasActivas()
  ├── i_proveedor_repository.dart         CRUD + watchProveedores()
  ├── i_factura_cliente_repository.dart   CRUD + watchFacturas() + watchCxC()
  ├── i_cuenta_por_pagar_repository.dart  CRUD + watchCxP() + watchVencimientosHoy()
  ├── i_inventario_repository.dart        CRUD items + registrarMovimiento() + watchStockBajo()
  └── i_finanzas_repository.dart          watchResumenMes() + generarResumenMes()
```

---

### 3.3 Nuevas Colecciones Firestore

```
activos_fijos/          {id} → ActivoFijo fields
polizas_seguro/         {id} → PolizaSeguro fields
proveedores/            {id} → Proveedor fields
facturas_clientes/      {id} → FacturaCliente fields
cuentas_por_pagar/      {id} → CuentaPorPagar fields
inventario_items/       {id} → ItemInventario fields
inventario_movimientos/ {id} → MovimientoInventario fields
resumenes_financieros/  {YYYY-MM} → ResumenFinanciero fields
```

**Reglas de seguridad Firestore:** Solo `administrador` puede escribir en activos_fijos, facturas, polizas. `supervisor` puede leer todo y escribir en cuentas_por_pagar (marcar pagado). `operador` sin acceso.

---

### 3.4 Nuevas Cloud Functions

```typescript
// functions/src/index.ts — 4 funciones adicionales:

// CF-9: Al completar viaje → genera factura al cliente
generarFacturaViaje: onDocumentWritten('viajes/{id}')
  - trigger: estado anterior != completado, nuevo == completado
  - busca configuración de precio (margen%) en config/pricing
  - crea documento en facturas_clientes/
  - fechaVencimiento = fechaEmision + 30 días (configurable)

// CF-10: Scheduled diario 08:00 México — marca CxP vencidas
vencimientosCxP: onSchedule('0 8 * * *')
  - busca CuentaPorPagar donde vencimiento < hoy y estado == pendiente
  - actualiza estado a 'vencido'
  - FCM a administrador

// CF-11: Scheduled día 1 de cada mes 03:00 — calcula depreciación y cierra período
cierreMensual: onSchedule('0 3 1 * *')
  - agrega ResumenFinanciero del mes anterior
  - suma depreciación mensual de todos los ActivoFijo
  - marca PeriodoContable anterior como cerrado
  - abre nuevo período

// CF-12: Stock bajo en inventario → FCM
alertaStockMinimo: onDocumentWritten('inventario_items/{id}')
  - trigger: stockActual <= stockMinimo
  - FCM a administrador/supervisor con nombre del item y stock actual
```

---

### 3.5 Nuevos Módulos del Dashboard (Torre de Control)

Se propone organizar el sidebar en **3 grupos con 4 nuevas secciones** en lugar de agregar ítems sueltos:

```dart
enum _Seccion {
  // OPERACIONES (sin cambio)
  overview, despacho, scoreOperadores, mantenimiento, documentos,
  
  // FINANZAS (NUEVO)
  finanzas,     // Tabbed: Resumen | CxC | CxP | Activos Fijos
  inventario,   // Tabbed: Stock | Proveedores | Pólizas
  historialViajes,  // Mejorado: km reales + depr. incluida
  
  // ADMINISTRACIÓN (sin cambio estructural)
  alertas, auditoria, usuarios,
}
```

#### Módulo FINANZAS (sección tabbed)

**Tab 1 — Resumen Ejecutivo:**
- `BarChart` ingresos vs egresos (6 meses, usando fl_chart)
- KPI cards: Facturado mes, Cobrado mes, Margen bruto %, CxC total
- `LineChart` flujo de caja proyectado 90 días (CxC a cobrar vs CxP a pagar)

**Tab 2 — Cuentas por Cobrar:**
- Tabla aging con 4 columnas: Corriente (0-30d) | 30-60d | 60-90d | +90d
- Por cliente, drill-down a facturas individuales
- Botón "Registrar Cobro" → dialog monto + fecha
- Semáforo de color por columna (verde → amarillo → naranja → rojo)

**Tab 3 — Cuentas por Pagar:**
- Lista de proveedores con saldo vs límite de crédito (progress bar)
- Vencimientos próximos 7 días — ordenados por urgencia
- Estado de línea Edenred/Sodexo: saldo disponible vs consumido
- Botón "Registrar Pago" → dialog

**Tab 4 — Activos Fijos:**
- Tabla de flota con: Unidad | Valor Libro | Depreciación/Mes | % Vida Consumida
- `LinearProgressIndicator` para % de depreciación acumulada
- Total activos fijos (valor libro consolidado)
- Alerta cuando un activo llega al 80% de vida consumida

#### Módulo INVENTARIO (sección tabbed)

**Tab 1 — Stock Actual:**
- Grid de tarjetas por item (similar a MantenimientoPage)
- Badge rojo cuando stock <= stockMinimo
- Botón flotante "+" → registrar entrada de stock con proveedor y costo

**Tab 2 — Proveedores:**
- Lista de proveedores con tipo, límite de crédito, saldo actual, día de corte
- CRUD completo (add/edit/delete)

**Tab 3 — Pólizas de Seguros:**
- Separa pólizas de `DocumentoVencimiento` en su propio espacio
- Muestra prima mensual total de flota, coberturas activas, próximos vencimientos

---

### 3.6 Cambios al Sidebar y Layout

#### Nuevo Sidebar expandible

```dart
// Nuevo parámetro en _Sidebar:
bool expanded;    // controlado por GestureDetector en header

// Anchos:
double get _width => expanded ? 240.0 : 72.0;

// En modo expandido: Row(Icon, SizedBox(8), Text(label))
// En modo colapsado: solo Icon, Tooltip en hover
```

#### Agrupación visual con encabezados

```dart
// Nuevo widget _SidebarGroupHeader:
// Solo visible en modo expandido
// Texto en labelSmall + letterSpacing: 2.5, color: white38
```

#### AnimatedSwitcher en contenido

```dart
// En _DashboardPageState._buildContent():
AnimatedSwitcher(
  duration: const Duration(milliseconds: 180),
  child: KeyedSubtree(
    key: ValueKey(_seccion),
    child: _buildContentInner(),
  ),
)
```

#### Dark mode toggle

```dart
// Nuevo StateProvider en theme_provider.dart:
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);

// En app.dart:
themeMode: ref.watch(themeModeProvider),

// Icono en TopBar → toggle entre light/dark
```

---

### 3.7 Correcciones Urgentes (bugs visuales)

| Archivo | Línea | Bug | Fix |
|---|---|---|---|
| `historial_viajes_page.dart` | 271 | `kmAprox = 450.0` hardcodeado | Usar `v.odometroFin - v.odometroInicio` desde Firestore |
| `historial_viajes_page.dart` | 159 | `'UNIDAD-002 (Ejemplo)'` hardcodeado | Calcular desde datos reales del stream |
| `dashboard_page.dart` | 427 | `DateTime.now()` en build sin stream | `StreamBuilder<DateTime>` con `Stream.periodic(30s)` |

---

### 3.8 Demo Providers para nuevos módulos

Cada nueva sección necesita su `_DemoXRepository` en `demo_providers.dart` con datos de muestra coherentes para que el demo siga funcionando sin Firebase:

```dart
class _DemoActivoFijoRepository implements IActivoFijoRepository { ... }
class _DemoFacturaClienteRepository implements IFacturaClienteRepository { ... }
class _DemoCuentaPorPagarRepository implements ICuentaPorPagarRepository { ... }
class _DemoInventarioRepository implements IInventarioRepository { ... }
```

Con datos en `demo_data.dart`:
- 4 activos fijos (uno por unidad existente)
- 6 facturas de clientes (3 cobradas, 2 pendientes, 1 vencida)
- 3 cuentas por pagar (Edenred, taller, seguro)
- 8 items de inventario (4 llantas, 2 filtros, 2 aceites)

---

### 3.9 Integración con Módulo "Historial y TCO" existente

El módulo existente muestra `tco.total` por viaje. Con los nuevos módulos, se enriquece:

```
TCO Real por Viaje =
  tco.combustible           (ya existe)
+ tco.mantenimiento         (ya existe)
+ tco.peajes                (ya existe)
+ tco.otros                 (ya existe)
+ depreciacionViaje         (NUEVO: ActivoFijo.depreciaciónMensual / viajesPromMes)
+ alícuotaSeguro            (NUEVO: PolizaSeguro.primaMensual / viajesPromMes)
─────────────────────────────────────────
= TCO Integral (costo real completo)
```

En `HistorialViajesPage`:
- Nueva columna "TCO Integral" junto a "TCO Operativo"
- Nueva fila en `_TopOffendersPanel`: "Mayor costo integral por km"
- Botón "Ver Factura" en cada fila → abre `FacturaCliente` asociada

---

## PARTE 4 — PLAN DE VERIFICACIÓN MULTIPLATAFORMA

### 4.1 Nuevas dependencias propuestas y compatibilidad

| Dependencia | Propósito | Web | Android | Windows | Riesgo |
|---|---|---|---|---|---|
| `fl_chart ^0.69.0` | Gráficas financieras | ✅ | ✅ | ✅ | YA instalado |
| `intl ^0.19.0` | Formato moneda MXN | ✅ | ✅ | ✅ | YA instalado |
| `shimmer ^3.0.0` | Skeletons de carga | ✅ | ✅ | ✅ | YA instalado |
| `pdf ^3.10.x` | Generar PDF de facturas | ✅ | ✅ | ✅ | NUEVO — bajo riesgo |
| `printing ^5.12.x` | Imprimir/descargar PDF | ✅ | ✅ | ✅ | NUEVO — bajo riesgo |

**Dependencias explícitamente DESCARTADAS:**
- `syncfusion_flutter_*` — licencia comercial, pesado, alternativa: fl_chart
- `sqflite` — no soporta Web ni Windows, ya tenemos Hive
- `path_provider` — ya cubierto por hive_flutter en Windows/Android/Web

### 4.2 Comandos de compilación y verificación

#### WEB (Torre de Control — modo producción)
```bash
# Verificar que no hay errores de compilación
flutter analyze

# Compilar para web
flutter build web --release --web-renderer canvaskit

# Ejecutar demo local
flutter run -d chrome -t lib/main_demo.dart --web-renderer html

# Ejecutar producción local
flutter run -d chrome -t lib/main.dart
```

**Puntos de verificación web específicos:**
- Módulo Finanzas → fl_chart renderiza correctamente en CanvasKit
- Sidebar expandible → AnimatedContainer no causa reflow en Chrome
- Generación PDF (si se implementa) → usa `dart:html` para descargar, no `dart:io`
- dark mode → MediaQuery.platformBrightness funciona en Chrome

#### ANDROID (App Operador)
```bash
# Análisis estático
flutter analyze

# Build APK debug
flutter build apk --debug -t lib/main.dart

# Build APK release
flutter build apk --release -t lib/main.dart

# Instalar en dispositivo conectado
flutter install --debug -t lib/main.dart
```

**Puntos de verificación Android específicos:**
- `google_mlkit_text_recognition` sigue siendo compatible (solo Android/iOS — ya está condicionado)
- `geolocator` permisos en AndroidManifest.xml — sin cambios
- Nuevas rutas Firestore no requieren índices adicionales críticos
- Generación PDF → usa `path_provider` para guardar en Downloads (Android)
- Canal de notificaciones FCM `sos_alerts` sigue registrado en MainActivity.kt

#### WINDOWS (Versión Desktop)
```bash
# Build Windows release
flutter build windows --release -t lib/main.dart

# Ejecutar debug Windows
flutter run -d windows -t lib/main.dart

# Ejecutar demo Windows
flutter run -d windows -t lib/main_demo.dart
```

**Puntos de verificación Windows específicos:**
- `google_mlkit_text_recognition` NO soporta Windows — confirmar que sigue condicionado con `defaultTargetPlatform`
- `geolocator` en Windows devuelve `LocationServiceDisabledException` — confirmar manejo existente
- `image_picker` en Windows usa file_picker internamente — sin cambios
- `fl_chart` es puro Dart/Canvas, funciona en Windows sin cambios
- Dark mode toggle funciona igual en desktop
- Sidebar expandido en Windows puede ser modo por defecto (pantalla grande)

#### VERIFICACIÓN CRUZADA FINAL
```bash
# Verificar que todos los nuevos archivos pasan el análisis
flutter analyze --fatal-infos

# Verificar que la demo sigue funcionando (sin Firebase)
flutter run -d chrome -t lib/main_demo.dart
flutter run -d windows -t lib/main_demo.dart

# Verificar imports condicionales (sos_audio)
flutter build web && flutter build windows && flutter build apk
```

---

## PARTE 5 — HOJA DE RUTA Y PRIORIZACIÓN

### Fase 1 — Quick Wins (semana 1): UX + bugs, sin entidades nuevas
1. Fix `kmAprox = 450.0` hardcodeado en HistorialViajesPage
2. Fix `_DateTimeDisplay` con `Stream.periodic`
3. `AnimatedSwitcher` entre secciones del dashboard
4. Dark mode toggle con `themeModeProvider`
5. `shimmer` en listados con carga (MantenimientoPage, DocumentosPage)
6. Sidebar con encabezados de grupo (sin expandir aún)

### Fase 2 — Activos Fijos y Pólizas (semana 2): Menor complejidad, mayor impacto inmediato
1. Entidad `ActivoFijo` + repositorio
2. Entidad `PolizaSeguro` + repositorio (reemplaza TipoDocumento.segurovehiculo en la UI)
3. Tab "Activos Fijos" dentro del nuevo módulo Finanzas
4. Tab "Pólizas" dentro del nuevo módulo Inventario
5. CF `cierreMensual` con cálculo de depreciación
6. `_DemoActivoFijoRepository` con datos de 4 unidades actuales

### Fase 3 — Facturación y CxC (semana 3): Conecta clientes con cobros
1. Entidad `FacturaCliente` + repositorio
2. CF `generarFacturaViaje`
3. Tab "Cuentas x Cobrar" en módulo Finanzas
4. Tabla aging con semáforo
5. Integración en HistorialViajesPage (botón "Ver Factura")
6. `_DemoFacturaClienteRepository`

### Fase 4 — Proveedores, CxP e Inventario (semana 4)
1. Entidades `Proveedor`, `CuentaPorPagar`, `ItemInventario`, `MovimientoInventario`
2. Módulo "Inventario" completo con sus 3 tabs
3. Tab "Cuentas x Pagar" + saldo Edenred
4. CF `vencimientosCxP` + CF `alertaStockMinimo`
5. `_DemoProveedorRepository` + `_DemoInventarioRepository`

### Fase 5 — Sidebar expandible + Resumen Financiero (semana 5)
1. Sidebar expandible 72px ↔ 240px con 3 grupos
2. Tab "Resumen Ejecutivo" con BarChart + LineChart
3. Entidad `ResumenFinanciero` + agregación mensual
4. KPI chips financieros en Top Bar
5. TCO Integral en HistorialViajesPage

### Fase 6 — PDF y Pulido Final (semana 6, opcional)
1. Dependencia `pdf + printing` para exportar facturas
2. Exportar reportes financieros en PDF (Resumen mensual)
3. Mejora Overview con KPI Row rediseñado
4. `StepIndicator` en wizard Iniciar Viaje
5. Banner de viaje activo en app operador

---

## RESUMEN EJECUTIVO

| Categoría | Actual | Propuesto | Gap |
|---|---|---|---|
| Entidades de dominio | 12 | 21 | +9 nuevas |
| Módulos dashboard | 9 | 11 (2 con tabs) | +2 agrupados |
| Cloud Functions | 8 | 12 | +4 nuevas |
| Colecciones Firestore | 6 | 14 | +8 nuevas |
| Dependencias nuevas | — | pdf + printing | mínimas |
| Cobertura financiera | Costos operativos | ERP completo | activos + pasivos + cierre |
| UX | Sidebar icónico, sin grupos | Expandible, agrupado, animated | Reducción de carga cognitiva |

**Impacto estimado en líneas de código:** ~3,500 líneas de Dart nuevas (entidades + repositorios + providers + páginas) + ~400 líneas TypeScript en Cloud Functions.

**Sin romper nada:** Todas las entidades nuevas son aditivas. Los repositorios existentes (`IViajeRepository`, `IUnidadRepository`, etc.) no se modifican. Las nuevas colecciones Firestore son independientes. La demo sigue funcionando en modo offline con stub repositories.
