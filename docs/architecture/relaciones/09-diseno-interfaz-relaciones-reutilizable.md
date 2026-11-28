# Diseño de interfaz reutilizable de relaciones

**Fecha:** 2026-11-28 · **Versión:** 1.0 · **Modelo rector:** `00-modelo-transversal-relaciones-origen-salud.md`
**Estado:** diseño implementado en código fuente; ejecución, verificación y publicación pendientes en entorno autorizado.

---

## 1. Principio

**[P]** Un solo componente de presentación para todas las familias, con secciones adaptadas por perfil. DENTAR y OFTAR usan el mismo mecanismo; cambian los grupos, sistemas y etiquetas, no el componente.

**[H]** Browse ya tiene pestañas `concept`, `relations`, `values`, `validity`, `clinical`, `trace` y un conmutador tabla/diagrama con `aria-pressed` (`BrowseController.php:15,54-55,92`; `portal/Views/partials/browse/detail/relations.php:40-71,121-180`). **[P]** El diseño debe reutilizar esa base, no crear otra página por catálogo.

---

## 2. Datos que debe mostrar toda fila

| Campo visible | Origen |
|---|---|
| Sistema | `os_terminology_system.code` o `source_system_code` |
| Código | `external_code` o `permanent_code` del otro extremo |
| Descripción | texto resuelto por idioma/revisión vigente |
| Tipo de relación | `mapping_type`/`mapping_nature` o `relation_type`/`relation_type_code` |
| Fuente | `provenance`, `source_reference` |
| Edición | `default_version`, `source/target_version`, `source_system_code` |
| Estado de revisión | `review_status` correspondiente |
| Vigencia | `valid_from`/`valid_to` |
| Dirección | `outgoing`/`incoming` calculado, nunca invertido automáticamente |
| Justificación | `context_text`/`clinical_rationale` |

**[P]** Los marcadores `<...>` en los wireframes son posiciones de maquetación, no códigos reales ni aprobaciones.

---

## 3. Secciones obligatorias de la ficha

1. Identidad del concepto (código permanente, descripción canónica, familia, dominio, categoría).
2. Definición, criterios clínicos y alcance.
3. Sinónimos, siglas y variantes con idioma/procedencia.
4. Validez, release y estado.
5. **Códigos relacionados**, con distinción visual **Clínica** vs **Terminológica**.
6. Trazabilidad: fuente, edición, licencia, revisión y auditoría.

---

## 4. Grupos de «Códigos relacionados»

**[P]** Orden fijo, encabezados colapsables y contadores. Agrupación interna por sistema, código y tipo. Las filas sin destino OFTAR/DENTAR se muestran como texto, nunca como enlace roto.

### 4.1 Perfil DENTAR

| # | Grupo | Clase |
|---:|---|---|
| 1 | Otros DENTAR (PR/DX/AN/CL) | Clínica |
| 2 | CDT y edición | Terminológica |
| 3 | Nomenclador Nacional | Terminológica |
| 4 | Nomencladores provinciales / institucionales | Terminológica |
| 5 | CIE-10 y ediciones | Terminológica |
| 6 | SNOMED CT Argentina | Terminológica |
| 7 | Otras familias justificadas | Clínica |
| 8 | Insumos o dispositivos | Clínica o recurso, según perfil ratificado |

**Ficha de procedimiento DENTAR:** código DENTAR, CDT+edición, Nomenclador Nacional, códigos institucionales, SNOMED, diagnósticos relacionados, fuente y vigencia.  
**Ficha de diagnóstico DENTAR:** código DENTAR, CIE-10, SNOMED, diagnósticos y procedimientos relacionados.

### 4.2 Perfil OFTAR

| # | Grupo | Clase |
|---:|---|---|
| 1 | Otros OFTAR | Clínica |
| 2 | Nomenclador Nacional | Terminológica |
| 3 | CAO | Terminológica |
| 4 | Regional NOA | Terminológica |
| 5 | CIE-10 | Terminológica (editorial si no hay edición resoluta) |
| 6 | CIE-10-ES 2026 | Terminológica |
| 7 | ICD-10-CM 2027 | Terminológica, referencia externa |
| 8 | SNOMED CT Argentina | Terminológica |

**[P]** Los ocho grupos de OFTAR se conservan; DENTAR usa los suyos con el mismo componente y la misma distinción visual.

---

## 5. Reglas de visibilidad

- Público: solo filas `approved`, con campo vigente y versión visible.
- Editorial autorizado: `draft`, `reviewed`, `unmatched`, sin correspondencia y pendientes.
- `rejected` no es valor persistible: el rechazo se muestra como decisión en trazabilidad, no como estado de fila.
- Las equivalencias llevan insignia distinta de las relaciones clínicas; `related` nunca se rotula «equivalente».
- Las filas con `untranslated=true` muestran el texto como no disponible, sin inventar traducción.

---

## 6. Accesibilidad y estado

**[P]** Mantener `scope="col"`, `aria-pressed`, contraste suficiente para insignias, navegación por teclado y conservación del estado canónico de la URL (`tab`, `rel_view`, filtros, paginación). No añadir parámetros por familia.

---

## 7. Wireframe común (estructura)

```
CÓDIGOS RELACIONADOS  (de <código propio>)
+-- [Clínica] <tipo> · <código destino> · <descripción> ----------------+
|   fuente: <fuente> · edición: <si existe> · vigencia: <si existe>    |
+-- [Terminológica · <mapping_type>] <sistema> · <código> -------------+
|   descripción: <texto vigente o no disponible>                      |
|   fuente: <fuente> · estado: <estado real> · licencia: <si aplica>   |
+----------------------------------------------------------------------+
```

**[H]** El componente quedó implementado en `portal/Repositories/CatalogRepository.php`, `BrowseService.php`, `BrowseController.php`, `context.php` y `detail/relations.php`, con etiquetas en los cuatro idiomas. **[P]** La publicación sigue sujeta a verificación en entorno autorizado.
