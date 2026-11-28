# CRUD administrativo directo y auditable de relaciones

**Convención:** `[H]` verificado en repositorio/documentación o en la salida del responsable · `[I]` inferencia · `[P]` propuesta.

**Estado:** preparado en el working tree. **No desplegado, no ejecutado en producción, sin commit ni push.**

---

## 1. Decisión del usuario

`[H]` El usuario pidió «editar/agregar/borrar relaciones» y eligió **Directo con auditoría**: el cambio se aplica de inmediato por un rol con permiso, pero queda en `draft`/pendiente y **no se publica** hasta una revisión formal.

`[H]` Alcance elegido: **las tres tablas** — `os_catalog_relation`, `os_concept_mapping` y `os_oftar_nomenclador_match`.

`[H]` Restricciones vigentes: `os_catalog` es el motor único; `oftar` es `family_code`, nunca `domain_type`; no se inventan datos, aprobaciones ni equivalencias; `SIN_DATOS`/`GAP_DOCUMENTADO` no son `PASS`; sin endpoints por familia; `rejected`/`pending_review`/`draft` no son publicables.

---

## 2. Lo que se implementó

### 2.1 Capa SQL

`[P]` `sql/08_arquitectura/relaciones_crud_auditable.sql` crea `public.os_relation_admin_write(text, text, bigint, jsonb, text, bigint, text)`:

- `[P]` `SECURITY DEFINER`, `SET search_path = public, pg_temp`. `origen_admin` recibe solo `EXECUTE`; **no** recibe `INSERT`/`UPDATE`/`DELETE` sobre las tablas base.
- `[P]` Entidades admitidas: `catalog_relation`, `concept_mapping`, `nomenclador_match`. Operaciones: `create`, `update`, `delete`.
- `[P]` Motivo (`p_reason`) obligatorio, mínimo 4 caracteres; actor obligatorio. El motivo se guarda en la auditoría.
- `[P]` Devuelve `before`/`after` en JSONB para que PHP audite con el estado completo.

Estados forzados por la función:

| Entidad | Alta / edición | Baja lógica | CHECK de la tabla |
|---|---|---|---|
| `os_catalog_relation` | `draft` | `deprecated` | `('draft','reviewed','approved','deprecated')` |
| `os_concept_mapping` | `draft` | `deprecated` | `('draft','reviewed','approved','deprecated')` |
| `os_oftar_nomenclador_match` | `proposed` | `rejected` | `('proposed','approved','rejected')` |

`[H]` Los CHECK se verificaron en `sql/03_oftar/aprobar_mapeo_nomencladores_oftar.sql:200-221`, `sql/02_catalogs/origen_catalog_engine.sql:119-133` y `sql/03_oftar/nomencladores_oftar_mapping.sql:38-55`. La función **nunca escribe `approved`**.

`[P]` La función escribe solo columnas del esquema base ya existente. No usa `relation_type_code`, `relation_kind`, `valid_from`, `valid_to`, `reviewed_by` ni `reviewed_at` de `os_catalog_relation`, para no depender de las fases 3/5 que aún no se aplicaron en el VPS. Los metadatos (`os_mapping_metadata`) se escriben solo si `to_regclass('public.os_mapping_metadata')` existe.

`[P]` Deduplicación previa acorde a las UNIQUE reales de cada tabla; validación de enums y de existencia de ítems/sistemas; baja **lógica**, sin `DELETE FROM`, `TRUNCATE` ni `DROP TABLE`.

### 2.2 Capa PHP

`[P]` `portal/Repositories/RelationAdminRepository.php`:

- Lecturas por `PortalDatabase` (solo lectura); escritura por `AdminDatabase` + `os_relation_admin_write()`.
- `beginTransaction()` → función → `AuditLogger::record()` → `commit()`; cualquier fallo hace `rollBack()` (**fail closed**).
- `matchTarget()` resuelve el destino de un par por `os_catalog_identifier` con `system_name='NOMENCLADOR-AR'` y `cat.code='oftar-pr'`; **no** por `permanent_code`. Es el criterio del caso H-02 (`460105 → 306002` resuelve a `OFT-PR-000025`).
- Las listas de pares muestran `target_permanent_code` calculado por el mismo identificador, y `unresolved` cuando no hay resolución.

`[P]` `portal/Controllers/AdminRelationController.php`:

- `catalog.view` para consultar; `catalog.edit_draft` para escribir (permiso ya asignado a `superadmin`, `catalog_admin` y `editor` en `sql/09_admin/fase1_identidad.sql:233,246,254,261`). **No se crea un permiso nuevo.**
- CSRF en todo POST, whitelist de entidades, razón obligatoria, mensajes flash estables.
- El alta de relaciones y mapeos recibe códigos permanentes y los resuelve a `item_id` en el servidor, sin aceptar IDs arbitrarios del navegador.

