# Verificación Manual — Globo Logistics

> Anotar hallazgos en la tabla al final de cada sección.
> Estado: ✅ OK | ❌ Error | ⚠️ Mejora | ⏭️ Pendiente

---

## SETUP

- [ ] App abre en Chrome (`localhost:9000`) o dispositivo Android
- [ ] Pantalla inicial muestra el **login de producción** (Acceso Seguro)

---

## 1. AUTENTICACIÓN

### Producción (modo por defecto)
- [ ] Login operador real → redirige a vista operador
- [ ] Login supervisor/admin real → redirige a dashboard
- [ ] Usuario desactivado → mensaje de cuenta desactivada
- [ ] Credenciales incorrectas → error legible
- [ ] Logout desde dashboard → vuelve al login (cierra sesión Firebase)
- [ ] Logout desde vista operador → vuelve al login

### Demo (vía botón "Probar Modo Demo")
- [ ] "Probar Modo Demo (datos de ejemplo)" → aparece pantalla DEMO MODE
- [ ] "Ingresar como Operador" → redirige a vista operador
- [ ] "Ingresar como Supervisor" → redirige a dashboard
- [ ] "Ingresar como Administrador" → redirige a dashboard
- [ ] "Volver a Modo Producción" → regresa al login email/password

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 2. DASHBOARD — Torre de Control

- [ ] KPIs en header (viajes en curso, alertas activas, unidades activas)
- [ ] Fila de accesos rápidos (Nuevo viaje, Flota, Clientes, Facturación, Reportes)
- [ ] Panel de alertas muestra datos
- [ ] Mapa de flota carga (tiles CartoDB visibles)
- [ ] Unidades aparecen en mapa
- [ ] Panel TCO muestra datos
- [ ] Sidebar sin overflow visual
- [ ] Dark/Light mode toggle funciona

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 3. DESPACHO

- [ ] Página carga correctamente
- [ ] Lista de viajes activos visible
- [ ] Dropdown de operadores muestra solo operadores activos
- [ ] Crear nuevo viaje: origen → destino → operador → unidad → guardar
- [ ] Viaje creado aparece en lista de inmediato (reactivo)
- [ ] Asignar viaje a otro operador funciona
- [ ] Finalizar viaje → pide motivo si hay varianza
- [ ] Viaje finalizado pasa a completados

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 4. MAPA DE FLOTA

- [ ] Tiles del mapa cargan (CartoDB Dark/Light)
- [ ] Marcadores de unidades visibles
- [ ] Click en marcador muestra info del viaje
- [ ] Pan y zoom funcionan
- [ ] Sin errores en consola del navegador

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 5. OPERADOR — Vista principal

- [ ] Vista carga con datos del viaje activo
- [ ] Estado del viaje (carga / tránsito / descarga) visible
- [ ] Botones de cambio de estado funcionan
- [ ] Sin viaje activo → muestra estado "offline"
- [ ] Botón SOS visible

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 6. INICIAR VIAJE (wizard desde operador)

- [ ] Paso 1: buscar origen → geocodifica con Nominatim
- [ ] Paso 2: buscar y agregar clientes/destinos
- [ ] Paso 3: pantalla de confirmación con resumen
- [ ] Confirmar → viaje creado aparece en dashboard
- [ ] En demo: viaje creado con ID único (no vacío)

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 7. SOS

- [ ] Botón SOS navega a pantalla SOS
- [ ] Activar SOS → alerta aparece en panel del dashboard
- [ ] SOS nuevo dispara overlay con alarma en el dashboard abierto (sin FCM)
- [ ] Alerta SOS visible en mapa
- [ ] Con SOS activo: tomar foto / grabar audio → evidencia se guarda
- [ ] Dashboard: "N evidencias adjuntas" → abre galería (fotos y audio reproducible)
- [ ] Dashboard: captura remota (mic/cámara) → overlay aparece en dispositivo del operador
- [ ] Desde dashboard: "Atender alerta" → cambia estado
- [ ] Cancelar SOS desde operador → alerta se cierra como falsa alarma

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 8. DOCUMENTOS Y VENCIMIENTOS

- [ ] Página carga (en demo puede estar vacía — normal)
- [ ] Semáforo rojo/amarillo/verde funciona
- [ ] Contador de vencidos/próximos visible en dashboard
- [ ] En producción: documentos de Firestore cargan
- [ ] Subir documento ≤700 KB funciona (se guarda en Firestore, sin Storage)

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 9. CLIENTES (sección nueva en sidebar)

