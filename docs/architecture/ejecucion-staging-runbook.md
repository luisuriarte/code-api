# Runbook de preparación — Implementación multilingüe en base independiente de staging

> **ESTADO: DOCUMENTO DE PREPARACIÓN. NO AUTORIZA EJECUCIÓN.**
>
> Este runbook organiza la implementación futura del diseño aprobado. **No
> autoriza** conexión a staging, ejecución de SQL, creación de base de datos,
> modificación de PostgreSQL, PHP/API/web/importadores ni `tools/sources/**`.
> Solo una autorización explícita de Fase 1 puede habilitar, sobre la base
> independiente de staging, la creación de esa base y la restauración del
> backup; esa autorización **no habilita modificar estructuras existentes ni el
> DDL/DML de las fases posteriores**.
> Toda orden, ruta o nombre de base que aparece aquí es una **plantilla de
> referencia con valores de ejemplo**, no una instrucción lista para ejecutar.
>
> El avance a cada fase requiere una autorización explícita y la compuerta que
> corresponda a ese momento (§3). La ejecución se hará **siempre en una base de
> datos independiente de staging, nunca en producción y nunca en la base
> original** (D-25).
>
> Diseño aprobado documentalmente en `cc803b5`. Referencias:
> [`decisiones-arquitectura-multilingue.md`](decisiones-arquitectura-multilingue.md)
> (D-01 a D-41), [`modelo-multilingue-propuesto.md`](modelo-multilingue-propuesto.md),
> [`plan-migracion-multilingue.md`](plan-migracion-multilingue.md) (14 fases,
> pruebas 1-44) y
> [`auditoria-internacionalizacion.md`](auditoria-internacionalizacion.md).

---

## 1. Propósito y alcance

Preparar, sin ejecutar nada, las condiciones operativas y probatorias para
iniciar la Fase 1 del plan sobre una base independiente de staging.

| Incluye | No incluye |
|---|---|
| Compuertas de prerrequisitos con estado y evidencia exigible | DDL, DML ni consultas ejecutables contra una base real |
| Procedimiento documentado de la Fase 1 | Credenciales, host, puerto ni nombre real de base de staging |
| Checklists de las 14 fases | Autorización para conectar, restaurar ni escribir |
| Plantillas de evidencia y actas de avance | Modificación de código, fuentes, importadores ni PostgreSQL |
| Regla de no avance entre fases | Ejecución en producción ni en la base original |

No existe en el repositorio un procedimiento automatizado de creación de la base
independiente ni credenciales de staging. Ese dato debe ser aportado por el
responsable de infraestructura **en el momento de la autorización**, no
inferido de este documento.

---

## 2. Reglas inmutables de preparación

1. **Base independiente (D-25).** La restauración de prueba se hace en una base
   de datos nueva y separada, con nombre propio y registrado. Un esquema temporal
   dentro de la base original **no** cumple el requisito.
2. **Nunca producción.** Ni lectura de verificación, ni backup, ni restauración,
   ni prueba se realizan en producción.
3. **Sin evidencia, sin avance.** Ninguna fase se marca como completada sin su
   acta y sus artefactos (§6). Las fases se ejecutan en orden; no se omite una
   compuerta intermedia.
4. **Sin ejecución implícita.** La aprobación del diseño y la existencia de este
   runbook no autorizan ninguna operación. Cada fase requiere autorización
   registrada.
5. **Aditiva e idempotente.** Las fases posteriores solo `CREATE TABLE IF NOT
   EXISTS`, `ADD COLUMN IF NOT EXISTS`, `INSERT` y `UPDATE`, con guardas. La
   única excepción es `DROP INDEX CONCURRENTLY` para índices inválidos o
   duplicados, con autorización **escrita, individual por índice y solo si ese
   índice aparece** (D-34); nunca se autoriza en forma genérica.
6. **API pública `approved`-only.** Ninguna fase puede publicar contenido sin
   aprobación, con o sin `ALLOW_UNREVIEWED_DISPLAY` (D-20, D-30).
7. **Tablas originales intactas.** Después de cada fase se repiten conteos y
   checksums; las tablas originales deben estar inalteradas.
8. **Dos límites de escritura en Fase 1.** La **base de origen** tiene cero
   escrituras: acceso de solo lectura; no se modifica. La **base independiente
   de staging** admite escrituras **exclusivamente** para crearla y restaurar el
   backup, con autorización específica de Fase 1. No se permite modificar
   estructuras existentes ni ejecutar DDL/DML de las fases posteriores: esa
   autorización no las habilita. Las operaciones autorizadas sobre staging se
   registran por separado (§4.2 y E-07).

---

## 3. Compuertas de prerrequisitos

### 3.1 Registro de prerrequisitos y estado actual

