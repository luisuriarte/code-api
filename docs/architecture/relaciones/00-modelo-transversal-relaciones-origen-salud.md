# Modelo transversal de relaciones clínicas y terminológicas de Origen Salud

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector general:** `docs/architecture/propuesta-arquitectura-catalogos-sanitarios.md`
**Documento rector de OFTAR:** `docs/audit/especificacion-definitiva-reconstruccion-oftar.md`
**Estado:** modelo transversal obligatorio incorporado a la arquitectura general y a la especificación de OFTAR. Primera aplicación: DENTAR y OFTAR. (No autoriza ejecución, migraciones, seeds ni escrituras en PostgreSQL.)

**Convención:** `[H]` hecho verificado en repositorio o en acta documental citada · `[I]` inferencia técnica · `[P]` decisión de diseño propuesta/sujeta a ratificación.

---

## 1. Cambio de alcance

**[P]** El modelo de relaciones deja de ser una capacidad exclusiva de OFTAR. Pasa a ser una **capacidad transversal del motor de catálogos de Origen Salud**, aplicable a todas las familias.

- **Primera aplicación obligatoria:** DENTAR (`dentar-pr`, `dentar-dx`) y OFTAR (`oftar-pr`, `oftar-dx`).
- **Aplicación futura sin rediseño:** NN-PMO, NBU, NHPGD, ANDIS, KINESIOLOGIA, SALUD_MENTAL y cualquier familia nueva.
- **Prohibición arquitectónica:** no crear un modelo de relaciones independiente por catálogo, ni un motor paralelo al canónico `os_catalog`.

**[H]** La arquitectura general ya fijó los principios de «infraestructura compartida», «un solo modelo de relaciones» y «extensibilidad real» (`propuesta-arquitectura-catalogos-sanitarios.md:319-324`), y declaró que una familia es una fila con `product_role='family'`, no una tabla nueva (`:349-353`).

---

## 2. Los tres componentes

El motor distingue tres responsabilidades que están integradas pero no se confunden:

| # | Componente | Pregunta que responde | Destino canónico |
|---:|---|---|---|
| 1 | **Identidad y definición del concepto** | «¿Qué es y cómo se identifica?» | `os_catalog`, `os_catalog_release`, `os_catalog_item`, `os_catalog_item_version`, `os_catalog_term`, `os_catalog_identifier`, `os_catalog_category` (`origen_catalog_engine.sql:12-105`). |
| 2 | **Relaciones clínicas, anatómicas y funcionales** | «¿Cómo se vincula este concepto con otro concepto del motor?» | `os_catalog_relation` + clasificación `os_relation_kind` / `os_relation_type` (`nomenclador_odontologico_nacional.sql:534-559`; `fase3_relaciones_mapeos.sql:60-113`; `fase1_infraestructura.sql:42-68`). |
| 3 | **Correspondencias terminológicas externas** | «¿A qué código de otro sistema corresponde?» | `os_concept_mapping` + `os_mapping_metadata` + `os_terminology_system` (`origen_catalog_engine.sql:111-136`; `fase3_relaciones_mapeos.sql:118-147`). |

**[P] Regla de oro:** las tres componentes comparten identidad de concepto y gobernanza, pero **no se fuerzan dentro de una única estructura**. Un mapeo no es una relación clínica; una relación clínica no es un mapeo; un identificador no es una definición.

---

## 3. Decisión sobre separación física

**[H]** `os_concept_mapping` tiene un solo `item_id` interno, un solo `terminology_system_id`, un `external_code`, un `relationship_role`, `mapping_type` con cinco valores y `UNIQUE(item_id, terminology_system_id, external_code, relationship_role)` (`origen_catalog_engine.sql:119-133`). No puede representar dos ítems internos, dirección clínica, `context_text` ni `source_field`.

