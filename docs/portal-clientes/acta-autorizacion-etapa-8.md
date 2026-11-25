# Acta de autorización — Etapa 8: Credenciales API

> **Estado:** AUTORIZADA. **Implementada localmente; pendiente de verificación en VPS.** **Producción intacta excepto la prueba real acotada autorizada en el punto 7.**
> **Fecha:** 2026-11-25.
> **Autorizado por:** responsable del proyecto.
> **Relación:** continuación de la Etapa 7, cerrada en `origen_codes_portal_clientes_test`.

## 1. Corrección de alcance

La Etapa 8 del `plan-implementacion-portal-clientes.md` es **Credenciales API**, no una nueva integración con Invoice Ninja.

- Invoice Ninja quedó cubierto por la **Etapa 6**: servicio backend, adaptador `mock`/`http`, vínculos y revisión. No se agregan llamadas HTTP nuevas a Invoice Ninja en esta etapa.
- La Etapa 8 cubre la **gestión de credenciales de la API propia de `code-api`** (`/v1`, `api_clients`) desde `/portal-clientes`, respetando el mecanismo real auditado en `auditoria-api.md`.
- Cualquier evolución de la API (hash, scopes, expiración, medición, `429`, OpenAPI, guardia `/v1/*`) queda diferida a una propuesta posterior **M6**, no incluida aquí.

## 2. Estado actual comprobado

Según `auditoria-api.md` y `arquitectura-credenciales-api.md`:

| Capacidad | Estado real |
|---|---|
| Transporte | `X-API-Key` o `Authorization: Bearer` |
| Almacenamiento | `public.api_clients.api_key` en texto plano |
| Comparación | Igualdad SQL exacta, sin hash ni pepper |
| Identidad visible | `id`, `institution_name`, `rate_limit_per_second` |
| Organización | No hay `organization_id` ni FK en `api_clients` |
| Entorno | No existe campo de entorno |
| Scopes | No existen |
| Revocación | Solo `is_active`; sin `revoked_at` |
| Expiración | No existe |
| Último uso | No existe |
| Consumo medido | No existe |
| Rate limiting | Columna presente, pero no aplicada; no hay `429` |
| Escritura actual | CLI/SQL controlado por `postgres`, no self-service |
| Rol `origen_api` | Solo lectura |

**Consecuencia:** el portal no debe anunciar hash seguro, scopes, expiración, último uso, consumo ni cuotas ejecutadas. Mostrarlos sería documentación falsa.

## 3. Autorización recibida

El responsable autorizó expresamente la **Etapa 8 — Credenciales API** del portal `/portal-clientes`, con estas decisiones:

> Autorizo la Etapa 8 únicamente en la base de prueba aislada `origen_codes_portal_clientes_test` para los metadatos del portal, sin despliegue en producción y sin cambios en catálogos, `/admin`, API pública, Invoice Ninja, FreeScout, Nginx, PHP-FPM ni sitio público.
>
> Autorizo el **self-service de crear, rotar y revocar** credenciales desde el portal, usando la **Opción A**: servicio/CLI controlado, **sin crear un rol nuevo de escritura** y sin ampliar los grants de `origen_customer`.
>
> Autorizo además **una prueba real acotada contra `https://api.origen.ar`**, con una credencial de prueba creada exclusivamente para esa prueba, sin usar credenciales reales preexistentes y sin operaciones de escritura comercial.
>
> No autorizo commit, push ni deploy.

## 4. Decisiones aprobadas

