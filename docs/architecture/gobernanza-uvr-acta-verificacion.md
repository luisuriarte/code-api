# Gobernanza UVR · acta de verificación en base

**Fecha:** 2026-11-20 · **Base de datos:** `origen_codes` · **Directorio:** `/var/www/html/origen.ar/code-api`
**Ejecución:** responsable (`sudo -u postgres psql`). El agente **no ejecutó SQL**.
**Autorización:** plan U0–U6 aprobado y [`gobernanza-uvr-acta-u0.md`](gobernanza-uvr-acta-u0.md) (C1–C12).
**Backup:** condición previa del plan; la salida de `pg_restore -l` no se incluyó en la transcripción de esta sesión.

---

## 1. Secuencia ejecutada

| # | Acción | Resultado |
|---|---|---|
| 1 | `verificacion_uvr_gobernanza.sql` (previa) | `SET` / `BEGIN READ ONLY`; se detuvo en el apartado 7 por un error **del verificador** (`relname` no existe en `information_schema.role_table_grants`). Sin impacto en datos: la sesión terminó con error antes del `ROLLBACK`, en una transacción de solo lectura. |
| 2 | `uvr_gobernanza_datos.sql` | `COMMIT` correcto: columnas, vista gobernada, dos CHECK nuevos, seis triggers y grants. Los `NOTICE: trigger ... does not exist, skipping` son esperados en primera ejecución. |
| 3 | `verificacion_uvr_gobernanza.sql` (corregida, con `table_name` y `\pset pager off`) | **Diez apartados completos**, `ROLLBACK` final. Sin errores. |

La corrección del verificador se registró en `tests/run.php` y en `sql/08_arquitectura/README.md`. **No fue necesario re-ejecutar la migración.**

## 2. Resultados observados

| Apartado | Comprobación | Esperado | Observado | Dictamen |
|---|---|---|---|---|
| 1 | Modelo y gobernanza presentes | todas `t` | `review_state`, `app_user`, `governance_request`, `governance_review`, `governance_decision`, `audit_log`, `uvr_eligible`, `uvr_valuation`, `uvr_component`, `uvr_conversion`, `uvr_geo_index`, `uvr_governed_view` → `t` | OK |
| 2 | Columnas gobernadas | 5 | `os_uvr_component.is_not_applicable` (boolean, NO), `negative_adjustment_evidence` (text, YES); `os_uvr_valuation.approved_by_user_id`, `calculated_by_user_id` (bigint, YES), `published_at` (timestamp with time zone, YES) | OK |
| 3 | `total_uvr` no almacenado | 0 columnas | `0` | OK |
| 4 | FK de actores a `os_admin.app_user` | 6 | 4 de gobernanza + `os_uvr_valuation_approved_by_user_id_fkey` y `os_uvr_valuation_calculated_by_user_id_fkey`, todas `ON DELETE SET NULL` | OK |
| 5 | CHECK gobernado de componentes | `component_type` + 2 nuevos | `ck_os_uvr_component_governed_value`, `ck_os_uvr_component_na_value`, `os_uvr_component_component_type_check` | OK |
| 6 | Triggers UVR activos | 8 (2 previos + 6 nuevos) | `trg_os_audit_log_immutable`, `trg_os_uvr_valuation_eligible`, `trg_os_uvr_valuation_immutable`, `trg_os_uvr_publication_ready`, `trg_os_uvr_valuation_audit`, `trg_os_uvr_component_audit`, `trg_os_uvr_conversion_audit`, `trg_os_uvr_geo_index_audit` | OK |
| 7 | Grants explícitos del panel | 10 objetos para `origen_admin` | 10 filas: cuatro tablas UVR y tres de gobernanza con `INSERT,SELECT,UPDATE`; `os_audit_log` con `SELECT`; las dos vistas con el conjunto completo de privilegios | OK, con observación |
| 8 | Grantees no deseados en `PUBLIC` | 0 filas | `0` | OK |
| 9 | Datos UVR vacíos | 0 salvo catálogo elegible | `os_uvr_eligible_catalog = 1` (`dentar-pr`); las otras siete tablas en `0` | OK |
| 10 | Regresión y legado | sin cambios | `603 \| 22 \| 0 \| 0 \| 9 \| 10 \| 10 \| 40` (relaciones, idiomas, reservas vinculadas, valoraciones, sustancias, productos, presentaciones, identificadores) | OK |

Secuencia observada en el apartado 10: `603 | 22 | 0 | 0 | 9 | 10 | 10 | 40`.

Los dos valores heredados `3 | 7` del criterio histórico (`os_pricing_values`, `os_fee_item`) se comprueban en `verificacion_fase7.sql` §8; no se re-ejecutaron en esta pasada.

## 3. Observación sobre los privilegios de las vistas

Las vistas `v_os_uvr_valuation_total` y `v_os_uvr_valuation_governed` aparecen con
`DELETE,INSERT,REFERENCES,SELECT,TRIGGER,TRUNCATE,UPDATE` para `origen_admin`.
La migración **solo** ejecutó `GRANT SELECT` sobre ambas y `REVOKE ALL ... FROM
PUBLIC` sobre la nueva; no se añadió `GRANT ALL` ni `ALTER DEFAULT PRIVILEGES`.
El conjunto amplio procede, por tanto, de ACL previas o heredadas ajenas a este
cambio. No contradice C8: no hay grantees `PUBLIC` y los permisos son explícitos
por objeto. Si se desea mínimo privilegio, se puede proponer una operación
separada y autorizada:

```sql
REVOKE ALL PRIVILEGES ON TABLE public.v_os_uvr_valuation_total,
    public.v_os_uvr_valuation_governed FROM origen_admin;
GRANT SELECT ON TABLE public.v_os_uvr_valuation_total,
    public.v_os_uvr_valuation_governed TO origen_admin;
```

**No ejecutada.** Requiere autorización nueva y su propia verificación.

## 4. Cierre

- **U1 cerrado en base.** No se cargaron valores UVR ni se crearon catálogos.
- Modelo verificado: 12 objetos presentes, 5 columnas gobernadas, 0 columnas
  `total_uvr`, 6 FK, 3 CHECK, 8 triggers y 0 grantees `PUBLIC`.
- **U0–U6 completos en repositorio y verificados en base** en lo que respecta al modelo de datos.
- `php tests/run.php` → `OK: 3023 comprobaciones`, incluida la regresión de esta acta.
- **Pendiente de autorización:** commit/push y despliegue del panel A–G. El agente no los realiza.
