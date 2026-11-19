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
| — | 3 | i18n: `os_catalog_language`, D-31 y corte `OS_IMPORT_MODE` (sin artefacto aquí) |
| `fase3_relaciones_mapeos.sql` | 4 | Extensión de relaciones y mapeos |
| `fase4_gobernanza.sql` | 5 | Solicitudes, revisiones, decisiones y auditoría |
| `fase5_productos.sql` | 6 | Concepto, producto, presentación e identificadores |
| `fase6_uvr.sql` | 7 | Valoración UVR sin valores cargados |

Cada migración es independiente y está envuelta en `BEGIN`/`COMMIT`. Ejecutar
una por fase, con verificación y backup entre ellas. Los scripts
`verificacion_*.sql` son `BEGIN READ ONLY` / `ROLLBACK`: no escriben.

## Operación de Fase 1

Artefactos: `fase1_infraestructura.sql` (migración) y `verificacion_fase1.sql`
(verificación `SELECT`-only). La Fase 1 crea cuatro tablas de referencia en
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
- `os_catalog_relation` queda intacta: 333 filas y 15 tipos distintos.
- `origen_admin` no recibe privilegios sobre estas cuatro tablas.

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
| 6 | `DROP TRIGGER trg_os_uvr_valuation_eligible`, `DROP VIEW v_os_uvr_valuation_total`, `DROP FUNCTION os_uvr_assert_eligible_service()`, tablas `os_uvr_geo_index`, `os_uvr_conversion`, `os_uvr_component`, `os_uvr_valuation`, `os_uvr_eligible_catalog`. |
| 5 | Tablas `os_regulatory_records`, `os_product_manufacturer`, `os_product_identifiers`, `os_product_presentation`, `os_product`, `os_concept`, `os_manufacturer`, más los catálogos de tipos `os_product_identifier_type` y `os_manufacturer_role`. |
| 4 | Triggers `trg_os_governance_*`, función `os_governance_audit_trigger()`, tablas `os_audit_log`, `os_governance_decision`, `os_governance_review`, `os_governance_request`. |
| 3 | `ALTER TABLE os_concept_mapping ALTER COLUMN review_status SET DEFAULT 'approved'`; tablas `os_terminology_system_alias`, `os_mapping_metadata`; quitar columnas y constraints `fk_ocr_*`/`ck_ocr_validity` de `os_catalog_relation`. |
| 1 | Tablas `os_review_state`, `os_relation_type`, `os_relation_kind`, `os_domain_registry`. |

Si una fase posterior depende de una anterior, revertir primero la posterior.
Después de cualquier rollback, repetir las consultas de verificación de la fase
y confirmar que `os_catalog_relation` conserva sus 333 filas y 15 tipos.