| # | Decisión | Valor aprobado |
|---|---|---|
| 1 | Escritura en `public.api_clients` | **Opción A**: servicio controlado, sin rol nuevo de escritura |
| 2 | Alternativa descartada | Opción B (`origen_customer_credentials`) queda **descartada** |
| 3 | Gestión desde el portal | **Sí**: self-service de crear, rotar y revocar |
| 4 | Entorno lógico | Solo `production`; no inventar `staging` ni `sandbox` |
| 5 | Secreto | Una sola visualización; sin copia en metadatos, logs, correos ni URLs |
| 6 | Scopes / expiración / último uso / consumo / `429` | **No ofrecerlos**; documentar como limitación y derivar a M6 |
| 7 | Permisos del portal | Reutilizar `credential.read/create/rotate/revoke` existentes en V5 |
| 8 | Quién escribe | `technical_admin` crea, rota y revoca; `developer` y `viewer` solo leen |
| 9 | Superadministrador de Origen Salud | No gestiona credenciales de una organización salvo autorización expresa |
| 10 | `institution_name` | Valor estable derivado de la organización activa, sin texto libre del navegador |
| 11 | Verificación de revocación | **Prueba HTTP real acotada** contra `https://api.origen.ar`, según el punto 7 |
| 12 | Nombres de auditoría | `credential.created`, `credential.rotated`, `credential.revoked` con `success`/`denied`/`failure` |

### 4.1 Conciliación de Opción A con self-service

Para que el self-service sea real sin crear un rol nuevo ni ampliar `origen_customer`, el backend ejecutará las tres operaciones sensibles a través de un **único servicio de servidor** con una conexión operativa configurada solo en `.env` del VPS.

- Esa conexión no se expone al navegador, a logs ni a respuestas.
- Toda escritura pasa por validación de permiso `credential.*`, CSRF y auditoría.
- La conexión solo se usa para `INSERT` en `public.api_clients` y `UPDATE` de `api_key` / `is_active`.
- No se otorgan grants nuevos a `origen_customer`.
- Riesgo aceptado: la conexión operativa tiene privilegios de escritura sobre `public.api_clients`; se compensa con una única superficie de código, sin SQL dinámico y con auditoría append-only.

Si en la implementación esta conexión no puede configurarse sin exponer credenciales, se detiene la etapa y se vuelve a plantear la Opción B; no se improvisa un grant alternativo.

## 5. Alcance habilitado

1. Crear, solo en `origen_codes_portal_clientes_test`, la tabla de metadatos `os_customer.api_credential` con:
   - identificador interno;
   - `organization_id` de `os_customer`;
   - `api_clients.id` asociado;
   - estado espejo derivado de `is_active`;
   - creador, rotador y revocador;
   - fechas y notas de auditoría del portal.
2. Migración `V8.001__api_credentials.up.sql`, `down.sql`, `verify.sql` y `verify_rollback.sql`, sin tocar tablas de V5, V6 ni V7.
3. Grants por objeto al rol `origen_customer` sobre los objetos nuevos, **sin** `ALTER DEFAULT PRIVILEGES`.
4. Servicio en `portal-clientes/` para crear, listar, rotar y revocar, con filtro obligatorio por organización activa.
5. Rutas y vistas localizadas en `es-AR`, `en` y `pt-BR`, sin textos hardcodeados.
6. Documentación de las limitaciones reales del mecanismo actual.
7. Pruebas locales y en base de prueba, incluyendo casos negativos de aislamiento y permisos.
8. La prueba HTTP real acotada autorizada en el punto 7.

## 6. Alcance prohibido

- Producción (`origen_codes`) para metadatos, credenciales operativas ni cambios de esquema.
- Cambios de esquema en `public.api_clients`: columnas nuevas, hash, scopes, expiración, `revoked_at`, `last_used_at` ni `organization_id`.
- Cambios en `ApiKeyAuthenticator`, la guardia `/v1/*`, `api/index.php`, OpenAPI ni `README-API.md`.
- Uso de credenciales reales preexistentes.
- Creación de clientes, facturas, pagos ni servicios en Invoice Ninja.
- Modificación de `/admin`, catálogos, importadores, API pública, Invoice Ninja, FreeScout, Nginx, PHP-FPM ni sitio público.
- Habilitación automática de servicios por credencial creada.
- Mostrar capacidades inexistentes: scopes, consumo, último uso, cuotas, expiración ni hash seguro.
- Operaciones `POST`, `PUT`, `PATCH` ni `DELETE` contra la API real durante la prueba.
- Commit, push ni deploy.

## 7. Prueba HTTP real acotada

Se autoriza **una sola** prueba contra `https://api.origen.ar`, con estas condiciones:

