# Diseño de interfaz de consulta de OFTAR

**Fecha:** 2026-11-28
**Versión:** 1.0
**Documento rector:** `especificacion-definitiva-reconstruccion-oftar.md` v1.0
**Estado:** OFTAR v1.0 — Especificación técnica consolidada, con modelo integral de relaciones clínicas y terminológicas, preparada para iniciar la implementación controlada. (No autoriza ejecución.)
**Convención:** `[H]` hecho verificado en repositorio · `[I]` inferencia · `[P]` propuesta no implementada.

---

## 0. Método y límite

**[H]** Diseño preparado por lectura de controladores, vistas y repositorios. No se ejecutaron SQL, seeds, migraciones ni pruebas. Los wireframes son propuestas de maquetación, no capturas de una pantalla existente.

---

## 1. Base verificada

**[H]** `portal/Controllers/BrowseController.php:15` define las pestañas `concept`, `relations`, `values`, `validity`, `clinical`, `trace`. `rel_view` se normaliza a `table|diagram` con default `table` (`:54-55`) y se conserva en el estado canónico de la URL (`:92`). Los filtros y la paginación históricos se normalizan en `:37-47,79-102`.

**[H]** `portal/Views/partials/browse/detail/relations.php` ya implementa el conmutador tabla/diagrama con `aria-pressed` (`:40-52`), filtros por tipo y sistema (`:54-71`), tabla con `scope="col"` (`:121-180`) y nodos de diagrama (`:74-119`). El enlace a ficha solo existe si `result_key` resuelve (`:93-97,145-161`).

**[H]** `portal/Repositories/CatalogRepository.php:2992-3121` hoy mezcla mapeos y relaciones en una lista única con `type`, `role`, `direction`, `result_key` y dedupe por `system|code|type` (`:3124-3149`). La separación visual propuesta es una capa de presentación aditiva: **no cambia ese repositorio ni su contrato actual**.

**[H]** La API de detalle expone `mappings` y `related_codes`, pero no `os_catalog_relation` (`api/services/CatalogEngineService.php:528-628`). El contrato nuevo `data.relations{clinical,terminological}` se documenta en `contratos-api-relaciones-oftar.md` y no está implementado.

---

## 2. Wireframe textual: ficha OFTAR-PR / OFTAR-DX

**[P]** Estructura obligatoria para ambas fichas. Los bloques marcados con `·` son los que el rector exige en la ficha; las pestañas existentes se conservan.

```
+--------------------------------------------------------------------------------+
| migas: Inicio / Buscar / OFTAR / [PR o DX] / OFT-PR-000000                      |
+--------------------------------------------------------------------------------+
| [H] IDENTIFICADOR                                                              |
|  Código permanente: OFT-PR-000000   Código oficial: 000000   Estado: activo     |
|  Sistema / edición / versión / release / vigencia: ver bloque FUENTE            |
+--------------------------------------------------------------------------------+
| [H] CANÓNICO                                                                   |
|  Término preferido (es-AR, aprobado)                                           |
|  Sinónimos · siglas · variantes · etiqueta idioma / sin traducir (si aplica)    |
+--------------------------------------------------------------------------------+
| [H] DESCRIPCIÓN / DEFINICIÓN                                                   |
|  Definición · criterios clínicos · definición corta · términos legos           |
|  Estado por campo: aprobado / pendiente (texto no aprobado = no publicado)      |
+--------------------------------------------------------------------------------+
| ALCANCE  |  CATEGORÍA  |  TÉCNICA  |  ÁREA  |  ANATOMÍA                          |
| scope    | category + | modalidad | AREA-* | ANAT-* + ATTR-STRUCTURE           |
|          | clinical_  | ATTR-     | (multi)| ATTR-LATERALIDAD                   |
|          | category   | MODALITY  |        | (jerarquía sin propagación)        |
+--------------------------------------------------------------------------------+
| FUNCIONES  |  CONDICIONES                                                      |
|  funciones declaradas / alteraciones funcionales    | diagnóstico justificante |
+--------------------------------------------------------------------------------+
| PESTAÑAS: [Datos] [Relaciones] [Valores] [Vigencia] [Clínica] [Trazabilidad]    |
|   ^ concept tab se conserva: "Datos" en la vista; tab=relations sin renombrar   |
+--------------------------------------------------------------------------------+
| CONTENIDO DE LA PESTAÑA RELACIONES  (tab=relations)                            |
|  Vista: [Tabla] [Diagrama]   <- rel_view=tabla|diagrama se conserva            |
|  Filtros: clase | tipo | dirección | sistema | edición | estado | vigencia     |
|  (Clínica)  [badge CLÍNICA]     filas de os_catalog_relation                    |
|  (Termino.) [badge TERMINOLÓGICA] filas de os_concept_mapping + metadata       |
+--------------------------------------------------------------------------------+
| CÓDIGOS RELACIONADOS  (8 grupos ordenados; ver §3)                              |
+--------------------------------------------------------------------------------+
| FUENTE / VIGENCIA                                                              |
|  sistema · edición · versión · release/fecha · código original                 |
|  descripción original · idioma · procedencia · source_reference                |
|  content_hash · valid_from / valid_to · responsable · revisión · auditoría      |
+--------------------------------------------------------------------------------+
```