- [ ] Sección "Clientes" visible en sidebar (grupo OPS)
- [ ] KPIs: activos, geocodificados, sin geocodificar
- [ ] Búsqueda por nombre/dirección/RFC filtra resultados
- [ ] "Nuevo cliente": nombre + dirección → geocodifica automáticamente
- [ ] Cliente creado aparece en lista
- [ ] Click en cliente → edición (cambiar dirección re-geocodifica)
- [ ] Desactivar cliente lo oculta del selector de viajes

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 9B. GESTIÓN DE FLOTA (sección nueva en sidebar)

- [ ] Sección "Flota" visible en sidebar (grupo OPS)
- [ ] KPIs: total, disponibles, en ruta, en taller, servicio próximo
- [ ] Búsqueda por placas/modelo filtra
- [ ] "Nueva unidad" → alta con placas, modelo, odómetro, tanque, operador
- [ ] Click en tarjeta → edición de unidad
- [ ] Unidad con servicio próximo muestra indicador rojo
- [ ] En demo: lista carga con datos mock; alta/edición avisa "solo producción"

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 10. ACTIVOS FIJOS

- [ ] Lista de activos carga
- [ ] Valor de flota total calculado
- [ ] Depreciación mensual calculada
- [ ] Crear/editar activo funciona

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 11. PÓLIZAS DE SEGURO

- [ ] Lista de pólizas carga
- [ ] Semáforo de vencimiento visible
- [ ] Prima total mensual calculada
- [ ] Crear nueva póliza funciona

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 12. INVENTARIO

- [ ] Lista de items carga
- [ ] Items con stock bajo resaltados
- [ ] Actualizar stock funciona
- [ ] Registrar movimiento funciona

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 13. FACTURAS DE CLIENTES

- [ ] Lista de facturas carga
- [ ] CXC (cuentas por cobrar) calculadas
- [ ] Registrar cobro funciona
- [ ] Facturas vencidas resaltadas
- [ ] Registrar carta porte funciona (producción)
- [ ] Al completar un viaje se genera factura automática GL-YYYY-XXXX

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 14. FACTURAS DE PROVEEDORES

- [ ] Lista de facturas proveedor carga
- [ ] CXP (cuentas por pagar) calculadas
- [ ] Crear nueva factura proveedor funciona
- [ ] Registrar pago funciona
- [ ] Facturas vencidas se marcan automáticas (motor cada 5 min)

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 15. REPORTES / ANALÍTICA

- [ ] Página carga con gráficas
- [ ] Gráfica de tendencia de viajes muestra datos
- [ ] Gráfica de distribución de gastos visible
- [ ] Score de operadores visible
- [ ] "Exportar PDF" genera PDF sin errores

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 16. GESTIÓN DE USUARIOS (solo Admin)

- [ ] Lista de usuarios carga (demo: 4 operadores + supervisor + admin)
- [ ] Cambiar rol funciona
- [ ] Activar/desactivar usuario funciona
- [ ] Crear usuario (solo producción — requiere Firebase Auth)

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 17. AUDITORÍA

- [ ] Página carga
- [ ] Log de eventos visible
- [ ] Filtros funcionan

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## 18. INTEGRACIÓN DEMO ↔ PRODUCCIÓN

- [ ] App arranca en modo producción por defecto
- [ ] Demo: todos los datos son mock (sin llamadas Firestore)
- [ ] "Probar Modo Demo" → providers cambian a mock **sin reiniciar la app**
- [ ] "Volver a Modo Producción" → providers vuelven a Firebase **sin reiniciar**
- [ ] FCM y GPS tracking silenciados en demo, activos en producción

---

## 19. AUTOMATIZACIÓN CLIENT-SIDE (motor costo-cero)

- [ ] Al abrir dashboard en producción, el motor procesa pendientes (consola: `[Automatizacion]`)
- [ ] Viaje completado → TCO calculado, unidad liberada, factura generada, score actualizado
- [ ] Unidad alcanza odómetro de servicio → pasa a "En taller" automáticamente
- [ ] Pólizas a ≤30 días de vencer generan alerta

### Hallazgos
| # | Descripción | Severidad |
|---|-------------|-----------|
|   |             |           |

---

## RESUMEN DE HALLAZGOS

| # | Sección | Descripción | Severidad | Estado |
|---|---------|-------------|-----------|--------|
|   |         |             |           |        |
|   |         |             |           |        |
|   |         |             |           |        |
|   |         |             |           |        |
|   |         |             |           |        |
