# Política definitiva de identificación externa de OFTAR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — análisis, diseño y documentación.
**Estado:** decisión documentada para la especificación definitiva. **No implementada; sin migraciones, seeds ni escrituras.**
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0. Ante contradicción, prevalece lo verificado y lo definido allí (§0).
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta para aprobación.

---

## 1. Corrección normativa principal

**[H]** `tools/sources/cie10_argentina/readme.md:3-7` describe el recurso como **“Edición Española de CIE-10”** y declara: *“La edición de referencia es la 6.ª Edición (2026) publicada por el Ministerio de Sanidad de España”*. La fuente oficial citada en `:41-49` es `sanidad.gob.es`, no un organismo argentino.

**[H]** El directorio se llama `cie10_argentina`, pero el propio README lo define como una importación de CIE-10-ES en tablas nativas de OpenEMR. El nombre describe el **destino de la instalación**, no la edición.

**[H]** No existe en el repositorio un acta, archivo, metadato ni documento que identifique una **edición argentina normativa de CIE-10** con versión, release y procedencia. La búsqueda local de `CIE-10-AR`, `CIE10AR` y equivalentes no produjo evidencia de tal edición.

**[I]** La afirmación de la segunda auditoría (“CIE-10-ES 2026 como núcleo argentino”) debe reformularse: CIE-10-ES 2026 puede ser la **fuente estructurada inicial en español y referencia complementaria**, pero **no puede presentarse como clasificación normativa argentina** sin evidencia que aún no existe en el repositorio.

**[I]** La verificación externa de una edición argentina quedó intentada y no disponible en este entorno (sin acceso a búsqueda web); por tanto no se afirma ninguna edición alternativa.

**[P] Decisión:** separar tres niveles que estaban confundidos:

1. **Familia CIE-10:** etiqueta general de clasificación; **no es un valor de gobernanza persistible** sin subtipo.
2. **CIE-10-ES 2026:** edición española, 6.ª edición, Ministerio de Sanidad de España; fuente estructurada inicial y referencia complementaria.
3. **CIE-10 de referencia para Argentina:** **pendiente de acta**. Debe declarar organismo, edición, versión, release y procedencia antes de usarse como norma. Hoy solo es un nombre de familia, no un hecho verificable.

---

## 2. Política por sistema

| Sistema | Identidad obligatoria | Rol en OFTAR | Regla de incorporación |
|---|---|---|---|
| **CIE-10-ES 2026** | `system=CIE-10-ES`, `edition=ES`, `version=2026`, `release=Diagnosticos_Tabla_Referencia_CIE10ES_2026`, `language=es`, `provenance=Ministerio de Sanidad de España (6.ª edición)` | Fuente estructurada inicial en español y referencia complementaria | Los códigos H00-H59 pueden ser candidatos iniciales de OFTAR-DX; la etiqueta “normativo argentino” requiere acta. |
| **CIE-10 referencia Argentina** | `edition/version/release/provenance` **a definir por acta** | Referencia normativa pendiente | No persistir como `system_code='CIE-10'` sin subtipo; no inventar organismo ni año. |
| **ICD-10-CM 2027** | `system=ICD-10-CM`, `edition=CM`, `version=2027`, `release=2027-code-descriptions-in-tabular-order.zip`, `language=en`, `provenance=CDC/NCHS-CMS (paquete tabular order local)` | Modificación clínica estadounidense independiente | Los 17 códigos exclusivos conservan identidad CM y descripción original; **no se incorporan automáticamente como CIE-10**. |
| **SNOMED CT Argentina Edition** | `system=SNOMED-CT`, `edition=Argentina Edition`, `release=20260820`, `effectiveTime`, `moduleId`, `refsetId` del RF2 | Terminología clínica complementaria | Enriquecer conceptos, descripciones, relaciones y correspondencias **verificadas**; no importar todos los conceptos ni asignar por similitud textual. |
| **CIE-10-PCS** | `system=ICD-10-PCS`, `edition=ES 2026` en el CSV local | Referencia de procedimientos para OFTAR-PR | No genera diagnósticos ni códigos OFTAR nuevos. |
| **Nomenclador Nacional 2025 / CAO / Regional NOA** | `system=NOMENCLADOR-AR-2025`, `CAO`, `REGIONAL-NOA`; número y descripción originales | Fuentes principales de OFTAR-PR | Conservar numeración y descripción; resolver siempre por `(catálogo, identificador)`. |

---

## 3. Los 17 códigos exclusivos ICD-10-CM 2027

**[H]** Son `H01.81`, `H01.82`, `H01.83`, `H01.84`, `H01.85`, `H01.86`, `H01.89`, `H018A`, `H018B`, `H05.831`, `H05.832`, `H05.833`, `H05.839`, `H40.841`, `H40.842`, `H40.843`, `H40.849`. Ninguno está en `Diagnosticos_Tabla_Referencia_CIE10ES_2026.csv`; las descripciones originales en inglés están en `revision-clinica-oftar-dx.md:34-56`.

