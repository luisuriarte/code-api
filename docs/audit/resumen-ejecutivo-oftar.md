# Resumen ejecutivo · Auditoría de OFTAR y propuesta de reconstrucción

**Fecha:** 2026-11-28  
**Estado:** Etapa Diagnóstico cerrada para revisión. **No se implementó nada.**  
**Restricción vigente:** no modificar seeds existentes, no modificar PostgreSQL, no ejecutar migraciones, no asignar UVR, no crear motor paralelo, no `DROP`/`TRUNCATE`/`DELETE`, no commit, push ni deploy por el asistente.

---

## 1. Objetivo

Auditir el estado real de la familia OFTAR y proponer la reconstrucción de **OFTAR-PR** y **OFTAR-DX** sin tocar los artefactos vigentes. La reconstrucción propuesta mantiene la arquitectura, la identidad visual, los contratos de API, las URLs públicas y los catálogos ya publicados; solo propone gobernanza y trazabilidad para las fuentes clínicas.

---

## 2. Fuente de verdad verificada

| Capa | Artefacto | Rol |
|---|---|---|
| Motor canónico | `sql/02_catalogs/origen_catalog_engine.sql` | Define `os_catalog`, `os_catalog_release`, `os_catalog_category`, `os_catalog_item`, `os_catalog_item_version`, `os_catalog_term`, `os_catalog_identifier`, `os_concept_mapping`. |
| Extensiones i18n/gobernanza | `sql/07_multilingue/01_fase2_tablas.sql`, `04_fase3_columnas.sql`, `05_fase3_triggers.sql` | Agregan `os_catalog_language`, `os_localized_text`, `os_field_review`, `os_translation_review` y columnas de revisión/proveniencia. **El motor base solo no basta** para explicar los importadores actuales. |
| Familia OFTAR | `sql/03_oftar/oftar_family.sql`, `oftar_core.sql` | Define la marca `oftar`, los catálogos `oftar-pr`/`oftar-dx`, prefijos, categorías internas y modelos editoriales. |
| Contrato API | `api/services/CatalogEngineService.php`, `api/services/TerminologySearchService.php` | Expone `category` (histórico) y `clinical_category` / `clinical_category_code` (nuevo), y el dominio único `oftar`. |
| Fuentes clínicas | CAO, Regional NOA, Nomenclador Nacional 2025, CIE-10-ES, ICD-10-CM/PCS, SNOMED CT Argentina | Fuentes de observación, no reemplazan al motor canónico. |

La separación pedida por el usuario se respeta en el modelo vigente: **categoría del concepto** (`CLIN-*`, transversal) y **catálogo de origen** (`oftar-pr`, `oftar-dx`, `nomenclador-oftalmologico-cao-ar`, `nomenclador-oftalmologico-regional-ar`) son dimensiones distintas.

---

## 3. Hechos verificados en el repositorio

1. La familia OFTAR tiene dos productos activos: `oftar-pr` (procedimientos) y `oftar-dx` (diagnósticos), con prefijos `OFT-PR-` y `OFT-DX-` y dominio único `oftar`. Los prefijos antiguos `OFTAR-PR-`/`OFTAR-DX-` ya no son el contrato vigente (`oftar_family.sql`, `renombrar_codigos_oftar.sql`).
2. `categorias_clinicas.sql` crea 12 categorías `CLIN-*`, 26 mapas de categoría fuente y 8 defaults por catálogo. Según la ejecución previa informada, ese script ya está aplicado en producción.
3. La API conserva `category` y agrega `clinical_category` y `clinical_category_code`; el filtro `category` acepta códigos `CLIN-*` sin romper deep links (`CatalogEngineService.php:155-174`, `:587-592`, `:814-829`).
4. Fuentes cuantificadas en disco:
   - CAO: **143 filas**, 143 códigos únicos, 12 categorías literal.
   - Regional NOA: **136 filas**, 136 códigos únicos, 3 grupos y 9 subgrupos.
   - Nomenclador Nacional 2025, sección OFTALMOLOGIA: **154 tuplas** en `fuente_nomenclador_oftar_pr.sql`.
   - CIE-10-ES 2026: **74.260** diagnósticos; dentro de H00-H59 hay **2.661** códigos.
   - ICD-10-CM 2027 en inglés: **17** códigos H exclusivos frente al CSV español; sumados a los 2.661 dan **2.678** diagnósticos esperados en OFTAR-DX.
   - ICD-10-PCS 2026: **78.948** procedimientos; **1.212** empiezan con `08`. No se importan como códigos OFTAR nuevos.