Fuente: `decisiones-arquitectura-multilingue.md` §4 *Decisiones pendientes*. La
columna **Momento** indica cuándo debe estar cerrada cada compuerta. **No** se
exige que las diez estén cerradas antes de empezar: varias se resuelven dentro
de las propias fases.

| # | Prerrequisito | Momento | Estado | Evidencia |
|---|---|---|---|---|
| 1 | Aprobación formal del registro y del modelo antes de cualquier DDL | Antes de Fase 2 | ✅ **CERRADA** | Aprobación documental; cuatro documentos en `cc803b5` |
| 2 | Ejecutar la etapa 4.3 y firmar la matriz de aprobación inicial | Antes de Fase 4 | ⏳ ABIERTA | Matriz 4.3 firmada por autoridad editorial (A-3) |
| 3 | Definir destino de tags PMO y corregir `sql/04_pmo/02_pmo_practicas.sql` | **Solo trabajo PMO (D-17)**; no bloquea la migración | ⏳ ABIERTA para PMO | Decisión y corrección revisada; bloqueante de la **carga PMO** |
| 4 | Parametrizar idioma en importadores (conservar `abbreviation→acronym` e invalidación D-31) | Antes de Fase 3 | ⏳ ABIERTA | Cambios revisados y prueba de invalidación |
| 5 | Confirmar en staging códigos de prueba y capas LOINC (D-26) | Antes de Fase 5 (tras Fase 1) | ⏳ ABIERTA | Acta con códigos y capas verificadas en la base independiente |
| 6 | Confirmar `source_release` real de los CSV LOINC | Antes de Fase 5 | ⏳ ABIERTA | Archivo real; `2.83` solo aparece en `importar_loinc.sql:2-5` y no se asume |
| 7 | Elegir mecanismo de identidad de aplicación y rol propietario de auditoría | Antes de Fase 2 | ⏳ ABIERTA | Decisión firmada con rol y mecanismo |
| 8 | Implementar `LanguageResolver`, evaluador editorial, API per-field y sitio | Fases 8-10, según corresponda | ⏳ ABIERTA | Componentes y matrices de prueba verdes |
| 9 | Decidir mapeo/endpoint futuro de NN 2025 y vocabulario FDI/caras | Fase 10 | ⏳ ABIERTA | Decisión documentada; NN sin endpoint propio hasta entonces |
| 10 | Autorizar la excepción D-34 | **Condicional**: solo si aparece un índice inválido o duplicado concreto | ⏳ NO APLICA AÚN | Autorización escrita, individual y específica para ese índice (A-2); si no se activa, registro de «No aplica» con evidencia de la verificación de índices |

> **Resultado actual:** la compuerta 1 está cerrada. Las demás se cierran en su
> momento. La compuerta 3 pertenece al trabajo PMO (D-17) y **no bloquea la
> migración multilingüe**; la compuerta 10 **no es una autorización genérica** y
> solo se activa ante un índice identificado. Si no se necesita ninguna
> operación D-34, se registra «No aplica» con su evidencia y **la fase no queda
> bloqueada**.

### 3.2 Matriz de dependencias de compuertas por fase

| Momento de cierre | Prerrequisito (§3.1) | Evidencia |
|---|---|---|
| **Antes de Fase 1** | Autorización específica de preparación; fuente no productiva autorizada; destino independiente (D-25); acceso mínimo; responsable de infraestructura | A-1, E-01, E-04 y autorización firmada |
| Antes de Fase 2 | Prerrequisitos técnicos y autorizaciones específicas de DDL: diseño aprobado (1), identidad de aplicación y rol de auditoría (7), autorización del DDL de Fase 2 | A-1 y decisión 7 |
| Antes de Fase 3 | Importadores parametrizados (4) | A-1 y revisión de importadores |
| Antes de Fase 4 | Matriz de aprobación inicial firmada, etapa 4.3 (2; D-19) | A-3 |
| Antes de Fase 5 | `source_release` confirmado (6) y fuentes/capas LOINC confirmadas en staging (5) | A-1, E-06, E-14 |
| Antes de Fases 8-10 | Decisiones e implementaciones correspondientes: resolver y evaluador (8), API, sitio y decisión NN 2025 (9) | A-1 y matrices de prueba |
| Antes de cualquier operación excepcional D-34 | Autorización escrita, individual y específica para **ese** índice (10) | A-2, o registro de «No aplica» con evidencia |
| Trabajo PMO (paralelo) | Compuerta 3, exclusiva de la carga PMO (D-17) | Decisión PMO y corrección revisada |

> No se adelantan a Fase 1 requisitos que corresponden a fases posteriores. La
> matriz 4.3 es la aprobación inicial del contenido **después del backfill**
> (Fase 4; D-19), no una condición para el inventario. Las compuertas de las
> fases 8-10 no pueden cerrarse antes de que esas fases se ejecuten. Si no se
> identifica ningún índice que requiera D-34, se registra «No aplica» con la
> evidencia de la verificación de índices y la fase continúa sin bloqueo.

