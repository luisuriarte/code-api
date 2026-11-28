# Verificación de OFTAR-PR — conciliación y equivalencias

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** Aprobada como base técnica para iniciar la implementación controlada (no autoriza ejecución; NO equivale a aprobación clínica).

**Convención:** [H] hecho verificado en repositorio/documentación Auditable · [I] inferencia · [P] propuesta.

Alcance documental: sin `psql` ni variables `DB_*`/`PG*`; no se consultó PostgreSQL, no se ejecutaron SQL, migraciones, seeds, importadores ni pruebas. El detalle completo de cada par está en `aprobacion-conciliacion-oftar-pr.md`; aquí solo se consolida lo verificable.

## 1. Consolidación verificada

[H] Núcleo NN 2025 = 154 códigos; CAO = 143; Regional NOA = 136. La matriz `docs/audit/matriz-conciliacion-clinica-oftar-pr.csv` tiene 433 filas, todas con `estado=propuesta_no_publicada`, `equivalencia_clinica_publicada=NO`, `equivalencia_facturacion_publicada=NO` e `importe_migrado=NO`.

[H] Clases declaradas: 38 exactas propuestas, 165 aproximadas/parciales, 2 más amplio, 1 más específico, 30 relacionados, 22 diferentes, 169 inciertas y 6 sin correspondencia; suman 433. «Exacta» es clase documental de la matriz, no valor de base de datos.

[H] Dictamen documental: 13 pares / 26 filas tienen justificación suficiente para **proponer** equivalencia; 6 pares / 12 filas requieren degradación o corrección: L35/L215 `306011`↔`460151` (sin ancla), L55/L255 `306031`↔`460213` (láser femto: modalidad/alcance), L138/L284 `306116`↔`461302` (incorrecto; el texto apunta a `461306`; par correcto propuesto `306113`↔`461302` y `306116`↔`461306`), L151/L179 `306129`↔`460111` (candidato textual `460144`), L168/L306 `460014`↔`425008` (informes clínicos, no incorporable) y L194/L310 `460127`↔`305004` (instrumento digital no declarado en Regional). Corrección obligatoria de la justificación RFG: las descripciones dicen «no incluye fluoresceína»; la base escrita «con fluoresceína» es incorrecta.

[H] Hay 48 registros CAO/Regional sin cobertura NN: 18 atributos, 8 variantes, 6 duplicados, 3 relacionados, 3 candidatos nuevos, 2 no incorporables y 8 pendientes. Candidatos a concepto canónico nuevo: CAO `460106` (RG digital unilateral sin descartables), Regional `305003` (Autofluorescencia bilateral) y Regional `305041` (Test de sensibilidad al contraste bilateral).

[P] Separación obligatoria por fila: código de origen, descripción original, fuente, edición/período, concepto canónico OFTAR, tipo de relación, evidencia, estado de revisión y responsable de aprobación. Equivalencia clínica ≠ equivalencia de facturación; ningún par con solo evaluación documental se marca clínicamente aprobado.

## 2. Vocabulario persistible

[H] El `CHECK` real de `os_concept_mapping.mapping_type` es `equivalent|narrower|broader|related|unmatched` (`sql/02_catalogs/origen_catalog_engine.sql:125-126`; confirmado en `tools/generate_unified_catalog_engine_sql.py:360-361`). No existe `exact`. [I] La palabra «exacta» de la matriz clínica es una etiqueta documental, NO un valor de base de datos. [H] El §7 del documento rector ya fue corregido a este vocabulario; la discrepancia histórica quedó cerrada en `inconsistencias-resueltas-oftar.md`. [P] Persistir la equivalencia como `mapping_type='equivalent'`.

[H] `os_concept_mapping.review_status` = `draft|reviewed|approved|deprecated`; la versión de concepto y la revisión de campo/traducción no tienen `CHECK` y usan default `unknown` (los scripts OFTAR asignan `approved`); `os_catalog_release.status` = `draft|review|published|deprecated`. No existen `pending_review` ni `rejected` en esas columnas. `rejected` existe solo en `os_oftar_nomenclador_match.review_status` con `CHECK(proposed|approved|rejected)` (`sql/03_oftar/nomencladores_oftar_mapping.sql:45-46`).

## 3. Tabla de verificación

| Afirmación | Evidencia | Resultado | Riesgo |
|---|---|---|---|
| 154/143/136 códigos y 433 filas no publicadas | `aprobacion-conciliacion-oftar-pr.md:13`; cabecera y filas de la matriz | verificado | Publicar una worklist como verdad de producción |
| Las 8 clases suman 433 | `especificacion-definitiva-reconstruccion-oftar.md` §8 | verificado | Mezclar clases documentales con valores de `CHECK` |
| 13 pares / 26 filas proponibles | `aprobacion-conciliacion-oftar-pr.md:17,27-41` | pendiente de acta | Aprobación clínica sin firma ni dos revisores |
| 6 pares / 12 filas a degradar o corregir; RFG | `aprobacion-conciliacion-oftar-pr.md:32,45-52` | pendiente de acta | Persistir pares erróneos o la frase «con fluoresceína» |
| 48 registros sin cobertura y 3 candidatos nuevos | `aprobacion-conciliacion-oftar-pr.md:91-112` | verificado | Altas automáticas sin decisión editorial |
| Campos separados; clínica ≠ facturación | columnas de la matriz; `especificacion-definitiva-reconstruccion-oftar.md` §12 y §15.3 | verificado | Pérdida de trazabilidad o cruce de equivalencias |
| `mapping_type` real y etiqueta «exacta» | `origen_catalog_engine.sql:125-126`; generador `:360-361` | verificado | Intentar persistir `exact` o valores inexistentes |
| Estados de revisión y publicación | `origen_catalog_engine.sql:130`; `04_fase3_columnas.sql:27`; `01_fase2_tablas.sql:70,131`; `nomencladores_oftar_mapping.sql:45-46` | verificado | Inventar `pending_review` o `rejected` |
| Sin PostgreSQL ni pruebas ejecutadas | alcance documental de este informe | verificado | Afirmar validación en base o ejecución de pruebas |

[P] Este informe consolida la base técnica para corregir la documentación y preparar, solo tras autorización, la implementación controlada. No autoriza ejecución, publicación ni aprobación clínica.
