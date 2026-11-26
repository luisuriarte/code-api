# Acta de autorización — Etapa 12: Despliegue

> **Fecha:** 2026-11-26.
> **Estado:** AUTORIZADA.
> **Autorizada por:** responsable del proyecto.
> **Decisión registrada:** «Aprobada y Autorizada la etapa 12. Implementa».
> **Alcance:** preparación y ejecución controlada del despliegue del código ya probado en la Etapa 11.
> **Ejecución:** el responsable ejecuta commit, push, subida de archivos y despliegue en el VPS. El asistente prepara artefactos, checklists y comandos; **no hace commit, push ni deploy**.

## 1. Decisión

Se autoriza la **Etapa 12 — Despliegue** definida en `plan-implementacion-portal-clientes.md`, con `plan-despliegue-etapa-12.md` como procedimiento y `manifiesto-despliegue-etapa-12.md` como inventario.

La Etapa 11 quedó cerrada: T-01…T-08 OK, T-09 no aplica y T-10 se ejecuta bajo esta acta.

## 2. Límites

| Ítem | Regla |
| --- | --- |
| Base productiva | `origen_codes` **no recibe cambios de esquema ni datos** en esta etapa. |
| Migraciones V5…V10 | **No ejecutar en producción.** Sus guardas rechazan `origen_codes`; las tablas versionadas siguen viviendo en la base aislada de prueba. |
| V10.002 | `ALTER ROLE origen_med NOSUPERUSER` ya fue aplicado y verificado. No revertirlo durante el despliegue. |
| `rolconnlimit` | `origen_med` debe conservar `CONNECTION LIMIT -1`. |
| DSN público | `PORTAL_DB_DSN` sigue apuntando a `origen_codes` solo para lecturas públicas. |
| DSN privado | `PORTAL_CUSTOMER_DB_DSN` y `SERVICE_REQUEST_DB_DSN` apuntan a `origen_codes_portal_clientes_test`. |
| Invoice Ninja | Solo token **de prueba** y `INVOICE_NINJA_ALLOW_TEST_CALLS=true`. No se crean clientes, presupuestos, facturas ni pagos. |
| Navegación | La Solicitud de Servicios sigue sin enlaces en nav, footer ni home; solo por URL directa. |
| Secretos | Solo en `.env` del servidor. Ningún token, password ni DSN con credenciales en Git, HTML, JS ni logs. |
| Cambios de infraestructura | No se modifican Nginx, FreeScout ni Invoice Ninja. No se requieren nuevas rutas de rewrite. |
| Rollback | Restaurar archivos y `.env`, recargar `php-fpm`. No hay rollback de esquema en `origen_codes`. |

## 3. Casos incluidos

- **T-10 — Despliegue y rollback:** revisión de diff, backup verificado, publicación controlada, regresión y rollback documentado.
- Verificación HTTP de solo lectura más el caso negativo de CSRF (`POST` sin token → `303`).
- Regresión de sitio público, `/portal`, `/portal-clientes`, Docs, DENTAR, OFTAR, UVR, sitemap y API pública.

## 4. Condiciones de salida

La Etapa 12 se considera cerrada cuando:

1. El diff revisado corresponde a `HEAD` y no incluye secretos.
2. Existe backup verificado de código, `.env` y bases antes de publicar.
3. Los archivos del manifiesto están publicados y `php -l` pasa en el VPS.
4. El verificador de despliegue termina sin fallos.
5. No hay regresión en las rutas de control.
6. No se crearon operaciones comerciales reales.
7. El informe de ejecución registra resultado, hashes, actor y decisión final.

Si falla cualquier verificación, se ejecuta el rollback del plan antes de intentar nuevamente.