### 3.3 Regla para cerrar una compuerta

Una compuerta solo pasa a `CERRADA` cuando concurren:

- la evidencia indicada en §3.1, con fecha y responsable;
- su registro en el acta de compuertas (A-1), indicando el momento correspondiente;
- la comprobación de que no reabre una decisión ya cerrada (D-01 a D-41).

Para la compuerta condicional D-34, si no se identifica un índice inválido o
duplicado, se registra «No aplica» con la evidencia de la verificación de
índices (A-2); esa condición **no bloquea la fase**.

No se exige el cierre anticipado de compuertas de fases futuras. Cerrar una
compuerta fuera de su momento no sustituye la autorización de la fase.

---

## 4. Fase 1 — Inventario y backup (procedimiento documentado)

### 4.1 Objetivo y condición de entrada

Fijar el punto de partida verificable y el inventario lingüístico real, sin
escribir en la base de origen. La base independiente de staging se crea y se
restaura únicamente bajo la autorización específica de Fase 1 (§2, punto 8).

- **Entrada (compuertas de Fase 1, §3.2):** autorización de preparación firmada;
  fuente no productiva autorizada; destino independiente asignado (D-25); acceso
  mínimo autorizado; responsable de infraestructura identificado. No se exigen
  aquí la matriz 4.3 ni las compuertas de fases posteriores.
- **Alcance de escritura:** cero escrituras en la base de origen (solo lectura;
  no se modifica). En la base independiente, solo crearla y restaurar el backup,
  con autorización específica de Fase 1. Queda prohibido modificar estructuras
  existentes y ejecutar DDL/DML de las Fases 2-14. Las operaciones autorizadas
  sobre staging se registran por separado (§4.2 y E-07).
- **Fuentes consultadas (solo lectura):** `sql/01_schema/design.sql`,
  `sql/02_catalogs/origen_catalog_engine.sql`, `sql/03_dentar/*`, `sql/04_pmo/*`,
  `sql/05_loinc.sql/importar_loinc.sql`, `tools/sql/snomed/*`, `tools/sources/**`,
  `api/**`, `web/**`.
- **Sin cambios de código.** Se generan únicamente artefactos de documentación y
  reporte.
- **Roles y permisos (precisión técnica):** un `pg_dump` con formato personalizado
  (`-Fc`) de una base **no incluye los roles globales del clúster**. La
  restauración no traslada credenciales ni privilegios productivos: los roles y
  permisos necesarios en staging se provisionan de forma controlada por el
  responsable de infraestructura, con privilegio mínimo, y ese
  aprovisionamiento se documenta por separado en E-04.

### 4.2 Secuencia de pasos

Todas las órdenes siguientes son **plantillas de referencia**. Los marcadores
`<...>` deben sustituirse por valores reales autorizados; no se ejecutan sin la
autorización de ejecución descrita en §8.

| Paso | Acción documentada | Resultado exigido | Evidencia |
|---|---|---|---|
| F1.1 | Registrar versión de PostgreSQL, codificación y `collation` de la base de origen; comprobar que la extensión `pg_trgm` está instalada y es válida | Versión y parámetros reproducibles; `pg_trgm` presente | E-01, E-02 |
| F1.2 | Registrar commit del repositorio (`cc803b5` o el que corresponda), fecha, responsable y entorno | Origen inequívoco del estado evaluado | E-01 |
| F1.3 | Obtener `pg_dump` en formato personalizado (`-Fc`) de la base de origen, con cuenta autorizada | Archivo `.dump` con ruta y tamaño registrados | E-03 |
| F1.4 | Calcular SHA-256 del dump y guardar el valor junto al archivo | Hash registrado e inmutable | E-03 |
| F1.5 | Crear, **fuera de producción**, una base de datos nueva e independiente con nombre registrado; verificar que no es la original ni un esquema dentro de ella | Base independiente identificada (D-25) | E-04 |
| F1.6 | Restaurar el dump en esa base independiente y comprobar extensiones, dependencias, funciones, triggers y secuencias; verificar por separado los roles provisionados en staging y sus permisos | Restauración completa y sin errores; roles/permisos aprovisionados con privilegio mínimo | E-04 |
| F1.7 | Ejecutar los conteos y checksums canónicos de las 15 tablas (§4.3) en origen y en la copia | Resultados idénticos; 0 huérfanos de FK; 0 duplicados que violen UNIQUE | E-05 |
| F1.8 | Levantar el inventario de idiomas real (§4.4) | Inventario firmado, sin inferencias de dialecto | E-06 |
| F1.9 | Confirmar que `os_catalog_item.observation` **no existe** y registrar el riesgo PMO como bloqueante de PMO | Hallazgo documentado, no corregido en esta fase | E-06 |
| F1.10 | Acordar y registrar la congelación temporal de importadores durante la toma de datos | Ventana documentada; 0 escrituras en la base de origen | E-01 |
| F1.11 | Verificar los dos límites de escritura (§2, punto 8) y firmar el acta de cierre de fase | Origen: cero escrituras; destino: solo creación y restauración autorizadas | E-07 |