**[P]** Diferencias de ficha:

- **PR:** la sección «Técnica» incluye modalidad y alcance/sesiones; «Valores» muestra UVR de trabajo profesional, gastos, responsabilidad y total solo cuando existan y estén aprobados. Los importes de CAO y Regional se presentan separados, sin conversión.
- **DX:** «Condiciones» incluye CIE-10-ES 2026, ICD-10-CM 2027 y SNOMED CT Argentina Edition con su edición explícita; los 17 códigos exclusivos CM conservan descripción `en` y se marcan «no traducido al es-AR», sin inventar traducción. No hay UVR.

**[P]** Navegación: las pestañas y los filtros conservan la URL canónica actual (`q`, `domain`, `catalog`, `family`, `type`, `category`, `status`, `version`, `validity`, `page`, `limit`, `tab`, `rel_view`). La paginación respeta `MAX_OFFSET=5000` y `MAX_PAGE_SIZE=100` (`CatalogRepository.php:56-57`). Ningún filtro nuevo renombra los históricos.

---

## 3. Wireframe textual: «Códigos relacionados»

**[P]** Ocho grupos, **siempre en este orden**, con encabezados colapsables y contadores. Dentro de cada grupo, orden por sistema, código y tipo; las filas sin destino OFTAR se muestran como texto, nunca como enlace roto. **Los marcadores `<…>` son posiciones de maquetación: no son códigos, tipos ni aprobaciones reales.** El tipo y el estado se muestran solo cuando la fila persistida los contiene y su revisión permite la visibilidad pública.

```
CÓDIGOS RELACIONADOS  (de <OFT-PR-OFT-DX>)
+--- 1. Otros OFTAR -----------------------------------------------------------+
| [Clínica] <código OFTAR> · Descripción canónica · OFTAR · <REL-...> · alcance |
|   fuente: <matriz/procedencia> · estado: <estado real> · vigencia: <si existe>|
+--- 2. Nomenclador Nacional ---------------------------------------------------+
| [Terminológica · <mapping_type>] <código> · Descripción original · NN 2025   |
|   alcance: <alcance> · fuente: <archivo/fila> · estado: <estado real>        |
+--- 3. CAO --------------------------------------------------------------------+
| [Terminológica · <mapping_type>] <código> · Descripción original · CAO       |
|   alcance: <alcance> · fuente: CAO · estado: <estado real>                   |
+--- 4. Regional NOA -----------------------------------------------------------+
| [Terminológica · <mapping_type>] <código> · Descripción original · Regional  |
|   alcance: <alcance> · fuente: Regional · estado: <estado real>              |
+--- 5. CIE-10 -----------------------------------------------------------------+
| [Terminológica · <mapping_type>] <código> · Descripción original · CIE-10    |
|   estado: draft -> SOLO vista editorial; público: oculto / sin equivalencia  |
+--- 6. CIE-10-ES --------------------------------------------------------------+
| [Terminológica · <mapping_type>] <código> · Descripción original · ES 2026   |
|   alcance: <alcance> · fuente: edición española · estado: <estado real>      |
+--- 7. ICD-10-CM --------------------------------------------------------------+
| [Terminológica · <mapping_type>] <código> · Descripción en · CM 2027         |
|   referencia externa, NO norma argentina; 17 exclusivos sin traducir         |
+--- 8. SNOMED CT Argentina ----------------------------------------------------+
| [Terminológica · <mapping_type>] <código> · FSN · SNOMED CT AR Edition       |
|   refset 447562003 · mapAdvice conservado · estado: <estado real>            |
+------------------------------------------------------------------------------+
```

**[P]** Columnas obligatorias de cada elemento: **código · descripción · sistema · tipo de relación · alcance · fuente · estado de revisión**. Se añaden edición/versión y vigencia cuando existan. Si un dato no existe, se muestra «desconocido» o se omite la celda con guion; nunca se completa con un valor inferido.

**[P]** Enlace a ficha OFTAR solo cuando existe `result_key` verificable y apunta a un ítem real. Si el destino es externo o no tiene ítem OFTAR, se muestra la identificación y la procedencia en texto plano, sin `href`, sin icono de enlace y sin `aria-label` que sugiera navegación. Esto conserva el comportamiento actual de `relations.php:93-97,145-161`.

---

## 4. Reglas visuales y de accesibilidad

**[P] V1 — Diferenciación VISUAL obligatoria.** Toda fila o nodo lleva una etiqueta textual explícita además del color:

