# Extensibilidad futura de OFTAR

**Fecha:** 2026-11-28
**Etapa:** tercera revisión — solo documentación.
**Estado:** diseño preparatorio. **OFTAR-AN, OFTAR-IN y OFTAR-DI NO se crean en esta etapa.**
**Convención:** `[H]` hecho verificado · `[I]` inferencia · `[P]` decisión propuesta.

---

## 1. Principio general

**[H]** El motor `os_catalog` ya soporta múltiples catálogos, releases, versiones, términos, identificadores, relaciones, mapeos, auditoría y gobernanza (`sql/02_catalogs/origen_catalog_engine.sql`, `sql/07_multilingue`). El dominio `oftar` es único y los catálogos son `oftar-pr` y `oftar-dx`.

**[I]** Incorporar nuevos catálogos no requiere un motor nuevo: basta un catálogo nuevo dentro del mismo dominio y relaciones gobernadas hacia los conceptos existentes. Lo que sí debe evitarse es crear relaciones ficticias o marcar compatibilidades clínicas sin evidencia.

**[P]** Regla de oro: **catálogo nuevo = identidad propia + relaciones verificadas**. Ningún concepto de AN/IN/DI se genera por inferencia automática desde una descripción.

---

## 2. Catálogos previstos y relaciones permitidas

| Catálogo futuro | Naturaleza | Relación prevista con OFTAR-PR / OFTAR-DX | Evidencia mínima antes de crearla |
|---|---|---|---|
| **OFTAR-AN** | Estructuras anatómicas | Un procedimiento **se realiza sobre** una estructura; un diagnóstico **afecta** una o varias estructuras | Terminología anatómica verificada y decisión editorial del concepto |
| **OFTAR-IN** | Insumos | Un procedimiento **utiliza** uno o varios insumos | Indicación del insumo en la práctica o nomenclador de origen |
| **OFTAR-DI** | Dispositivos | Un dispositivo **está indicado para** un procedimiento; un procedimiento **implanta** un dispositivo | Declaración del fabricante, nomenclador o evidencia clínica aprobada |

**[P]** Las relaciones se modelan con los mecanismos existentes (`os_catalog_relation`, `os_concept_mapping`, tablas puente de dominio cuando corresponda), nunca con códigos OFTAR nuevos que codifiquen la combinación. Por ejemplo: **no** crear `OFT-PR-XXXXXX` para “cirugía con dispositivo Y”.

---

## 3. Ejemplos de uso — solo como patrón, no como datos cargados

| Patrón | Concepto de origen | Concepto de destino | Relación propuesta | Estado |
|---|---|---|---|---|
| Procedimiento → anatomía | `OFT-PR-…` queratoplastia | `OFT-AN-…` córnea | `performed_on` / `affects_structure` | `[P]` patrón, sin código asignado |
| Procedimiento → insumo | `OFT-PR-…` cirugía de catarata | `OFT-IN-…` lente intraocular | `uses` | `[I]` el núcleo declara exclusiones de lente; debe revisarse antes de vincular |
| Dispositivo → procedimiento | `OFT-DI-…` dispositivo de drenaje | `OFT-PR-…` cirugía de glaucoma | `indicated_for` | `[P]` patrón, sin compatibilidad clínica afirmada |
| Diagnóstico → anatomía | `OFT-DX-…` retinopatía | `OFT-AN-…` retina | `affects_structure` | `[P]` patrón; actualmente resuelto por atributo anatómico |
| Diagnóstico → procedimiento | `OFT-DX-…` catarata | `OFT-PR-…` facoemulsificación | `treated_by` | `[P]` patrón; usar `oftar_concept_diagnosis` con rol revisado |
| Procedimiento → diagnóstico | `OFT-PR-…` terapia láser | `OFT-DX-…` retinopatía diabética | `indicated_for` | `[P]` patrón; requiere indicación verificada |

**[P]** Ninguno de estos ejemplos implica que la relación ya exista en datos. Sirven para definir el tipo semántico y la dirección antes de que el usuario apruebe la creación de los catálogos.

---

## 4. Requisitos para futuras incorporaciones

1. **Identidad permanente:** cada catálogo nuevo usa su propio prefijo, con numeración independiente; no reutilizar `OFT-PR-` ni `OFT-DX-` para AN/IN/DI.
2. **Categoría clínica propia:** definir `CLIN-*` solo si el tipo de concepto lo justifica; no reutilizar `CLIN-DIAG` para anatomía o insumos por conveniencia.
3. **Multilingüe:** descripciones en `es-AR`, `en`, `pt-BR` según la política de Origen Salud; sin columnas `name_en`/`name_pt` ad hoc.
4. **Procedencia:** todo concepto nuevo declara sistema, edición, versión, release, idioma y procedencia según la política definitiva.
5. **Gobernanza:** dos revisiones, `review_status`, hash y traza en `os_audit_log`.
6. **Sin publicación automática:** las relaciones se publican solo con evidencia y aprobación humana.
7. **API aditiva:** nuevos filtros o facets no quitan `category` ni `clinical_category`.

---

## 5. Decisiones sin migración frente a ampliación futura

| Necesidad | Sin migración | Ampliación futura |
|---|---|---|
| Crear catálogo AN/IN/DI en el mismo dominio | Sí, como datos de `os_catalog` | No |
| Relacionar conceptos con `os_catalog_relation` | Sí | No, salvo nuevos `relation_type` no representables |
| Mantener anatomía como atributo en PR/DX | Sí | No |
| Compatibilidad dispositivo–procedimiento multivaluada | Sí, con relaciones | Solo si se exige un campo estructurado propio |
| UVR de insumos/dispositivos | No en esta etapa | Requiere modelo y aprobación separados |

**[P]** Hasta que se apruebe la creación de AN/IN/DI, las relaciones anatómicas de PR/DX se resuelven con atributos y no se reservan códigos futuros.

---

## 6. Cierre

**[I]** La arquitectura actual ya es extensible; el riesgo no es técnico sino editorial: crear catálogos o relaciones antes de tener evidencia verificable.

**[P]** OFTAR queda preparado para AN/IN/DI sin haberlos desarrollado. Toda compatibilidad clínica queda pendiente de aprobación explícita.