1. Se crea una credencial de prueba nueva, exclusiva para esta etapa. No se reutiliza ni modifica ninguna credencial real existente.
2. El responsable debe confirmar, antes de crearla, cuál es la base real que sirve a `api.origen.ar` y verificar un backup previo.
3. Secuencia:
   - `GET /health` → `200`.
   - `GET /v1/domains` con la clave de prueba en `X-API-Key` → `200`.
   - Revocar la credencial de prueba (`is_active = false`).
   - Repetir `GET /v1/domains` con la misma clave → `401`.
4. Sin `POST`, `PUT`, `PATCH` ni `DELETE`. Sin términos clínicos ni datos de pacientes.
5. Sin cambios en catálogos, `/admin`, facturación, pagos ni credenciales existentes.
6. La clave de prueba se genera en el servidor, se guarda solo en un archivo con permisos `600` o en `.env`, y nunca se pega en actas, documentos, logs, comandos ni repositorio.
7. Al finalizar, la credencial queda **revocada**, no eliminada, para preservar evidencia. Se registra el resultado en esta acta.
8. Si cualquiera de los pasos devuelve un resultado inesperado, se detiene y se reporta; no se reintenta con otra credencial.

## 8. Reglas de verificación

1. Backup lógico previo en `origen_codes_portal_clientes_test` con `pg_dump -Fc`, verificado con `pg_restore -l` y hash SHA-256.
2. Aplicar la migración `up` en la base de prueba.
3. Ejecutar `verify.sql` en `BEGIN READ ONLY`: tablas, columnas, triggers y grants esperados; `columnas_prohibidas = 0`.
4. Ejecutar `down.sql` y `verify_rollback.sql`; conservar `audit_log`, roles y tablas de V5-V7.
5. Reaplicar `up` y verificar idempotencia.
6. `php -l` en todos los archivos PHP tocados.
7. Paridad i18n en `es-AR`, `en` y `pt-BR`.
8. `php tests/run.php` sin fallas y sin avisos `Deprecated`.
9. Casos negativos:
   - `viewer` no crea, rota ni revoca;
   - `developer` solo lee;
   - una credencial de la organización A no es visible para la B;
   - un ID del navegador no autoriza por sí solo;
   - el secreto no aparece en URL, logs ni HTML después de la creación.
10. Prueba HTTP real del punto 7, con su resultado registrado.

## 9. Criterios de aceptación

- Toda credencial pertenece a una organización del contexto activo.
- El secreto aparece solo en creación/rotación.
- La revocación es verificable contra la API real con la credencial de prueba autorizada.
- La interfaz no ofrece capacidades que la API no implementa.
- Las operaciones sensibles quedan auditadas.
- El buscador público, los clientes API existentes y `/portal` siguen funcionando.
- No se usaron credenciales reales preexistentes.
- No se tocó producción salvo la credencial de prueba revocada.

## 10. Estado actual

| Elemento | Estado |
|---|---|
| Acta | **AUTORIZADA** el 2026-11-25 |
| Código de la Etapa 8 | Implementado localmente: `ApiCredentialService`, `CredentialDatabase`, `ApiCredentialRepository`, `CredentialController`, vista y rutas |
| Migración V8 | Implementada: `up`, `down`, `verify`, `verify_rollback`; pendiente de ejecutar en VPS |
| Cambios en `.env` del portal | Pendientes; solo en servidor |
| Conexión operativa de escritura | Pendiente de configurar; sin rol nuevo |
| Credencial de prueba real | Pendiente de crear; se revocará al finalizar |
| Llamadas HTTP | Ninguna hasta la prueba autorizada |
| Suite local | `OK: 3695 comprobaciones`, sin fallas |
| Commit / push / deploy | Ninguno |

## 11. Condición de avance

La Etapa 8 puede comenzar. Antes de la prueba HTTP real, el responsable debe confirmar la base que sirve a `api.origen.ar` y el backup previo. La etapa se considerará cerrada cuando:

- la migración `up`/`verify`/`down`/`verify_rollback`/`up` esté verificada en prueba;
- `php tests/run.php` pase sin fallas;
- los casos negativos pasen;
- la prueba real devuelva `200` antes de revocar y `401` después;
- la credencial de prueba quede revocada y documentada;
- no se haya hecho commit, push ni deploy.
