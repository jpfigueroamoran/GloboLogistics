# Globo Logistics - Sistema Integral de Gestión Flotillera

![Globo Logistics Banner](https://placehold.co/1200x400/1E1E1E/FFF?text=Globo+Logistics+-+Torre+de+Control+y+Operaciones)

**Globo Logistics** es una plataforma logística de grado empresarial diseñada para la gestión, despacho y auditoría financiera de flotillas de transporte. La plataforma se compone de dos interfaces altamente acopladas en tiempo real:

1. **Torre de Control (Web/Escritorio):** Panel de mando para gerentes, auditores y despachadores.
2. **Aplicación Móvil (Android/iOS):** Terminal de trabajo y telemétrica para los operadores (choferes) en ruta.

---

## 🏗️ Arquitectura y Flujo de Trabajo

El sistema está diseñado para erradicar las fugas de capital y optimizar la administración de combustible ("Litro Exacto"). Las interacciones ocurren de forma síncrona mediante Firebase Firestore.

![Arquitectura del Sistema](https://placehold.co/800x400/2A2A2A/FFF?text=Diagrama+de+Flujo:+Despacho+-%3E+Operador+-%3E+Auditoría)

### 1. Centro de Despacho Dinámico
La asignación de rutas ya no es estática. Desde la Torre de Control, el despachador selecciona a los **Operadores Reales** y a las **Unidades Vehiculares** disponibles, emparejándolos con rutas de alta demanda. Al asignar, el viaje se dispara inmediatamente hacia el dispositivo móvil del operador.

![Centro de Despacho](https://placehold.co/800x400/2A2A2A/FFF?text=Pantalla+Centro+de+Despacho)

### 2. Operador Móvil y Telemétrica
El conductor utiliza la aplicación para registrar eventos críticos del viaje.
- **Rastreo y Geolocalización:** Seguimiento de la unidad.
- **Botón de Pánico (SOS):** Protocolos de seguridad activados con un solo toque.
- **Evidencia Documental:** Carga de facturas, recibos de casetas (peajes) y tickets de combustible cargados.

### 3. Sistema Anti-Falsos Positivos
Un problema común en auditoría son las falsas acusaciones de robo de combustible por bajo rendimiento (Km/L). **Globo Logistics tiene inteligencia mecánica integrada.** Si una unidad se acerca a su ciclo de mantenimiento preventivo (< 500km restantes en el odómetro), el sistema atenúa automáticamente el sobreconsumo asumiéndolo como desgaste de motor y no como "huachicoleo", previniendo prácticas injustas (*mobbing* laboral).

### 4. Derecho de Réplica del Operador
Si la varianza de combustible entre lo registrado y lo calculado por la telemetría excede un margen de tolerancia (ej. 5%), el operador no puede finalizar el viaje sin antes **ingresar una justificación obligatoria** en la app (Ej. "Hubo embotellamiento severo", "Manguera del tractocamión pinchada"). Esta justificación viaja directamente al sistema contable.

![Derecho de Réplica](https://placehold.co/400x400/2A2A2A/FFF?text=App+Móvil+-+Derecho+de+Réplica)

### 5. Auditoría Retrospectiva y Detección de Fugas (TCO)
Diseñado específicamente para el departamento contable, este módulo analiza los viajes con estado `completado`.

![Historial y TCO](https://placehold.co/800x400/2A2A2A/FFF?text=Torre+de+Control+-+Historial+y+TCO)

- **Top Offenders:** Widgets proactivos que destacan la "Ruta con mayor fuga de capital" y la "Unidad con peor rendimiento de Km/L".
- **Filtros de Correlación Cruzada:** Aislar datos por *Operador* y por *Unidad* para determinar si el sobreconsumo lo genera el factor humano (manejo inadecuado) o la máquina (motor desajustado).
- **Costo Total de Propiedad (TCO):** Una matriz consolidada que suma casetas, combustible y prorrateo de mantenimientos.

---

> El código fuente ha sido optimizado bajo el patrón de manejo de estado **Riverpod**, y la interfaz utiliza el sistema de **Design Tokens** (Colores, Tipografía y Espaciado estandarizado) garantizando consistencia a lo largo de toda la aplicación.
