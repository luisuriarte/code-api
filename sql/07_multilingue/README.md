# Scripts SQL — Implementación multilingüe (Fases 2 a 7, recuperación LOINC ES y validación Fase 12)

Scripts ejecutables derivados del diseño aprobado en `cc803b5`. Entorno de
**pruebas con datos no reales**. Ejecutar en la base independiente (`origen_codes`),
no en producción.

## Estado en el entorno de pruebas

Los scripts `01` a `14` ya fueron ejecutados en `origen_codes`. La validación
Fase 12 (`12_fase12_validacion.sql`) quedó en 0 hallazgos técnicos. La matriz
D-19 fue **aprobada por el responsable**: ejecutar `15` para registrar esa
aprobación por campo, luego `16` y `17` como reportes de verificación. El corte
de Fase 13 queda preparado pero **no activo** (`OS_IMPORT_MODE=dual`).

## Orden de ejecución

| # | Archivo | Fase | Transacción |
|---|---|---|---|
| 1 | `01_fase2_tablas.sql` | 2 — tablas nuevas | `BEGIN/COMMIT` |
| 2 | `02_fase2_indices.sql` | 2 — índices | **FUERA de transacción** (`CONCURRENTLY`) |
| 3 | `03_fase2_datos_base.sql` | 2 — siembra de idiomas | `BEGIN/COMMIT` |
| 4 | `04_fase3_columnas.sql` | 3 — columnas aditivas | `BEGIN/COMMIT` |
| 5 | `05_fase3_triggers.sql` | 3 — triggers y auditoría | `BEGIN/COMMIT` |
| 6 | `06_fase4_backfill_seguro.sql` | 4 — backfill sin inventar procedencia | `BEGIN/COMMIT` |
| 7 | `07_fase5_loinc_tabla.sql` | 5 — tabla LOINC y regla central de prioridad | `BEGIN/COMMIT` |
| 8 | `08_fase5_loinc_indices.sql` | 5 — índices LOINC | **FUERA de transacción** (`CONCURRENTLY`) |
| 9 | `09_fase5_loinc_backfill.sql` | 5 — backfill EN y vista de resolución | `BEGIN/COMMIT` |
| 10 | `10_fase6_dentar.sql` | 6 — campos clínicos DENTAR (solo SQL) | `BEGIN/COMMIT` |
| 11 | `11_fase7_snomed_cie10.sql` | 7 — tag RF2 real de SNOMED | `BEGIN/COMMIT` |
| 12 | `12_fase12_validacion.sql` | 12 — reporte de validación | solo `SELECT` (sin transacción) |
| 13 | `13_fase5b_variantes_es.sql` | 5b — recuperar capas LOINC es-MX/es-AR desde CSV | `BEGIN/COMMIT` |
| 14 | `14_d19_matriz_pendiente.sql` | 12 / 4.3 — reporte para la matriz editorial D-19 | solo `SELECT` (sin transacción) |
| 15 | `15_d19_aprobacion_editorial.sql` | 12 / 4.3 — registro aditivo de la aprobación D-19 | `BEGIN/COMMIT` |
| 16 | `18_fase11_invalidacion_mapeos.sql` | 11 — invalidación D-31 de revisiones D-19 | `BEGIN/COMMIT` |
| 17 | `16_fase12_post_d19.sql` | 12 — validación posterior a D-19 | solo `SELECT` (sin transacción) |
| 18 | `17_fase13_verificacion_final.sql` | 13 — nulabilidad D-36 y estado del corte | solo `SELECT` (sin transacción) |

Ejecutar **en orden**. Los scripts son idempotentes (`IF NOT EXISTS`,
`ON CONFLICT DO NOTHING`) salvo los `UPDATE` de Fase 4, que se repetirán sin
cambiar el resultado.

## Cómo ejecutar

### Desde el VPS como usuario `postgres` (sin clave, peer auth)

