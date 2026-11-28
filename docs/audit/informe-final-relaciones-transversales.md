# Informe final — modelo transversal de relaciones y perfil OFTAR v1.0

**Fecha:** 2026-11-28
**Alcance:** consolidar OFTAR v1.0 como base técnica aprobada y convertir el modelo de relaciones clínicas/terminológicas en capacidad transversal de Origen Salud, con DENTAR y OFTAR como primeras aplicaciones.
**Convención:** `[H]` hecho verificado en repositorio o acta documental · `[I]` inferencia técnica · `[P]` decisión propuesta sujeta a ratificación.

> **Límite:** solo documentación y código fuente del repositorio. No se ejecutaron migraciones, seeds, importadores, SQL de escritura ni escrituras en PostgreSQL. No se generaron seeds. No se publicó ni aprobó clínicamente nada. La secuencia se detiene antes de la etapa 10 del plan transversal.

---

## 1. Archivos inspeccionados

- **8 documentos exigidos:** `especificacion-definitiva-reconstruccion-oftar.md`, `modelo-funcional-canonico-oftar.md`, `arquitectura-tecnica-oftar-final.md`, `clasificacion-anatomica-oftar-final.md`, `taxonomia-oftar-final.md`, `matriz-estados-publicacion-oftar.md`, `universo-diagnosticos-oftar-dx.md`, `aprobacion-conciliacion-oftar-pr.md`.
- **DDL y SQL:** `sql/02_catalogs/origen_catalog_engine.sql`, `sql/03_dentar/nomenclador_odontologico_nacional.sql`, `sql/03_dentar/dentar_family.sql`, `sql/03_oftar/*`, `sql/07_multilingue/*`, `sql/08_arquitectura/fase1_infraestructura.sql`, `fase3_relaciones_mapeos.sql`, `fase3_i18n.sql`, `fase4_gobernanza.sql`, fuentes CDT y `tools/sources/odontologico/odontologico.sql`.
- **API y portal:** `api/index.php`, `api/services/CatalogEngineService.php`, `api/services/TerminologySearchService.php`, `api/controllers/ConceptController.php`, `portal/Repositories/CatalogRepository.php`, `portal/Admin/CatalogGovernanceService.php`, vistas `browse-detail.php`, `partials/browse/detail/*`, `admin/catalogs/*`.
- **Procesamiento y pruebas:** importadores/generadores de DENTAR y OFTAR, `tools/generate_unified_catalog_engine_sql.py`, `MappingReviewReader.php`, `tests/run.php`, `docs/dentar/generado/*`.
- **Arquitectura general:** `docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md` y documentos de gobernanza UVR.

## 2. Archivos modificados

- **Nuevos (13 entregables transversales):** `docs/architecture/relaciones/00…12-*.md`.
- **Nuevo complementario:** este informe (`docs/audit/informe-final-relaciones-transversales.md`), que no se cuenta entre los 13 entregables.
- **Modificados en esta ronda (12):**
  - `docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md`
  - `docs/audit/especificacion-definitiva-reconstruccion-oftar.md`
  - `docs/audit/modelo-relaciones-clinicas-oftar.md`
  - `docs/audit/modelo-relaciones-terminologicas-oftar.md`
  - `docs/audit/diccionario-tipos-relacion-oftar.md`
  - `docs/audit/integracion-os-catalog-oftar.md`
  - `docs/audit/integracion-os-concept-mapping-oftar.md`
  - `docs/audit/modelo-trazabilidad-versionado-oftar.md`
  - `docs/audit/contratos-api-relaciones-oftar.md`
  - `docs/audit/diseno-interfaz-consulta-oftar.md`
  - `docs/audit/plan-pruebas-oftar.md`
  - `docs/audit/plan-implementacion-controlada-oftar.md`
- **Detalle:** 21 artefactos OFTAR conservan la frase de cierre exacta; los 13 transversales no la llevan porque no son documentos OFTAR. Sin commit, push ni deploy.

## 3. Decisiones

