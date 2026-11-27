# Arquitectura de credenciales API — Portal de clientes

> **Estado:** propuesta condicionada al mecanismo real auditado. **No implementado.**
> **Fecha:** 2026-11-24.
>
> No se modificó `api_clients`, la autenticación, OpenAPI ni la guardia `/v1/*`.

## 1. Convenciones de estado

- **Estado actual comprobado:** ver `auditoria-api.md`.
- **Propuesta:** gestión desde el portal de clientes sin cambiar la API.
- **Decisión pendiente:** evolución M6 (hash, scopes, `429`, consola) y cualquier cambio en autenticación.
- **Riesgo:** exposición o falsa sensación de seguridad.
- **Dependencia:** etapa 8 y autorización específica.
- **Requisito de autorización:** cambiar esquema, autenticación o guardia de API.

## 2. Estado actual que condiciona el diseño

| Capacidad | Estado real |
|---|---|
| Transporte | `X-API-Key` o `Authorization: Bearer` |
| Almacenamiento | `api_clients.api_key` en texto plano |
| Comparación | Igualdad SQL exacta, sin hash ni pepper |
| Identidad visible | `id`, `institution_name`, `rate_limit_per_second` |
| Organización | No hay `organization_id` ni FK |
| Entorno | No existe campo de entorno |
| Scopes | No existen |
| Revocación | Solo `is_active`; sin `revoked_at` |
| Expiración | No existe |
| Último uso | No existe |
| Consumo | No existe medición persistida |
| Rate limiting | Columna existe pero no se aplica; no hay `429` |
| Escritura actual | SQL/psql ejecutado por `postgres`, no por la API |

## 3. Principio rector

El portal debe gestionar **metadatos y ciclo de vida compatible** con el mecanismo real. No debe anunciar capacidades que la API no implementa.

Si el usuario ve una opción, el backend debe poder cumplirla de verdad.

## 4. Modelo propuesto sin cambios de API

### 4.1 Entidad de metadatos propuesta

Nombre ilustrativo: `os_customer_api_credential`.

Campos conceptuales:

- Identificador interno.
- Organización propietaria.
- `api_clients.id` asociado.
- Entorno lógico, si se decide incorporar; hoy solo existiría `production`.
- Usuario creador y usuario que rotó/revocó.
- `created_at`.
- Estado espejo: `active`/`inactive`, derivado de `api_clients.is_active`.
- Notas de auditoría.

**Regla:** esta entidad sería propiedad del portal de clientes, nunca del portal de gobernanza.

### 4.2 Creación

Flujo propuesto:

1. Usuario autorizado de la organización activa solicita creación.
2. Backend valida permiso y contexto.
3. Backend genera clave con `random_bytes(32)` en hex, mismo formato que el mecanismo actual.
4. Backend inserta en `api_clients` con `institution_name` estable derivado de la organización.
5. Backend registra metadatos y auditoría.
6. La clave se muestra **una sola vez** al solicitante.
7. No se guarda copia en el esquema de metadatos ni en logs.

**Limitación comprobada:** como la API guarda la clave en texto plano, el portal no puede ofrecer «hash seguro» sin evolucionar la API. Esta limitación debe mostrarse honestamente en documentación y decisiones.

### 4.3 Consulta

Datos que pueden mostrarse:

- Identificador interno y referencia a `api_clients.id`.
- Organización, entorno lógico si aplica.
- Estado activo/inactivo.
- Fecha de creación.
- Quién creó, rotó o revocó, según metadatos del portal.

Datos que **no** deben mostrarse:

- Clave completa después de la creación.
- «Último uso», porque no existe.
- Consumo, porque no existe.
- Scopes, porque no existen.
- Cuotas aplicadas, porque no están implementadas.

### 4.4 Rotación

Flujo propuesto:

1. Validar permiso `credential.rotate`.
2. Generar nueva clave hex de 32 bytes.
3. Actualizar `api_clients.api_key`.
4. Registrar quién rotó y cuándo.
5. Mostrar nueva clave una sola vez.
6. La anterior deja de ser válida de inmediato por igualdad exacta.

**Riesgo:** no hay periodo de gracia. Debe documentarse en la interfaz.

### 4.5 Revocación

