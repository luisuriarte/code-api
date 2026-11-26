# Acta de autorización — Etapa 9: Interfaz del portal

> **Estado:** AUTORIZADA el 2026-11-26 e **IMPLEMENTADA EN LOCAL**. Pendiente de verificación en el VPS y de subida por el responsable. **No desplegada en producción.**
> **Autorizado por:** responsable del proyecto.
> **Relación:** continuación de la Etapa 8, cerrada en `origen_codes_portal_clientes_test`.

## 1. Alcance autorizado

Se autoriza completar la navegación y las vistas de `/portal-clientes` con las secciones previstas en el `plan-implementacion-portal-clientes.md`:

- Inicio (existente, con accesos rápidos).
- Mi organización (existente; etiqueta renombrada).
- Usuarios y permisos (existente; etiqueta renombrada).
- Mis servicios (existente, con modalidades comerciales).
- Mis API (nueva).
- Credenciales (existente).
- Documentación técnica (nueva).
- Soporte (nueva).
- Facturación y pagos (nueva, como enlace configurable).

Idiomas: `es-AR`, `en` y `pt-BR`, con preferencia de la URL explícita sobre la detección del navegador. El dominio i18n sigue siendo `customer_portal`; no se modifican los catálogos del portal público ni de gobernanza.

## 2. Decisiones comerciales incorporadas a la interfaz

- Se muestran tres modalidades como texto localizado: **precio público**, **desde un importe** y **cotización personalizada**.
- No se crea tabla de precios en PostgreSQL ni se copian importes al código. Invoice Ninja permanece como fuente de verdad de productos, precios, impuestos, presupuestos y facturas.
- El portal privado muestra servicios contratados y habilitados; el catálogo público de precios corresponde a la Etapa 10.
- No se publica la sección de **Consumo**: no existe medición confiable en `code-api` y cobrar por consumo sin medición expondría a facturación incorrecta.
- La preferencia comercial de modelo híbrido queda registrada como intención, sin facturación de excedentes hasta contar con medición real.
- Precio de lista y precio presupuestado no se confunden: las condiciones especiales pertenecen al sistema comercial.

## 3. Límites

- No se ejecuta SQL de migración: la Etapa 9 es solo interfaz.
- No se crea ni consulta cliente, contacto, producto, precio, presupuesto, factura ni pago en Invoice Ninja.
- No se agrega token real ni llamada HTTP nueva a Invoice Ninja.
- No se habilita SSO, vinculación automática por correo ni activación automática por factura.
- No se modifica Nginx, PHP-FPM ni el front controller de `/portal`.
- No se realiza commit, push ni deploy; el responsable gestiona versión y subida de archivos.

## 4. Configuración

La única variable nueva es `PORTAL_CUSTOMER_BILLING_URL`, opcional y solo en el servidor:

```dotenv
PORTAL_CUSTOMER_BILLING_URL=https://<portal-de-facturacion>
```

Debe ser `https`. Vacía o inválida, la vista informa que el enlace no está configurado. El valor nunca se deriva del `Host` de la petición ni se escribe en el repositorio. El enlace se abre en pestaña nueva con `rel="noopener noreferrer"`.

## 5. Adenda — DENTAR y OFTAR en el catálogo técnico

> **Autorizada por:** responsable del proyecto. Fecha: 2026-11-26. Motivo: se omitió la inclusión original en V7.001.

Se autoriza una migración **aditiva** `V7.002__dentar_oftar_services`, sin reabrir ni modificar V7.001:

| Código | Nombre | Dominio | Ruta verificada | Modalidad comercial prevista |
| --- | --- | --- | --- | --- |
| `api.dentar` | DENTAR | `odontologia` | `/v1/odontologia/diagnosticos` | Desde un importe / institucional |
| `api.oftar` | OFTAR | `oftar` | `/v1/catalogs/{catalog_code}/items` con `oftar-pr` u `oftar-dx` | Cotización inicial |

- Solo dos filas en `os_customer.service`, con `GET`, autenticación requerida y fuente verificada.
- No se guardan precios, importes, UVR, facturas ni pagos.
- No se crean tablas, columnas ni grants nuevos.
- No se modifica Invoice Ninja ni se crean clientes, presupuestos ni facturas.
- Vigencia: la migración se ejecuta solo en `origen_codes_portal_clientes_test`; producción queda intacta.
- Rollback: `V7.002 down` antes de `V7.001 down`; si hay habilitaciones referenciadas, el `DELETE` falla en vez de borrar en cascada.

Precauciones documentadas que se conservan: DENTAR no es nomenclador oficial ni estándar internacional; `DENTAR-DX` no tiene UVR ni facturación; `DENTAR-AN` y `DENTAR-CL` siguen como “No publicado” por decisión editorial; las relaciones CDT aún no son navegables; OFTAR se consulta por dominio/catálogo, sin endpoint propio.

## 6. Cierre

La verificación local debe incluir `php -l`, la suite `php tests/run.php`, paridad de claves i18n en los tres idiomas y revisión de que no existan importes ni ruta de consumo. La etapa se considera cerrada en prueba cuando el responsable confirme esas comprobaciones en el VPS. Queda fuera de esta autorización la contratación pública (Etapa 10), las pruebas de despliegue (Etapa 11) y el despliegue (Etapa 12).
