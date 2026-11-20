# Acta U7 · Sistema de Gobernanza y Valoración de Prestaciones Sanitarias

**Estado:** APROBADA.
**Fecha:** 2026-11-20.
**Autorización:** aprobación expresa del responsable para ampliar el alcance del
plan U0–U6. Respuestas registradas: (1) registrar la decisión en documentación;
(2) elegir el modelo de identidad de prestación a criterio del agente dentro de
las opción propuesta; (3) continuar con el flujo del panel.

Esta acta **amplía el alcance conceptual** de la gobernanza UVR. No modifica las
decisiones C1–C12 del acta
[`gobernanza-uvr-acta-u0.md`](gobernanza-uvr-acta-u0.md), no autoriza SQL,
commits, push ni despliegue, y deja vigente la verificación en base de U0–U6.

## 1. Decisión de alcance

La valoración UVR **no pertenece exclusivamente a DENTAR** ni a un nomenclador
odontológico. Es una capacidad transversal del sistema: puede asociarse a
cualquier código que represente una **prestación o procedimiento valorable**,
cualquiera sea el catálogo donde esté definido.

El nombre interno y documental del conjunto pasa a ser **Sistema de Gobernanza y
Valoración de Prestaciones Sanitarias**, con dos capacidades:

1. **Gobernanza de catálogos:** códigos, descripciones, conceptos, relaciones,
   equivalencias y clasificación.
2. **Gobernanza de prestaciones y valoración:** identidad de la prestación,
   componentes UVR, metodología, vigencia, fuentes, revisión y aprobación.

La UVR es un **mecanismo de valoración dentro de la segunda capacidad**, no el
nombre del sistema. El término visible en la interfaz sigue siendo **Gestión**
(decisión aprobada en U0); el cambio terminológico es documental e interno.

## 2. Decisiones aprobadas

| ID | Decisión | Consecuencia operativa |
|---|---|---|
| U7.1 | UVR transversal a prestaciones de cualquier catálogo. | Se retira el carácter odontológico-exclusivo del modelo. |
| U7.2 | La identidad de la prestación es una entidad propia, **`os_prestacion`**, independiente de `os_catalog_item`. | Decisión adoptada por el agente entre las opciones propuestas: tabla nueva, no catálogo interno de referencia. Evita un parche sobre el FK `NOT NULL` de `os_uvr_valuation.service_item_id`. |
| U7.3 | Elegibilidad por **tipo de prestación y evidencia**, nunca por catálogo. | `os_uvr_eligible_catalog` deja de ser la regla de fondo; pasa a ser un dato legacy que se conserva intacto. |
| U7.4 | Un **perfil de valoración** define metodología, componentes aplicables, alcance, jurisdicción, versión, revisión y aprobación. | Entidad objetivo `os_uvr_profile`; `methodology` de texto libre queda como legado. |
| U7.5 | Un componente puede ser **aplicable, no aplicable o pendiente de determinación**. No se imponen los tres componentes a toda prestación. | El total respeta la metodología del perfil, no una suma fija. |
| U7.6 | Un mapeo o correspondencia **nunca copia ni deriva UVR**. Equivalencia clínica no implica equivalencia económica. | Los vínculos son navegación y trazabilidad; cada valoración se justifica por separado. |
| U7.7 | Diagnósticos, medicamentos, insumos y conceptos clínicos generales **no reciben UVR por el solo hecho de existir** en un catálogo. | Se conserva la exclusión de `dentar-dx` y se extiende el criterio a CIE-10, ANMAT e insumos. |
| U7.8 | Sí corresponde UVR a **procedimientos diagnósticos** (endoscopía, biopsia, imagen con lectura profesional) cuando implican trabajo y recursos. | La regla prohíbe el diagnóstico como concepto, no todo lo que contenga la palabra «diagnóstico». |
| U7.9 | La competencia por especialidad se resuelve con los **grants por catálogo y los 14 permisos existentes**. | No se crean permisos nuevos sin acta independiente. |
| U7.10 | API pública, OpenAPI, guardia `/v1/*` y FHIR quedan **sin cambios**. | No se crean `/v1/uvr` ni `/fhir/*`. |
| U7.11 | Legado intacto, correcciones con **nueva fila**, sin `UPDATE`. | Se mantiene C12; la migración futura es aditiva. |

