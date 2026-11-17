# Guía de diligenciamiento de evidencias — Fase 1

> **NATURALEZA: GUÍA DE REGISTRO, NO DE EJECUCIÓN.** Ordena cómo completar las
> plantillas E-01 a E-07 del runbook durante la Fase 1. **No contiene órdenes
> ejecutables, credenciales, DDL/DML ni conexiones.** Las operaciones se rigen
> por [`ejecucion-staging-runbook.md`](ejecucion-staging-runbook.md) §4.1/§4.2 y
> por la autorización firmada
> [`autorizacion-ejecucion-fase-1.md`](autorizacion-ejecucion-fase-1.md).

## 1. Marco

| Campo | Valor |
|---|---|
| Fase | Fase 1 — Inventario y backup |
| Autorización | `autorizacion-ejecucion-fase-1.md`, firmada el `2026-11-17` por Luis A. Uriarte (autorizante y responsable de ejecución) |
| Alcance de la firma | Crear la base independiente `origen_codes` y restaurar el backup; cero escrituras en `origen_salud @ localhost` |
| Excluido | Modificar estructuras existentes y DDL/DML de las Fases 2-14 |
| Responsable de ejecución | Luis A. Uriarte |
| Ventana registrada | `2026-11-17, 10:30 GMT-3` |
| Origen | `origen_salud @ localhost` (desarrollo, no productivo; solo lectura) |
| Destino | `origen_codes`, esquema por defecto `public`, entorno declarado desarrollo |
| Rol | `origen_api` (solo lectura en origen; privilegio mínimo en destino; no superuser) |

Si se exige **staging en sentido estricto**, declarar el entorno real del destino
antes de iniciar. No se trasladan credenciales ni privilegios productivos.

## 2. Orden de diligenciamiento

El orden respeta la secuencia F1.1 a F1.11 del runbook (§4.2). La casilla de
congelación de importadores se registra **antes** de la toma del dump.

| # | Paso del runbook | Evidencia | Se completa | Estado inicial |
|---|---|---|---|---|
| 0 | F1.10 (acuerdo previo) | E-01 | Ventana y responsable de la congelación de importadores | Ya registrado: `2026-11-17, 10:30 GMT-3`, Luis A. Uriarte |
| 1 | F1.1, F1.2 | E-01, E-02 | Versión PostgreSQL, codificación, `collation`, estado de `pg_trgm`; datos de identificación | Identificación prellenada; verificaciones técnicas en blanco |
| 2 | F1.3, F1.4 | E-03 | Archivo dump, ruta, tamaño, SHA-256, cuenta utilizada y verificación del hash | En blanco |
| 3 | F1.5, F1.6 | E-04 | Creación de `origen_codes`, restauración, extensiones/dependencias/funciones/triggers/secuencias, roles y permisos mínimos | Identificación prellenada; casillas de verificación en blanco |
| 4 | F1.7 | E-05 | Conteos y checksums de las 15 tablas; 0 huérfanos de FK; 0 duplicados UNIQUE | En blanco |
| 5 | F1.8, F1.9 | E-06 | Inventario lingüístico real; `os_catalog_item.observation` no existe; riesgo PMO; D-39 y D-40 | En blanco |
| 6 | F1.11 | E-07 | Acta de cierre de Fase 1, verificación de los dos límites de escritura y firma | En blanco |

## 3. Contenido a registrar por evidencia

### E-01 / E-02 — Entorno y versión

- Completar solo los campos técnicos que quedaron en blanco: versión de
  PostgreSQL, codificación, `collation` y casillas de `pg_trgm`.
- Si `pg_trgm` no está disponible o no es válida: **detener** y registrar la
  incidencia (no se continúa con el dump).
- Confirmar que la identificación prellenada sigue vigente: commit `cc803b5`,
  responsable Luis A. Uriarte, entorno desarrollo, `origen_salud @ localhost` y
  `origen_codes` (distinta del origen, no esquema temporal, esquema `public`).

### E-03 — Backup y SHA-256

- Registrar archivo, ruta, tamaño en bytes, SHA-256, cuenta utilizada
  (`origen_api`, **sin credenciales en el documento**) y fecha/hora.
