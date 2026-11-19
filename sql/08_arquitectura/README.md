# Artefactos SQL propuestos (NO EJECUTAR sin aprobación)

Esta carpeta contiene DDL **aditivo** derivado de
`docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md`.

## Estado

- **No ejecutados.** No se han aplicado a `origen_codes` ni a ninguna otra base.
- **No contienen datos inventados.** Los únicos `INSERT` son:
  - registros ya existentes en el código (`DOMAINS`/`DOMAIN_CATALOG`), y
  - tipos de relación leídos de `os_catalog_relation` cuando la tabla existe.
- No crean catálogos DENTAR-IN/PD/EQ ni cargan UVR, productos, registros
  sanitarios, fabricantes ni actores de gobernanza.

## Requisitos antes de ejecutar

1. Aprobación formal de la fase correspondiente (§15.2 y §16 del documento).
2. Backup verificado de `origen_codes` y entorno de prueba separado.
3. Revisión de `review_status`: el cambio de `DEFAULT 'approved'` a `'draft'`
   puede ocultar mapeos creados por el sync hasta que sean aprobados.
4. Rollback documentado. Está prohibido `DROP TABLE`, `DROP COLUMN`,
   `TRUNCATE` y `DELETE` de datos; los scripts solo usan `CREATE`,
   `ADD COLUMN IF NOT EXISTS`, `ALTER COLUMN ... SET DEFAULT`,
   `DROP TRIGGER IF EXISTS` (solo para recrear el mismo trigger) e
   `INSERT ... ON CONFLICT DO NOTHING`.

## Orden propuesto y alineación de numeración

Los nombres de archivo conservan una numeración histórica que **no coincide**
con la del §16 del documento de arquitectura. Al ejecutar, guíese por la columna
"Fase §16", no por el número del nombre de archivo. Los nombres no se renombran
para no romper referencias existentes en `tests/run.php` y en el documento.

| Archivo | Fase §16 | Objetivo |
| --- | --- | --- |
| — | 0 | Documental (ya completada, no requiere SQL) |
| `fase1_infraestructura.sql` | 1 | Registro de dominios y tablas de referencia |
| — | 2 | Conciliar OpenAPI, READMEs y verificadores (no requiere SQL) |
| `fase3_i18n.sql` | 3 | i18n: D-31 y sembrado de `os_catalog_language` |
| `fase3_relaciones_mapeos.sql` | 4 | Extensión de relaciones y mapeos (+ `verificacion_fase4.sql`) |
| `fase4_gobernanza.sql` | 5 | Solicitudes, revisiones, decisiones y auditoría (+ `verificacion_fase5.sql`) |
| `fase5_productos.sql` | 6 | Concepto, producto, presentación e identificadores |
| `fase6_uvr.sql` | 7 | Valoración UVR sin valores cargados |

Cada migración es independiente y está envuelta en `BEGIN`/`COMMIT`. Ejecutar
una por fase, con verificación y backup entre ellas. Los scripts
`verificacion_*.sql` son `BEGIN READ ONLY` / `ROLLBACK`: no escriben.

## Operación de Fase 1

Artefactos: `fase1_infraestructura.sql` (migración), `verificacion_fase1.sql`
(verificación `SELECT`-only) y `fase1_correcion_privilegios.sql` (correctivo,
solo si hace falta). La Fase 1 crea cuatro tablas de referencia en
`public` y siembra dominios, clasificaciones de relación y estados de revisión a
partir de fuentes ya existentes. **No modifica** `os_catalog`, `os_catalog_item`,
`os_catalog_relation`, importadores, API pública ni catálogos publicados.

```bash
# Backup verificado y, si es posible, base de prueba antes de ejecutar.
pg_dump -Fc origen_codes > origen_codes_pre_fase1.dump
pg_restore -l origen_codes_pre_fase1.dump

# Como superusuario de PostgreSQL, desde la raíz del repositorio:
psql -v ON_ERROR_STOP=1 -d origen_codes -f sql/08_arquitectura/fase1_infraestructura.sql
psql -v ON_ERROR_STOP=1 -d origen_codes -f sql/08_arquitectura/verificacion_fase1.sql
```

Criterios de aceptación de la verificación:

- 4 tablas nuevas: `os_domain_registry`, `os_relation_kind`, `os_relation_type`
  y `os_review_state`.
- 12 dominios (3 `full`, 9 `catalog`) con etiquetas iguales a
  `TerminologySearchService::DOMAIN_CATALOG`.
- 7 clasificaciones de relación y 10 estados de revisión; solo `approved` y
  `published` tienen `is_publication_allowed = true`.
