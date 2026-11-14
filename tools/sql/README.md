# Scripts SQL manuales

Scripts para ejecutar **a mano** desde `psql`, DBeaver o pgAdmin. No forman
parte del arranque de la aplicación ni se ejecutan desde PHP.

## Índice

| Archivo | Cuándo usarlo | Modifica datos |
| --- | --- | --- |
| `snomed/01_esquema.sql` | Antes de una carga masiva de SNOMED CT. Crea el esquema `sct2`. | Sí (sólo `sct2`) |
| `snomed/02_carga.sql` | **Generado** por `tools/php/generar_carga_snomed.php`. Un `COPY` por archivo RF2. | Sí |
| `snomed/03_postcarga.sql` | Después de `02`. Índices, derivadas, vistas y publicación en `public`. | Sí |
| `snomed/04_codigos_opcional.sql` | Opcional, después de `03`. Publica los refsets filtrables en `public.snomed_refset_member`. | Sí |
| `snomed/05_map_excel.sql` | Opcional, después de `03`. Carga los mapeos NBU y GTIN generados con `tools/php/convertir_excel_maps.php`. | Sí |
| `snomed/99_verificacion.sql` | Después de `03` (y de `04`/`05` si se usaron). Conteos, integridad, publicación y artefactos opcionales. | No |
| `verify_snomed_import.sql` | Después de usar el importador PHP por lotes. Auditoría de volúmenes e integridad. | No |
| `post_import_maintenance.sql` | Después de una carga masiva, para actualizar estadísticas del planner. | No (sólo `ANALYZE` / `VACUUM`) |

El detalle del flujo nuevo está en [`snomed/README.md`](snomed/README.md).

## Dos formas de importar SNOMED CT

| Vía | Cuándo usarla | Scripts |
| --- | --- | --- |
| Carga masiva con `COPY` | Release completa (millones de filas) o actualización trimestral. | `snomed/01` → generar `snomed/02` → `snomed/03` → [`snomed/04` opcional] → [`snomed/05` opcional] → `snomed/99` |
| Importador PHP por lotes | Pruebas, cargas parciales, archivos `Full` sueltos o entornos sin acceso al sistema de archivos del servidor. | `tools/php/import_snomed_rf2.php` + `verify_snomed_import.sql` |

Ambas vías publican en las mismas tablas (`snomed_concepts`,
`snomed_descriptions`, `snomed_relationships`), así que la API no cambia.

La vía `COPY` es la recomendada para producción: es varias veces más rápida,
valida la cabecera RF2 antes de tocar la base y deja los índices para el final.

## Convenciones

- Todos los scripts son idempotentes y de solo lectura, salvo que se indique lo
  contrario en el encabezado.
- No incluyen comandos meta de `psql` (por ejemplo `\timing`), para que también
  funcionen en DBeaver. Las excepciones son `snomed/02_carga.sql` generado con
  `--cliente` y `snomed/05_map_excel.sql`, que usan `\copy` y requieren
  `psql -f`. `05` trae un apéndice con `COPY` para ejecutarlo desde DBeaver si
  los TSV están en el servidor.
- `VACUUM` no puede ejecutarse dentro de una transacción: en DBeaver activar
  *autocommit* antes de correr `post_import_maintenance.sql`.
- El esquema de referencia es `sql/design.sql` en la raíz del proyecto.

## Flujo recomendado tras una importación RF2 con el importador PHP

1. `php tools/php/import_snomed_rf2.php <archivo> concept`
2. `php tools/php/import_snomed_rf2.php <archivo> description`
3. `php tools/php/import_snomed_rf2.php <archivo> relationship`
4. `psql -d origen_salud -f tools/sql/verify_snomed_import.sql`
5. `psql -d origen_salud -f tools/sql/post_import_maintenance.sql`