Flujo propuesto:

1. Validar permiso `credential.revoke`.
2. `UPDATE api_clients SET is_active = FALSE`.
3. Registrar auditoría con actor y organización.
4. La credencial deja de autenticar en la siguiente petición.

**Limitación:** no hay campo `revoked_at`; la fecha debe tomarse del registro de auditoría del portal, nunca inventarse en la API.

## 5. Aislamiento y permisos

- Toda consulta filtra por `organization_id` del contexto activo.
- Ningún ID de credencial del navegador autoriza por sí solo.
- `developer` solo ve credenciales explícitamente autorizadas.
- `viewer` no crea, rota ni revoca.
- Toda operación sensible exige CSRF y queda auditada.
- Ningún secreto en URL, HTML después de la creación, mensaje de error ni log.
- Ningún token en `Referer` ni en parámetros GET.

## 6. Roles de base y escritura

**Propuesta:** no ampliar `origen_api`, que es solo lectura.

Alternativas a decidir:

1. **Sin rol de escritura nuevo:** las operaciones sensibles pasan por un servicio/CLI controlado, como hoy. Menos exposición, más operación manual.
2. **Rol dedicado propuesto**, por ejemplo `origen_customer_credentials`: solo `INSERT` y `UPDATE` de columnas permitidas en `public.api_clients`, sin acceso a catálogos ni a `os_admin`, sin `ALTER DEFAULT PRIVILEGES`, con `REVOKE` explícito por objeto.

**Decisión pendiente:** cuál de las dos alternativas se adopta. Cualquier grant requiere autorización.

## 7. Entornos

- La API real tiene una sola base de servidor declarada en OpenAPI: `https://api.origen.ar`.
- No existe campo de entorno en `api_clients`.
- Por lo tanto, la primera versión solo puede mostrar un entorno lógico: `production`.
- No inventar `staging`, `sandbox` ni URLs alternativas sin infraestructura verificada.

## 8. Evolución futura propuesta (M6)

Solo después de autorización expresa:

1. Agregar `key_prefix`, `key_hash`, `expires_at`, `revoked_at`, `scopes`, `organization_id` y `last_used_at`.
2. Generar clave con prefijo visible y secreto separado.
3. Comparar con hash seguro y `hash_equals`.
4. Eliminar texto plano con plan de migración y rotación forzada.
5. Implementar scopes por clave y verificarlos en backend antes de cada ruta.
6. Aplicar `rate_limit_per_second` con `429`.
7. Registrar solicitudes reales por clave, endpoint, fecha, resultado y latencia.
8. Actualizar OpenAPI, documentación y pruebas.

**No hacer ahora:** tocar OpenAPI, la guardia `/v1/*`, `ApiKeyAuthenticator`, `api_clients` ni el buscador público.

## 9. Riesgos

- Mostrar la clave en texto plano en el navegador es inherente al mecanismo actual; minimizar exposición con una sola visualización.
- La rotación sin gracia puede cortar integraciones activas.
- La revocación no guarda fecha propia en la API.
- Crear un rol con escritura en `public.api_clients` amplía superficie de ataque.
- Publicar scopes o consumo inexistentes sería documentación falsa.
- Cualquier cambio de autenticación puede romper el buscador público que usa `WEB_API_KEY`.

## 10. Criterios de aceptación propuestos

- La credencial siempre pertenece a una organización del contexto activo.
- El secreto aparece solo en el momento de creación/rotación.
- No aparece en logs ni en URLs.
- La revocación surte efecto verificable contra la API real.
- La interfaz no ofrece capacidades inexistentes.
- Las operaciones sensibles están auditadas.
- Regresión: el buscador público y los clientes API existentes siguen funcionando.

## 11. Requisito de autorización

No crear tablas de metadatos, modificar `api_clients`, crear roles, ampliar grants, cambiar autenticación ni publicar gestión self-service sin aprobación explícita del propietario.

**Estado vigente (2026-11-26):** la aprobación de la Etapa 8 autorizó el self-service en entorno de prueba y la excepción de escritura en `public.api_clients` (`origen_codes`). La activación en producción y la migración V11.001 de hash con pepper siguen pendientes de acta; el código implementa la doble lectura para no romper credenciales legacy.