**Registro separado de operaciones autorizadas sobre staging (Fase 1):**

| Operación | Base | Autorización | Evidencia |
|---|---|---|---|
| Crear la base independiente | Staging; nunca la base de origen | Específica de Fase 1 | E-04 |
| Restaurar el backup | Staging; nunca la base de origen | Específica de Fase 1 | E-04 |
| Provisionar roles y permisos mínimos | Staging | Responsable de infraestructura | E-04 |
| Verificar objetos, conteos y checksums | Origen (solo lectura) y copia | Fase 1 | E-05 |

**Fuera de alcance de Fase 1:** modificar estructuras existentes y ejecutar
cualquier DDL/DML de las Fases 2-14.

**Plantilla de referencia para F1.3 / F1.4** (no ejecutar):

```text
pg_dump -h <HOST> -U <USUARIO_ADMIN> -d <BASE_ORIGEN> -Fc \
  -f <RUTA>/<BASE_ORIGEN>_pre_multilingue.dump
sha256sum <RUTA>/<BASE_ORIGEN>_pre_multilingue.dump
```

**Plantilla de referencia para F1.6** (no ejecutar). El ejemplo del manual usa
`--clean --if-exists`; sobre la base independiente debe evaluarse ese indicador
solo con autorización y después de verificar el respaldo, porque `--clean`
elimina objetos previos:

```text
pg_restore -h <HOST> -U <USUARIO_ADMIN> -d <BASE_INDEPENDIENTE> \
  <RUTA>/<BASE_ORIGEN>_pre_multilingue.dump
```

**Precisión sobre F1.6:** el dump con formato personalizado contiene objetos y
datos de una base, **no los roles globales del clúster**. Comprobar "roles"
después de `pg_restore` significa verificar que los roles necesarios ya fueron
provisionados en staging por el responsable de infraestructura, con privilegio
mínimo y sin trasladar credenciales ni privilegios productivos. Ese
aprovisionamiento es un paso independiente de la restauración y se registra en
E-04.

No se registra aquí ninguna cadena de conexión real: `manual-carga-catalogos.md`
(§4.2 y §14) contiene ejemplos con valores de muestra que **no** deben copiarse
como si fueran credenciales válidas.

### 4.3 Conteos y checksums canónicos

Aplican las reglas del plan §2.2:

- columnas explícitas en orden fijo;
- `ORDER BY` por clave primaria;
- representación determinista de `NULL` (centinela documentado);
- sin recortes ni normalizaciones ocultas;
- se guarda la consulta exacta utilizada, junto con versión de PostgreSQL,
  codificación y `collation`;
- se repiten después de **cada** fase; las tablas originales deben permanecer
  inalteradas.

Tablas del inventario (15): `os_catalog`, `os_catalog_release`,
`os_catalog_category`, `os_catalog_item`, `os_catalog_item_version`,
`os_catalog_term`, `os_catalog_identifier`, `os_concept_mapping`,
`os_fee_schedule`, `os_pricing_values`, `snomed_descriptions`,
`cie10_descriptions`, `loinc`, `nomencladores_argentina`, `vademecum_comercial`.

### 4.4 Inventario lingüístico esperado

| Fuente | Estado real a registrar | Regla |
|---|---|---|
| `os_*` | Todo `es-AR` | No inferir otros dialectos |
| SNOMED | `es` / `en` (ISO-639-1, sin tag dialectal en `sct2.description`) | D-05: `es` no se convierte en `es-AR`; D-27 |
| CIE-10 | Según carga real | Registrar lo observado, sin asumir |
| LOINC | Sin `language_code` en la tabla actual; capas EN → es-MX → es-AR → ConsumerName | D-26/D-40: capas ya sobrescritas en BD; `source_release` a confirmar |
| CDT | Sufijos `nombre_en` / `nombre_es` | D-37: tablas y rutas nativas; no `/v1/nomenclador` |
| NN 2025 | Sin idioma y sin endpoint propio | D-37; mapeo pendiente (compuerta 9) |

Además:

- confirmar ausencia de `os_catalog_item.observation`;
- no marcar `es-AR` como `is_source_only` aunque aparezca una capa LOINC en ese
  idioma (D-39): la procedencia se declara en la fila, no en `os_language`;
- no inventar `source_language_code`: se derivará con
  `loinc_source_language(language_code, source_file)` en Fase 5 (D-40).

### 4.5 Criterios de salida de Fase 1

- Backup restaurable en base independiente (D-25), con SHA-256 registrado; roles
  y permisos de staging aprovisionados por separado.
