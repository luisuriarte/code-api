# Integración del modelo transversal con `os_concept_mapping`

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** diseño de integración. (No autoriza inserciones ni aprobaciones.)

---

## 1. Qué responsabilidades cubre ya la tabla

**[H]** `os_concept_mapping` (`origen_catalog_engine.sql:119-133`) ya cubre:

- ítem interno único (`item_id`), sistema externo (`terminology_system_id`) y código externo (`external_code`);
- cinco valores de `mapping_type`: `equivalent`, `narrower`, `broader`, `related`, `unmatched`;
- cuatro roles: `procedure_concept`, `justifying_diagnosis`, `observation_concept`, `substance_concept`;
- justificación clínica, estado de revisión, procedencia y referencia de origen;
- `UNIQUE(item_id, terminology_system_id, external_code, relationship_role)`.

**[H]** `os_mapping_metadata` añade ediciones de origen/destino, `mapping_type_ext`, `mapping_nature`, método, confianza, referencia, licencia, revisión y vigencia (`fase3_relaciones_mapeos.sql:118-141`). `os_terminology_system_alias` declara equivalencia de sistemas por código exacto (`:153-154`).

---

## 2. Qué requiere un mecanismo complementario

| Necesidad | ¿Lo cubre `os_concept_mapping`? | Destino |
|---|---|---|
| Relación entre dos ítems internos | No | `os_catalog_relation` |
| Dirección clínica y `context_text` | No | `os_catalog_relation` |
| Tipo clínico jerárquico o funcional | No | `os_relation_type` + `os_catalog_relation` |
| Múltiples sistemas y ediciones para un mismo concepto | Sí, con filas distintas y `UNIQUE` respetado | `os_concept_mapping` |
| Reutilizar un código externo en varias familias | Sí, sin duplicar el concepto externo | sistema + código + metadatos |
| Texto externo condicionado a revisión de campo | Parcial: la tabla guarda estado; la publicación la resuelve `MappingReviewReader` | `MappingReviewReader.php:10-130` |

**[P]** No se usa `os_concept_mapping` para PR↔DX. El rol `justifying_diagnosis` califica un mapeo; no convierte la fila en una relación clínica.

---

## 3. Reglas de inserción futura

1. **[P]** Resolver sistema por `code` + edición + release. No mezclar códigos de sistemas distintos aunque coincidan alfanuméricamente.
2. **[P]** Verificar `UNIQUE` de cuatro columnas antes de insertar; si existe la fila, actualizar solo metadatos gobernados con auditoría, nunca borrar y reinsertar aprobaciones.
3. **[P]** `mapping_type` se elige entre los cinco valores reales; «exacta/aproximada/parcial» se expresan con `mapping_type` + `mapping_nature`.
4. **[P]** `external_display` y `clinical_rationale` solo se publican si hay `os_field_review` aprobado y `content_hash` vigente; si no, `null` + `untranslated=true`.
5. **[P]** `review_status='draft'` para toda propuesta nueva; `approved` solo tras doble revisión y acta.
6. **[P]** `source_reference`, `provenance` y `license_reference` son obligatorios para CDT, CAO, Nomenclador Nacional, nomencladores institucionales, CIE-10 y SNOMED cuando la fuente lo exija.

---

## 4. Particularidades DENTAR

| Correspondencia | Destino | Regla |
|---|---|---|
| `DENTAR-PR` → CDT | `os_concept_mapping` | system `CDT-<edición>`; conservar descripción oficial, categoría/subcategoría y licencia; no equivalencia automática. |
| `DENTAR-PR` → Nomenclador Nacional | `os_concept_mapping` | system `NOMENCLADOR-AR-<edición>`; conservar `01.01`, capítulo, normas y vigencia. |
| `DENTAR-PR` → nomenclador institucional | `os_concept_mapping` | una fila por institución/jurisdicción; arancel y cobertura fuera de la identidad clínica. |
| `DENTAR-DX` → CIE-10 | `os_concept_mapping` | edición explícita; `broader`/`narrower` solo con jerarquía verificada. |
| `DENTAR-PR`/`DX` → SNOMED CT AR | `os_concept_mapping` | refset/versión y `mapAdvice` en justificación cuando aplique. |
| `DENTAR-PR` → `DENTAR-DX` | `os_catalog_relation` | nunca `os_concept_mapping`. |

**[H]** El acta documental registra 237 mapeos `dentar_concept_mapping` con `system_code='NOMENCLADOR-AR'` y 138 identificadores sobre DENTAR-PR (`propuesta-arquitectura-catalogos-sanitarios.md:485-492`). El artefacto del nomenclador crea identificadores secundarios en ambos sentidos y relaciones `referencia_literal` sin juicio de equivalencia clínica (`nomenclador_odontologico_nacional.sql:105-113,438-449,495-606`). **[I]** Es evidencia histórica; este documento no modifica esas filas.

**[H]** El CSV DENTAR generado incluye `cdt_2025` y `snomed_sctid` (`docs/dentar/generado/dentar-pr-cdt-2025.csv:1-6`), pero no hay licencia ADA ni diff entre ediciones en el repositorio. **[P]** Los campos `source_reference`, `provenance` y `license_reference` deben quedar incompletos o `unknown` hasta que exista evidencia; nunca se completan por inferencia.

---

## 5. Particularidades OFTAR

- `OFT-PR` → Nomenclador Nacional / CAO / Regional NOA: correspondencia terminológica; los códigos externos conservan su numeración.
- `OFT-DX` → CIE-10-ES 2026 / ICD-10-CM 2027: edición obligatoria; CM como referencia externa.
- SNOMED: selectivo, refset `447562003`, sin equivalencia automática.
- `OFT-PR` ↔ `OFT-DX`: relación clínica en `os_catalog_relation`.

---

## 6. Cambios de edición

**[P]** Cuando cambia una edición de CDT, SNOMED, CIE-10 u otro sistema:

1. se registra la nueva edición como sistema/versión nuevo;
2. se crean nuevas filas de mapeo con vigencia, sin alterar la identidad DENTAR/OFTAR;
3. se marcan las correspondencias afectadas para revisión;
4. se preserva el histórico y la auditoría;
5. nunca se reescribe una aprobación anterior.

---

## 7. Límite

**[P]** Nada de lo anterior autoriza a importar datos ni a aprobar correspondencias por coincidencia textual. Toda carga requiere autorización explícita, acta y verificación posterior.
