# Hallazgo — visibilidad de los nomencladores oftalmológicos y sus relaciones

**Fecha:** 2026-11-28 · **Entorno:** producción `origen_codes` · **Estado:** diagnóstico preparado, pendiente de ejecución por el responsable.

**Convención:** `[H]` verificado en repositorio/documentación · `[I]` inferencia · `[P]` propuesta.

---

## 1. Lo que el código ya permite

`[H]` Ambos nomencladores están en la whitelist del explorador (`portal/Repositories/CatalogRepository.php:42-52`) y en la lista de opciones de `browse.php:18-19`, con familias `oftar` y `nomenclador`. No hace falta agregarlos al código.

`[H]` `GET /v1/catalogs` (`api/services/CatalogEngineService.php:27-58`) devuelve **todos** los catálogos con `is_active = TRUE`; no aplica whitelist de familia. Si no aparecen en ese endpoint, la causa está en los datos (`is_active`, carga del SQL o versión desplegada), no en el filtro de la API.

`[H]` `GET /v1/catalogs/{code}/items` exige release `status='published'` y versión vigente (`:137-146`). `/v1/search?domains=oftar` usa `v_oftar_search_catalog`, que exige `cat.family_code='oftar'`, `cat.product_role='catalog'`, `cat.is_active=TRUE`, `item.status='active'` y `ver.review_status='approved'` (`sql/03_oftar/oftar_domain_search.sql:45-80`). El dominio `oftar` **no** está en `DEFAULT_DOMAINS`; hay que pedirlo explícitamente.

`[H]` `relationsForItem()` (`CatalogEngineService.php:824-947`) consulta `os_catalog_relation` con `source_item_id = :item OR target_item_id = :item`, filtra `review_status='approved'` y devuelve `direction` `outgoing`/`incoming`. La bidireccionalidad ya está soportada; la ficha del portal reutiliza el mismo contrato.

---

## 2. Lo que falta en datos/gobernanza

`[H]` `sql/03_oftar/aprobar_mapeo_nomencladores_oftar.sql` es el único script que publica identificadores secundarios y relaciones `referencia_literal` entre OFT-PR y los nomencladores. Solo actúa sobre filas de `os_oftar_nomenclador_match` con `review_status='approved'` (`:167-171`, `:237-257`). No hay acta registrada de ejecución: el acta de ejecución de relaciones transversales cubre DDL y semillas de `os_relation_type`, no la aprobación de estos pares.

`[H]` El propio verificador del script indica el estado esperado: `=== 5. Enlaces publicados (0 hasta aprobar pares del mapeo) ===` y `=== 6. Mapeo gobernado (91 proposed en CAO, 0 en Regional) ===` (`verificacion_post_aprobacion_nomencladores_oftar.sql:56-65`). Con 91 propuestas y 0 aprobadas, el script no crea ninguna relación. Regional no tiene propuestas: no puede haber relaciones sin una fuente revisada nueva.

`[H]` H-02 (`docs/audit/auditoria-oftar-actual.md:75-85`): `os_oftar_nomenclador_match.target_code` contiene códigos de 6 dígitos del Nomenclador Nacional, pero la unión a OFT-PR exige `permanent_code = target_code` y los códigos permanentes son `OFT-PR-NNNNNN`. Aun aprobando los 91 pares CAO, el `JOIN` no resolvería el destino y la publicación sería silenciosamente 0. La corrección propuesta es resolver el destino por `os_catalog_identifier` (`system_name='NOMENCLADOR-AR'`) y no reutilizar retirados.

`[H]` Las matrices clínicas `matriz-conciliacion-clinica-oftar-pr.csv` y `matriz-equivalencias-oftar-pr.csv` están íntegramente como `propuesta_no_publicada` (`verificacion-oftar-pr.md:14`). Publicar equivalencias clínicas por coincidencia textual está prohibido por el acta de ejecución.

`[I]` La ausencia simultánea en API y browser es compatible con cualquiera de estos estados, que el diagnóstico distingue: (a) los catálogos no se cargaron o están inactivos; (b) están cargados pero las versiones siguen sin aprobación, por lo que no hay ítems en la vista de búsqueda; (c) el VPS ejecuta una versión del portal anterior a la inclusión de los catálogos; (d) hay pares propuestos pero ninguno aprobado, por lo que no hay relaciones.

---

## 3. Verificación a ejecutar en el VPS

```bash
cd /var/www/html/origen.ar/code-api

sudo -u postgres psql -X -v ON_ERROR_STOP=1 -P pager=off -d origen_codes \
  -f sql/03_oftar/verificacion_visibilidad_catalogos_oftar.sql \
  2>&1 | tee /tmp/visibilidad_catalogos_oftar.log

curl -s https://api.origen.ar/v1/catalogs | grep -o 'nomenclador-oftalmologico-[a-z-]*' | sort -u
curl -s 'https://api.origen.ar/v1/search?domains=oftar&q=OFT' | head -c 2000
curl -s 'https://api.origen.ar/v1/catalogs/nomenclador-oftalmologico-cao-ar/items?limit=1'

git log -1 --format='%h %s' -- portal/Views/browse.php
grep -n "nomenclador-oftalmologico" portal/Views/browse.php
```

Salida: `/tmp/visibilidad_catalogos_oftar.log`.

---

## 4. Criterio de cierre

| Resultado del diagnóstico | Acción |
|---|---|
| Catálogos inactivos o ausentes en `os_catalog` | `[P]` Acta separada para cargar/activar los dos catálogos; no tocar family_code ni product_role. |
| Catálogos activos pero versiones `unknown` | `[P]` Acta para ejecutar `aprobar_mapeo_nomencladores_oftar.sql` (solo `preferred_term`); sin inventar definiciones. |
| 91 pares `proposed` y 0 `approved` | `[P]` Revisión humana gobernada antes de aprobar; el agente no aprueba correspondencias. |
| H-02 confirmado | `[P]` Corregir la resolución de destino por identificador secundario antes de publicar enlaces; repetir verificación. |
| Relaciones 0 en ambos sentidos | Conforme al estado actual: no se publican relaciones sin pares aprobados. No marcar `PASS`. |
| Código del VPS anterior | `[P]` Despliegue autorizado de la rama; el agente no hace deploy. |

`[P]` Ninguna de estas acciones se ejecutó. La decisión de publicación gobernada sigue limitada al sostén técnico registrado en `docs/audit/acta-publicacion-relaciones-transversales.md`.
