# Runbook de preparación — Implementación multilingüe en base independiente de staging

> **ESTADO: DOCUMENTO DE PREPARACIÓN. NO AUTORIZA EJECUCIÓN.**
>
> Este runbook organiza la implementación futura del diseño aprobado. **No
> autoriza** conexión a staging, ejecución de SQL, creación de base de datos,
> modificación de PostgreSQL, PHP/API/web/importadores ni `tools/sources/**`.
> Toda orden, ruta o nombre de base que aparece aquí es una **plantilla de
> referencia con valores de ejemplo**, no una instrucción lista para ejecutar.
>
> El avance a la ejecución requiere una autorización explícita y posterior a la
> verificación de **todas** las compuertas de la §3. La ejecución se hará
> **siempre en una base de datos independiente de staging, nunca en producción y
> nunca en la base original** (D-25).
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
   duplicados, con autorización **escrita caso por caso** (D-34).
6. **API pública `approved`-only.** Ninguna fase puede publicar contenido sin
   aprobación, con o sin `ALLOW_UNREVIEWED_DISPLAY` (D-20, D-30).
7. **Tablas originales intactas.** Después de cada fase se repiten conteos y
   checksums; las tablas originales deben estar inalteradas.
8. **Cero escritura en Fase 1.** La fase de inventario y backup no modifica
   ningún objeto.

---

## 3. Compuertas de prerrequisitos

### 3.1 Estado actual

Fuente: `decisiones-arquitectura-multilingue.md` §4 *Decisiones pendientes*.

| # | Prerrequisito | Estado | Evidencia para cerrarlo |
|---|---|---|---|
| 1 | Aprobación formal del registro y del modelo antes de cualquier DDL | ✅ **CERRADA** | Aprobación documental del usuario; cuatro documentos en `cc803b5` |
| 2 | Ejecutar la etapa 4.3 y firmar la matriz de aprobación inicial | ⏳ ABIERTA | Matriz 4.3 firmada por autoridad editorial (plantilla A-3) |
| 3 | Definir destino de tags PMO y corregir `sql/04_pmo/02_pmo_practicas.sql` | ⏳ ABIERTA | Decisión de destino + corrección revisada. **Bloqueante de PMO**, no de esta migración |
| 4 | Parametrizar idioma en importadores (conservar `abbreviation→acronym` e invalidación D-31) | ⏳ ABIERTA | Cambios revisados y prueba de invalidación |
| 5 | Confirmar en staging códigos de prueba y capas LOINC (D-26) | ⏳ ABIERTA | Acta con códigos reales y capas verificadas |
| 6 | Confirmar `source_release` real de los CSV LOINC | ⏳ ABIERTA | Evidencia del archivo real; `2.83` solo aparece en `importar_loinc.sql:2-5` y no se asume |
| 7 | Elegir mecanismo de identidad de aplicación y rol propietario de auditoría | ⏳ ABIERTA | Decisión firmada con rol y mecanismo |
| 8 | Implementar `LanguageResolver`, evaluador editorial, API per-field y sitio | ⏳ ABIERTA | Fases 8-10 completadas y matrices de prueba verdes |
| 9 | Decidir mapeo/endpoint futuro de NN 2025 y vocabulario FDI/caras | ⏳ ABIERTA | Fase 10: decisión documentada; NN sin endpoint propio hasta entonces |
| 10 | Aprobar por escrito la excepción D-34 para cada índice inválido | ⏳ ABIERTA | Autorización individual por índice (plantilla A-2) |

> **Resultado de la compuerta global: NO SUPERADA.** Solo la compuerta 1 está
> cerrada. No se prepare ni se autorice la ejecución hasta que las diez estén
> cerradas, con su evidencia registrada en el acta A-1 (§6).

### 3.2 Regla para cerrar una compuerta

Una compuerta solo pasa a `CERRADA` cuando concurren:

- la evidencia indicada en la tabla, con fecha y responsable;
- su registro en el acta de compuertas (A-1);
- la comprobación de que no reabre una decisión ya cerrada (D-01 a D-41).