**[H]** `os_catalog_relation` tiene dos FKs a `os_catalog_item`, `relation_type`, `source_system_code`, `source_field`, `source_value`, `context_text`, `review_status`, `provenance` y `UNIQUE` de siete columnas (`nomenclador_odontologico_nacional.sql:534-559`). Fase 3 añadió `valid_from`, `valid_to`, catálogos y releases de ambos extremos, `relation_kind`, método, confianza, responsable, licencia e inversa (`fase3_relaciones_mapeos.sql:60-73`). No puede representar un código externo sin convertirlo en ítem interno.

**[P] Decisión:** **mantener dos tablas con responsabilidades distintas**. No se crea una tabla nueva para el modelo transversal y no se duplican conceptos externos como ítems de catálogo.

- Clínica/anatomía/función → `os_catalog_relation`.
- Terminología externa → `os_concept_mapping` + `os_mapping_metadata`.
- Tipos gobernados → `os_relation_type` / `os_relation_kind` (presentes en SQL de Fase 1; su estado en ejecución debe verificarse en el acta `READ ONLY`).
- El valor `relation_type` heredado (15 tipos CDT y `referencia_literal`) se conserva; el tipo semántico OFTAR/DENTAR se propone en `relation_type_code` aditivo con FK, **sin ejecutar**.

**[I]** Separar físicamente es más seguro que unificar: evita usar `mapping_type='related'` como comodín para relaciones clínicas y evita convertir cada código de CDT, CAO o SNOMED en un ítem interno.

---

## 4. Modelo común de datos

Todo lo que debe poder identificarse se resuelve con campos existentes o con adiciones propuestas y justificadas:

| Requisito | Origen clínico (`os_catalog_relation`) | Correspondencia (`os_concept_mapping`) |
|---|---|---|
| Concepto de origen | `source_item_id` | `item_id` |
| Catálogo / familia / dominio de origen | derivado por `os_catalog_item.catalog_id → os_catalog.code/family_code/domain_type`; opcional `source_catalog_id`, `source_release_id` | derivado del mismo modo desde `item_id` |
| Concepto de destino interno | `target_item_id` | no aplica; se resuelve por identificadores cuando coincide |
| Catálogo / familia / dominio de destino | derivado desde `target_item_id`; opcional `target_catalog_id`, `target_release_id` | `terminology_system_id` + `external_code`; nunca un ítem duplicado |
| Tipo de relación | `relation_type` heredado o `relation_type_code` propuesto; `relation_kind` | `mapping_type` + `mapping_nature` |
| Dirección | `source_item_id → target_item_id`; `inverse_relation_type` propuesto | fija OFTAR/DENTAR → externo; `relationship_role` califica el rol |
| Fuente | `source_system_code`, `source_field`, `source_value`, `provenance` | `os_terminology_system.code`, `provenance`, `source_reference` |
| Edición / versión | `source_release_id`/`target_release_id`, `source_system_code` con edición, `license_reference` | `os_terminology_system.default_version`, `os_mapping_metadata.source_version/target_version` |
| Justificación / evidencia | `context_text`, `provenance`, `clinical_rationale` documental | `clinical_rationale`, `source_reference`, `provenance` |
| Alcance / contexto | `context_text`, categoría, `clinical_criteria` | `relationship_role`, `mapping_nature`, `context_text` documental |
| Vigencia | `valid_from`/`valid_to`, releases de extremos | `valid_from`/`valid_to` en `os_mapping_metadata` |
| Estado de revisión | `review_status` | `review_status` de mapeo y de metadatos |
| Responsable / historial | `reviewed_by`, `reviewed_at`, `os_audit_log` | `reviewed_by`, `reviewed_at`, `os_audit_log` |

**[P]** `source_value` debe conservarse literalmente. En DENTAR, `01.01` no se transforma en `0101`; en CDT y CAO se conserva el formato original. La normalización solo vive en identificadores derivados, nunca en el código de origen.

---

## 5. Configuración por dominio, familia y catálogo

