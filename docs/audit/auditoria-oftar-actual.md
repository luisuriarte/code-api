# Auditoría actual de OFTAR

**Fecha:** 2026-11-28  
**Alcance:** lectura y análisis del repositorio. Sin acceso a VPS/PostgreSQL. Sin cambios en seeds, SQL, tests ni base de datos.  
**Etapa:** Diagnóstico. La implementación queda condicionada a aprobación explícita.

---

## 1. Metodología y convención de evidencia

Se inspeccionaron los artefactos reales del repositorio, no sus nombres históricos. Las afirmaciones se clasifican así:

- **[H] Hecho verificado:** se puede demostrar con un archivo leído o un conteo reproducible local.
- **[I] Inferencia:** consecuencia lógica de hechos verificados; requiere confirmación en PostgreSQL cuando depende de datos cargados.
- **[P] Propuesta:** decisión sugerida para la reconstrucción; **no implementada**.

Donde no hay acceso a PostgreSQL se dice expresamente **estado desconocido en producción**.

---

## 2. Cadena de dependencias del motor

La fuente de verdad no es un único archivo:

1. `sql/02_catalogs/origen_catalog_engine.sql` crea el núcleo `os_catalog*` y `os_concept_mapping`.
2. `sql/07_multilingue/01_fase2_tablas.sql` crea `os_catalog_language`, `os_localized_text`, `os_field_review` y `os_translation_review`.
3. `sql/07_multilingue/04_fase3_columnas.sql` agrega a `os_catalog_item_version` las columnas `source_language_code`, `language_evidence`, `provenance`, `review_status`, `source_reference`, `content_hash`, `valid_from`, etc.
4. `sql/07_multilingue/05_fase3_triggers.sql` calcula hashes y audita cambios.
5. `sql/03_oftar/oftar_family.sql` y `oftar_core.sql` crean la familia OFTAR y sus modelos editoriales.
6. `sql/08_arquitectura/categorias_clinicas.sql` agrega la taxonomía `CLIN-*` sin renombrar `os_catalog_category`.
7. `api/services/CatalogEngineService.php` y `TerminologySearchService.php` consumen ese esquema y definen el contrato público.

**[H]** Los importadores OFTAR insertan columnas (`provenance`, `review_status`, `source_reference`, etc.) que no existen en el motor base; por eso la cadena anterior es obligatoria.  
**[I]** Si alguna migración de la cadena no fue aplicada en una base, los importadores fallarían o degradarían su gobernanza.

---

## 3. Estado real de la familia

| Elemento | Valor verificado | Evidencia |
|---|---|---|
| Dominio de búsqueda | `oftar` (único) | `TerminologySearchService.php:49`, `:52-68`; `oftar_domain_search.sql:9-15` |
| Catálogos activos | `oftar-pr`, `oftar-dx` | `oftar_family.sql:54-73`; `oftar_core.sql:138-156` |
| Prefijos | `OFT-PR`, `OFT-DX` | `oftar_family.sql:57-63`; `renombrar_codigos_oftar.sql:87-118` |
| Categorías internas | 12: 4 raíces y 8 hojas en PR; 1 en DX | `oftar_core.sql:86-101`; `oftar_categorias.csv:2-14` |
| Idiomas declarados | `es-AR` default/fallback, `en` partial, `pt-BR` planned | `oftar_core.sql:167-185` |
| UVR | Solo el ejemplo editorial de OCT en `uvr_ejemplo_oct_oftar_pr_u7b.sql`; ninguna en OFTAR-DX | `oftar_core.sql:345`; `sync_oftar_dx_to_os.sql:17`; `UvrPublicRepository.php:37,96-107` |
| Vista de búsqueda | Solo versiones `approved` | `oftar_domain_search.sql:45-80` |

**[H]** No existen columnas `name_en`/`name_pt`; la localización vive en `os_localized_text` / archivos YAML y en `oftar_category_version(language, name, description)` para categorías editoriales.

---

## 4. Hallazgos detallados

### H-01 · Rutas legacy rotas

**[H]** `tools/generate_nomencladores_oftalmologicos_sql.py:4-6,52,59,73` y los encabezados de `sql/03_oftar/nomenclador_oftalmologico_cao.sql:11` y `..._regional.sql:11` citan `tools/sources/oftar/cao.csv` y `tools/sources/oftar/oftal2.csv`. Esas rutas no existen.

**[H]** Las rutas reales son:

- `tools/sources/oftalmologico/Concejo_Argentino_de_Oftalmologia-cao.csv`
- `tools/sources/oftalmologico/Nomenclador-Oftalmologico-Regional-Abril-2026.csv`
- `tools/sources/oftalmologico/oftar/importar_cie10_dx.sql`
- `tools/sources/oftalmologico/oftar/oftar_categorias.csv`