- Checksums e inventario registrados y firmados.
- Cero escrituras en la base de origen; en la base independiente, solo crearla y
  restaurar el backup con autorización de Fase 1 (§2, punto 8), registradas por
  separado (§4.2 y E-07).
- Queda registrado que la autorización de Fase 1 **no habilita modificar
  estructuras existentes ni ejecutar DDL/DML de las Fases 2-14**.
- Estas condiciones de entrada y salida reproducen
  `plan-migracion-multilingue.md`, Fase 1 (§3): backup verificado en base
  independiente y aprobación firmada.
- Riesgo PMO registrado como bloqueante de PMO (D-17), no de esta migración.
- Confusión Fase 4 del proyecto original (PMO) vs. Fase 6 del plan (DENTAR)
  explícitamente descartada.
- Acta E-07 firmada.

**No se avanza a Fase 2 sin esta acta y sin las compuertas de Fase 2 (§3.2).**

---

## 5. Checklists por fase

Estado inicial de todas las casillas: **pendiente**. No se marcan hasta que el
acta de la fase esté firmada. Las condiciones de avance se toman del plan §3.

| # | Fase | Condición de avance / cierre | Evidencia | Estado |
|---|---|---|---|---|
| 1 | Inventario y backup | Backup verificado en base independiente, checksums e inventario firmados; 0 escrituras en origen; destino solo creación/restauración | E-01…E-07 | ☐ Pendiente |
| 2 | Creación de estructuras lingüísticas | Integridad, índices y permisos verificados; ninguna tabla existente alterada; `es-AR` no source-only (D-39); compuertas 1 y 7 cerradas; D-34 solo si aparece un índice concreto, si no «No aplica» con evidencia y sin bloqueo | E-08…E-10, A-2 | ☐ Pendiente |
| 3 | Ampliación de estructuras existentes | Definición vigente verificada; DDL aditivo e idempotente; ámbito de hash D-41 implementado (`row_shared`/`field_individual`); aprobación firmada | E-11…E-12 | ☐ Pendiente |
| 4 | Backfill controlado y aprobación inicial | Reporte de reconciliación revisado y matriz 4.3 firmada (compuerta 2; D-19) | E-13, A-3 | ☐ Pendiente |
| 5 | Migración de LOINC | Política de prioridad y `source_release` confirmados; `loinc_source_language(...)` validada; ninguna variante sobrescrita | E-14…E-15 | ☐ Pendiente |
| 6 | Adaptación de DENTAR (D-09) | Mapeo `abbreviation→acronym` conservado; validaciones de términos y campos clínicos aprobadas | E-16 | ☐ Pendiente |
| 7 | Conservación de SNOMED y CIE-10 (D-05) | Decisión D-05 aceptada; `es` sin dialecto inferido; validaciones aprobadas | E-17 | ☐ Pendiente |
| 8 | Implementación de `LanguageResolver` | Resolver aprobado con matriz de pruebas verde; no consulta tablas de contenido | E-18 | ☐ Pendiente |
| 9 | Adaptación de API | Matriz de pruebas y contrato aprobados; `approved`-only; D-39/D-40 en el contrato | E-19 | ☐ Pendiente |
| 10 | Adaptación del sitio y exposición CDT/NN | Revisión visual y funcional aprobada; decisión NN 2025 (compuerta 9) | E-20 | ☐ Pendiente |
| 11 | Dual-read y dual-write condicionados | Periodo de observación y reconciliación limpios; rollback posible desde backups; D-41 en dual-write | E-21 | ☐ Pendiente |
| 12 | Validación y reconciliación | Pruebas 1-44 ejecutadas en staging, incluidas 42-44 (D-39/D-40/D-41) | E-22 | ☐ Pendiente |
| 13 | Corte controlado | Aprobación final independiente de los cuatro documentos | E-23 | ☐ Pendiente |
| 14 | Plan de rollback | Procedimiento firmado con responsables y tiempos; cierre del plan | E-24 | ☐ Pendiente |

**Regla de no avance:** una fase solo puede iniciarse cuando la anterior tiene
su acta firmada **y** las compuertas de su momento están cerradas (§3.2). No se
permite avanzar "en paralelo" ni dejar una validación pendiente para la fase
siguiente. La compuerta PMO (3) es exclusiva del trabajo PMO (D-17) y **no
bloquea la migración**; la compuerta D-34 (10) se abre solo si se identifica un
índice concreto, con autorización escrita individual (A-2), y se registra «No
aplica» con evidencia si no se requiere, sin bloquear la fase.

---

## 6. Plantillas de evidencia

### E-01 / E-02 — Entorno y versión

