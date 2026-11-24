# Plan de implementación — Portal privado de clientes

> **Estado:** propuesta para revisión. **No autorizado para implementación.**
> **Fecha:** 2026-11-24.
> **Relación:** especificación general del proyecto, etapas 1 y 2.
>
> Este documento describe el plan propuesto. Ninguna de sus acciones puede
> ejecutarse sin autorización expresa y por etapa. Las etapas 1 y 2 son de
> auditoría y diseño; la implementación comienza recién en la etapa 4.

## 1. Convenciones de estado

Cada entrega posterior debe distinguir:

- **Estado actual comprobado:** verificado en repositorio, base o sistema externo.
- **Propuesta:** diseño sin ejecutar.
- **Decisión pendiente:** requiere pronunciamiento del propietario.
- **Riesgo:** consecuencia adversa potencial.
- **Dependencia:** algo que debe existir o aprobarse antes.
- **Requisito de autorización:** permiso expreso necesario para avanzar.

## 2. Principios rectores

1. `/portal` sigue siendo exclusivamente de gobernanza de catálogos.
2. `/portal-clientes` tendrá identidad, autenticación y autorización propias.
3. Invoice Ninja continúa siendo la fuente de verdad comercial y financiera.
4. No se duplican productos, precios, facturas, presupuestos ni pagos.
5. No se crean automáticamente clientes comerciales, habilitaciones ni credenciales.
6. La coincidencia de correo electrónico nunca vincula identidades entre portales.
7. Toda operación sensible queda auditada.
8. Los secretos nunca llegan al navegador ni a logs.
9. Las rutas públicas y localizadas existentes no se modifican como efecto colateral.
10. Ante duda comercial o de identidad, se escala a revisión humana.

## 3. Mapa de etapas

| Etapa | Nombre | Naturaleza | Resultado | Autorización |
|---|---|---|---|---|
| 1 | Auditoría técnica | Solo lectura | 4 documentos de auditoría | No requiere cambios |
| 2 | Diseño arquitectónico | Documental | 7 documentos de diseño | No requiere cambios |
| 3 | Aprobación | Decisión | Acta de aprobación por etapa | **Requerida** |
| 4 | Preparación técnica | Implementación controlada | Entorno de prueba, rollback | **Autorizada**; ver `acta-autorizacion-etapa-4.md` |
| 5 | Identidad y organizaciones | Implementación | Modelo `os_customer_*` | **Cerrada en prueba**; ver `acta-autorizacion-etapa-5.md` |
| 6 | Integración Invoice Ninja | Implementación | Servicio backend y pruebas | **Requerida** |
| 7 | Servicios y habilitaciones | Implementación | Entitlements administrados | **Requerida** |
| 8 | Credenciales API | Implementación | Gestión según mecanismo real | **Requerida, específica** |
| 9 | Interfaz del portal | Implementación | Secciones y i18n | **Requerida** |
| 10 | Contratación pública | Implementación | Carrito y solicitud comercial | **Requerida** |
| 11 | Pruebas | Verificación | Plan de pruebas ejecutado | Parte de cada etapa |
| 12 | Despliegue | Producción | Publicación | **Requerida, explícita** |

## 4. Etapa 1 — Auditoría técnica

### 4.1 Actividades propuestas

- Mapear controladores, rutas, repositorios, vistas y servicios del portal de gobernanza.
- Verificar autenticación, sesiones, CSRF, RBAC, recuperación y auditoría existentes.
- Verificar el mecanismo real de autenticación de `code-api`.
- Inventariar esquemas, tablas, roles y privilegios desde los artefactos SQL del repositorio; contrastar con la base solo en lectura cuando el responsable lo autorice.
- Verificar la instalación de Invoice Ninja y FreeScout sin credenciales ni pruebas destructivas.
- Revisar Nginx, PHP, HTTPS, logs, backups y despliegue desde archivos disponibles.

### 4.2 Restricciones