- `os_relation_type` se deriva de `os_catalog_relation` (15 tipos esperados),
  sin códigos inventados.
- `os_catalog_relation` queda intacta: **603 filas** (333 de las CDT + 270 del
  Nomenclador Odontológico Nacional de la Fase 9) y 15 tipos distintos.
- `origen_admin` no recibe privilegios sobre estas cuatro tablas.

### Hallazgo operativo: DEFAULT ACL en `public`

`origen_codes` tiene un `DEFAULT PRIVILEGES FOR TABLES postgres` que concede
automáticamente `SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER`
a `origen_admin` sobre **toda tabla nueva** creada en `public` por `postgres`.
Por eso la primera ejecución de la Fase 1 devolvió 4 filas en el apartado 8 de
la verificación, aunque el DDL terminó en `COMMIT`.

La migración ya incluye el `REVOKE` correctivo al final. **Estado en
`origen_codes`: corrección aplicada y reverificada el 2026-11-19; apartado 8 en
0 filas y solo `postgres` como grantee.** Si se aplicó una versión anterior del
archivo en otro entorno, ejecutar una sola vez:

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/fase1_correcion_privilegios.sql
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/verificacion_fase1.sql
```

El apartado 8 debe devolver **0 filas**. No se modifica el `DEFAULT ACL` global
porque afectaría a tablas de otras fases; las fases 4, 6 y 7 deben incluir el
mismo `REVOKE` sobre sus tablas nuevas. Si el apartado 8b muestra otros grantees
además del propietario, retirarlos con el mismo criterio.

## Operación de Fase 3 (§16): i18n

Autorizada el 2026-11-19. Deja sin efecto, para esta fase, el diferimiento M7
del Acta M0 (decisión 16 del §15.2). Artefactos: `fase3_i18n.sql` (migración) y
`verificacion_fase3.sql` (verificación `BEGIN READ ONLY` / `ROLLBACK`).

La migración hace dos cosas y nada más:

1. Instala `trg_ocm_invalidate_fr` para activar **D-31** (mismo cuerpo que
   `sql/07_multilingue/18_fase11_invalidacion_mapeos.sql`).
2. Siembra `os_catalog_language` con un `is_default` y un `is_fallback` por
   catálogo no familiar. El idioma default se deriva del más frecuente en
   `os_catalog_item_version` entre los idiomas activos y seleccionables (D-27,
   D-38); si no hay versiones seleccionables, se usa `es-AR`. El fallback es
   `en` cuando existe contenido en inglés o cuando el default es `es-AR`, y
   `es-AR` en los demás casos. `coverage_status='undetermined'` porque la
   cobertura editorial no está verificada.

No reejecuta los scripts `01`..`15` de `sql/07_multilingue` (ya cargados), no
crea tablas nuevas, no cambia `OS_IMPORT_MODE` (modo efectivo `dual`), no activa
la Fase 13 y no toca importadores, API pública ni catálogos publicados.

```bash
sudo -u postgres pg_dump -Fc origen_codes > origen_codes_pre_fase3.dump
sudo -u postgres pg_restore -l origen_codes_pre_fase3.dump

sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/fase3_i18n.sql
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/verificacion_fase3.sql

