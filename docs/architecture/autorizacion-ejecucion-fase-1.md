# Autorización operativa — Fase 1 (inventario y backup)

> **ALCANCE EXCLUSIVO: FASE 1.** Esta autorización habilita únicamente la Fase 1
> del plan de migración multilingüe sobre la base independiente declarada.
> **No autoriza** las Fases 2-14, ni DDL/DML, ni conexión u operación en
> producción, ni modificación de la base de origen.
>
> Se emite en el marco del runbook
> [`ejecucion-staging-runbook.md`](ejecucion-staging-runbook.md) (§4 y §8). Las
> órdenes y nombres que allí figuran siguen siendo plantillas de referencia; esta
> autorización no las convierte en instrucciones listas para ejecutar.

## 1. Identificación

| Campo | Valor |
|---|---|
| Fase autorizada | Fase 1 — Inventario y backup |
| Diseño de referencia | `cc803b5` (D-01 a D-41) |
| Runbook de referencia | `ejecucion-staging-runbook.md`, §4 (procedimiento) y §8 (pase a ejecución) |
| Autorizante | Luis A. Uriarte |
| Fecha de emisión | 2026-11-17 |
| Responsable de ejecución | Luis A. Uriarte |
| Responsable de infraestructura | Luis A. Uriarte |
| Ventana operativa | 2026-11-17, 10:30 GMT-3 |

## 2. Compuertas previas a Fase 1

Cerradas el `2026-11-17` y registradas en el acta A-1 del runbook:

| # | Compuerta | Estado | Evidencia |
|---|---|---|---|
| 1 | Autorización de preparación (crear base + restaurar backup; excluido DDL/DML de Fases 2-14) | **CERRADA** | A-1 y esta autorización |
| 2 | Origen confirmado como no productivo | **CERRADA** | A-1, E-01 |
| 3 | Destino independiente asignado (D-25), distinto del origen y no esquema temporal | **CERRADA** | A-1, E-01, E-04 |
| 4 | Acceso mínimo autorizado (solo lectura en origen) | **CERRADA** | A-1, E-03, E-04 |
| 5 | Responsable de infraestructura identificado | **CERRADA** | A-1 |

La aprobación formal del diseño (compuerta 1 de §3.1) quedó cerrada en `cc803b5`
y pertenece al momento previo a Fase 2. No se exigen aquí las compuertas de
fases posteriores (matriz de dependencias, §3.2 del runbook).

## 3. Operaciones autorizadas — solo Fase 1

| Operación | Base / objeto | Autorizada | Evidencia a diligenciar |
|---|---|---|---|
| Registrar versión de PostgreSQL, codificación y `collation`; verificar `pg_trgm` | Origen, solo lectura | SÍ | E-01, E-02 |
| Obtener `pg_dump` en formato personalizado (`-Fc`) | Origen, solo lectura | SÍ | E-03 |
| Calcular y registrar SHA-256 del dump | Archivo de dump | SÍ | E-03 |
| Crear la base independiente `origen_codes` | Fuera de producción; nunca la base de origen | SÍ | E-04 |
| Restaurar el dump en esa base independiente | `origen_codes` | SÍ | E-04 |
| Provisionar roles y permisos mínimos (`origen_api`) | `origen_codes` | SÍ | E-04 |
| Conteos, checksums e inventario lingüístico | Origen (solo lectura) y copia | SÍ | E-05, E-06 |
| Verificar los dos límites de escritura y firmar acta de cierre | — | SÍ | E-07, §4.2 |

**Cero escrituras en la base de origen: no se modifica.** En la base
independiente se permite exclusivamente crearla y restaurar el backup. Las
operaciones autorizadas sobre staging se registran por separado (§4.2 y E-07).

## 4. Límites expresamente excluidos

- Queda prohibido modificar estructuras existentes.
- Queda excluido el DDL/DML de las Fases 2-14.
- No se conecta ni se opera sobre producción; el origen declarado es desarrollo.
- No se trasladan credenciales ni privilegios productivos. Un `pg_dump -Fc` de
  una base individual no incluye los roles globales del clúster: los roles y
  permisos necesarios se provisionan de forma controlada con privilegio mínimo
  (§4.1 del runbook).
- No se ejecutan importadores ni se escriben `tools/sources/**`, API, web ni código.
- Esta autorización no habilita las compuertas de fases posteriores ni la carga
  PMO (D-17, carril paralelo). D-34 requiere además una autorización escrita,
  individual y específica por índice; si no se requiere, se registra «No aplica»
  con evidencia sin bloquear la fase.

## 5. Datos operativos declarados

| Campo | Valor |
|---|---|
| Base de origen | `origen_salud @ localhost` (desarrollo, no productiva) |
| Base destino | `origen_codes` (independiente; esquema por defecto `public`) |
| Entorno declarado para el destino | desarrollo |
| Cuenta/rol para `pg_dump` | `origen_api` (solo lectura en origen) |
| Cuenta/rol para restauración | `origen_api` (privilegio mínimo, no superuser) |
| Retracción 1 | Se retira la declaración previa de que `origen_salud @ localhost` era productiva; se declaró uso para desarrollo |
| Retracción 2 | Se retiran las declaraciones previas de traslado de permisos y de rol `superuser`; no se trasladan credenciales ni privilegios productivos |

**Observación sobre el entorno:** el destino se declara en «desarrollo» mientras
el runbook habla de «staging». D-25 queda cubierto en sus condiciones
verificables (base independiente, distinta del origen y no producción). Si el
procedimiento exige staging en sentido estricto, debe declararse el entorno real
antes de iniciar la ejecución.

**Credenciales:** no se incluyen en este documento. Se entregan por canal seguro
al responsable de ejecución, sin valores productivos.

## 6. Condición de cierre de Fase 1

La Fase 1 se considera cerrada únicamente cuando:

- el dump y su SHA-256 quedan registrados (E-03);
- la base independiente queda creada y restaurada sin errores, con roles y
  permisos mínimos verificados por separado (E-04);
- los conteos y checksums coinciden entre origen y copia, sin huérfanos de FK ni
  duplicados que violen UNIQUE (E-05);
- el inventario lingüístico queda firmado y el riesgo PMO queda registrado como
  bloqueante de PMO, no de la migración (E-06);
- se verifica «cero escrituras en la base de origen» y solo creación y
  restauración en el destino (E-07 y §4.2);
- se firma el acta de cierre de Fase 1 (E-07).

Cualquier hallazgo que reabra una decisión D-01 a D-41 detiene la secuencia y
vuelve al documento de decisiones; no se resuelve «sobre la marcha» en la base.
El avance a la Fase 2 requiere nueva autorización y sus compuertas específicas
(§3.2 del runbook).

## 7. Emisión y firma

Documento preparado documentalmente con los datos confirmados. Según
declaración del autorizante, fue firmado en ambos campos el `2026-11-17`, con
lo cual tiene efecto operativo **exclusivamente para la Fase 1** y en los
términos de esta autorización.

```text
Autorizado por:  Luis A. Uriarte
Firma:           FIRMADA (declarada por Luis A. Uriarte)
Fecha:           2026-11-17

Recibido por (responsable de ejecución): Luis A. Uriarte
Firma:           FIRMADA (declarada por Luis A. Uriarte)
Fecha:           2026-11-17
```

> Nota de alcance: la firma habilita la ejecución de la **Fase 1** por el
> responsable designado. Esta autorización **no** habilita las Fases 2-14, el
> DDL/DML, la operación en producción ni la modificación de la base de origen.
> El entorno del destino sigue declarado como «desarrollo»; si se exige staging
> estricto, debe declararse el entorno real antes de iniciar.