5. El importador CAO siembra **91 propuestas** de correspondencia textual con el Nomenclador Nacional; el Regional siembra **0**. Ninguna se publica sin revisión humana.
6. Los importadores de nomencladores de origen **no copian precios**: CAO y Regional conservan categoría/descripción, pero no `valor`, `honorario_medico`, `gasto` ni `valor_total`.
7. `sync_oftar_dx_to_os.sql` proyecta los diagnósticos al motor canónico y deja textos/mapeos en revisión; no crea UVR.
8. `v_oftar_search_catalog` publica **solo versiones aprobadas** y excluye UVR.
9. `php tests/run.php` falla actualmente **4 de 4088** verificaciones porque `tests/run.php:2789` y `:3424` apuntan a `tools/sources/oftar/importar_cie10_dx.sql`, ruta que ya no existe. La ruta real es `tools/sources/oftalmologico/oftar/importar_cie10_dx.sql`.

---

## 4. Hallazgos críticos

| ID | Hallazgo | Impacto | Estado |
|---|---|---|---|
| H-01 | Las rutas legacy `tools/sources/oftar/...` siguen citadas en el generador, encabezados SQL y tests. | Regresión de tests y riesgo de regenerar artefactos con fuentes inexistentes. | Verificado; sin corregir. |
| H-02 | `os_oftar_nomenclador_match.target_code` se siembra con el código de 6 dígitos del Nomenclador Nacional, pero `aprobar_mapeo_nomencladores_oftar.sql:163-165` busca `os_catalog_item.permanent_code = target_code` en `oftar-pr`, cuyos códigos son `OFT-PR-NNNNNN`. | Las 91 propuestas CAO podrían no publicarse nunca. **Requiere verificación en PostgreSQL.** | Verificado en código; consecuencia inferida. |
| H-03 | Los SQL generados CAO/Regional ejecutan `DELETE FROM` sobre sus tablas espejo antes de insertar. | Contradice la regla de no destructividad para una futura reconstrucción. | Verificado en `tools/generate_nomencladores_oftalmologicos_sql.py:248`. |
| H-04 | El motor base `origen_catalog_engine.sql` no incluye columnas de revisión/proveniencia que usan los importadores. | Los importadores dependen de migraciones i18n posteriores; hay que documentar la cadena de dependencias. | Verificado. |
| H-05 | No hay verificación local del estado real de producción de OFTAR-PR/OFTAR-DX ni de si `catalogos_gestion_gobernada.sql` fue ejecutado. | Imposible afirmar cobertura publicada sin consultar PostgreSQL. | Pendiente de ejecución por el usuario. |

---

## 5. Propuesta en una línea

Mantener el modelo actual de **familia → catálogos → ítems → versiones → textos localizados/mapeos**, reconstruir OFTAR-PR y OFTAR-DX con identificadores propios permanentes (`OFT-PR-NNNNNN`, `OFT-DX-NNNNNN`), conservar CAO y Regional como catálogos de origen con su numeración histórica, y publicar toda correspondencia solo después de **revisión humana con dos aprobaciones**. No importar SNOMED ni CIE-10-PCS completos, no inventar equivalentes ni asignar UVR a diagnósticos.

---

## 6. Decisiones que se piden al usuario

1. Aprobar el diagnóstico y la propuesta de reconstrucción contenidos en esta carpeta.
2. Autorizar, si corresponde, ejecutar las verificaciones de solo lectura listadas en `auditoria-oftar-actual.md` para confirmar H-02 y el estado real de producción.
3. Confirmar que no se debe corregir todavía la regresión de `tests/run.php` (restricción actual: no implementar).

---

## 7. Entregables

| Archivo | Contenido |
|---|---|
| `auditoria-oftar-actual.md` | Hallazgos detallados, evidencia y verificaciones pendientes. |
| `inventario-fuentes-oftar.md` | Inventario exhaustivo de fuentes, scripts, seeds y referencias. |
| `matriz-equivalencias-oftar-pr.csv` | 279 filas CAO + Regional con candidatos textuales y clasificación propuesta; sin equivalencias clínicas afirmadas. |
| `cobertura-oftar-pr.md` | Cobertura actual y esperada de procedimientos. |
| `cobertura-oftar-dx.md` | Cobertura actual y esperada de diagnósticos CIE-10 H00-H59. |
| `modelo-canonico-oftar-propuesto.md` | Modelo canónico propuesto, con catálogo y categoría del concepto separados. |
| `plan-reconstruccion-oftar.md` | Plan por fases, gobernanza, verificaciones y criterios de aceptación. |
| `resumen-ejecutivo-oftar.md` | Este documento. |

**Nota final:** ningún archivo de `sql/03_oftar/`, `tools/sources/`, `tests/` ni PostgreSQL fue modificado durante esta auditoría.
