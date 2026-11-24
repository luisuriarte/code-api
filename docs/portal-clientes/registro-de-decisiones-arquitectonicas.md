# Registro de decisiones arquitectónicas — Portal de clientes

> **Estado:** registro aprobado como línea base de diseño mediante
> `acta-aprobacion-etapas-1-2.md`. **Ninguna decisión ha sido ejecutada.**
> **Fecha:** 2026-11-24.
>
> Las decisiones marcadas como **PROPUESTA** quedan aprobadas como diseño, pero
> no autorizan implementación. Las marcadas como **PENDIENTE** siguen requiriendo
> pronunciamiento específico. Las que dicen **COMPROBADO** describen el estado
> actual del repositorio o de los sistemas observados, no una autorización.

## 1. Convenciones de estado

- **COMPROBADO:** verificado en repositorio o consulta pública de solo lectura.
- **PROPUESTA:** diseño recomendado, sin ejecutar.
- **PENDIENTE:** requiere pronunciamiento del propietario.
- **RIESGO:** consecuencia adversa si se decide o ejecuta mal.
- **DEPENDENCIA:** condición previa.
- **AUTORIZACIÓN:** permiso expreso necesario para ejecutar.

## 2. Decisiones

| ID | Tema | Estado | Resumen | Dependencia / autorización |
|---|---|---|---|---|
| A-01 | Separación de portales | **PROPUESTA** | `/portal` de gobernanza sigue intacto; `/portal-clientes` es independiente. | Aprobación del acta. Sin cambios en `/admin`, sitio público ni API. |
| A-02 | Nombre del frente | **PROPUESTA** | Nuevo frente bajo `/{locale}/portal-clientes/...`. | Aprobación de rutas. No publicar sin autorización. |
| A-03 | Identidad | **PROPUESTA** | Esquema propio para clientes; no reutilizar `os_admin`. | Creación de esquema requiere autorización. |
| A-04 | Usuarios | **PROPUESTA** | Usuarios de clientes con contraseña hasheada y verificación de correo. | Definir política SMTP y contraseña. |
| A-05 | Sesiones | **PROPUESTA** | Cookies y tokens propios; token persistido como hash; expiración y revocación. | No compartir secretos ni cookies con `/admin`. |
| A-06 | SSO | **PROPUESTA** | No incluir SSO en la primera versión. | Solo podría revisarse como decisión futura. |
| A-07 | Vinculación por correo | **PROPUESTA** | Nunca vincular identidades ni clientes por correo igual. | Regla obligatoria; excepción solo con revisión humana. |
| A-08 | Multi-organización | **PROPUESTA** | Membresías explícitas, contexto activo y filtro por organización en backend. | Definir si un usuario puede tener varias organizaciones. |
| A-09 | Roles de clientes | **PROPUESTA** | Roles propios: owner, admin, technical_admin, developer, viewer. | Aprobación de permisos granular. |
| A-10 | Invitaciones | **PROPUESTA** | Solo por invitación; token hasheado, un solo uso y vencimiento. | Sin autorregistro público. |
| A-11 | Auditoría | **PROPUESTA** | Registro append-only separado de `os_admin.audit_log`. | Sin secretos en eventos. |
| A-12 | Invoice Ninja como fuente comercial | **COMPROBADO + PROPUESTA** | Repo referencia `INVOICE_NINJA_BASE_URL`; versión real no verificada. Se propone conservar Invoice Ninja como fuente de verdad. | Ver `auditoria-invoice-ninja.md`. No crear datos reales sin autorización. |
| A-13 | Vinculación comercial | **PROPUESTA** | Buscar por vínculo previo, identificador fiscal, razón social y contactos; ambigüedad = revisión humana. | No usar solo email. |
| A-14 | Duplicados | **PROPUESTA** | No crear cliente ante coincidencia dudosa. | Requiere procedimiento de revisión. |
| A-15 | Productos y precios | **PROPUESTA** | Consultar desde Invoice Ninja en backend; navegador envía IDs, nunca importes. | No guardar precios locales como verdad. |
| A-16 | Facturación y pagos | **PROPUESTA** | Enlace al portal nativo de Invoice Ninja; sin iframe ni UI propia. | Verificar Client Portal real. |
| A-17 | Carrito público | **PROPUESTA** | Carrito sin cuenta, con CSRF, rate limiting y validación backend. | `RATE_CART` existe pero sin consumidor; requiere autorización. |
| A-18 | Habilitación técnica | **PROPUESTA** | Administrativa, nunca automática por factura. | Definir condición comercial suficiente. |
| A-19 | Servicios técnicos | **PROPUESTA** | Catálogo técnico propio, relación flexible con productos comerciales. | Solo servicios reales verificados. |
| A-20 | Credenciales API | **PROPUESTA CONDICIONADA** | Gestionar metadatos y ciclo de vida compatible con API actual. | No cambiar autenticación sin decisión específica. |
| A-21 | Hash de API keys | **PENDIENTE** | El mecanismo real guarda texto plano; el hash requiere evolución M6. | Autorización separada. |
| A-22 | Scopes por credencial | **PENDIENTE** | No existen hoy. No ofrecerlos en la interfaz. | Autorización separada. |
| A-23 | Revocación y expiración | **PROPUESTA LIMITADA** | Hoy solo `is_active`; fecha de revocación se registra en auditoría del portal. | No agregar columnas sin autorización. |
| A-24 | Rotación | **PROPUESTA** | Nueva clave, invalida anterior de inmediato; sin periodo de gracia. | Documentar riesgo. |
| A-25 | Medición de consumo | **PROPUESTA** | No publicar consumo sin medición real. | Requiere implementar y autorizar telemetría. |
| A-26 | Último uso de credencial | **COMPROBADO** | No existe hoy. | No mostrar. |
| A-27 | Rate limiting API | **COMPROBADO + PENDIENTE** | `rate_limit_per_second` existe pero no se aplica; no hay `429`. | Cualquier aplicación requiere autorización. |
| A-28 | Entornos API | **PROPUESTA** | Solo `production` hasta verificar otra infraestructura. | No inventar `staging` ni `sandbox`. |
| A-29 | i18n | **PROPUESTA** | `es-AR`, `en`, `pt-BR` con mecanismo existente; URL explícita prevalece. | Paridad de claves YAML. |
| A-30 | Regresión | **PROPUESTA** | Verificar sitio público, `/admin`, `/v1`, Browse, DENTAR, OFTAR, Docs, UVR y sitemap tras cada etapa. | Parte de cada despliegue. |
| A-31 | Despliegue | **PROPUESTA** | Backup, diff revisado, rollback ensayado y verificación posterior. | Autorización explícita. |
| A-32 | Commit/push | **PROPUESTA** | No hacer commit, push ni deploy sin autorización. | Regla operativa actual. |