1. **[P]** `os_catalog` sigue siendo el motor único; `oftar` es `family_code`/dominio funcional, nunca `domain_type`.
2. **[P]** OFTAR pasa a ser **perfil de dominio** del mecanismo común; DENTAR es la primera aplicación simultánea y futuras familias se incorporan sin rediseño.
3. **[H]** Separación física: relaciones internas en `os_catalog_relation`; correspondencias externas en `os_concept_mapping` + `os_mapping_metadata`; no se crea tabla nueva ni motor paralelo.
4. **[P]** Un solo diccionario de 31 códigos `REL-*`, reutilizable por semántica; tres tipos explícitamente solicitados no incluidos quedan como ampliaciones pendientes `[P]`.
5. **[P]** Contrato único `data.relations{clinical,terminological}`; sin endpoints por familia; `mappings` y `related_codes` intactos.
6. **[P]** Un solo componente de ficha, con grupos adaptados por DENTAR/OFTAR e insignias distintas para Clínica y Terminológica.
7. **[P]** Se mantiene la secuencia canónica de 13 etapas del perfil OFTAR y se añade un plan transversal de 14 etapas con gate explícito antes de carga.

## 4. Inconsistencias corregidas

- Valores de `mapping_type` en la arquitectura general: reemplazados por `equivalent|narrower|broader|related|unmatched`; `mapping_nature` por `univocal|multiple|partial|approximate|not_mappable`.
- Numeración de §7 corregida (7.1–7.5) y texto obsoleto «las relaciones siguen sin ser navegables» actualizado a la integración aprobada de Fase 4.
- Referencias cruzadas erróneas en el modelo transversal (`09/08` → `10/09`).
- Errores tipográficos y marcadores accidentales en documentos nuevos (`跨`, `组内`, `fechaStructured`, `/OFSTAR`, `Relation clínica`).
- Brechas documentales marcadas como tales: licencia CDT, diff multi-edición CDT, vigencia normativa del Nomenclador Nacional y ausencia de nomencladores odontológicos provinciales/institucionales.
- `23.292` queda únicamente como cifra **prohibida/no reproducible**; nunca como dato operativo.

## 5. Compatibilidad con el esquema real

- **[H]** Compatibilidad verificada **por lectura de SQL versionado y código**, no por consulta a PostgreSQL en ejecución.
- **[H]** `os_catalog`: `domain_type ∈ dental|medical|biochemical|rehabilitation|mental_health|pharma|terminology`; `family_code`, `product_role ∈ family|catalog`.
- **[H]** `os_concept_mapping`: `mapping_type` de cinco valores; `relationship_role` de cuatro; `review_status ∈ draft|reviewed|approved|deprecated`; `UNIQUE` de cuatro columnas.
- **[H]** `os_catalog_relation`: `relation_type` heredado de 15 tipos CDT; `source_value VARCHAR(20)`; mismo `review_status`; `UNIQUE` de siete columnas; `ck_os_catalog_relation_not_self`.
- **[H]** Fase 3/4 agrega columnas aditivas y `os_mapping_metadata`, pero su aplicación en el entorno destino sigue sujeta a acta `READ ONLY`.
- **[H]** `psql` no disponible y sin variables `DB_*`/`PG*`: no se afirma compatibilidad runtime.

## 6. Modelo clínico

- **[P]** Tres componentes separados: identidad/definición, relaciones clínicas/anatómicas/funcionales y correspondencias terminológicas.
- **[P]** Relaciones entre conceptos internos de la misma familia, entre catálogos distintos y entre familias, siempre con justificación clínica; nunca por similitud textual.
- **[P]** Cinco clases: PR-PR, DX-DX, PR-DX, ANAT y FUNC; dirección `source → target`, sin inversas automáticas; simetría declarada requiere segunda fila.
- **[P]** Puente transitorio `referencia_literal` + `context_text`/`provenance`; destino gobernado `relation_type_code` con FK a `os_relation_type`, migración **no ejecutada**.
- **[P]** Los 31 códigos OFTAR se conservan; no se inventan los cinco códigos faltantes para llegar a «~36».

## 7. Modelo terminológico

- **[P]** Ocho clases documentales mapeadas a los CHECK reales: `equivalent`+`univocal`, `related`+`approximate`, `related`+`partial`, `broader`, `narrower`, `related` justificada, `unmatched`+`not_mappable`, pendiente con `review_status='draft'`.
- **[P]** Coincidencia textual no demuestra equivalencia; una relación clínica nunca se publica como mapeo; `justifying_diagnosis` no crea relación PR↔DX.
- **[P]** Dirección OFTAR → externo uniforme (`broader` = OFTAR más amplio, `narrower` = más específico), pendiente de ratificación.
- **[P]** DENTAR incorpora CDT, Nomenclador Nacional y nomencladores provinciales/regionales/institucionales como referencias con sistema, edición, licencia, vigencia y justificación; `01.01` nunca se normaliza a `0101`.
- **[P]** Identidad DENTAR/OFTAR permanente; cambios de edición externa crean nuevas correspondencias/vigencias sin alterar el código maestro.