- Marcar la coincidencia del hash. Si no coincide: **detener**.
- La operación se ejecuta solo en la base de origen, en modo de lectura, según
  la plantilla de referencia del runbook (§4.2); esta guía no reproduce la orden.

### E-04 — Restauración en base independiente

- Confirmar destino `origen_codes` (esquema `public`), rol `origen_api` y
  responsable de la provisión de roles (Luis A. Uriarte).
- Marcar, tras la verificación real: extensiones, dependencias, funciones,
  triggers y secuencias; roles provisionados en staging; permisos con privilegio
  mínimo; ausencia de credenciales/privilegios productivos; aprovisionamiento
  documentado por separado; `--clean` evaluado si se usó.
- Recordar que `pg_dump -Fc` **no incluye roles globales del clúster**: su
  provisión es controlada y se documenta aparte (runbook §4.1).
- Marcar «restauración correcta» o, con errores, **detener**.

### E-05 — Conteos y checksums

- Adjuntar la consulta exacta utilizada (sin normalizaciones ocultas), el
  centinela de `NULL` y el `ORDER BY <PK>`.
- Completar las 15 filas de la tabla del runbook con conteo y hash de origen y
  copia, y la columna «Igual».
- Verificar 0 huérfanos de FK y 0 duplicados que violen UNIQUE. Cualquier
  diferencia detiene la fase y vuelve al documento de decisiones.

### E-06 — Inventario lingüístico

- Completar el valor observado por fuente y su adjudicación/evidencia.
- Marcar que `os_catalog_item.observation` **no existe** y que el riesgo PMO
  queda registrado como bloqueante de **PMO**, no de la migración (D-17).
- Marcar que `es-AR` **no** se marca `is_source_only` (D-39) y que
  `source_language_code` no se inventa: se derivará en Fase 5 (D-40).
- Firmar la evidencia.

### E-07 — Acta de cierre de Fase 1

- Completar fase, fechas, responsables, resumen de operaciones y validaciones.
- Verificar y marcar: **origen con 0 escrituras** (solo lectura); **destino solo
  crear la base y restaurar el backup**; no se modificaron estructuras
  existentes; no se habilitó DDL/DML de Fases 2-14; operaciones sobre staging
  registradas por separado (runbook §4.2).
- Registrar resultado `APTO` o `NO APTO`, incidencias y resolución, compuertas
  cerradas en la fase y firma.
- Sin E-07 firmada, la Fase 1 no está cerrada.

## 4. Compuertas que NO se adelantan

| Prerrequisito | Momento real | En Fase 1 |
|---|---|---|
| Diseño aprobado (`cc803b5`) | Antes de Fase 2 | Ya cerrado; no se reabre |
| Identidad de aplicación y rol de auditoría | Antes de Fase 2 | No se exige |
| Importadores parametrizados | Antes de Fase 3 | No se exige |
| Matriz 4.3 firmada (D-19) | Antes de Fase 4 | No se exige |
| `source_release` y fuentes LOINC | Antes de Fase 5 | No se exige |
| Resolver/API/sitio/NN 2025 | Fases 8-10 | No se exige |
| PMO (D-17) | Carril paralelo | No bloquea la migración |
| D-34 (índice concreto) | Antes de la operación excepcional | No se evalúa en Fase 1; si no se requiere, se registrará «No aplica» con evidencia en su momento (A-2) |

## 5. Cierre y avance

- Al firmar E-07, la Fase 1 queda cerrada con el dump verificado en la base
  independiente (condición de salida del plan de migración, Fase 1 §3).
- El avance a la Fase 2 exige nueva autorización y sus compuertas específicas
  (runbook §3.2): diseño aprobado, identidad/rol de auditoría y autorización
  específica del DDL de Fase 2.
- Todo hallazgo que reabra D-01 a D-41 detiene la secuencia y vuelve al
  documento de decisiones; no se resuelve «sobre la marcha» en la base.

> Esta guía **no autoriza ni ejecuta** operación técnica alguna. Las evidencias
> se diligencian con los resultados reales de la ejecución realizada por el
> responsable designado.