**[H]** `php tests/run.php` produce `FALLOS (4 de 4088)` y el warning `file_get_contents(.../tools/sources/oftar/importar_cie10_dx.sql): Failed to open stream` en `tests/run.php:3424`. Las cuatro verificaciones afectadas son las que validan identidad externa, importador CIE-10, no creación de UVR y prefijo `OFT-DX`.

**[I]** Regenerar los SQL con el generador actual probablemente fallaría por falta de fuentes; el problema es de configuración de rutas, no de contenido clínico.

**[P]** Corregir rutas y encabezados, y actualizar `tests/run.php`, **solo después** de aprobación de implementación.

---

### H-02 · Posible descalce entre `target_code` y `permanent_code`

**[H]** El generador siembra `os_oftar_nomenclador_match.target_code` con códigos de 6 dígitos del Nomenclador Nacional, p. ej. `('460105', '306002', 'oftar-pr')` (`nomenclador_oftalmologico_cao.sql`, bloque de propuestas; verificado por conteo de 91 filas).

**[H]** `importar_nomenclador_oftar_pr.sql:99-118` asigna códigos permanentes `OFT-PR-NNNNNN`, y `oftar_assert_catalog_code()` los valida con regex `^OFT-PR-[0-9]{6}$` (`oftar_family.sql:120-125`).

**[H]** `aprobar_mapeo_nomencladores_oftar.sql:163-165` hace `JOIN os_catalog_item tgt ON tgt.catalog_id = tc.id AND tgt.permanent_code = m.target_code` para `tc.code = 'oftar-pr'`.

**[I]** Si la tabla de mapeo conserva los 91 valores de 6 dígitos, el join no encuentra ítems y ninguna relación se publica. El efecto sería silencioso: las propuestas quedan `approved` pero sin identificadores ni relaciones navegables.

**[P]** La reconstrucción debe resolver el destino por `os_catalog_identifier` (`system_name='NOMENCLADOR-AR'`, `value=target_code`) y escribir en la tabla de mapeo el `permanent_code` `OFT-PR-NNNNNN` resultante. No reutilizar retirados.

---

### H-03 · Sentencias destructivas en SQL generado

**[H]** `tools/generate_nomencladores_oftalmologicos_sql.py:248` emite `DELETE FROM public.os_source_oftar_*` antes de insertar el espejo. Los SQL generados lo reproducen (`nomenclador_oftalmologico_cao.sql:79`, `..._regional.sql:79`).

**[I]** Es idempotente, pero contradice la regla actual de no `DELETE`. Una reconstrucción aprobada debe sustituirlo por `INSERT ... ON CONFLICT (codigo) DO UPDATE` y control de hash, sin borrar filas.

**[P]** Mantener el espejo como tabla de origen inmutable por release; nunca sobrescribir una fila publicada sin nueva versión.

---

### H-04 · Cobertura de fuentes

**[H]** Conteos locales reproducibles:

| Fuente | Filas | Código único | Categorías | UAE |
|---|---:|---:|---:|---|
| CAO | 143 | 143 | 12 | `Concejo_Argentino_de_Oftalmologia-cao.csv` |
| Regional NOA | 136 | 136 | 3 grupos / 9 subgrupos | `Nomenclador-Oftalmologico-Regional-Abril-2026.csv` |
| NN 2025 OFTALMOLOGIA | 154 | 154 | implícita en descripción | `fuente_nomenclador_oftar_pr.sql` |
| CIE-10-ES 2026 H00-H59 | 2.661 | 2.661 | capítulo H | `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv` |
| ICD-10-CM 2027 H exclusivos | 17 | 17 | capítulo H | `2027-code-descriptions-in-tabular-order.zip` |
| ICD-10-PCS 2026 `08*` | 1.212 | 1.212 | procedimientos | `Procedimientos_Tabla_Referencia_CIE10ES_2026.csv` |

**[H]** La coincidencia textual exacta normalizada CAO ↔ NN es de 91 pares; Regional ↔ NN es 0.

**[I]** La cobertura esperada de OFTAR-PR es de 154 ítems; la de OFTAR-DX es de 2.678 (2.661 del CSV español + 17 exclusivos en inglés). Production real: **desconocida en esta auditoría**.

**[P]** No importar CIE-10-PCS ni SNOMED completos como códigos propios; usarlos como mapeos opcionales sujetos a revisión.

---

### H-05 · Equivalencia vs. referencia

**[H]** `nomencladores_oftar_mapping.sql:38-62` define `match_basis IN ('texto_identico_normalizado','revision_manual')` y estados `proposed|approved|rejected`.

**[H]** El propio script de aprobación indica explícitamente `referencia literal gobernada, sin juicio de equivalencia clínica` (`aprobar_mapeo_nomencladores_oftar.sql:240-248`).

**[I]** La coincidencia de texto es una base objetiva para proponer, no una equivalencia clínica ni de facturación. Los importes de CAO/Regional son datos económicos de la fuente y **no se migraron**.

**[P]** La matriz `matriz-equivalencias-oftar-pr.csv` separa `candidato_textual`, `equivalencia_clinica` y `equivalencia_facturacion`; todas las equivalencias clínicas/facturación figuran como `NO_DECLARADA`.

