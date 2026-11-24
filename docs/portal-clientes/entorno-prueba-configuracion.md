# Entorno de prueba y configuración — Etapa 4

> **Estado:** propuesta de configuración. **No creado. No aplicado.**
> **Secretos:** ninguno. Todos los valores sensibles son placeholders.

## 1. Principio

La Etapa 4 trabaja en un entorno independiente de producción. Producción `origen_codes` no se toca.

Si ya existe una base independiente autorizada para pruebas, se usa esa. Si no, el responsable debe crearla fuera de este entorno de trabajo antes de cualquier migración futura.

## 2. Nombres propuestos

| Elemento | Valor propuesto | Estado |
|---|---|---|
| Base de prueba | `origen_codes_portal_clientes_test` | Propuesto, no creado. |
| Esquema de identidad futura | `os_customer` | **No creado**; reservado para Etapa 5. |
| Rol de aplicación futuro | `origen_customer` | **No creado**; requiere autorización de Etapa 5. |
| Rol de solo lectura futuro | `origen_customer_read` | **No creado**; opcional. |
| Prefijo de secretos | `PORTAL_CUSTOMER_` | Propuesto. |
| Dominio de prueba | `portal-clientes.test.example.invalid` | Reservado, no público. |

## 3. Catálogo de variables — sin secretos reales

| Variable | Valor de ejemplo seguro | Uso |
|---|---|---|
| `PORTAL_CUSTOMER_DB_DSN` | `pgsql:host=127.0.0.1;port=5432;dbname=origen_codes_portal_clientes_test` | Conexión de aplicación al entorno de prueba. |
| `PORTAL_CUSTOMER_DB_USER` | `origen_customer_test` | Usuario de base de prueba. |
| `PORTAL_CUSTOMER_DB_PASSWORD` | `__SET_IN_SECURE_STORE__` | Nunca en Git, logs ni documentos. |
| `PORTAL_CUSTOMER_APP_ENV` | `test` | Entorno lógico. |
| `PORTAL_CUSTOMER_APP_DEBUG` | `false` | Evita trazas en respuesta. |
| `PORTAL_CUSTOMER_BASE_URL` | `https://portal-clientes.test.example.invalid` | Generación de URLs. Nunca usar `Host` de petición. |
| `PORTAL_CUSTOMER_SESSION_SECRET` | `__GENERATE_32_BYTES__` | Firmas/cookies; se genera fuera del repo. |
| `PORTAL_CUSTOMER_PASSWORD_PEPPER` | `__GENERATE_32_BYTES__` | Hash de contraseñas; distinto del pepper de gobernanza. |
| `PORTAL_CUSTOMER_TOKEN_PEPPER` | `__GENERATE_32_BYTES__` | Fingerprints de IP/user-agent. |
| `PORTAL_CUSTOMER_SESSION_TTL` | `43200` | Segundos; dato ajustable. |
| `PORTAL_CUSTOMER_INVITE_TTL` | `604800` | Segundos; dato ajustable. |
| `PORTAL_CUSTOMER_REQUIRE_HTTPS` | `true` | Exigencia HTTPS. |
| `PORTAL_CUSTOMER_SMTP_HOST` | `smtp.test.example.invalid` | Solo prueba. |
| `PORTAL_CUSTOMER_SMTP_PORT` | `587` | Solo prueba. |
| `PORTAL_CUSTOMER_SMTP_USER` | `__NOT_SET__` | Sin credenciales reales. |
| `PORTAL_CUSTOMER_SMTP_PASSWORD` | `__NOT_SET__` | Sin credenciales reales. |
| `PORTAL_CUSTOMER_SMTP_FROM` | `no-reply@test.example.invalid` | Remitente ficticio. |
| `INVOICE_NINJA_BASE_URL` | `https://gestion.uriarte.ar` | Referencia real; solo metadata, sin llamadas. |
| `INVOICE_NINJA_API_TOKEN` | `__NOT_SET_IN_STAGE4__` | No se usa en esta etapa. |
| `FREESCOUT_BASE_URL` | `https://soporte.uriarte.ar` | Referencia real; solo metadata, sin llamadas. |
| `FREESCOUT_API_TOKEN` | `__NOT_SET_IN_STAGE4__` | No se usa en esta etapa. |

## 4. Reglas de secretos

1. Ningún valor real en este documento ni en el repositorio.
2. Los secretos reales, si se generan, se guardan en un gestor externo o archivo con permisos restringidos fuera de Git.
3. No imprimir secretos en consola, logs, correos ni mensajes de error.
4. No reutilizar pepper de `os_admin`.
5. No reutilizar `WEB_API_KEY`, `ORIGEN_API_KEY` ni tokens de Invoice Ninja/FreeScout.
6. Si un secreto se expone, se documenta el incidente y se rota con autorización específica.

## 5. Aislamiento respecto de producción

- La base de prueba no comparte esquemas con producción.
- No se usa `origen_admin` ni `origen_api` de producción desde el entorno de prueba.
- No se consultan catálogos publicados reales desde el portal de clientes en esta etapa.
- No se crean clientes ni contactos en Invoice Ninja.
- No se envían correos reales.

## 6. Verificación local de esta etapa

Solo lectura:

```powershell
git status --short
Get-ChildItem docs\portal-clientes -File | Select-Object Name,Length
```

No se ejecutaron comandos contra la base de prueba ni contra producción.
