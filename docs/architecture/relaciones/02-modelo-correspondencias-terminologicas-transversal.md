# Modelo transversal de correspondencias terminológicas

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** diseño obligatorio para DENTAR y OFTAR. (No autoriza importación, aprobación ni publicación.)

---

## 1. Responsabilidad

**[H]** `os_concept_mapping` vincula un ítem interno (`item_id`) con un sistema externo (`terminology_system_id`) y un `external_code`; `mapping_type` solo admite `equivalent|narrower|broader|related|unmatched`, y `relationship_role` admite `procedure_concept|justifying_diagnosis|observation_concept|substance_concept` (`origen_catalog_engine.sql:119-133`).

**[P]** Esa tabla cubre **correspondencias**, no relaciones clínicas internas. Un concepto externo se registra una vez por sistema+edición+código y se reutiliza en todas las relaciones que correspondan; no se duplica como ítem de catálogo.

---

## 2. Las ocho clases

| # | Clase documental | Persistencia | Regla dura |
|---:|---|---|---|
| 1 | Equivalencia exacta | `equivalent` + `univocal` | «Exacta» es etiqueta documental; requiere ancla verificable, evidencia y doble revisión. |
| 2 | Equivalencia aproximada | `related` + `approximate` | Nunca `equivalent`; explicar la diferencia en `clinical_rationale`/`source_reference`. |
| 3 | Correspondencia parcial | `related` + `partial` | `broader`/`narrower` solo si hay jerarquía real verificada. |
| 4 | Correspondencia más amplia | `broader` | Dirección propio → externo, sujeta a ratificación. |
| 5 | Correspondencia más específica | `narrower` | Dirección propio → externo, sujeta a ratificación. |
| 6 | Correspondencia asociativa | `related` justificada | No es equivalencia; si es interna, va a `os_catalog_relation`. |
| 7 | Sin correspondencia | `unmatched` + `not_mappable` | Decisión negativa documentada, nunca equivalencia. |
| 8 | Pendiente de evaluación | `review_status='draft'` | Sin texto externo público; `pending_review` no es valor de `CHECK`. |

**[H]** `mapping_nature` admite `univocal|multiple|partial|approximate|not_mappable` (`fase3_relaciones_mapeos.sql:125-127`). **[P]** La coincidencia textual nunca basta: se exigen sistema, edición, alcance, modalidad, lateralidad, región y normas particulares cuando apliquen.

---

## 3. Sistemas por familia

### 3.1 DENTAR

| Sistema | Uso | Conservación obligatoria |
|---|---|---|
| **CDT — Current Dental Terminology** | Referencia internacional principal para `DENTAR-PR`; correspondencia con `DENTAR-DX` solo con justificación; vínculo con SNOMED cuando corresponda. | Código, descripción oficial, edición/año, categorías y subcategorías, cambios entre ediciones (agregados, modificados, eliminados), licencia y condiciones de uso. **No asumir equivalencia exacta.** |
| **Nomenclador Nacional de Prestaciones Odontológicas de Argentina** | Referencia fundamental para `DENTAR-PR`. | Código original con separadores (`01.01` **no** → `0101`), descripción, capítulo, categoría, normas particulares, alcance, requisitos/restricciones, vigencia y fuente documental. |
| **Nomencladores provinciales, regionales e institucionales** | Obras sociales, colegios y federaciones, organismos provinciales, sistemas públicos, entidades de cobertura y otras instituciones argentinas. | Identidad independiente; institución, jurisdicción, código, descripción, edición/versión, vigencia, normas, valores arancelarios y condiciones de cobertura **separados de la identidad clínica**. |
| **CIE-10 y ediciones identificadas** | Referencia de `DENTAR-DX`. | Edición explícita; nunca `CIE-10` sin subtipo cuando convivan ediciones. |
| **SNOMED CT Argentina Edition** | Enriquecimiento semántico de PR y DX. | Refset/versión, concepto, `mapAdvice` cuando aplique y licencia. |
| **Otros sistemas odontológicos documentados** | Solo con perfil aprobado y fuente verificable. | Sin importación automática como equivalentes. |

**[H]** El catálogo `nomenclador-odontologico-ar`, release `NOM-ODON-AR-v1` y sistema `NOMENCLADOR-AR` están documentados como ejecutados por el usuario el 2026-11-19, con 135 ítems y numeración original (`propuesta-arquitectura-catalogos-sanitarios.md:460-492`). **[I]** Ese hecho es evidencia histórica documental; este diseño no realiza cargas nuevas.

**[H]** El `CHECK` de `relation_type` incluye valores CDT como `alternate_benefit`, `interchangeable_with`, `used_in_combination_with`, `billed_in_conjunction_with` y `referencia_literal` (`nomenclador_odontologico_nacional.sql:538-545`). **[P]** Se conservan como procedencia; no se degradan a `related` ni se reutilizan como sustitutos de tipos clínicos sin gobernanza.