Las compuertas 2, 3, 5, 6, 7 y 10 son **externas a la ejecución de Fase 1** y
deben resolverse antes de autorizar cualquier cambio. Las compuertas 4, 8 y 9 se
resuelven dentro de las fases correspondientes, pero **no habilitan por sí solas
el inicio**: la autorización de ejecución exige el cierre previo de las seis
externas.

---

## 4. Fase 1 — Inventario y backup (procedimiento documentado)

### 4.1 Objetivo y condición de entrada

Fijar el punto de partida verificable y el inventario lingüístico real, sin
escribir en ninguna base.

- **Entrada:** compuertas externas 2, 3, 5, 6, 7 y 10 cerradas; nombre de la base
  independiente asignado; acceso de solo lectura a la base de origen concedido
  por el responsable; ventana de congelación temporal de importadores acordada.
- **Fuentes consultadas (solo lectura):** `sql/01_schema/design.sql`,
  `sql/02_catalogs/origen_catalog_engine.sql`, `sql/03_dentar/*`, `sql/04_pmo/*`,
  `sql/05_loinc.sql/importar_loinc.sql`, `tools/sql/snomed/*`, `tools/sources/**`,
  `api/**`, `web/**`.
- **Sin cambios de código.** Se generan únicamente artefactos de documentación y
  reporte.

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
| F1.6 | Restaurar el dump en esa base independiente y comprobar extensiones, roles, dependencias, funciones, triggers, secuencias y permisos | Restauración completa y sin errores | E-04 |
| F1.7 | Ejecutar los conteos y checksums canónicos de las 15 tablas (§4.3) en origen y en la copia | Resultados idénticos; 0 huérfanos de FK; 0 duplicados que violen UNIQUE | E-05 |
| F1.8 | Levantar el inventario de idiomas real (§4.4) | Inventario firmado, sin inferencias de dialecto | E-06 |
| F1.9 | Confirmar que `os_catalog_item.observation` **no existe** y registrar el riesgo PMO como bloqueante de PMO | Hallazgo documentado, no corregido en esta fase | E-06 |
| F1.10 | Acordar y registrar la congelación temporal de importadores durante la toma de datos | Ventana documentada; 0 escrituras en Fase 1 | E-01 |
| F1.11 | Verificar que no se ejecutó ninguna operación de escritura y firmar el acta de cierre de fase | 0 operaciones de escritura | E-07 |

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

- Backup restaurable en base independiente (D-25), con SHA-256 registrado.
- Checksums e inventario registrados y firmados.
- 0 operaciones de escritura.
- Riesgo PMO registrado como bloqueante de PMO, no de esta migración.
- Confusión Fase 4 del proyecto original (PMO) vs. Fase 6 del plan (DENTAR)
  explícitamente descartada.
- Acta E-07 firmada.

**No se avanza a Fase 2 sin esta acta.**

---

## 5. Checklists por fase

Estado inicial de todas las casillas: **pendiente**. No se marcan hasta que el
acta de la fase esté firmada. Las condiciones de avance se toman del plan §3.

| # | Fase | Condición de avance / cierre | Evidencia | Estado |
|---|---|---|---|---|
| 1 | Inventario y backup | Backup verificado en base independiente, checksums e inventario firmados, 0 escrituras | E-01…E-07 | ☐ Pendiente |
| 2 | Creación de estructuras lingüísticas | Integridad, índices y permisos verificados; ninguna tabla existente alterada; `es-AR` no source-only (D-39); D-34 autorizado por índice | E-08…E-10, A-2 | ☐ Pendiente |
| 3 | Ampliación de estructuras existentes | Definición vigente verificada; DDL aditivo e idempotente; ámbito de hash D-41 implementado (`row_shared`/`field_individual`); aprobación firmada | E-11…E-12 | ☐ Pendiente |
| 4 | Backfill controlado y aprobación inicial | Reporte de reconciliación revisado y matriz 4.3 firmada (compuerta 2) | E-13, A-3 | ☐ Pendiente |
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
su acta firmada **y** las compuertas que le corresponden están cerradas. No se
permite avanzar "en paralelo" ni dejar una validación pendiente para la fase
siguiente.

---

## 6. Plantillas de evidencia

### E-01 / E-02 — Entorno y versión

