# Dry-run local · DENTAR-AN, DENTAR-CL y relaciones CDT

Generado sin ejecutar SQL ni conectarse a la base. No se modificaron esquemas,
tablas ni datos de PostgreSQL. Todo lo producido queda en `docs/dentar/generado/`.

## Archivos generados

- `dentar-an-candidatos.csv`: 624 conceptos anatómicos.
- `dentar-cl-candidatos.csv`: 218 conceptos clínicos.
- `dentar-an-cl-propuerto.sql`: alta editorial y publicación en `os_*`.
- `dentar-cdt-relaciones-propuerto.sql`: tabla nueva de relaciones, identificadores CDT y las 333 relaciones.
- `RESUMEN_AN_CL.md`: este archivo.

## Fuentes realmente utilizadas

- SNOMED CT Argentina Snapshot `2026-08-20` (RF2), descripciones activas preferidas en `es` y `en`.
- Relaciones `is-a` activas del mismo Snapshot para el cierre anatómico.
- Refsets simples reales: DX `398711000221107`, PR `399211000221109`, SUMAR `371191000221103`.
- `tools/sources/snomed-dental/General Dentistry.sql` sólo como lista semilla de 224 conceptos; sus términos ingleses no se publican.
- `dentar-pr-cdt-2025.csv` y `dentar-pr-cdt-relaciones.csv` para los identificadores y relaciones CDT.

## Reglas DENTAR-AN

1. Semillas anatómicas auditadas: `4335006`, `38199008`, `48077000`, `48477009`, `49460000`, `53620006`, `74262004`, `90228003`, `245643006`, `245775004`, `272661000`, `385294005`.
2. Se tomó el cierre de descendientes `is-a` activos más la semilla: 1158 conceptos con descripción preferida.
3. Se excluyeron: como_un_todo=533 fetal_o_embrionario=2; 1 concepto coincide en dos reglas, por lo que las exclusiones únicas son 534.
4. Conjunto final: 1158 − 534 = **624** conceptos, `DNT-AN-000001`…`DNT-AN-000624`, categoría `CAT-AN`, tipo `anatomy`.
5. Todas las filas tienen término preferido `es` y sinónimo `en` del RF2; no se tradujeron términos.

## Reglas DENTAR-CL

1. Los 224 conceptos del paquete dental se clasificaron por raíz semántica RF2.
2. Se incluyeron 201 hallazgos clínicos, 13 situaciones/hallazgos sin raíz resoluble y 4 caries morfológicas.
3. Se excluyeron 5 estructuras dentales porque ya pertenecen a DENTAR-AN y 1 procedimiento (`38592005`) porque permanece en DENTAR-PR.
4. Conjunto final: **218** conceptos, `DNT-CL-000001`…`DNT-CL-000218`, categoría `CAT-CL`, tipo `clinical_finding`.
5. `SNOMED-CT` es obligatorio en ambos catálogos; no hay CIE-10, Nomenclador ni CDT en AN/CL.

## Duplicados y solapes

- SCTID duplicados entre AN y CL: **0**.
- Las 5 estructuras dentales del paquete quedan sólo en AN.
- Las 4 caries morfológicas quedan sólo en CL.
- `Evaluación` sigue en DENTAR-PR; no se duplica en CL.

## Relaciones CDT

- Relaciones: **333** filas, **303** pares únicos, **15** tipos.
- Campos de origen observados: `notes`, `procedure`.
- Tabla propuesta: `os_catalog_relation`, con `source_system_code`, `source_field`, `source_value`, `context_text`, `source_cdt_id`, `review_status` y `provenance`.
- Se conservan los 15 tipos literales: `alternate_benefit`, `billed_in_conjunction_with`, `concurrent_to`, `denied_as_integral`, `frequency_limitations`, `integral_to`, `interchangeable_with`, `not_paid_separately`, `not_to_be_used_with`, `paid_as_code`, `procedure_code_not_used_for`, `refer_to_details`, `referencia_literal`, `shares_frequency_limitation_with`, `used_in_combination_with`.
- Se agregan 805 identificadores `CDT-2025` y sus mapeos para que los códigos sean navegables.
- Se agrega el alias `NOMENCLADOR-AR` junto al histórico `NOMENCLADOR_AR`, sin borrar el original.

## Cambios de esquema propuestos

- Registrar `dentar-an` y `dentar-cl` en `dentar_catalog` y `os_catalog`.
- Ampliar la `CHECK` de `dentar_concept.concept_type` con `anatomy` y `clinical_finding`.
- Crear `os_catalog_relation`; no reutilizar `os_concept_mapping` porque aplana los 15 tipos a `related`.
- Actualizar `dentar_catalog_id()` para reconocer los cuatro códigos activos.

## Pendiente posterior a la revisión

- Autorización explícita para ejecutar DDL y cargas en entorno controlado.
- Actualizar `tools/php/import_dentar_csv.php` y `sync_dentar_to_os.sql` si se quiere que el flujo estándar también cubra AN/CL.
- Integrar `CatalogRepository::itemRelations()` con `os_catalog_relation` para que las relaciones CDT sean clicables en el portal.
- Validar en VPS los recuentos y la navegación de relaciones.

## Estado

No se ejecutó `psql`, ni el importador, ni `sync_dentar_to_os.sql`; no hubo commit, push ni deploy.
Validación local: CSV parseables, DNT únicos, SCTID únicos por catálogo y sin solape AN/CL, relaciones con destino resuelto y tipos/campos consistentes con la fuente.