| Clase | Badge | Tratamiento visual sugerido | Texto para lector de pantalla |
|---|---|---|---|
| Relación clínica | **«Clínica»** | Borde sólido + color azul institucional + icono de cadena | «Relación clínica: tipo …» |
| Correspondencia terminológica | **«Terminológica · <mapping_type>»** | Borde punteado + color ámbar + icono de conversión | «Correspondencia terminológica de tipo <mapping_type>: …» |

**[P] V2.** El color **nunca es el único indicador**: se exige el badge textual, el borde/forma y el atributo `data-rel-class`. `equivalent`, `related`, `narrower`, `broader` y `unmatched` se escriben siempre; «exacta» queda reservado a etiquetas documentales históricas y no se usa como valor de interfaz sin contexto.

**[P] V3.** Contraste mínimo WCAG AA para texto y badges; foco visible en enlaces, selects y pestañas; `aria-pressed` en el conmutador tabla/diagrama (ya presente en `relations.php:48`); `scope="col"` en encabezados (`:124-132`); `role="group"` y `aria-label` en filtros (`:40`).

**[P] V4.** Los filtros anuncian cambios con una región `aria-live="polite"` que indica «N resultados visibles». La tabla conserva orden por teclado; el diagrama ofrece `<details>/<summary>` y una tabla equivalente accesible desde el propio diagrama, sin depender de posición espacial.

**[P] V5.** Estado pendiente/no aprobado: en vista editorial autorizada se muestra badge «Pendiente» con color neutro/advertencia y se indica que **no es público**. En vista pública esas filas no existen: no se atenúan ni se muestran como borrador navegable.

**[P] V6.** Vigencia vencida o retirada se marca con texto «Retirado»/«Vigencia finalizada» y fecha; no se elimina la fila del historial. `motion` reducido: sin animaciones de expansión obligatorias.

**[P] V7.** Las ocho secciones de «Códigos relacionados» son colapsables pero **todas están presentes en el DOM** y enumeradas en un índice; un grupo vacío muestra «Sin registros publicados», no se oculta por completo.

---

## 5. Lo que NO debe mostrarse como equivalencia

**[P] N1.** Un número coincidente entre sistemas: CAO `460105`, Regional `305022` o NN y un código CIE/CM con la misma cadena. La resolución es por **sistema + edición + release**, no por texto (rector §4).

**[P] N2.** `referencia_literal` ni las relaciones de facturación (`alternate_benefit`, `not_paid_separately`, `billed_in_conjunction_with`, etc.). Son vínculos literales o administrativos, no juicio de equivalencia clínica (`nomenclador_odontologico_nacional.sql:538-545,580-584`).

**[P] N3.** `related`, `approximate`, `partial`, `unmatched` ni `mapping_nature='not_mappable'`. «Relacionado» se muestra como relacionado; «sin correspondencia» como sin correspondencia (`origen_catalog_engine.sql:125-126`; `fase3_relaciones_mapeos.sql:125-127`).

**[P] N4.** CIE-10-ES 2026 frente a ICD-10-CM 2027. Los 17 códigos exclusivos CM son referencia externa independiente; no se presentan como versión argentina ni se traducen automáticamente (rector §3 y §4). CIE-10-ES no se rotula «norma argentina» sin acta.

**[P] N5.** Mapeos SNOMED del refset `447562003` con `mapAdvice` conservado en `clinical_rationale`: son enriquecimiento gobernado con `mapping_type='related'`, **no** equivalencias de procedimientos ni importación masiva (rector §3).

**[P] N6.** Filas con `review_status` distinto de `approved`, con revisión de campo no vigente o con `content_hash` desactualizado. Tampoco solicitudes `draft`/`in_review`, decisiones sin evidencia ni un hipotético valor `rejected`: el rechazo es decisión de gobernanza, no estado de CHECK (rector §9.2).

**[P] N7.** Similitud textual, descripciones parecidas o una matriz documental no aprobada. La aprobación documental de 13 pares PR no es aprobación clínica (rector §2 y §9).

**[P] N8.** Agrupaciones anatómicas. `ANAT-UVE` no sustituye a `ANAT-COROID`; `ANAT-SUP` no propaga automáticamente córnea, conjuntiva y película lagrimal; `ANAT-NEU` no se usa para motilidad (rector §6 y §15.3).

**[P] N9.** UVR, aranceles, importes migrados ni columnas de equivalencia de facturación. La clase clínica y la clase terminológica no se presentan como justificación de cobertura.

**[P] N10.** CIE-10-PCS como generador de diagnósticos o códigos OFTAR nuevos; solo referencia quirúrgica justificada (rector §4).

**[P] N11.** Un enlace a ficha inexistente, un badge «Terminológica» aplicado a una relación clínica, o un badge «Clínica» aplicado a un mapeo: son clases distintas y deben permanecer separadas también en la interfaz.

---

## 6. Cierre

**[P]** La interfaz propuesta pone las relaciones en el centro de la consulta y conserva todas las rutas, filtros, pestañas y `rel_view` existentes. Es un diseño preparado para implementación controlada; **no autoriza ejecución** ni modifica el portal actual.