```bash
cd /var/www/html/origen.ar/code-api/
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/01_fase2_tablas.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/02_fase2_indices.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/03_fase2_datos_base.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/04_fase3_columnas.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/05_fase3_triggers.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/06_fase4_backfill_seguro.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/07_fase5_loinc_tabla.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/08_fase5_loinc_indices.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/09_fase5_loinc_backfill.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/10_fase6_dentar.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/11_fase7_snomed_cie10.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off -f sql/07_multilingue/12_fase12_validacion.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/13_fase5b_variantes_es.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off -f sql/07_multilingue/14_d19_matriz_pendiente.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/15_d19_aprobacion_editorial.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/18_fase11_invalidacion_mapeos.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off -f sql/07_multilingue/16_fase12_post_d19.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off -f sql/07_multilingue/17_fase13_verificacion_final.sql
```

Tras ejecutar el 13, volver a correr el 12 para que la validación incluya las
capas es-MX/es-AR recién recuperadas. El 14 es de solo lectura: entregó las
filas de la matriz D-19. El 15 registra la aprobación ya decidida por la
autoridad editorial; el 16 y el 17 solo verifican, no cambian estados.

Si tu `pg_hba.conf` usa `md5`/`scram` en localhost en vez de `peer`:

```bash
PGPASSWORD=... psql -h localhost -U postgres -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/01_fase2_tablas.sql
```

### Desde DBeaver-CE

1. Conectarse a la base `origen_codes` con el usuario `postgres`.
2. Abrir cada archivo y ejecutarlo en orden.
3. **Importante** para `02_fase2_indices.sql` y `08_fase5_loinc_indices.sql`:
   desactivar la opción de ejecutar el script dentro de una transacción
   (autocommit activo). PostgreSQL no permite `CREATE INDEX CONCURRENTLY`
   dentro de `BEGIN/COMMIT`.

## Requisitos

- PostgreSQL 14 o superior (`CREATE OR REPLACE TRIGGER`).
- Extensión `pg_trgm` (el script 02 la crea si falta).

## Puntos de control

- Antes de `02_fase2_indices.sql`, verificar que no hay índices inválidos ni
  duplicados con el nombre `uq_*`. Si aparece uno inválido o duplicado, **detener**
  y revisar; no se incluye ningún `DROP INDEX`.
- `os_concept_mapping` ya tiene `review_status` con un `CHECK` propio
  (`draft|reviewed|approved|deprecated`). No se modifica: el estado editorial
  de esa tabla se gestiona en `os_field_review`.
- Fase 4 no marca nada como `approved` ni `official_source`: cuando no hay
  evidencia se deja `unknown`/`unreviewed`/`NULL`, que no es publicable.
- `os_concept_mapping` no tiene columna `language_code`: el evento de auditoría
  registra `language_code='undet'` (cabe en `VARCHAR(10)`), sin inventar idioma.
- `loinc_localized_text` **no** se auditó en Fase 3: se incorpora en Fase 5
  (matriz D-29 de 7 a 8 tablas).
- `source_release='2.83'` está confirmado en `tools/sources/loinc/Loinc.csv`
  (`VersionLastChanged="2.83"`) y en `importar_loinc.sql:2-5`.
- La capa EN se recuperó desde la BD en `09_fase5_loinc_backfill.sql`; las
  capas es-MX/es-AR se recuperaron desde los CSV en `13_fase5b_variantes_es.sql`
  (sin modificar el importador). Ninguna capa se derivó de otra.
- La vista `v_loinc_resolved` aplica la prioridad D-33 y marca conflictos;
  lo que queda `unknown`/`undetermined`/en conflicto NO es publicable.
- La Fase 6 cubre solo la parte SQL: publicar los tres campos clínicos. Queda
  como código (fuera de estos scripts) quitar los literales `'es-AR'` del sync
  y usar `dentar_diagnosis.clinical_name` como `preferred_term` de `dentar-dx`.
- `10_fase6_dentar.sql` solo crea `uq_oct_identity` si no hay duplicados
  preexistentes; si los hay, lo reporta y no borra nada.
- `11_fase7_snomed_cie10.sql` omite el backfill con un NOTICE si
  `sct2.description` no está cargada, en vez de inventar un tag dialectal.
