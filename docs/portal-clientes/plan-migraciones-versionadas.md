# Convención de migraciones versionadas y reversibles — Etapa 4

> **Estado:** convención preparada. **Ninguna migración ejecutada.**
> **No incluye DDL de `os_customer_*`**: eso pertenece a la Etapa 5 y no está autorizado.

## 1. Principios

1. Toda migración futura tiene número secuencial, descripción corta y sentido `up`/`down`.
2. Toda migración `up` tiene una `down` equivalente o una compensación documentada.
3. Las migraciones se ejecutan primero en entorno de prueba.
4. Producción no se toca sin autorización posterior.
5. No se usan secretos dentro de archivos SQL.
6. No se usa `ALTER DEFAULT PRIVILEGES`.
7. Los privilegios se conceden y revocan objeto por objeto.
8. La auditoría nueva es append-only.
9. Antes de aplicar, se registra hash del archivo y backup.
10. Después de aplicar, se verifica con `SELECT`-only.

## 2. Nomenclatura propuesta

```
V4.000__baseline_entorno_prueba.sql
V4.000__baseline_entorno_prueba.down.sql
V5.001__os_customer_identity.sql
V5.001__os_customer_identity.down.sql
V6.001__invoice_ninja_links.sql
V6.001__invoice_ninja_links.down.sql
V7.001__entitlements.sql
V7.001__entitlements.down.sql
V8.001__credential_metadata.sql
V8.001__credential_metadata.down.sql
```

**Regla:** los archivos `V5.*` en adelante son referencias de planificación. No se crean ni ejecutan en la Etapa 4.

## 3. Estructura de una migración `up`

Plantilla documental, no ejecutada:

```sql
-- migrations/VX.NNN__descripcion.up.sql
-- Autorización requerida: ACTA DE ETAPA correspondiente.
-- Entorno permitido: base independiente de prueba.
-- No ejecutar en producción sin autorización explícita.
-- Antes: backup verificado.
-- Después: verificación SELECT-only.
--
-- begin_up
-- ... sentencias autorizadas ...
-- commit_up
```

## 4. Estructura de una migración `down`

Plantilla documental, no ejecutada:

```sql
-- migrations/VX.NNN__descripcion.down.sql
-- Revierte exclusivamente los objetos creados por VX.NNN__descripcion.up.sql.
-- No elimina datos reales.
-- No revierte auditoría append-only.
-- Debe ejecutarse en el mismo entorno donde se aplicó la up.
--
-- begin_down
-- ... sentencias autorizadas ...
-- commit_down
```

## 5. Registro de aplicación propuesto

Tabla de control futura, **no creada**:

| Columna | Finalidad |
|---|---|
| `version` | Identificador `VX.NNN`. |
| `description` | Descripción corta. |
| `checksum_sha256` | Hash del archivo aplicado. |
| `applied_at` | Fecha de aplicación. |
| `applied_by` | Actor autorizado. |
| `environment` | `test`, nunca `production` sin acta. |
| `rollback_checksum_sha256` | Hash del archivo `down`. |
| `status` | `applied`, `rolled_back`, `failed`. |

## 6. Procedimiento propuesto por migración

1. Verificar autorización vigente para la etapa.
2. Verificar entorno: `SELECT current_database(), current_user;`.
3. Calcular hash del archivo `up` y `down`.
4. Verificar backup previo.
5. Aplicar `up` solo en entorno autorizado.
6. Ejecutar verificación `SELECT`-only.
7. Registrar resultado.
8. Si falla, ejecutar `down` en el mismo entorno y documentar.

## 7. Prohibiciones

- No crear `os_customer` en esta etapa.
- No ejecutar migraciones contra `origen_codes` productiva.
- No mezclar migraciones de gobernanza con las del portal de clientes.
- No borrar tablas de catálogos ni datos de auditoría.
- No usar transacciones largas sin timeout.
- No guardar secretos en migraciones.

## 8. Estado real

No se creó ningún archivo ejecutable de migración. No se ejecutó DDL ni DML. No se creó la tabla de control.
