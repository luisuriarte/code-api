# Acta de autorización — Etapa 8: Credenciales API

> **Estado:** AUTORIZADA y **CERRADA EN PRUEBA** el 2026-11-25. Migración, rollback, self-service y prueba HTTP real verificados. **Producción intacta salvo dos excepciones autorizadas: el grant operativo del punto 4.2 y las credenciales de prueba revocadas del punto 7. No desplegado en producción.**
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

### 4.2 Excepción autorizada en producción: grant operativo a `origen_admin`

La base real que sirve a `api.origen.ar` es `origen_codes` (confirmada por el responsable el 2026-11-25). Allí `origen_admin` no tenía `INSERT` ni `UPDATE` sobre `public.api_clients` (`f|f`), por lo que la conexión operativa de la Opción A no podía funcionar. El responsable autorizó expresamente otorgar esos permisos a ese **rol ya existente**:

```sql
GRANT SELECT, INSERT, UPDATE ON TABLE public.api_clients TO origen_admin;
GRANT USAGE ON SEQUENCE public.api_clients_id_seq TO origen_admin;
```

- `SELECT` es necesario porque el servicio usa `INSERT ... RETURNING id`.
- `USAGE` sobre la secuencia es necesario porque `api_clients.id` es `SERIAL`.
- **No se crea ningún rol nuevo**, no se amplían los grants de `origen_customer` y no se modifica el esquema de `public.api_clients`.
- Backup lógico previo verificado: `/var/lib/postgresql/backups/etapa8_pre_2026-11-25_1716.dump`, SHA-256 `1497374da5c05227f0ba44bc858f5f59d3f53df9c966e270ba9b7fe7dd4c0ef5`, `pg_restore -l` correcto (1665 entradas).
- Grant ejecutado y verificado el 2026-11-25: `t|t|t|t` para `SELECT`, `INSERT`, `UPDATE` y `USAGE` sobre la secuencia.

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
- No se tocó producción salvo el grant operativo autorizado en el punto 4.2 y la credencial de prueba revocada.

## 10. Estado actual

| Elemento | Estado |
|---|---|
| Acta | **AUTORIZADA** el 2026-11-25 |
| Código de la Etapa 8 | Implementado: `ApiCredentialService`, `CredentialDatabase`, `ApiCredentialRepository`, `CredentialController`, vista y rutas |
| Suite local y en VPS | `OK: 3695 comprobaciones`, sin fallas ni avisos `Deprecated` |
| Migración V8 en base de prueba | `up` → `verify` → `down` → `verify_rollback` → `up` → `verify` ejecutados. `tablas_v8 = 1`, `columnas_prohibidas = 0`, `capacidades_inexistentes = 0`, `trigger_revocacion = 1`, `sin_borrado = t`, `total_tablas = 21` |
| Cambios en `.env` del portal | Configurados y verificados solo en el VPS (conexión operativa y clave de prueba) |
| Base real confirmada | `origen_codes`, 1 fila preexistente en `public.api_clients` |
| Backup previo | Verificado: `etapa8_pre_2026-11-25_1716.dump`, SHA-256 registrado en el punto 4.2 |
| Conexión operativa de escritura | Roll `origen_admin` existente; grant ejecutado (`t|t|t|t`) y conexión `PDO=OK` verificada como `www-data` |
| Credencial de prueba real | Creada, rotada y revocada. Las tres filas de `api_credential` quedan `revoked`; `api_clients` `id=3,4,5` con `is_active = f` |
| Llamadas HTTP | Solo `GET`: `/health` y `/v1/domains` → `200` antes de revocar; `/v1/domains` → `401` después |
| Commit / push / deploy | El asistente no hizo ninguno; el responsable gestionó la versión del código |

### 10.1 Incidente: credenciales duplicadas por reenvío del POST

Durante la prueba visual se recargó dos veces `/credentials` después de crear la credencial. El controlador renderizaba la clave directamente en la respuesta del `POST` (sin POST-Redirect-GET), por lo que el navegador reenvió el formulario y creó **dos credenciales adicionales**. Resultado: tres credenciales creadas, una autorizada para la prueba y dos duplicadas no utilizadas.

Corrección aplicada: cada formulario lleva un `submit_nonce` de un solo uso, consumido con `hash_equals()`. Un reenvío del navegador ya no coincide, se convierte en un `GET` inofensivo y no crea ni rota nada. El secreto sigue sin guardarse en sesión, metadatos, URL ni logs.

Las tres credenciales creadas se **revocaron** (ninguna se eliminó) y conservan su rastro en `os_customer.audit_log`. El sondeo `200` se verificó con la credencial inicial y, tras corregir el DSN y el reenvío, con la clave rotada de la última; el `401` final se verificó con esa clave rotada ya revocada. Ninguna credencial preexistente fue modificada.

## 11. Resultado de la prueba real

- Antes de revocar: `OK /health => 200`, `OK /v1/domains => 200`.
- Después de revocar: `OK /v1/domains => 401 (esperado 401)`. `/health` no se consulta en modo `401` porque es público y responde `200` sin API Key.
- Auditoría: `credential.created|success|3`, `credential.rotated|success|1`, `credential.revoked|success|3` y `credential.created|failure|8` (intentos previos al DSN correcto y validaciones rechazadas).
- Metadatos: `1|3|revoked|f|t`, `2|4|revoked|f|t`, `3|5|revoked|t|t`.
- `public.api_clients` en `origen_codes`: `id=1` preexistente `t`; `id=3,4,5` con `f`.
- Sin operaciones `POST`, `PUT`, `PATCH` ni `DELETE` contra la API real. Sin datos clínicos ni términos de pacientes.

## 12. Cierre

Ensayo de rollback ejecutado en `origen_codes_portal_clientes_test`: `down` → `verify_rollback` → `up` → `verify`.

- `verify_rollback`: `tablas_v8_restantes = 0`, `funcion_revocacion_v8_restante = 0`, `audit_log = 1`, `tablas_v5_v6_v7 = 10`, `columnas_api_clients = 0`.
- `verify` tras reaplicar: `tablas_v8 = 1`, `columnas_prohibidas = 0`, `capacidades_inexistentes = 0`, `trigger_revocacion = 1`, `columnas_api_clients = 0`, `columnas_api_clients_prohibidas = 0`, `lee/crea/actualiza_metadatos = t`, `sin_borrado = t`, `usa_secuencia = t`, `total_tablas = 21`.

La Etapa 8 queda **cerrada en prueba**. No se desplegó en producción: permanece el grant operativo autorizado y las credenciales de prueba revocadas. Siguen sin autorización las Etapas 9-12 y la evolución M6 de la API (hash, scopes, expiración, último uso, medición y `429`). El asistente no hizo commit, push ni deploy.