- No ejecutar DDL, DML, migraciones ni `COMMIT`.
- No modificar código, catálogos, importadores, API, Nginx, FreeScout ni Invoice Ninja.
- No crear clientes, presupuestos, facturas ni pagos.
- No instalar dependencias ni desplegar.
- No hacer commit ni push.

### 4.3 Entregables

- `auditoria-portal-gobernanza.md`
- `auditoria-api.md`
- `auditoria-invoice-ninja.md` (incluye FreeScout)
- `auditoria-infraestructura.md` (incluye el inventario PostgreSQL del repositorio)

Son 4 documentos de auditoría más 8 de diseño: **12 entregables en total**.

## 5. Etapa 2 — Diseño arquitectónico

### 5.1 Actividades propuestas

- Definir la separación estricta entre gobernanza y clientes.
- Proponer modelo de organizaciones, usuarios, membresías, roles e invitaciones.
- Proponer vínculo estable con clientes/contactos de Invoice Ninja.
- Proponer relación producto comercial ↔ servicio técnico ↔ habilitación.
- Proponer arquitectura de credenciales acorde al mecanismo real de la API.
- Proponer rutas, interfaz, idiomas y estrategia de despliegue.
- Registrar decisiones, alternativas, riesgos y autorizaciones pendientes.

### 5.2 Entregables

- `arquitectura-portal-clientes.md`
- `modelo-identidad-organizaciones.md`
- `modelo-comercial-invoice-ninja.md`
- `modelo-servicios-entitlements.md`
- `arquitectura-credenciales-api.md`
- `plan-implementacion-portal-clientes.md`
- `plan-pruebas-portal-clientes.md`
- `registro-de-decisiones-arquitectonicas.md`

## 6. Etapa 3 — Aprobación

### 6.1 Punto de parada obligatorio

No se pasa a implementación sin acta que apruebe, como mínimo:

1. Separación de portales e identidades.
2. Modelo de organizaciones y permisos.
3. Estrategia de vinculación con Invoice Ninja.
4. Política de habilitación técnica.
5. Estrategia de credenciales API.
6. Diseño de rutas e i18n.
7. Plan de pruebas.
8. Plan de despliegue y rollback.

### 6.2 Decisiones que requieren aprobación individual

Cualquier cambio que afecte:

- Autenticación del portal de gobernanza.
- Autenticación de la API pública.
- Estructuras `os_admin` u `os_catalog_*`.
- Configuración de Invoice Ninja.
- Configuración de FreeScout.
- Nginx, HTTPS, PHP o servicios del VPS.
- Datos comerciales reales.

## 7. Etapa 4 — Preparación técnica (solo después de aprobación)

**Propuesta:**

- Crear entorno de desarrollo/pruebas separado de producción.
- Definir variables de configuración del nuevo portal, nunca secretos en claro.
- Preparar mecanismo de migraciones versionado y reversible.
- Definir backup previo y procedimiento de rollback.
- Preparar datos ficticios de organizaciones, usuarios y servicios.

**No incluye:** cambios en producción ni creación de clientes reales.

## 8. Etapa 5 — Modelo de organizaciones e identidad

**Propuesta:**

- Esquema propio para identidad de clientes, separado de `os_admin`.
- Rol de base de datos propio, con privilegios limitados a ese esquema.
- Autenticación con contraseña hasheada, sesiones con token hasheado y CSRF.
- Invitaciones con token de un solo uso, vencimiento y auditoría.
- Aislamiento por organización en todas las consultas del backend.
- Control de acceso verificado en servidor, nunca solo en la interfaz.

**Reglas de no mezcla:**

- No reutilizar `os_admin.app_user`, `os_admin.session`, `os_admin.role`, `os_admin.membership`, `os_admin.invitation`, `os_admin.catalog_grant` ni `os_admin.audit_log` para clientes comerciales.
- No compartir cookies de sesión ni secretos de sesión.
- No heredar roles de gobernanza por coincidencia de correo.