## 8. Integración `os_catalog`

- **[P]** Familiar/catálogo/relación se resuelven por FKs a `os_catalog_item`, `os_catalog`, `os_catalog_release`; `family_code` y `domain_type` gobiernan las reglas.
- **[P]** Perfil configurable por dominio, familia, catálogo, tipo de concepto y naturaleza de relación; sin tabla nueva de configuración sin aprobación.
- **[H]** `v_oftar_search_catalog` filtra versión `approved`; la visibilidad por campo se resuelve en PHP; la capa de relaciones reutiliza esas reglas.
- **[P]** API aditiva sobre el envelope actual; sin duplicación de rutas ni alteración de contratos.

## 9. Integración `os_concept_mapping`

- **[H]** La tabla ya soporta múltiples sistemas/ediciones por concepto, roles, justificación, revisión y procedencia.
- **[P]** No se usa para relaciones entre dos ítems internos; no se duplica el concepto externo como ítem de catálogo.
- **[P]** `external_display`/`clinical_rationale` solo se publican con revisión de campo vigente y `content_hash`; si no, `null` + `untranslated=true`.
- **[P]** CDT, CAO, Nomenclador Nacional, CIE-10 y SNOMED requieren `source_reference`, `provenance` y `license_reference` cuando corresponda; la falta de licencia bloquea publicación.
- **[H]** Evidencia histórica: 237 mapeos `NOMENCLADOR-AR`, 333 relaciones CDT y 270 del Nomenclador; este informe no los modifica.

## 10. Pruebas ejecutadas

- **0 pruebas ejecutadas en esta ronda**; 0 consultas SQL, 0 requests API, 0 escrituras.
- **Antecedente histórico:** `php tests/run.php` registró `OK: 4068 comprobaciones` en rondas anteriores; **no se repitió** y no se usa como evidencia de este cambio.
- Plan de pruebas transversal preparado con 38 casos (T-01…T-38), todos `PENDIENTE`, incluyendo DENTAR-PR↔DX, PR↔CDT, DX↔CIE-10, DENTAR↔SNOMED, OFTAR-PR↔DX, OFTAR↔CAO/NN, OFTAR↔CIE-10, OFTAR↔SNOMED, relaciones entre familias, equivalencias exactas/parciales, no equivalencia clínica, direccionalidad, integridad, versionado, trazabilidad, publicación y compatibilidad API.

## 11. Riesgos

- Estado runtime de Fase 1/3/4 no verificado; el diseño puede requerir ajustes tras el acta `READ ONLY`.
- `relation_type` cerrado de 15 tipos impide persistir `REL-*` sin migración aditiva aprobada.
- `itemRelations()` mezcla hoy mapeos y relaciones; separar sin romper `mappings`/`related_codes` exige PR y regresiones.
- Fuentes DENTAR sin licencia/diff/vigencia normativa verificada en el repositorio.
- Riesgo de aprobación automática por texto similar o de mezcla Clínica/Terminológica en la UI.
- Carga sin firma clínica: 13 pares PR, 6 correcciones, 48 registros CAO/Regional y 3 candidatos siguen pendientes.

## 12. Estado de preparación y decisión clínica pendiente

- **Preparación documental:** lista. OFTAR v1.0 permanece como **«Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada.»**
- **Decisión clínica pendiente:** ratificación de los 31 tipos, de la dirección `broader`/`narrower`, de la simetría y de cada par/corrección/candidato; CDT y nomencladores solo se aprueban con edición, fuente, licencia y evidencia.
- **Otros pendientes:** universo DX (2.661 CIE-10-ES 2026 frente a 2.678 condicional), P-01…P-19, acta `READ ONLY`, backup y autorización explícita.
- **Cierre operativo:** etapas 1–9 documentadas; etapa 10 bloqueada; etapas 11–14 no iniciadas. **Se detuvo antes de generar o ejecutar seeds.**

---

## Criterio de aceptación transversal

**[P] Cumplido en el plano documental:** DENTAR y OFTAR pueden administrarse con un mecanismo común (`os_catalog_relation` + `os_concept_mapping` + `os_relation_type`), sin motores paralelos y sin perder particularidades mediante perfiles de dominio. La extensión a NN-PMO, NBU, NHPGD, ANDIS, KINESIOLOGIA, SALUD_MENTAL y futuras familias no requiere un modelo nuevo. La verificación práctica queda supeditada a autorización, acta y pruebas pendientes.