```text
Fecha / hora:
Responsable:
Commit del repositorio:
Entorno:              [ ] desarrollo  [ ] staging-independiente
                      PRODUCCIÓN QUEDA EXCLUIDA: no es opción válida.
Versión PostgreSQL:
Codificación:
Collation:
Extensión pg_trgm:    [ ] instalada  [ ] válida  [ ] NO disponible -> detener
Base de origen:       <registrar>
Base independiente:   <registrar>   [ ] distinta de la original  [ ] no es esquema temporal
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
Base destino:         <nombre registrado>
[ ] Extensiones verificadas      [ ] Roles verificados
[ ] Dependencias verificadas     [ ] Funciones verificadas
[ ] Triggers verificados         [ ] Secuencias verificadas
[ ] Permisos verificados
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
Operaciones de escritura en Fase 1: 0  [ ] verificado
Validaciones ejecutadas:
Resultado:            [ ] APTO  [ ] NO APTO
Incidencias y resolución:
Compuertas cerradas en esta fase:
Firma:
```

### A-1 — Acta de compuertas (§3)

```text
#  Prerrequisito                                    Estado  Evidencia  Fecha  Responsable
1   Aprobación formal del diseño                     CERRADA cc803b5    —      usuario
2   Matriz 4.3 firmada                               ABIERTA
3   Tags PMO + corrección 02_pmo_practicas.sql       ABIERTA
4   Parametrización de importadores                  ABIERTA
5   Códigos y capas LOINC verificados en staging     ABIERTA
6   source_release real de CSV confirmado            ABIERTA
7   Identidad de aplicación y rol de auditoría       ABIERTA
8   Resolver/evaluador/API/sitio implementados       ABIERTA
9   Mapeo/endpoint NN 2025 decidido                  ABIERTA
10  Autorización D-34 por índice                     ABIERTA

Resultado global: NO SUPERADA  (requiere 10/10 CERRADA)
```

### A-2 — Autorización individual D-34

```text
Índice:
Tabla / esquema:
Motivo:                [ ] inválido (indisvalid)  [ ] duplicado exacto
Creado por esta migración o autorizado por escrito: [ ] sí
Definición previa registrada:                       [ ] sí
Fuera de transacción y recreado con CONCURRENTLY:   [ ] previsto
Autorizado por:                    Fecha:
Alcance prohibido: tablas, columnas y datos -> NUNCA
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
Compuertas externas (2,3,5,6,7,10) cerradas
        |
        v
Autorización explícita de ejecución (§8)
        |
        v
Fase 1 -> acta E-07 firma? --no--> DETENER
        | si
        v
Fase N -> validaciones y acta firmada? --no--> DETENER
        | si
        v
Fase N+1 ... hasta Fase 14
```

Cualquier hallazgo que reabra una decisión D-01 a D-41 detiene la secuencia y
vuelve al documento de decisiones; no se resuelve "sobre la marcha" en la base.

---

## 8. Para pasar de preparación a ejecución

Cuando las diez compuertas estén cerradas, solicitar **por escrito**:

1. Confirmación explícita de cada compuerta con su evidencia (acta A-1).
2. Entorno y credenciales de staging facilitados por el responsable de
   infraestructura, con privilegio mínimo y sin credenciales en este documento.
3. Nombre de la **base de datos independiente** de staging (D-25) y confirmación
   de que no es producción ni la base original.
4. Ventana de congelación de importadores y responsable de la misma.
5. Autorización de ejecución por fase, empezando por la Fase 1.

Hasta que esos cinco puntos estén presentes, este runbook permanece como
**preparación documental** y no se ejecuta ninguna de sus plantillas.

---

## 9. Trazabilidad

| Documento | Función en este runbook |
|---|---|
| `decisiones-arquitectura-multilingue.md` | Origen de las 10 compuertas y de D-01 a D-41 |
| `modelo-multilingue-propuesto.md` | Contrato técnico y de salida; D-39, D-40, D-41 |
| `plan-migracion-multilingue.md` | Fases 1-14, condiciones de avance, pruebas 1-44, §2.2 |
| `auditoria-internacionalizacion.md` | Cierre de hallazgos y riesgos registrados |
| `manual-carga-catalogos.md` §4.2 y §14 | Ejemplos de `pg_dump`/`pg_restore` (valores de muestra) |

**Fin del documento de preparación. No autoriza ejecución.**
