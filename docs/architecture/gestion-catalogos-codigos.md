# Gestión de catálogos y códigos

Estado: **implementada, con migración SQL aplicada y verificada el 2026-11-20; pendiente de despliegue**.

## Alcance aprobado

- Flujo gestionado: propuesta → revisión → decisión → publicación.
- Campos editable: Ítem (`permanent_code`, `status`), Versión (`preferred_term`,
  `definition`, `clinical_criteria`, `language_code`), Release (`version_tag`,
  `valid_from`, `valid_to`, `status`), relaciones e idiomas.
- Un botón **Ver UVR** por código abre `/admin/uvr/proposals` con el
  `service_item_id` precargado.
- Botón público **Gestión** en el header, siempre visible en `es-AR`, `en` y
  `pt-BR`, enlazado a `/admin/login`.

## Modelo de seguridad

- No se crean permisos nuevos: se reutilizan los 14 permisos existentes.
- `origen_admin` **no recibe** `INSERT`/`UPDATE`/`DELETE` sobre `os_catalog_*`.
- La publicación invoca una función `SECURITY DEFINER` que comprueba:
  1. solicitud de tipo `catalog_change`;
  2. dos revisiones aprobadas por actores distintos;
  3. decisión con evidencia;
  4. estado que permita publicación (`os_review_state.is_publication_allowed`).
- Propuesta, revisión y decisión quedan en `os_admin.audit_log` (append-only)
  con el actor real de `os_admin.app_user`. La publicación registra además
  `catalog_change_published` en `public.os_audit_log` desde la función segura.
- No se modifica `ALTER DEFAULT PRIVILEGES`, no se toca la API pública ni
  OpenAPI, y no se crean rutas `/v1/*` ni `/fhir/*`.

## Rutas del panel

| Ruta | Uso |
| --- | --- |
| `/admin/catalogs` | Selector de catálogo y alta de código |
| `/admin/catalogs/{code}` | Búsqueda y listado de códigos |
| `/admin/catalogs/{code}/items/{id}` | Detalle, UVR y propuesta de cambio |
| `/admin/catalogs/proposals` | Bandeja de solicitudes |
| `/admin/catalogs/proposals/{id}` | Revisiones, decisión y publicación |

Todas pasan por `AdminGuard`; los formularios usan CSRF y PRG.

## SQL aplicado y verificado (2026-11-20)

- `sql/08_arquitectura/catalogos_gestion_gobernada.sql`
- `sql/08_arquitectura/verificacion_catalogos_gestion.sql` (`BEGIN READ ONLY;` / `ROLLBACK;`)

Resultado de la verificación en `origen_codes`:

- función `os_catalog_apply_governed_change(BIGINT, BIGINT, TEXT)` con `SECURITY DEFINER = t`;
- `EXECUTE` solo para `origen_admin` y `postgres`; sin privilegios `PUBLIC`;
- `origen_admin` sin `INSERT`/`UPDATE`/`DELETE` directo en `os_catalog_*`;
- 0 solicitudes y 0 publicaciones de catálogo al momento de la verificación;
- trigger `trg_os_audit_log_immutable` activo (`tgenabled = O`);
- verificador finalizado con `ROLLBACK`, sin cambios confirmados.

## Verificación local

- `php -l` sin errores en los archivos nuevos y modificados.
- `php tests/run.php` → `OK` con paridad de claves en `es-AR`, `en`, `pt-BR` y `es`.

## Pendiente

1. Despliegue y prueba de humo en el VPS de `/admin/uvr` y `/admin/catalogs`.
