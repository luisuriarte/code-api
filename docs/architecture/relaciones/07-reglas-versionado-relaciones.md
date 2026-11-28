# Reglas de versionado del modelo transversal de relaciones

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** reglas propuestas. (No ejecuta cambios de vigencia.)

---

## 1. Niveles de versión

| Nivel | Objeto | Evidencia |
|---|---|---|
| Concepto | `os_catalog_item` + `os_catalog_item_version` | `permanent_code` estable; versión por release/idioma (`origen_catalog_engine.sql:63-82`). |
| Catálogo | `os_catalog_release` | `version_tag`, `valid_from`, `valid_to`, `status` (`origen_catalog_engine.sql:42-52`). |
| Relación clínica | `os_catalog_relation` | `valid_from`, `valid_to`, `source/target_catalog_id`, `source/target_release_id` (`fase3_relaciones_mapeos.sql:60-73`). |
| Correspondencia | `os_concept_mapping` + `os_mapping_metadata` | `source/target_version`, `valid_from`, `valid_to` (`fase3_relaciones_mapeos.sql:118-141`). |
| Campo / traducción | `os_localized_text`, `os_field_review` | `content_hash`, `scope_release_id`, `review_status` (`01_fase2_tablas.sql:55-137`). |
| Publicación | `os_catalog_release.status` y reglas de proyección | `draft|review|published|deprecated` (`origen_catalog_engine.sql:49`). |

**[P]** Son seis planos distintos. Cambiar uno no cambia automáticamente los demás.

---

## 2. Identidad estable

1. **[P]** El identificador permanente (`DNT-*`, `OFT-*`) no cambia por traducción, revisión, cambio de edición externa ni cambio de descripción.
2. **[H]** `os_catalog_identifier` conserva identificadores externos por `(item_id, system_name, value)` (`origen_catalog_engine.sql:92-99`). El código original `01.01` permanece literal.
3. **[P]** Una relación aprobada no se modifica silenciosamente. Si cambia su significado, se cierra la vigencia y se crea una fila nueva con nueva procedencia.
4. **[P]** La `UNIQUE` de siete columnas evita duplicados exactos; no se usa `DELETE` para resolver conflictos (`nomenclador_odontologico_nacional.sql:556-558`).

---

## 3. Vigencia

**[H]** Fase 3 agregó `ck_os_catalog_validity`: `valid_to` puede ser nulo, `valid_from` puede ser nulo, y si ambos existen `valid_to > valid_from` (`fase3_relaciones_mapeos.sql:100-101`). La misma regla existe para metadatos de mapeo (`:139-140`).

**[P]** Reglas operativas:

- vigencia nula = sin fecha estructurada declarada; no equivale a «vigente desde siempre»;
- la vigencia de la relación debe ser compatible con los releases de ambos extremos cuando estén declarados;
- una relación entre conceptos retirados no se publica automáticamente;
- las fechas administrativas de carga no se presentan como normativas (ej. release del Nomenclador Nacional cargado con `CURRENT_DATE`, documentado en `propuesta-arquitectura-catalogos-sanitarios.md:479`).

---

## 4. Cambios de sistemas externos

| Cambio | Acción | Prohibición |
|---|---|---|
| Nueva edición de CDT | Registrar sistema+edición; crear correspondencias nuevas; revisar las afectadas | Reescribir códigos DENTAR. |
| Código CDT eliminado | Marcar vigencia/revisión; conservar fila histórica | Borrar la relación anterior. |
| Código CDT modificado | Nueva fila con nueva vigencia y justificación | Cambiar `external_code` de la fila aprobada. |
| SNOMED nuevo release | Actualizar metadatos y revisar `mapAdvice` | Aprobar por coincidencia de descripción. |
| CIE-10 nueva edición | Declarar edición; no mezclar con la anterior | Usar `CIE-10` sin subtipo. |
| Nomenclador institucional nuevo | Alta con institución, jurisdicción y vigencia | Mezclarlo con `NOMENCLADOR-AR`. |

---

## 5. Historial y auditoría

**[H]** `os_audit_log` registra `entity_type`, `entity_id`, `action`, `actor`, `before_data`, `after_data`, `content_hash` y `created_at` (`fase4_gobernanza.sql:120-131`). **[P]** Toda transición relevante de una relación o mapeo debe dejar traza append-only: creación, revisión, aprobación, deprecación y cambio de vigencia.

**[P]** No se registra `rejected` como valor de `review_status`: el rechazo es una decisión de gobernanza documentada en el historial, sin eliminar la propuesta.

---

## 6. Regla de publicación

**[P]** Una relación se publica solo si:

1. ambos extremos están activos y visibles según su perfil;
2. la versión del concepto está aprobada;
3. los campos usados tienen revisión vigente;
4. la fila de relación o mapeo está `approved`;
5. la vigencia es compatible;
6. la clase es Clínica o Terminológica y se muestra en su sección correspondiente.

**[P]** Si falta alguna condición, la fila permanece en vista editorial o no se muestra. Nunca se completa con datos supuestos.