```text
Fecha / hora:         2026-11-17 (ventana operativa: 10:30 GMT-3)
Responsable:          Luis A. Uriarte
Commit del repositorio: cc803b5
Entorno:              [X] desarrollo  [ ] staging-independiente
                      PRODUCCIÓN QUEDA EXCLUIDA: no es opción válida.
                      Observación: destino declarado en desarrollo; si se exige
                      staging estricto, declarar el entorno real antes de ejecutar.
Versión PostgreSQL:   <se registra en Fase 1>
Codificación:         <se registra en Fase 1>
Collation:            <se registra en Fase 1>
Extensión pg_trgm:    [ ] instalada  [ ] válida  [ ] NO disponible -> detener
Base de origen:       origen_salud @ localhost (desarrollo, no productiva)
Base independiente:   origen_codes   [X] distinta de la original  [X] no es esquema temporal
                      Esquema por defecto: public
Las verificaciones técnicas se diligencian durante la ejecución de Fase 1.
```

### E-03 — Backup y SHA-256

```text
Archivo dump:
Ruta:
Tamaño (bytes):
SHA-256:
Cuenta utilizada:     <autorizada, sin credenciales en el documento>
Fecha / hora:
Verificación SHA-256: [ ] coincide  [ ] NO coincide -> detener
```

### E-04 — Restauración en base independiente

```text
Base destino:         origen_codes (esquema por defecto: public; entorno desarrollo)
Rol de restauración:  origen_api (privilegio mínimo, no superuser)
Responsable de la provisión de roles: Luis A. Uriarte
Las casillas siguientes se verifican y marcan durante la ejecución de Fase 1.
[ ] Extensiones verificadas      [ ] Dependencias verificadas
[ ] Funciones verificadas        [ ] Triggers verificados
[ ] Secuencias verificadas
[ ] Roles provisionados en staging (NO vienen en el dump -Fc)
[ ] Permisos aprovisionados con privilegio mínimo
[ ] Sin credenciales ni privilegios productivos trasladados
[ ] Aprovisionamiento de roles documentado por separado
[ ] --clean evaluado y autorizado si se usó
Restauración:         [ ] correcta  [ ] con errores -> detener
Responsable:
```

### E-05 — Conteos y checksums

```text
Consulta exacta utilizada: <adjuntar, sin normalizaciones ocultas>
Representación de NULL:    <centinela documentado>
Orden:                     ORDER BY <PK>

Tabla                         Conteo_origen  Hash_origen  Conteo_copia  Hash_copia  Igual
os_catalog
os_catalog_release
os_catalog_category
os_catalog_item
os_catalog_item_version
os_catalog_term
os_catalog_identifier
os_concept_mapping
os_fee_schedule
os_pricing_values
snomed_descriptions
cie10_descriptions
loinc
nomencladores_argentina
vademecum_comercial

Huérfanos de FK:            0    [ ] verificado
Duplicados que violan UNIQUE: 0  [ ] verificado
```

### E-06 — Inventario lingüístico

```text
Fuente      Valor observado        Evidencia/adjudicación
os_*        es-AR
SNOMED      es / en                sin tag dialectal en sct2.description
CIE-10      <según carga>
LOINC       sin language_code      capas EN/es-MX/es-AR/ConsumerName
CDT         nombre_en/nombre_es    rutas nativas /v1/search/odontologia
NN 2025     sin idioma             sin endpoint propio

[ ] os_catalog_item.observation NO existe
[ ] Riesgo PMO registrado como bloqueante de PMO (no de esta migración)
[ ] es-AR NO marcado como is_source_only (D-39)
[ ] source_language_code NO se inventa; se derivará en Fase 5 (D-40)
Firmado por:
```

### E-07 / E-xx — Acta de cierre de fase

```text
Fase:
Fecha de inicio / fin:
Responsable de ejecución:
Responsable de aprobación:
Resumen de operaciones:
Escrituras en Fase 1:
  Origen:  0  [ ] verificado (acceso de solo lectura)
  Destino: solo crear la base independiente y restaurar el backup,
           con autorización específica de Fase 1  [ ] verificado
  [ ] No se modificaron estructuras existentes
  [ ] No se habilitó DDL/DML de Fases 2-14
Operaciones sobre staging registradas por separado (§4.2): [ ] sí
Validaciones ejecutadas:
Resultado:            [ ] APTO  [ ] NO APTO
Incidencias y resolución:
Compuertas cerradas en esta fase:
Firma:
```

### A-1 — Acta de compuertas (§3)