# OS_IMPORT_MODE no está en la base: debe estar vacío o ser 'dual'.
sudo -u www-data printenv OS_IMPORT_MODE
```

Criterios de aceptación: trigger `trg_ocm_invalidate_fr` activo; apartado 2 en
**0 filas** (un default y un fallback por catálogo); apartado 3 en **0 filas**
(solo idiomas activos y no `source-only`); apartado 8 en **0 filas** (preferencia
de `es-AR` en empates); `origen_med` conserva `SELECT` sobre
`os_catalog_language`. Si apareciera `origen_admin` en el apartado 6, aplicar el
mismo patrón de `REVOKE` de `fase1_correcion_privilegios.sql` antes de cerrar.

### Hallazgo de la ejecución del 2026-11-19

La primera ejecución insertó 22 filas (11 catálogos × 2 idiomas) y pasó los
apartados 1–7, pero `dentar-an` y `dentar-cl` quedaron con default `en`: esos
catálogos tienen la misma cantidad de versiones `es-AR` y `en` (dos por ítem) y
el desempate original era alfabético (`en` < `es-AR`). La regla fue corregida en
`fase3_i18n.sql` para futuras ejecuciones (en empate gana `es-AR`, D-27). Para la
base ya ejecutada, aplicar el correctivo idempotente:

```bash
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/fase3_correcion_idioma_default.sql
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/verificacion_fase3.sql
```

El correctivo solo intercambia los flags `is_default`/`is_fallback` de `es-AR` y
`en` en los catálogos donde `es-AR` tiene tantas o más versiones seleccionables.
No cambia códigos, no elimina filas y deja `coverage_status='undetermined'`.

**Estado final (2026-11-19): aplicado y reverificado.** `INSERT 0 2` × 4 y
`COMMIT`; `dentar-an` y `dentar-cl` quedaron con `es-AR` default / `en` fallback.
La verificación final devolvió 0 filas en los apartados 2, 3, 4 y 8, 22 filas en
el apartado 5 y `origen_med` como único grantee además del propietario. **Fase 3
cerrada en base.**

## Operación de Fase 4 (§16): relaciones y mapeos generales

Autorizada el 2026-11-19. El nombre `fase3_relaciones_mapeos.sql` conserva la
numeración histórica; en §16 corresponde a la **Fase 4**. Artefactos: migración
`fase3_relaciones_mapeos.sql` y verificación `verificacion_fase4.sql`
(`BEGIN READ ONLY` / `ROLLBACK`). Requiere la Fase 1 ejecutada.

La migración hace cuatro cosas y nada más:

1. Añade 13 columnas a `os_catalog_relation` (`valid_from`, `valid_to`,
   `source_catalog_id`, `source_release_id`, `target_catalog_id`,
   `target_release_id`, `relation_kind`, `mapping_method`, `confidence_level`,
   `reviewed_by`, `reviewed_at`, `license_reference`,
   `inverse_relation_type`), seis constraints y dos índices, sin tocar las
   **603 filas** existentes ni su `CHECK` de 15 tipos.
2. Crea `os_mapping_metadata` y `os_terminology_system_alias`. Esta última se
   siembra solo con alias de `dentar_terminology_system` cuyo código coincide
   exactamente con `os_terminology_system.code`.
3. Cambia el `DEFAULT` de `os_concept_mapping.review_status` a `'draft'`
   (hallazgo 13). **No modifica filas existentes**, pero los mapeos que inserten
   los importadores en el futuro necesitarán aprobación D-19 para publicarse.
4. Revoca `PUBLIC`/`origen_admin` sobre las dos tablas nuevas por el
   `DEFAULT ACL` de `public`, en la misma transacción.

**Decisión 10 del §15.2: aprobada y ya satisfecha en código.**
`CatalogRepository::itemRelations()` ya consulta `os_catalog_relation` y
`tests/run.php` ya lo exige, así que esta fase no cambia código ni navegación.
No se modifica la API pública, los importadores, los catálogos publicados ni
Browse Codes. No se reejecutan los scripts `01`..`15`.

```bash
sudo -u postgres pg_dump -Fc origen_codes > origen_codes_pre_fase4.dump
sudo -u postgres pg_restore -l origen_codes_pre_fase4.dump

sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/fase3_relaciones_mapeos.sql
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/verificacion_fase4.sql
```

Criterios de aceptación: apartado 2 = **13 columnas**; apartado 3 = los seis
constraints y los dos índices; apartado 4 = **603 relaciones / 15 tipos / 0
kinds inválidos / 0 vigencias inválidas**; apartado 5 = las dos tablas nuevas;
apartados 6, 8 y 9 (huérfanos) en **0 filas**; apartado 7 = `'draft'`. Si el
apartado 8 devuelve filas, ejecutar el mismo `REVOKE` del correctivo de Fase 1
amplificado a `os_mapping_metadata` y `os_terminology_system_alias`.

**Estado final (2026-11-19): ejecutada y verificada en base.** La migración
terminó en `COMMIT` (13 columnas, 6 constraints, 2 índices, 2 tablas nuevas y
`REVOKE` aplicado). La verificación devolvió 603 relaciones / 15 tipos, 0 filas
en los apartados 6, 8 y 9, 0 huérfanos y **603 relaciones navegables** (decisión
10), con `column_default = 'draft'`. **Fase 4 cerrada en base.**

## Operación de Fase 5 (§16): gobernanza y auditoría unificadas

Autorizada el 2026-11-19. El nombre `fase4_gobernanza.sql` conserva la numeración
histórica; en §16 corresponde a la **Fase 5**. Artefactos: migración
`fase4_gobernanza.sql` y verificación `verificacion_fase5.sql`
(`BEGIN READ ONLY` / `ROLLBACK`). Requiere la Fase 1 y M1 (`os_admin.app_user`),
ya aplicados.

La migración crea cuatro tablas vacías —`os_governance_request`,
`os_governance_review`, `os_governance_decision` y `os_audit_log`— con defaults
`'draft'`/`'unreviewed'` y `evidence_reference` obligatoria. No siembra filas.

- **Actores reales:** cada tabla incorpora una columna `<nombre>_user_id BIGINT`
  que referencia `os_admin.app_user(id)`. Los campos textuales históricos se
  conservan. El trigger toma `app.actor_id` (el mismo setting que D-31) cuando
  la aplicación lo envía; si no, queda `NULL` y usa el rol de base como
  procedencia.
- **Auditoría append-only:** `trg_os_audit_log_immutable` impide `UPDATE` y
  `DELETE` sobre `os_audit_log`, con el mismo patrón que
  `os_admin.audit_log` en M1. Los otros tres triggers registran altas, cambios
  y bajas de solicitudes, revisiones y decisiones.
- **Privilegios:** `REVOKE` de `PUBLIC`/`origen_admin` sobre las cuatro tablas
  nuevas por el `DEFAULT ACL` de `public`. No se otorga escritura a ningún rol
  de aplicación: conectar el panel a estas tablas requiere autorización nueva.
- No modifica `os_admin`, importadores, API pública, catálogos publicados ni
  Browse Codes. No reejecuta los scripts `01`..`15`.

```bash
sudo -u postgres pg_dump -Fc origen_codes > origen_codes_pre_fase5.dump
sudo -u postgres pg_restore -l origen_codes_pre_fase5.dump

sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/fase4_gobernanza.sql
sudo -u postgres psql -v ON_ERROR_STOP=1 -d origen_codes \
  -f sql/08_arquitectura/verificacion_fase5.sql
```

Criterios de aceptación: apartado 2 = 4 tablas; apartados 3 y 4 = 4 columnas y
4 FK a `os_admin.app_user`; apartado 5 = 4 triggers activos (`O`); apartado 6 =
`'draft'`/`'unreviewed'`; apartado 7 = `NO`; apartado 8 = 0 filas; apartado 9 =
0 filas en las cuatro tablas; apartado 10 = 603 relaciones, 22 idiomas por
catálogo y los usuarios `os_admin` intactos.

## Backup y rollback por fase

Antes de cada fase: `pg_dump -Fc origen_codes > origen_codes_pre_faseN.dump` y
verificar el dump (`pg_restore -l`). El rollback principal es **restaurar ese
dump**; es la única vía que revierte también `ALTER COLUMN ... SET DEFAULT` y
cualquier dato creado por los `INSERT`.

Si se prefiere revertir solo los objetos de una fase, ejecutar **en orden
inverso** las operaciones a continuación, en una transacción separada y revisada (estas
sentencias no forman parte de los archivos forward). La columna "Fase" usa la
numeración histórica de los archivos; ver la tabla de alineación más arriba:

| Fase | Reversión manual (en orden inverso) |
| --- | --- |
| 3 (§16, i18n) | `DROP TRIGGER trg_ocm_invalidate_fr` y rellenar `os_catalog_language` desde el dump previo (solo si se quiere revertir; la vía principal es restaurar el dump). No crear ni eliminar tablas. |
| 6 | `DROP TRIGGER trg_os_uvr_valuation_eligible`, `DROP VIEW v_os_uvr_valuation_total`, `DROP FUNCTION os_uvr_assert_eligible_service()`, tablas `os_uvr_geo_index`, `os_uvr_conversion`, `os_uvr_component`, `os_uvr_valuation`, `os_uvr_eligible_catalog`. |
| 5 | Tablas `os_regulatory_records`, `os_product_manufacturer`, `os_product_identifiers`, `os_product_presentation`, `os_product`, `os_concept`, `os_manufacturer`, más los catálogos de tipos `os_product_identifier_type` y `os_manufacturer_role`. |
| 4 (§16 = Fase 5 gobernanza) | Triggers `trg_os_governance_*`, `trg_os_audit_log_immutable`, funciones `os_governance_audit_trigger()` y `os_governance_audit_immutable()`, tablas `os_audit_log`, `os_governance_decision`, `os_governance_review`, `os_governance_request`. La vía principal es restaurar el dump. |
| 3 (§16 = Fase 4 relaciones) | `ALTER TABLE os_concept_mapping ALTER COLUMN review_status SET DEFAULT 'approved'`; tablas `os_terminology_system_alias`, `os_mapping_metadata`; quitar columnas y constraints `fk_ocr_*`/`ck_ocr_validity` de `os_catalog_relation`. La vía principal es restaurar el dump. |
| 1 | Tablas `os_review_state`, `os_relation_type`, `os_relation_kind`, `os_domain_registry`. |

Si una fase posterior depende de una anterior, revertir primero la posterior.
Después de cualquier rollback, repetir las consultas de verificación de la fase
y confirmar que `os_catalog_relation` conserva sus 603 filas y 15 tipos.