**Estado:** **cerrada en entorno de prueba** según `acta-autorizacion-etapa-5.md`. El responsable ejecutó backup, `up`, `verify.sql`, `down`, `verify_rollback.sql`, nueva re-aplicación del `up` y verificación final. Los artefactos SQL y PHP están en `sql/10_portal_clientes/` y `portal-clientes/`. La ejecución en producción sigue sin autorización.

## 9. Etapa 6 — Integración con Invoice Ninja

**Propuesta:**

- Servicio backend `InvoiceNinjaService`.
- API token exclusivamente en servidor.
- HTTPS, timeouts, reintentos controlados e idempotencia.
- Búsqueda previa por vinculación existente, identificador fiscal normalizado, razón social y contactos.
- Detección de coincidencias dudosas con intervención administrativa.
- Sin creación automática de clientes en caso de ambigüedad.

**Pruebas:** entorno de prueba o datos ficticios. No generar facturas ni pagos reales.

**Autorización requerida:** uso de API real, creación de clientes o presupuestos.

## 10. Etapa 7 — Servicios y habilitaciones

**Propuesta:**

- Catálogo técnico de servicios de Origen Salud.
- Relación flexible producto comercial ↔ servicio técnico.
- Estados separados: solicitado, presupuestado, contratado, pendiente de pago, pendiente de habilitación, activo, suspendido, vencido, cancelado.
- Habilitación administrativa controlada; no automática por factura emitida.
- Auditoría de cada cambio de estado y de quien lo ejecuta.

**Autorización requerida:** política de activación y ejecución de habilitaciones.

## 11. Etapa 8 — Credenciales API

**Propuesta:**

- Integrarse al mecanismo real de `code-api`, documentado en `auditoria-api.md`.
- Si el mecanismo actual no soporta scopes, revocación o medición, documentar la limitación y proponer evolución separada.
- Nunca almacenar secretos en claro si el mecanismo permite hash.
- Mostrar el secreto una sola vez cuando sea técnicamente posible.
- Registrar creación, rotación y revocación.

**Autorización requerida:** cualquier cambio en autenticación de API.

## 12. Etapa 9 — Interfaz del portal

**Propuesta de secciones:**

- Inicio.
- Mi organización.
- Usuarios y permisos.
- Mis servicios.
- Mis API.
- Credenciales.
- Consumo (solo con medición real).
- Documentación técnica.
- Soporte.
- Facturación y pagos (enlace al portal nativo de Invoice Ninja).

**Idiomas:** `es-AR`, `en`, `pt-BR`, usando el mecanismo existente de I18n. URL explícita prevalece sobre detección del navegador.

**Autorización requerida:** publicación de rutas y navegación.

## 13. Etapa 10 — Contratación pública

**Propuesta:**

- Carrito sin exigir cuenta.
- Formulario con datos mínimos de organización y contacto.
- Validación backend de productos y precios contra Invoice Ninja.
- CSRF, rate limiting y protección anti-spam.
- No crear cuenta técnica ni habilitar API automáticamente.
- No crear facturas ni pagos reales durante pruebas.

**Autorización requerida:** publicación del flujo y cualquier operación comercial real.

## 14. Etapa 11 — Pruebas

Ver `plan-pruebas-portal-clientes.md`. Cada etapa debe pasar sus pruebas antes de habilitar la siguiente.

## 15. Etapa 12 — Despliegue

**Propuesta:**

- Pipeline con revisión de diff.
- Backup previo.
- Rollback documentado y ensayado.
- Verificación post-despliegue de: `/portal`, Browse Codes, DENTAR, Docs, API pública y `/portal-clientes`.
- Sin commit, push ni deploy sin autorización expresa.

## 16. Criterios de salida de etapas 1 y 2

- [x] No se modificó PostgreSQL.
- [x] No se modificó código de producción.
- [x] No se modificó la API pública.
- [x] No se crearon clientes, facturas ni pagos.
- [x] No se modificaron Nginx, FreeScout ni Invoice Ninja.
- [x] No se hicieron commits, push ni despliegues.
- [x] Diseño completo presentado y aprobado.
- [x] Autorización expresa recibida para iniciar la etapa 4; ver `acta-autorizacion-etapa-4.md`.