```text
#  Prerrequisito                                 Momento            Estado        Evidencia  Fecha  Responsable
1   Aprobación formal del diseño                  Antes Fase 2       CERRADA       cc803b5
2   Matriz 4.3 firmada                            Antes Fase 4       ABIERTA
3   Tags PMO + corrección 02_pmo_practicas.sql    Solo PMO (D-17)    ABIERTA       no bloquea la migración
4   Parametrización de importadores               Antes Fase 3       ABIERTA
5   Códigos y capas LOINC en staging              Antes Fase 5       ABIERTA
6   source_release real de CSV confirmado         Antes Fase 5       ABIERTA
7   Identidad de aplicación y rol de auditoría    Antes Fase 2       CERRADA       decisión 2026-11-17: aplicación "Terminología-as-a-Service para América Latina"; auditoría: Luis A. Uriarte
8   Resolver/evaluador/API/sitio                  Fases 8-10         ABIERTA
9   Mapeo/endpoint NN 2025                        Fase 10            ABIERTA
10  Autorización D-34 por índice                  Condicional        NO APLICA AÚN

Compuertas previas a Fase 1 — CERRADAS (registro 2026-11-17):
[X] Autorización de preparación firmada — Luis A. Uriarte, 2026-11-17
    [X] Crear base independiente
    [X] Restaurar backup
    [X] Queda excluido DDL/DML de Fases 2-14
[X] Origen confirmado como no productivo
    Base: origen_salud @ localhost; entorno: desarrollo
    Motivo: uso para desarrollo, no producción
    Retracción registrada: se retira la declaración previa de que era productiva
[X] Destino independiente asignado (D-25)
    Base: origen_codes; esquema por defecto: public; entorno: desarrollo
    [X] Distinta de la base de origen
    [X] No es esquema temporal dentro del origen
    [X] No es producción
[X] Acceso mínimo autorizado
    Cuenta/rol para pg_dump: origen_api
    Cuenta/rol para restauración: origen_api
    [X] Solo lectura en la base de origen
    [X] Rol real, no superuser; sin privilegios productivos
    Retracción registrada: se retira la declaración previa de traslado de permisos
[X] Responsable de infraestructura identificado: Luis A. Uriarte
    [X] Aprovisiona roles y permisos mínimos

Ventana operativa (§8.4): 2026-11-17, 10:30 GMT-3; responsable Luis A. Uriarte.

Observación: el destino se declara en entorno «desarrollo», mientras el runbook
menciona «staging». Quedan cubiertas las condiciones verificables de D-25 (base
independiente, distinta del origen y no producción); si se exige staging en
sentido estricto, debe declararse el entorno real antes de la ejecución.

Compuerta 7 — CERRADA (declaración 2026-11-17):
[X] Aplicación: Terminología-as-a-Service para América Latina
[X] Rol propietario de la auditoría: Luis A. Uriarte
[X] Mecanismo de identidad de aplicación: configuración local de sesión
    (app.actor_id / app.importer_run_id con ámbito transaccional, D-10);
    SESSION_USER queda solo como evidencia de respaldo, no como autor.

Cierre de Fase 1 — DECLARADO por Luis A. Uriarte (2026-11-17):
[X] Fase 1 ejecutada por el responsable; acta E-07 firmada.
    Nota: los resultados técnicos de E-03/E-04/E-05/E-06 y E-07 no se aportaron
    a este repositorio; quedan en poder del responsable. No se inventan aquí
    versiones, hashes, conteos ni firmas. Esta declaración habilita el pase a
    Fase 2; no sustituye la evidencia cuando se audite la fase.

Autorización de desarrollo — DECLARADA por Luis A. Uriarte (2026-11-17):
[X] Levantamiento de la restricción de no generar DDL/DML y de no modificar
    código/importadores/fuentes, limitada a la Fase 2 y a los artefactos que se
    producen en docs/architecture/. La ejecución en la base NO está autorizada
    por este cambio: requiere autorización operativa de DDL de Fase 2.
[X] Ámbito de modificación de importadores/fuentes/código: PENDIENTE de lista
    concreta de archivos. Sin esa lista no se modifica ningún archivo de código.

Nota: el cierre de las compuertas previas NO autorizó la ejecución de Fase 1;
la autorización firmada lo hizo para esa fase. El pase a Fase 2 requiere además
la autorización operativa de su DDL, que hoy NO está otorgada.

Regla: cada compuerta se cierra en su momento. No se requiere 10/10 para Fase 1.
PMO (3) pertenece a su propio trabajo (D-17) y no bloquea la migración.
D-34 (10) se activa solo ante un índice concreto; si no aplica, registrar
«No aplica» con evidencia de la verificación de índices, sin bloquear la fase.
```

### A-2 — Autorización individual D-34

> Compuerta **condicional**: se emite solo cuando se identifica un índice
> inválido o duplicado concreto. No existe autorización genérica previa y su
> ausencia no bloquea las fases que no requieren esa excepción.

```text
Índice:
Tabla / esquema:
Motivo:                [ ] inválido (indisvalid)  [ ] duplicado exacto
Creado por esta migración o autorizado por escrito: [ ] sí
Definición previa registrada:                       [ ] sí
Fuera de transacción y recreado con CONCURRENTLY:   [ ] previsto
Autorizado por:                    Fecha:
Alcance prohibido: tablas, columnas y datos -> NUNCA

Registro si NO se requiere esta excepción:
[ ] No aplica: verificación de índices registrada en <evidencia>
    Fecha:                    Responsable:
    La fase NO queda bloqueada por D-34.
```