## 3. Modelo objetivo (no implementado en esta acta)

| Entidad | Responsabilidad |
|---|---|
| `os_prestacion` | Identidad común de la prestación; independiente de catálogo e idioma. |
| `os_prestacion_codigo` | Vínculo validado entre la prestación y un código de cualquier catálogo (DENTAR-PR, nomenclador odontológico, SNOMED procedures, institucional). Sin copia de valores. |
| `os_uvr_profile` | Metodología, alcance, jurisdicción, vigencia, versión, revisor y aprobador. |
| `os_uvr_profile_component` | Aplicabilidad de cada componente dentro del perfil. |

La valoración se asocia a la **prestación de referencia** y al **perfil**. Un
mismo código puede participar de varias prestaciones; una misma prestación puede
tener más de un perfil con contextos distintos, siempre con justificación y dos
revisiones. `total_uvr`, `importe_referencial` y `estimated_payment` siguen siendo
**derivados** y se rigen por C1/C7/C2.

## 4. Deuda actual que esta decisión declara

Estos puntos contradicen el modelo objetivo y se corrigen en fases posteriores,
no en esta acta:

1. `UvrGovernanceService::CATALOG_CODE = 'dentar-pr'` fija el catálogo de propuesta.
2. `os_uvr_valuation.service_item_id` apunta a `os_catalog_item(id)` y es `NOT NULL`.
3. `os_uvr_eligible_catalog` es un allowlist por catálogo, no por prestación.
4. `component_type` tiene CHECK cerrado a tres valores y las listas están
   repetidas en el controlador y el servicio.
5. `methodology` es texto libre, sin versión ni aprobación de perfil.
6. La revisión por especialidad no tiene ámbito por perfil metodológico.

## 5. Fases posteriores (aprobadas para implementación)

El responsable aprobó U7-B/C/D el 2026-11-20. La aprobación habilita preparar
artefactos y código, **no ejecutar SQL, publicar ni desplegar**: la migración y
su verificación quedan a cargo del responsable de la base, con backup verificado.

| Fase | Contenido | Estado |
|---|---|---|
| U7-A | Esta acta y la referencia documental. Sin SQL. | **Aprobada y aplicada.** |
| U7-B | SQL aditivo: seis entidades del §3, vista derivada, vista pública, REVOKE por tabla, grants puntuales a `origen_admin` y `origen_med`, auditoría append-only. Sin `UPDATE` al legado ni `ALTER DEFAULT PRIVILEGES`. | **Aprobada; aplicada y verificada por el responsable el 2026-11-20** (`COMMIT` de la migración y `ROLLBACK` del verificador de 11 secciones). |
| U7-C | PHP del panel: quitar `CATALOG_CODE` fijo, perfil + prestación, validación por prestación, ámbito por grants. Conserva fallback a U0–U6 cuando U7-B no está aplicado. | **Aprobada; implementada con detección de esquema, no desplegada.** |
| U7-D | Exposición pública/Browse de la prestación valorada, sin `/v1/uvr` ni `/fhir/*`. `estimated_payment` nunca se expone; el importe visible es `importe_referencial`. | **Aprobada; implementada con vista filtrada, no desplegada.** |

Con U7-B aplicado, las seis tablas nuevas están vacías: no se cargaron
prestaciones, perfiles ni valores inventados. El panel mantiene la degradación
a U0–U6 mientras no existan prestaciones y perfiles gobernados, pero el selector
de catálogos ya muestra todos los catálogos UVR gobernados (excluidos
`dentar-dx`, terminologías e insumos según U7.7) y respeta los grants por
catálogo sin crear permisos nuevos. La elegibilidad plena por prestación se
activa cuando el responsable cargue, con aprobación, al menos una prestación y
un perfil. Hasta ese momento, la **publicación** de valoraciones legacy sigue
sujeta al guardián `os_uvr_eligible_catalog` de U0–U6 (`dentar-pr`).