- `12_fase12_validacion.sql` es **solo lectura**: no contiene DDL, DML ni
  meta-comandos de psql (funciona igual en psql y en DBeaver-CE). Un valor
  distinto de cero en una consulta marcada "DEBE SER 0" es un hallazgo a
  revisar; el script NO corrige nada ni aprueba contenido.
- `13_fase5b_variantes_es.sql` usa `COPY ... FROM` **lateral del servidor**
  (SQL puro, sin `\copy`). El usuario `postgres` del servidor debe poder leer
  los dos CSV en `/var/www/html/origen.ar/code-api/tools/sources/loinc/`.
  Recupera 12 campos por variante sin tocar `loinc` ni el importador: las capas
  es-MX y es-AR quedan como filas separadas, con `source_release='2.83'` tomado
  de la cabecera del importador (los CSV de variantes no traen versión) y
  `version_last_changed_normalizada='(sin_version)'`. Nada queda `approved`.
  La carga va **campo por campo en transacciones separadas** (24 `INSERT`):
  imprime progreso y, si se interrumpe, reejecutar no duplica nada.
- `14_d19_matriz_pendiente.sql` es **solo lectura**. Entregó tabla, campo,
  idioma (`'undet'`: `os_concept_mapping` no tiene `language_code`), release,
  fuente, motivo, revisor y fecha para las 419 filas `approved` heredadas.
  Ejecutado: 419 filas de `os_concept_mapping` sin `os_field_review` y
  `aprobadas_sin_os_field_review=419`. La autoridad editorial **aprobó D-19**;
  el script `15` registra esa decisión sin degradar ni cambiar el
  `review_status` heredado de las 419 filas.
- `18_fase11_invalidacion_mapeos.sql` instala el trigger que retira la
  aprobación D-19 de un campo cuando cambia su texto o `source_reference`, con
  evento `approval_invalidated` en la misma transacción (D-31). No borra datos.
- Las fases 8 a 11 (LanguageResolver, API, sitio, dual-read/dual-write) son
  cambios de código, no SQL. Fase 8 quedó implementada en `api/services/`
  (`LanguageResolver`, `LanguageCatalog`, `FieldReviewRepository`,
  `EditorialEvaluator`, `EditorialResult`) y se verifica con
  `php tools/php/verificar_fase8.php`. Fase 9 ya está cableada a los endpoints:
  `Accept-Language`/`lang`, `Vary`, `Content-Language`, publicación solo de
  campos aprobados y `field_languages` por campo; se verifica con
  `php tools/php/verificar_fase9.php`. Fase 10 quedó implementada en el portal:
  tres locales (`es-AR`, `en`, `pt-BR`), buscador que consume `GET /v1/search`
  propagando `lang`/`Accept-Language`, visualización del contrato idiomático de
  Fase 9 y documentación de las rutas reales de CDT/NN; se verifica con
  `php tools/php/verificar_fase10.php`. Fase 11 agregó `MappingReviewReader`,
  `EditorialEvaluator::evaluateUndet()` e `ImporterIdentity`, y se verifica con
  `php tools/php/verificar_fase11.php`.
- `16_fase12_post_d19.sql` y `17_fase13_verificacion_final.sql` son solo
  lectura. El primero confirma cobertura D-19, vigencia de hash y auditoría; el
  segundo comprueba D-36 sin introducir `NOT NULL`. Se verifican con
  `php tools/php/verificar_fase12.php` y `verificar_fase13.php`.
- La Fase 13 queda preparada con `OS_IMPORT_MODE=dual`; el modo `new_only` falla
  explícitamente hasta existir una implementación write-only verificada. No se
  activa corte, no se pide backup y la reversión se documenta por auditoría y
  reproceso en `docs/architecture/corte-controlado-multilingue.md`.

**Sin backup**: decisión explícita del responsable sobre datos de prueba no
reales. Estos scripts son aditivos y no destruyen tablas, columnas ni datos
existentes.