**[P]** El mecanismo es común; la **política es configurable**. Cada perfil declara:

1. tipos de relación admitidos;
2. combinaciones origen → destino válidas;
3. sistemas externos pertinentes y ediciones aceptadas;
4. reglas de revisión;
5. campos adicionales obligatorios;
6. visibilidad pública o solo editorial.

**[H]** La `os_catalog` ya dispone de `domain_type`, `family_code` y `product_role` (`origen_catalog_engine.sql:12-40`). `os_domain_registry` registra dominios expuestos (`fase1_infraestructura.sql:12-38`). No se crea una tabla nueva de configuración sin aprobación: el perfil se documenta primero en `04-reglas-validez-dominio-catalogo.md` y, si se decide persistirlo, se propone una ampliación aditiva con justificación.

**Ejemplos gobernados:**

| Origen | Destino válido | Sistema externo pertinente | Regla |
|---|---|---|---|
| `dentar-pr` | `dentar-dx`, `dentar-pr`, `dentar-an`, `dentar-cl` | CDT, Nomenclador Nacional, nomencladores provinciales/institucionales, SNOMED CT AR | `DENTAR-PR` conserva su código permanente; los externos son referencia. |
| `dentar-dx` | `dentar-pr`, `dentar-dx` | CIE-10, SNOMED CT AR | Sin UVR ni facturación; no equivalencia por texto similar. |
| `oftar-pr` | `oftar-dx`, `oftar-pr` | Nomenclador Nacional, CAO, Regional NOA, SNOMED CT AR | `OFT-PR-NNNNNN` es maestro; `justifying_diagnosis` no crea relación clínica. |
| `oftar-dx` | `oftar-pr`, `oftar-dx` | CIE-10-ES 2026, ICD-10-CM 2027, SNOMED CT AR | CIE-10-ES no es norma argentina; CM 2027 es referencia externa. |
| DENTAR ↔ OFTAR | solo con justificación clínica documentada | — | Nunca se publica por similitud textual ni se convierte en mapeo. |

---

## 6. Interfaces compartidas

**[H]** Hoy `CatalogRepository::itemRelations()` mezcla mapeos y relaciones en una sola lista (`portal/Repositories/CatalogRepository.php:2992-3121`), y `CatalogEngineService` devuelve `mappings`/`related_codes` pero no consulta `os_catalog_relation` (`api/services/CatalogEngineService.php:528-628`).

**[P]** El destino es una sola proyección `data.relations{clinical, terminological}` y un solo componente de ficha reutilizable para DENTAR y OFTAR, con secciones adaptadas por perfil. `mappings` y `related_codes` se conservan intactos por compatibilidad. Detalle en `10-contratos-api-relaciones-transversales.md` y `09-diseno-interfaz-relaciones-reutilizable.md`.

---

## 7. Documentos del modelo transversal

1. `00-modelo-transversal-relaciones-origen-salud.md` — este documento.
2. `01-modelo-relaciones-clinicas-transversal.md`
3. `02-modelo-correspondencias-terminologicas-transversal.md`
4. `03-diccionario-tipos-relacion-transversal.md`
5. `04-reglas-validez-dominio-catalogo.md`
6. `05-integracion-os-catalog.md`
7. `06-integracion-os-concept-mapping.md`
8. `07-reglas-versionado-relaciones.md`
9. `08-reglas-gobernanza-relaciones.md`
10. `09-diseno-interfaz-relaciones-reutilizable.md`
11. `10-contratos-api-relaciones-transversales.md`
12. `11-plan-pruebas-relaciones-transversales.md`
13. `12-plan-implementacion-relaciones-transversales.md`

---

## 8. Límite

**[P]** Este modelo no ejecuta DDL, DML, migraciones ni seeds. No aprueba equivalencias, no crea códigos nuevos y no modifica identificadores existentes. La primera aplicación práctica queda sujeta a acta `READ ONLY`, firma clínica y autorización explícita posterior.