`[P]` Rutas planas en `portal/Router.php`: `GET /admin/relations` y `POST /admin/relations` con `op=create|update|delete`. Sin endpoints por familia.

`[P]` Vista `portal/Views/admin/relations/index.php`: tres secciones, búsqueda, edición en línea, baja con confirmación, aviso explícito de «no publicable», `datalist` de destinos por identificador y visualización de la resolución `NOMENCLADOR-AR`. Enlace en el menú administrativo con `catalog.view`.

`[P]` Traducciones añadidas en `messages.es-AR.yaml`, `messages.es.yaml`, `messages.en.yaml` y `messages.pt-BR.yaml`. Etiquetas nuevas, sin tocar códigos ni `family_code`.

`[P]` `php tests/run.php` → **OK: 4140 comprobaciones** (antes: 4116). Se ajustó el conteo de artefactos SQL de 16 a 17 y se agregaron comprobaciones de la función, RBAC, CSRF, transacción, auditoría, resolución por identificador, vistas y traducciones.

---

## 3. Lo que NO se hizo

`[H]` No se ejecutó SQL en producción; no se copió nada al VPS; no hay commit, push ni deploy.

`[H]` No se publicaron relaciones ni equivalencias: no se escribe `approved`, no se aprueban los 90 pares `proposed`, no se crean equivalencias clínicas a partir de las matrices (`propuesta_no_publicada`).

`[H]` No se cambió `family_code`, `domain_type`, contratos de API (`OFT-PR-NNNNNN`, `OFT-DX-NNNNNN`, `mappings`, `related_codes`, `uvr`, `data.relations{clinical,terminological}`) ni la decisión de publicación ya tomada (solo sostén técnico).

`[H]` No se crearon datos de prueba en producción.

---

## 4. Riesgos y límites

`[I]` El flujo gobernado anterior (`/admin/catalogs/proposals`) sigue existiendo y puede publicar cambios aprobados con `catalog.publish`. El CRUD directo **no** habilita esa publicación: un registro creado aquí queda `draft`/`proposed` hasta que una revisión formal decide.

`[I]` La baja lógica conserva la fila; el exclusionismo depende de que las proyecciones públicas sigan filtrando `review_status='approved'` (corrección ya aplicada en `CatalogRepository.php`).

`[I]` La resolución por identificador se muestra, pero el alta de un par no crea automáticamente una relación navegable. Publicar ese enlace sigue requiriendo revisión formal y el script correspondiente, corregido para resolver por identificador.

`[I]` Si `origen_admin` no tiene `EXECUTE` sobre la función porque el parche no se aplicó, el panel mostrará `relation_write_failed` y la transacción se revertirá; no escribirá parcialmente.

---

## 5. Pendiente en el VPS (sin ejecutar por el agente)

`[P]` 1. Aplicar `sql/08_arquitectura/relaciones_crud_auditable.sql` con `postgres`, tras backup verificado. Verificación `READ ONLY` posterior:

```sql
SELECT has_function_privilege(
  'origen_admin',
  'public.os_relation_admin_write(text,text,bigint,jsonb,text,bigint,text)',
  'EXECUTE'
);
SELECT review_status, count(*) FROM public.os_catalog_relation GROUP BY 1 ORDER BY 1;
SELECT review_status, count(*) FROM public.os_concept_mapping GROUP BY 1 ORDER BY 1;
SELECT review_status, count(*) FROM public.os_oftar_nomenclador_match GROUP BY 1 ORDER BY 1;
```

`[P]` 2. Copiar los archivos PHP, las cuatro traducciones y el enlace del menú; verificar `/admin/relations` con un usuario `catalog.view` y otro sin ese permiso (403).

`[P]` 3. Repetir la verificación original pendiente: aplicar `patches/verificacion_T01_T38_relaciones_transversales_v1_a_v3.patch`, ejecutar la v3 por `postgres` y capturar `/tmp/T01_T38_sql_v3.log`.

`[P]` 4. Repetir los `curl` autenticados con `Authorization: Bearer $API_KEY` sobre `/v1/catalogs`, `/v1/search?domains=oftar&q=OFT` y `/v1/catalogs/nomenclador-oftalmologico-cao-ar/items?limit=1`.

`[P]` 5. Solo después de revisión formal y autorización explícita: commit, push, deploy y firma del acta. Rollback: restaurar backup `20261126` (ya verificado por el responsable).
