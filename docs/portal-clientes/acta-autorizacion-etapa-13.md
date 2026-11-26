# Acta de autorización — Etapa 13: Puesta en producción real

> **Fecha:** 2026-11-26.
> **Estado:** AUTORIZADA.
> **Autorizada por:** responsable del proyecto, al elegir «Etapa 13: producción real».
> **Alcance:** crear la base operativa del portal de clientes, publicar la configuración de producción y habilitar de forma controlada los enlaces de la Solicitud de Servicios.
> **Ejecución:** el responsable ejecuta SQL, cambios de `.env`, subida de archivos y despliegue. El asistente prepara artefactos y comandos; **no hace commit, push ni deploy**.

## 1. Decisión

Se autoriza la **Etapa 13 — Producción real** del portal de clientes. La Etapa 12 quedó cerrada y todo el código ya está versionado y desplegado.

Esta acta **deja sin efecto**, solo a partir de esta etapa y bajo las condiciones aquí descritas, las siguientes reglas de etapas anteriores:

| Regla anterior | Excepción autorizada en Etapa 13 |
| --- | --- |
| «Token real de Invoice Ninja prohibido; solo token de prueba con `INVOICE_NINJA_ALLOW_TEST_CALLS=true`». | Se permite un **token real** de solo lectura en `.env` del servidor, con `INVOICE_NINJA_ALLOW_LIVE_CALLS=true` y `INVOICE_NINJA_ALLOW_TEST_CALLS=false`. |
| «La Solicitud de Servicios no debe tener enlaces en nav, footer ni home». | Se permite publicar el enlace mediante `PORTAL_SERVICE_REQUEST_LINK_ENABLED=true`, reversible en caliente. |

Todo lo demás sigue vigente.

## 2. Límites

| Ítem | Regla |
| --- | --- |
| Base `origen_codes` | **No recibe cambios de esquema ni datos.** Sigue siendo la base de lectura pública y de credenciales operativas. |
| Base nueva | `origen_codes_portal_clientes`, separada de `origen_codes` y de `origen_codes_portal_clientes_test`. |
| Migraciones | Aplicar solo `V5.001`, `V6.001`, `V7.001`, `V7.002`, `V8.001` y `V10.001` en la base nueva. **No aplicar `V10.002`**: el cambio cluster-wide ya está hecho. |
| Datos | No copiar las dos solicitudes ficticias ni usuarios de prueba. La base nueva arranca vacía salvo los datos base de la migración V5. |
| DSN público | `PORTAL_DB_DSN` sigue apuntando a `origen_codes`. |
| DSN privado | `PORTAL_CUSTOMER_DB_DSN` y `SERVICE_REQUEST_DB_DSN` pasan a `origen_codes_portal_clientes`. |
| DSN de credenciales | `PORTAL_CUSTOMER_CREDENTIAL_DB_DSN` sigue apuntando a `origen_codes`, sin escribir allí. |
| Invoice Ninja | Solo `GET`. No se crean clientes, presupuestos, facturas ni pagos. El token real nunca se pone en Git, HTML, JS ni logs. |
| Secretos | Solo en `.env` del servidor con permisos restringidos. `.env.example` queda sin valores. |
| Enlaces | `PORTAL_SERVICE_REQUEST_LINK_ENABLED` empieza en `false`; se activa recién tras verificar la base y el catálogo. |
| Rollback | Desactivar flags, restaurar DSNs a la base de prueba y recargar `php-fpm`. No borrar `origen_codes`. |

## 3. Casos incluidos

- Creación y verificación de la base operativa.
- Migraciones versionadas en orden, con `ON_ERROR_STOP=1`.
- Configuración de modo producción de Invoice Ninja y de enlaces públicos.
- Regresión de sitio público, `/portal`, `/portal-clientes`, Docs, DENTAR, OFTAR, UVR, sitemap, API pública y `/solicitud`.
- Comprobación de que no se escribió en `origen_codes` ni se crearon operaciones comerciales.

## 4. Condiciones de salida

1. `current_database()` es `origen_codes_portal_clientes` en todas las migraciones.
2. Todas las verificaciones `SELECT`-only devuelven los valores esperados.
3. No existe ningún valor secreto en `.env.example`, Git, HTML ni logs.
4. `invoiceNinjaLiveEnabled()` es `true` pero el token no se imprime.
5. Los enlaces aparecen solo si el flag está activo y desaparecen al desactivarlo.
6. El verificador de la Etapa 13 termina sin fallos.
7. Invoice Ninja sigue sin clientes, presupuestos, facturas ni pagos nuevos.
8. El informe de ejecución queda completado por el responsable.

Si falla cualquiera, se ejecuta el rollback del plan antes de reintentar.
