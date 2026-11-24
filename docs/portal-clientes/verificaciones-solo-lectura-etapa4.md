# Verificaciones de solo lectura — Etapa 4

> **Estado:** procedimiento preparado. **No ejecutado contra VPS ni sistemas externos.**
> **Regla:** todo SQL termina en `ROLLBACK`. No se usa `COMMIT`. No se consultan valores de secretos.

## 1. Verificaciones locales ya ejecutadas por el asistente

| Comprobación | Resultado |
|---|---|
| `git status --short` | Solo `?? docs/portal-clientes/`. |
| Conteo de archivos de documentación | Revisado; sin cambios en código. |
| Búsqueda de typos en documentación | Sin hallazgos relevantes. |

Si el responsable quiere repetir:

```powershell
git status --short
Get-ChildItem docs\portal-clientes -File | Sort-Object Name | Select-Object Name,Length
```

## 2. Verificación SQL en VPS — la ejecuta el responsable

No ejecutar si no se autorizó acceso de solo lectura al VPS.

```bash
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 <<'SQL'
BEGIN READ ONLY;

SELECT current_database() AS base,
       current_user AS usuario,
       version() AS version_pg;

SELECT to_regclass('public.api_clients') AS api_clients,
       to_regnamespace('os_admin') AS os_admin_schema,
       to_regnamespace('os_customer') AS os_customer_schema;

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'api_clients'
ORDER BY ordinal_position;

SELECT rolname
FROM pg_roles
WHERE rolname IN ('origen_api', 'origen_med', 'origen_admin')
ORDER BY rolname;

SELECT nspname
FROM pg_namespace
WHERE nspname LIKE 'os_customer%'
ORDER BY nspname;

SELECT defaclrole::regrole AS rol,
       defaclnamespace::regnamespace AS esquema,
       defaclobjtype AS tipo_objeto,
       defaclacl AS privilegios
FROM pg_default_acl
ORDER BY 1, 2, 3;

ROLLBACK;
SQL
```

**No incluir:** `SELECT api_key FROM api_clients`, ni cualquier consulta que devuelva secretos.

## 3. Interpretación esperada

| Comprobación | Resultado esperado / acción |
|---|---|
| `current_database()` | Debe ser `origen_codes` si se audita producción; solo lectura. |
| `api_clients` | Debe existir. |
| `os_admin_schema` | Debe existir según documentación M1/M2. |
| `os_customer_schema` | Debe ser `NULL`; si existe, detener y documentar. |
| Columnas de `api_clients` | `api_key` debe ser texto; sin `scopes`, `expires_at`, `last_used_at`. |
| Roles | Registrar cuáles existen realmente. |
| `pg_default_acl` | Registrar si hay defaults; no modificar. |

Si alguna salida contradice la documentación, se documenta como **NO VERIFICADO / CONTRADICCIÓN**, no se corrige en esta etapa.

## 4. Verificación de base de prueba — si el responsable la creó

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 <<'SQL'
BEGIN READ ONLY;

SELECT current_database() AS base,
       current_user AS usuario;

SELECT nspname
FROM pg_namespace
WHERE nspname LIKE 'os_customer%'
ORDER BY nspname;

SELECT schemaname, tablename
FROM pg_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY schemaname, tablename;

ROLLBACK;
SQL
```

**Resultado esperado en Etapa 4:** no debe existir `os_customer`; la base de prueba debe estar vacía de objetos del portal de clientes.

## 5. Verificación de archivos y secretos en el repositorio

```powershell
git status --short
rg -n "(api[_-]?key|password|token|pepper)\s*[:=]\s*[^_\s]" docs\portal-clientes
```

Si aparece un valor real, se detiene y se documenta como incidente. Los placeholders permitidos son `__NOT_SET__`, `__SET_IN_SECURE_STORE__`, `__GENERATE_32_BYTES__` y `DEMO_ONLY_DO_NOT_USE_*`.

## 6. Verificación pública de sistemas externos — sin credenciales

```powershell
Invoke-WebRequest -Method Head https://gestion.uriarte.ar | Select-Object StatusCode
Invoke-WebRequest -Method Head https://soporte.uriarte.ar | Select-Object StatusCode
```

Solo confirma disponibilidad HTTP. No obtiene versión, API ni configuración.

Para cerrar esos puntos hace falta una sesión autenticada autorizada por el responsable. No se realiza en esta etapa.

## 7. Prohibiciones

No ejecutar:

```sql
CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, TRUNCATE, GRANT, REVOKE, COMMIT
```

durante estas verificaciones. Todo bloque SQL debe usar `BEGIN READ ONLY;` y `ROLLBACK;`.

## 8. Registro de resultados

El responsable puede completar:

| ID | Fecha | Comando | Resultado | Observación |
|---|---|---|---|---|
| V-01 |  |  |  |  |
| V-02 |  |  |  |  |
| V-03 |  |  |  |  |

No pegar secretos ni respuestas sensibles en este archivo.
