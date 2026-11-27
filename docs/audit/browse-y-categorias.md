# Browse Code y categoría del concepto

- **Fecha:** 2026-11-27
- **Alcance:** correcciones posteriores al informe final de la auditoría (`informe-final.md`)
- **Estado:** cambios preparados en local; **sin commit, push ni deploy**
- **Responsable de ejecución:** el responsable del sitio, en ventana controlada

---

## 1. Principio rector

Se conserva la distinción entre dos dimensiones que antes estaban mezcladas:

| Dimensión | Dónde vive | Quién la gobierna |
|---|---|---|
| **Catálogo al que pertenece el código** | `os_catalog`, `os_catalog_item`, capítulos DENTAR/OFTAR/PMO/CDT | Catálogo fuente; no se reescribe |
| **Categoría del concepto** | `os_clinical_category` y tablas puente nuevas | Propuesta gobernada con dos revisiones y decisión con evidencia |

No se renombró ni borró `os_catalog_category`, `category_id`, los capítulos existentes ni las URLs públicas. La taxonomía nueva es **aditiva**: si las tablas no existen, el frente y la API siguen funcionando con el facet histórico.

---

## 2. Browse Code

| Síntoma reportado | Corrección preparada |
|---|---|
| «Código = Todos» no encontraba nada | «Todos» ya no envía `__all__`. El checkbox no tiene `name`, el JS escribe cadenas vacías en los hidden `domain`/`catalog` y `BrowseController::paramValues()` descarta `__all__` si llega por una URL antigua. |
| Al marcar una casilla se perdía la selección | El `<select multiple>` se reemplazó por un desplegable con una casilla por opción. `syncCodeDropdown()` guarda la selección por familia y la restaura al cambiar de familia; las opciones incompatibles se ocultan/deshabilitan, pero no se desmarcan. |
| No se veían los criterios clínicos | El bloque ya vivía al final de **Concepto** (la pestaña `clinical` se retiró en `b14ca92`). Se agregó un acceso directo «Criterios clínicos» dentro de Concepto y un ancla al bloque. Los textos solo se muestran si existen en la fuente; nunca se inventan. |
| No aparecía DENTAR | El selector inyecta `dentar`, `oftar` y `nomenclador` como familias cuando la BD no devuelve filas activas. Además, los enlaces que llegan con `domain + catalog` y sin `family` infieren la familia desde el catálogo, para que el desplegable no descarte la selección en la primera búsqueda reactiva. |

Archivos: `portal/Views/browse.php`, `web/assets/js/browse-explorer.js`, `web/assets/css/app.css`, `portal/Controllers/BrowseController.php`, `portal/Views/partials/browse/detail.php`, `portal/Views/partials/browse/detail/concept.php` y las cuatro catalogaciones de traducción.

---

## 3. Categoría del concepto

### 3.1 Códigos

`CLIN-DIAG`, `CLIN-PROC`, `CLIN-PREST`, `CLIN-MED`, `CLIN-EST`, `CLIN-OBS`, `CLIN-SINT`, `CLIN-DISP`, `CLIN-ANAT`, `CLIN-MICRO`, `CLIN-ALERG`, `CLIN-HALLAZGO`.

Cada categoría tiene etiqueta, definición y ejemplos en los cuatro idiomas. La resolución de un código usa, en orden:

1. asignación gobernada (`os_catalog_item_clinical_category`);
2. mapa de la categoría fuente (`os_catalog_category_clinical_map`);
3. valor por catálogo (`os_catalog_clinical_default`), **solo si** no hay asignación ni mapa.

### 3.2 Administración

El formulario de propuesta incorpora un selector «Categoría del concepto». El listado y la ficha muestran esa columna al lado del catálogo. El valor se valida contra la tabla de categorías activas y viaja en `proposed_change` como:

```json
{ "clinical_category": { "code": "CLIN-PROC" } }
```

El aplicador gobernado lo escribe únicamente en `os_catalog_item_clinical_category`, con `source_request_id` y traza en `os_audit_log`. No se escribe en `os_catalog` ni en `os_catalog_category`.

### 3.3 API

- `GET /v1/catalogs/{catalog}/items?category=CLIN-...` filtra por categoría del concepto.
- Un `category` histórico (capítulo fuente) sigue funcionando igual.
- La respuesta incorpora `clinical_category` y `clinical_category_code` **sin quitar** `category`.
- Si la migración no fue aplicada, las columnas nuevas valen `null` y el contrato anterior queda intacto.

---

## 4. SQL preparado (el asistente no lo ejecuta)

Orden sugerido, con backup previo y acta:

1. `sql/08_arquitectura/categorias_clinicas.sql` — crea las cuatro tablas, carga las 12 categorías, los mapas y los defaults conocidos, y concede `SELECT` a `origen_med` si el rol existe.
2. `sql/08_arquitectura/catalogos_gestion_gobernada.sql` — reemplaza la función `os_catalog_apply_governed_change` para agregar el hook de categoría. Es `CREATE OR REPLACE`, idempotente; no modifica datos.

Precauciones:

- El archivo de categorías usa `ON CONFLICT DO UPDATE` en `os_clinical_category`: si el responsable edita etiquetas o definiciones a mano, una réplica sobrescribirá esos cambios con los valores del script.
- No se inventaron defaults para ANMAT, LOINC, microorganismos ni alergias: solo se mapearon catálogos verificados. Las demás categorías se asignan mediante propuesta gobernada.
- No se incluye rollback destructivo. Retirar las tablas requiere acta explícita y decisión humana; el código de lectura ya tolera que no existan.

### Verificación posterior (solo lectura)

```sql
SELECT code, name, sort_order FROM public.os_clinical_category ORDER BY sort_order;
SELECT count(*) AS mapas FROM public.os_catalog_category_clinical_map;
SELECT count(*) AS defaults FROM public.os_catalog_clinical_default;
SELECT catalog_code, clinical_category_code FROM public.os_catalog_clinical_default ORDER BY catalog_code;
SELECT proname, prosecdef FROM pg_proc
 WHERE proname = 'os_catalog_apply_governed_change';
```

En el portal: abrir `/es-AR/browse`, confirmar que «Todos» lista resultados, que DENTAR/OFTAR aparecen al elegir familia, que la selección se conserva al cambiar de familia y que «Criterios clínicos» enlaza al bloque dentro de Concepto. En admin: abrir un código y comprobar que «Categoría del concepto» es independiente del catálogo; enviar una propuesta de prueba **solo si** el responsable autoriza el flujo completo de dos revisiones.

---

## 5. Verificación local realizada

| Comprobación | Resultado |
|---|---|
| `php tests/run.php` | `OK: 4086 comprobaciones` |
| `php -l` sobre los archivos PHP modificados | Sin errores |
| `node --check web/assets/js/browse-explorer.js` | Sin errores |
| HTTP local `/es-AR/browse` con `domain=__all__`, familia DENTAR y catálogo DENTAR-DX | `200`; resumen «Todos» / «Códigos seleccionados: 1»; hidden `domain`/`catalog` correctos |
| Familias visible en el selector | `dentar`, `oftar`, `nomenclador` |

Pendiente de verificación en producción (requiere despliegue y datos reales): que existan criterios clínicos aprobados en la fuente y que los facets de `type`/`category` tengan datos. En el entorno local aparecían vacíos porque la base de prueba no tiene filas para esos campos; no se agregaron datos ficticios.