**[P]** Deben conservarse como referencia externa con identidad CM explícita. Su eventual proyección como ítems `OFT-DX-NNNNNN` es una decisión de gobernanza separada y elevaría el catálogo de 2.661 a 2.678 **solo si se aprueba**; en ese caso la cifra debe escribirse “2.661 CIE-10-ES + 17 ICD-10-CM”, nunca “2.678 CIE-10”.

**[P]** No se traducen al español de forma automática. Si no hay texto `es-AR` aprobado, se conserva el display `en` y se registra el hueco idiomático sin inventarlo.

---

## 4. Campos obligatorios de todo identificador externo

**[P]** Todo identificador externo debe poder distinguir nueve datos:

| # | Dato | Estado en el modelo actual | Destino propuesto |
|---:|---|---|---|
| 1 | Sistema de codificación | Parcial: `os_catalog_identifier.system_name`, `oftar_external_identity.system_code` | Conservar; usar valores específicos por edición. |
| 2 | Edición | No estructurado; solo en texto de `source_reference`/`provenance` | Metadato de sistema/release; mientras tanto, texto obligatorio normalizado. |
| 3 | Versión | Parcial: `os_terminology_system.default_version`, nombre de release | Hacer obligatoria por sistema. |
| 4 | Release / fecha de publicación | Parcial: `os_catalog_release`, `effectiveTime` RF2 | Metadato estructurado; sin DDL, `source_reference` normalizado. |
| 5 | Código original | Sí: `os_catalog_identifier.value`, `oftar_external_identity.code_raw` | Conservar sin normalizar destructivamente. |
| 6 | Descripción original | Parcial: términos por idioma y `external_display` | Conservar la descripción literal de la fuente. |
| 7 | Idioma | Parcial: `language_code`, `source_language_code`, `language_evidence` | Hacer obligatorio; `en` para CM, `es` para ES. |
| 8 | Procedencia | Sí: `provenance`, `source_reference` en `os_concept_mapping` (Fase 3) | Hacer obligatoria y específica por edición. |
| 9 | Estado de vigencia | Parcial: `active` RF2, `valid_from`/`valid_to`, `review_status` | Registrar cuando la fuente lo proporcione; si no, `desconocido`, nunca `vigente` por inferencia. |

**[H]** `os_catalog_identifier` expone `system_name`, `value` e `is_primary` (`sql/02_catalogs/origen_catalog_engine.sql`). `os_concept_mapping` incorpora `terminology_system_id`, `external_code`, `external_display`, `mapping_type`, `relationship_role`, `review_status` y, desde la Fase 3, `source_language_code`, `language_evidence`, `provenance`, `source_reference`, `content_hash`, `valid_from`/`valid_to` (`sql/07_multilingue/04_fase3_columnas.sql`). `oftar_external_identity` expone `system_code`, `code_raw`, `code_normalized`, `owner_catalog`, `entity_kind` (`sql/03_oftar/oftar_external_identity.sql`).

**[I]** El modelo actual ya puede almacenar la mayoría de los nueve datos de forma distribuida. Lo que **no** hace de forma limpia es distinguir edición + release + procedencia como una identidad única y evitar que dos ediciones compartan `system_code`.

**[P] Sin migración:** normalizar los valores persistidos (`CIE-10-ES`, `ICD-10-CM`), completar `source_reference`/`provenance`/`language` y usar `os_catalog_release` para la versión.
**[P] Ampliación futura (solo si se aprueba):** metadatos estructurados de `edition/version/release/provenance` en el sistema o en una identidad externa versionada, sin duplicar conceptos ni crear motor paralelo.

---

## 5. Reglas de no invención

1. No etiquetar CIE-10-ES 2026 como “edición argentina” ni como norma argentina sin acta.
2. No usar `CIE-10` como `system_code` final cuando haya dos ediciones implicadas.
3. No convertir códigos ICD-10-CM exclusivos en códigos CIE-10-ES ni inventar traducciones.
4. No importar SNOMED CT masivamente ni asignar conceptos por similitud de texto.
5. No usar CIE-10-PCS como fuente de diagnósticos.
6. No reutilizar prefijos OFTAR retirados ni cambiar `OFT-PR-`/`OFT-DX-`.
7. No publicar mapeos sin evidencia, `review_status` aprobado y revisión humana.

---

## 6. Cierre

**[I]** La política anterior era correcta al no traducir huecos idiomáticos, pero incorrecta al llamar “núcleo argentino” a una edición española y al agrupar dos ediciones bajo `CIE-10`.

**[P]** Queda resuelto: CIE-10-ES 2026 es fuente estructurada inicial y referencia complementaria; ICD-10-CM 2027 es referencia externa independiente; SNOMED CT Argentina Edition es enriquecimiento gobernado; la edición CIE-10 de referencia en Argentina sigue pendiente de acta y no se inventa.
