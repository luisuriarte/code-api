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

## Orden propuesto

| Archivo | Fase del documento |
| --- | --- |
| `fase1_infraestructura.sql` | 1 — registro de dominios y tablas de referencia |
| `fase3_relaciones_mapeos.sql` | 3 — extensión de relaciones y mapeos |
| `fase4_gobernanza.sql` | 4 — solicitudes, revisiones, decisiones y auditoría |
| `fase5_productos.sql` | 5 — concepto, producto, presentación e identificadores |
| `fase6_uvr.sql` | 6 — valoración UVR sin valores cargados |

Cada archivo es independiente y está envuelto en `BEGIN`/`COMMIT`. Ejecutar
uno por fase, con verificación y backup entre ellos.

## Backup y rollback por fase

Antes de cada fase: `pg_dump -Fc origen_codes > origen_codes_pre_faseN.dump` y
verificar el dump (`pg_restore -l`). El rollback principal es **restaurar ese
dump**; es la única vía que revierte también `ALTER COLUMN ... SET DEFAULT` y
cualquier dato creado por los `INSERT`.

Si se prefiere revertir solo los objetos de una fase, ejecutar **en orden
inverso** las operaciones a continuación, en una transacción separada y revisada (estas
sentencias no forman parte de los archivos forward):

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