### 3.1.1 Evidencia y brechas verificadas en DENTAR

**[H]** La fuente CDT 2025 del repositorio define `dental_cdt_codes` con
`cdt_code`, `service_type`, `description`, `procedure`, `notes` y `req`
(`tools/sources/cdt/Argentina_dental_cdt_codes_2025_postgres.sql:1-24`). El
dry-run documentado registra 805 filas candidatas, 333 relaciones únicas y 8
exclusiones, sin carga a PostgreSQL (`docs/dentar/generado/RESUMEN.md:1-16,67-75`).
El CSV generado conserva `cdt_2025` y `snomed_sctid`
(`docs/dentar/generado/dentar-pr-cdt-2025.csv:1-6`).

**[H]** **Brechas:** no hay en el repositorio texto de licencia ADA ni un diff
entre ediciones CDT que permita afirmar agregados, modificados o eliminados;
tampoco hay artefactos de nomencladores odontológicos
provinciales/regionales/institucionales. **[P]** Por tanto, esos extremos se
documentan como requisitos de incorporación futura, no como datos existentes.
No se afirma licencia, vigencia normativa ni existencia de esos nomencladores
sin evidencia nueva.

**[H]** El Nomenclador Nacional conserva códigos originales como `01.01`,
`11.01.01` y sufijos (`bis`, `i`, `F`, `C`), sin normalización
(`sql/03_dentar/nomenclador_odontologico_nacional.sql:239-373,417-421`);
`definition` recibe `norma_particular` (`:423-435`); los indicadores fuente se
preservan como atributos (`:28-39,123-148,173-193,452-492`). La release usa
`valid_from=CURRENT_DATE` con aclaración explícita de que **no es fecha
normativa** (`:397-404`). **[P]** La vigencia normativa queda pendiente de
acta; no se inventa.

**[H]** No se encontró evidencia de correspondencia directa CDT ↔ `DENTAR-DX`
en los artefactos inspeccionados; solo `DENTAR-PR` ↔ CDT y `DENTAR-DX` ↔
CIE-10/SNOMED (`docs/dentar/README.md:9-10`,
`docs/dentar/generado/RESUMEN_DX.md:1-40,71-79`). **[P]** La regla del usuario
se conserva como capacidad permitida **con justificación**, no como dato cargado.

### 3.2 OFTAR

| Sistema | Uso | Regla |
|---|---|---|
| Nomenclador Nacional | Núcleo de `OFTAR-PR` | Prefijo canónico `OFT-PR-NNNNNN`; fuente secundaria. |
| CAO | Complemento de `OFTAR-PR` | 143 códigos inmutables; 3 candidatos sin alta automática. |
| Regional NOA | Complemento de `OFTAR-PR` | 136 códigos inmutables. |
| CIE-10-ES 2026 | `OFTAR-DX` en español | 6.ª edición, Ministerio de Sanidad de España; **no norma argentina**. |
| ICD-10-CM 2027 | Referencia externa | 17 códigos exclusivos sin traducir ni convertir automáticamente. |
| SNOMED CT Argentina Edition | Enriquecimiento selectivo | refset `447562003`; `related` con justificación. |

### 3.3 Familias futuras

**[P]** NN-PMO, NBU, NHPGD, ANDIS, KINESIOLOGIA, SALUD_MENTAL y otras podrán registrar sus nomencladores con el mismo mecanismo: sistema + edición + release + justificación de pertinencia. No se asume que un sistema aplica a todas las familias.

---

## 4. Independencia de identidad

1. **[P]** DENTAR y OFTAR conservan sus códigos permanentes (`DNT-PR-NNNNNN`, `DNT-DX-NNNNNN`, `OFT-PR-NNNNNN`, `OFT-DX-NNNNNN`). CDT y los nomencladores argentinos son fuentes de referencia, no identificadores maestros.
2. **[P]** Un cambio de edición de CDT, SNOMED o CIE-10 crea nueva correspondencia o nueva vigencia; **no cambia** el identificador DENTAR/OFTAR.
3. **[P]** Un mismo concepto interno puede tener múltiples correspondencias simultáneas con sistemas y ediciones distintos, respetando `UNIQUE` de cuatro columnas (`origen_catalog_engine.sql:132`).
4. **[P]** Valores arancelarios, cobertura y requisitos de autorización se guardan como atributos gobernados separados; nunca se infiere de ellos una equivalencia clínica.
5. **[P]** Se respetan licencias y condiciones de uso de CDT y demás fuentes; `license_reference` es obligatorio cuando la fuente lo exija (`fase3_relaciones_mapeos.sql:131`).

---

## 5. Publicación

**[P]** El texto externo solo se publica si la fila está `approved` y la revisión de campo vigente coincide con el hash (`MappingReviewReader.php:10-130`). Las clases 7 y 8 y las filas `draft`/`deprecated` solo se muestran en vista editorial autorizada.