### A-3 — Matriz de aprobación inicial (etapa 4.3)

```text
Recurso / versión:
Idioma efectivo declarado:
Procedencia (source_file / source_reference / provenance):
Estado editorial:      [ ] approved  [ ] pending/authority  [ ] unreviewed
Autoridad que aprueba:
Fecha:
Campos incluidos:      [ ] seis campos compartidos (row_shared, D-41)
                       [ ] campo individual en os_field_review (field_individual, D-41)
Observaciones:
Firma:
```

> Sin esta matriz firmada, las pruebas 1-3 esperan contenido vacío declarado
> (D-19). No se aprueba contenido automáticamente por ser "oficial".

---

## 7. Regla de no avance resumida

```text
Compuertas previas a Fase 1 cerradas (§3.2)
        |
        v
Autorización de Fase 1: crear base independiente + restaurar backup
        (origen: cero escrituras; NO modifica estructuras existentes
         ni habilita DDL/DML de Fases 2-14)
        |
        v
Fase 1 -> acta E-07 firmada? --no--> DETENER
        | si
        v
Compuerta del momento para Fase N cerrada? --no--> DETENER
        | si
        v
Fase N -> validaciones y acta firmada? --no--> DETENER
        | si
        v
Fase N+1 ... hasta Fase 14

PMO (compuerta 3): carril paralelo, bloquea solo su carga (D-17)
D-34 (compuerta 10): solo si aparece un índice concreto (A-2);
                     si no aplica, registrar evidencia y continuar
```

Cualquier hallazgo que reabra una decisión D-01 a D-41 detiene la secuencia y
vuelve al documento de decisiones; no se resuelve "sobre la marcha" en la base.

---

## 8. Para pasar de preparación a ejecución

Para autorizar la **Fase 1**, con las compuertas previas a Fase 1 cerradas
(§3.2), solicitar **por escrito**. Los seis puntos siguientes quedan reunidos en
[`autorizacion-ejecucion-fase-1.md`](autorizacion-ejecucion-fase-1.md), firmado
por Luis A. Uriarte el `2026-11-17` en ambos campos (autorizante y responsable de
ejecución), con efecto operativo exclusivo para Fase 1:

1. Confirmación de las compuertas previas a Fase 1 con su evidencia (acta A-1).
2. Entorno y credenciales de staging facilitados por el responsable de
   infraestructura, con privilegio mínimo y sin credenciales en este documento.
3. Nombre de la **base de datos independiente** de staging (D-25) y confirmación
   de que no es producción ni la base original.
4. Ventana de congelación de importadores y responsable de la misma.
5. Aprovisionamiento controlado de roles y permisos en staging, sin trasladar
   credenciales ni privilegios productivos (§4.1).
6. Autorización de ejecución de **Fase 1**, limitada a crear la base
   independiente y restaurar el backup; cero escrituras en la base de origen;
   **excluye explícitamente modificar estructuras existentes y el DDL/DML de las
   Fases 2-14**.

Las compuertas de fases posteriores se solicitan en su momento (§3.2). La
compuerta PMO (3) pertenece a su propio trabajo (D-17) y no condiciona esta
autorización; la autorización D-34 (10) se pide solo si aparece un índice
concreto y, si no se requiere, se registra «No aplica» con evidencia sin
bloquear la fase.

Hasta que esos seis puntos estén presentes, este runbook permanece como
**preparación documental** y no se ejecuta ninguna de sus plantillas.

---

## 9. Trazabilidad

| Documento | Función en este runbook |
|---|---|
| `decisiones-arquitectura-multilingue.md` | Origen de las 10 compuertas y de D-01 a D-41; D-17 (PMO), D-19 (aprobación inicial), D-25 (base independiente) y D-34 (excepción por índice) |
| `modelo-multilingue-propuesto.md` | Contrato técnico y de salida; D-39, D-40, D-41 |
| `plan-migracion-multilingue.md` | Fases 1-14, condiciones de avance, pruebas 1-44, §2.2 |
| `auditoria-internacionalizacion.md` | Cierre de hallazgos y riesgos registrados |
| `autorizacion-ejecucion-fase-1.md` | Autorización operativa de Fase 1, firmada el 2026-11-17 (alcance exclusivo de Fase 1) |
| `guia-diligenciamiento-evidencias-fase-1.md` | Orden de registro de E-01 a E-07 durante Fase 1; guía de registro, no de ejecución |
| `ddl-fase-2-propuesto.md` | DDL propuesto de Fase 2, derivado del diseño aprobado; artefacto documental, no aplicado ni ejecutado |
| `manual-carga-catalogos.md` §4.2 y §14 | Ejemplos de `pg_dump`/`pg_restore` (valores de muestra) |

**Fin del documento de preparación. No autoriza ejecución.**