## 3. Decisiones que no pueden tomarse en etapas 1 y 2

Las siguientes quedan expresamente fuera de este diseño ejecutable:

1. Cambiar autenticación de `code-api`.
2. Modificar `api_clients`, `ApiKeyAuthenticator` ni guardia `/v1/*`.
3. Crear o modificar esquemas o roles de base.
4. Agregar `/fhir/*` ni `/v1/uvr`.
5. Cambiar el portal de gobernanza.
6. Modificar catálogos, importadores, fuentes ni traducciones clínicas aprobadas.
7. Cambiar Nginx, PHP-FPM, certificados ni backups.
8. Configurar o modificar Invoice Ninja ni FreeScout.
9. Crear clientes, presupuestos, facturas o pagos reales.
10. Hacer commit, push o deploy.

## 4. Riesgos derivados de decidir sin evidencia

| Riesgo | Decisión afectada |
|---|---|
| Diseñar contra versión incorrecta de Invoice Ninja | A-12 a A-16. |
| Crear portal mixto | A-01, A-03, A-05. |
| Filtrar datos entre organizaciones | A-08, A-09. |
| Publicar capacidades inexistentes de API | A-21 a A-25. |
| Romper el buscador público | A-20, A-27. |
| Habilitar servicios sin contrato verificado | A-18, A-19. |

## 5. Estado de la aprobación

El acta `acta-aprobacion-etapas-1-2.md` aprueba el paquete general:

1. A-01 a A-11: separación e identidad.
2. A-12 a A-19: comercio, Invoice Ninja y habilitación.
3. A-20 a A-28: credenciales y API, con las limitaciones documentadas.
4. A-29 y A-30: i18n y regresión.
5. A-31 y A-32: despliegue y control de cambios como principios.

Siguen pendientes los puntos marcados como `PENDIENTE` y los temas `NO VERIFICADO` listados en el acta.

## 6. Cierre

Este registro documenta decisiones aprobadas como diseño. **No constituye autorización para implementar.** El proceso debe detenerse aquí hasta que el propietario autorice expresamente una etapa concreta de ejecución.