---

### H-06 · Categoría del concepto vs. catálogo

**[H]** `categorias_clinicas.sql:1-8` declara que no renombra `os_catalog_category` ni cambia el catálogo de origen.

**[H]** `CatalogEngineService.php:109-123`, `:155-174` y `:587-592` mantienen `category` y agregan `clinical_category` con precedencia: asignación administrativa → mapa de categoría fuente → default del catálogo.

**[I]** Un mismo código puede pertenecer al catálogo `oftar-pr` y tener categoría clínica `CLIN-EST`; son ejes distintos.

**[P]** Conservar el contrato; no convertir `CLIN-*` en catálogos ni en dominios.

---

### H-07 · Gobernanza de textos

**[H]** Los importadores CAO/Regional y CIE-10 crean `os_field_review` en estado `unknown`; `aprobar_preferred_term_oftar_dx.sql` y `aprobar_mapeo_nomencladores_oftar.sql` aprueban solo `preferred_term` con guarda de hash. `definition` y `external_display` quedan pendientes o NULL.

**[H]** `sync_oftar_dx_to_os.sql:11-17` documenta 17 códigos exclusivos en `en` y `H01.8` en `es-AR`, sin traducción inventada.

**[P]** Mantener dos revisiones humanas: una editorial (textos) y una de correspondencias (pares). Ninguna aprobación automática por coincidencia textual.

---

### H-08 · Estado de producción no verificable desde el repositorio

**[H]** No hay volcados ni resultados de `psql` adjuntos que confirmen:

- número real de ítems en `oftar-pr` y `oftar-dx`;
- si `catalogos_gestion_gobernada.sql` fue ejecutado;
- si `os_oftar_nomenclador_match.target_code` contiene 6 dígitos o `OFT-PR-NNNNNN`;
- si los 91 pares CAO están `proposed`, `approved` o `rejected`;
- si `v_oftar_search_catalog` está accesible para `origen_api`.

**[I]** El repositorio describe la intención; la base describe la realidad. Sin consulta de solo lectura no se puede cerrar la cobertura publicada.

---

## 5. Verificaciones pendientes para el usuario (solo lectura)

Ejecutar en `origen_codes`; no modifican datos.

```sql
BEGIN READ ONLY;

-- A. Cobertura por catálogo OFTAR
SELECT c.code, count(i.id) AS items,
       count(*) FILTER (WHERE i.status = 'active') AS activos
  FROM os_catalog c
  LEFT JOIN os_catalog_item i ON i.catalog_id = c.id
 WHERE c.family_code = 'oftar'
 GROUP BY c.code ORDER BY c.code;

-- B. Prefijos reales (deben ser OFT-PR / OFT-DX)
SELECT c.code, o.code_prefix, count(i.id) AS items
  FROM oftar_catalog o
  JOIN os_catalog c ON c.code = o.code
  LEFT JOIN os_catalog_item i ON i.catalog_id = c.id
 GROUP BY c.code, o.code_prefix ORDER BY c.code;

-- C. Estado del mapeo CAO/Regional
SELECT source_catalog_code, review_status, count(*) AS pares,
       min(target_code) AS ejemplo_target
  FROM os_oftar_nomenclador_match
 GROUP BY 1,2 ORDER BY 1,2;

-- D. H-02: ¿el target_code existe como permanent_code?
SELECT m.source_catalog_code, count(*) AS propuestas,
       count(t.id) AS targets_resueltos
  FROM os_oftar_nomenclador_match m
  LEFT JOIN os_catalog tc ON tc.code = m.target_catalog_code
  LEFT JOIN os_catalog_item t
         ON t.catalog_id = tc.id AND t.permanent_code = m.target_code
 GROUP BY m.source_catalog_code ORDER BY 1;

-- E. Textos publicados en la vista de búsqueda
SELECT catalogo, count(*) AS items, count(DISTINCT codigo_permanente) AS permanentes
  FROM v_oftar_search_catalog
 GROUP BY catalogo ORDER BY catalogo;

-- F. Categorías clínicas efectivas
SELECT code, count(*) AS items
  FROM os_catalog_item_clinical_category
 GROUP BY code ORDER BY code;

ROLLBACK;
```

Si la consulta D devuelve `targets_resueltos = 0` para CAO, H-02 queda confirmado en producción.

---

## 6. Cierre del diagnóstico

El modelo OFTAR es estructuralmente coherente y ya separa catálogo de categoría clínica. Los problemas detectados son de **operación y trazabilidad**: rutas obsoletas, un descalce de identificadores en la publicación de mapeos, sentencias destructivas en generadores y falta de verificación de producción. Ninguno justifica crear un motor paralelo ni reemplazar los seeds vigentes.

La propuesta de reconstrucción se detalla en `plan-reconstruccion-oftar.md`; el modelo objetivo en `modelo-canonico-oftar-propuesto.md`.
