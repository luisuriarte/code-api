# Modelo comercial e integración con Invoice Ninja

> **Estado:** propuesta arquitectónica. **No implementado.**
> **Fecha:** 2026-11-24.
>
> Invoice Ninja continúa siendo la fuente de verdad comercial y financiera.
> No se crearon clientes, contactos, presupuestos, facturas ni pagos.

## 1. Convenciones de estado

- **Estado actual comprobado:** instalación pública accesible en `https://gestion.uriarte.ar`; respuesta HTML con título «Invoice Ninja» y SPA React. Versión y endpoints **no verificados** sin credenciales.
- **Propuesta:** adaptador backend y modelo de vínculos.
- **Decisión pendiente:** versión real, API token, permisos y flujo comercial autorizado.
- **Riesgo:** duplicidad comercial o divergencia de datos.
- **Dependencia:** etapas 1, 4 y 6.
- **Requisito de autorización:** cualquier uso de API real u operación de creación.

## 2. Responsabilidades por sistema

### 2.1 Invoice Ninja

Fuente de verdad de:

- Clientes comerciales y contactos.
- Identificación fiscal y datos comerciales.
- Productos y precios.
- Presupuestos.
- Facturas.
- Pagos y estados financieros.
- Portal nativo de clientes.

### 2.2 Origen Salud

Administra:

- Organizaciones técnicas de clientes.
- Usuarios, membresías y roles del portal de clientes.
- Servicios técnicos disponibles.
- Relación producto comercial ↔ servicio técnico.
- Solicitudes, contrataciones e habilitaciones técnicas.
- Credenciales API y entornos.
- Vínculos estables con registros de Invoice Ninja.

No administra:

- Precios propios.
- Facturas duplicadas.
- Pagos duplicados.
- Datos fiscales de autoridad.

## 3. Estado actual verificado de forma pública

Consulta HTTP de solo lectura al dominio público:

- Responde con una aplicación SPA de Invoice Ninja.
- El HTML expone bundles JS y metadatos genéricos.
- No se obtuvo versión instalada, estado de API, endpoints, webhooks ni configuración del Client Portal.
- No se intentó autenticación ni se usaron tokens.

**Consecuencia:** no se puede afirmar que endpoints o campos de la documentación pública estén disponibles en esta instalación. La etapa 1 debe verificarlos directamente con credenciales autorizadas o documentar la limitación.

## 4. Entidades propuestas

Nombres ilustrativos, sujetos a aprobación.

### 4.1 `os_billing_customer_link`

Vincula una organización técnica de Origen Salud con un cliente de Invoice Ninja.

Atributos conceptuales:

- `organization_id` interno.
- `invoice_ninja_client_id` estable.
- Estado del vínculo: `proposed`, `confirmed`, `needs_review`, `inactive`.
- Quién vinculó, cuándo y evidencia de la decisión.
- Notas de revisión humana.

**Regla:** el vínculo se crea solo después de verificar identidad comercial. Nunca se asume por correo electrónico.

### 4.2 `os_billing_contact_link`

Vincula un usuario del portal de clientes con un contacto comercial de Invoice Ninja, si la versión instalada expone contactos de forma consultable.

Atributos conceptuales:

- `customer_user_id`, `invoice_ninja_contact_id`.
- Estado y trazabilidad.
- Sin credenciales ni contraseñas compartidas.

**Regla:** es opcional. Si no hay API de contactos suficiente, se documenta y se deja para revisión administrativa.

### 4.3 Solicitud comercial

Entidad propuesta para el carrito público:

- Datos de organización y contacto.
- Servicios solicitados.
- Comentarios y aceptación de condiciones.
- Estado: `received`, `under_review`, `needs_info`, `approved`, `rejected`, `converted`.
- Registro anti-duplicados y de revisión humana.

**No crea** cliente, cuenta técnica, factura ni habilitación automáticamente.

## 5. Prevención de clientes duplicados

Antes de crear un cliente en Invoice Ninja:

1. Consultar si existe vínculo previo confirmado.
2. Normalizar y buscar identificador fiscal.
3. Comparar razón social.
4. Revisar contactos y correos institucionales.
5. Considerar clientes archivados e inactivos.
6. Si hay coincidencia exacta → reutilizar y vincular.
7. Si hay coincidencia ambigua → `needs_review`, sin creación.
8. Si no hay coincidencia → crear solo con autorización.

**Prohibido:** usar solo el correo electrónico como criterio de identidad comercial.

## 6. Servicio backend propuesto

`InvoiceNinjaService`, responsabilidades:

- Buscar clientes por vínculo, identificador fiscal y razón social.
- Consultar contactos del cliente.
- Consultar productos y precios.
- Crear clientes cuando esté autorizado y sea seguro.
- Crear presupuestos cuando esté autorizado.
- Consultar estados comerciales.
- Obtener datos mínimos para habilitación técnica.
- Registrar operaciones relevantes sin secretos.

Requisitos técnicos:

- API token solo en servidor, desde variable de entorno.
- HTTPS obligatorio.
- Timeouts y reintentos controlados.
- Idempotencia en creación.
- Validación estricta de respuestas.
- No exponer token en HTML, JS, cookies, URL ni logs.
- No confiar en importes enviados por navegador.

## 7. Catálogo comercial y precios

- Los productos y precios se consultan desde Invoice Ninja en backend.
- El carrito enviado por navegador puede enviar IDs de producto, nunca importes.
- El backend recalcula y valida la selección.
- Si el producto no existe o está inactivo, la solicitud se rechaza.
- Un producto puede habilitar varios servicios técnicos.
- Un servicio técnico puede venderse mediante varios productos o contratos.

## 8. Flujo comercial propuesto

1. Solicitud pública o interna de servicios.
2. Validación de datos y detección de duplicados.
3. Identificación o creación autorizada de cliente en Invoice Ninja.
4. Preparación de presupuesto por el procedimiento comercial.
5. Envío y aceptación mediante Invoice Ninja.
6. Facturación correspondiente, según procedimiento comercial.
7. Verificación de condición comercial requerida.
8. Habilitación técnica administrativa.
9. Invitación al responsable técnico del portal de clientes.

**Regla:** factura emitida no equivale a servicio habilitado.

## 9. Portal nativo de facturación

- La opción «Facturación y pagos» debe enlazar al Client Portal oficial de Invoice Ninja.
- No iframe.
- No interfaz propia de facturas ni pagos.
- No construir URLs con tokens de acceso propios.
- No duplicar presupuestos, facturas ni pagos.
- La forma exacta de acceso debe verificarse en la versión instalada.

## 10. Webhooks

**Estado:** no verificado.

Si la versión instalada los soporta:

- Validar autenticidad con el mecanismo real.
- Verificar origen o firma.
- Evitar procesamiento duplicado mediante idempotencia.
- Registrar evento y resultado.
- Manejar reintentos.
- No confiar en payload no verificado.

Si no existen o no son adecuados: evaluar conciliación periódica desde backend, previa autorización.

## 11. Riesgos

- Crear un segundo cliente por correo distinto para la misma razón social.
- Copiar precios al portal y que queden desactualizados.
- Habilitar servicios por una factura pendiente de pago.
- Exponer token de Invoice Ninja en frontend.
- Duplicar información fiscal y perder la fuente de verdad.
- Asumir endpoints de una versión distinta a la instalada.

## 12. Decisiones pendientes

1. Versión exacta de Invoice Ninja y endpoints disponibles.
2. Mecanismo de API token y permisos.
3. Campos reales de cliente y contacto.
4. Configuración del Client Portal y acceso por contacto.
5. Disponibilidad de webhooks y validación.
6. Política de habilitación: pago confirmado, presupuesto aceptado o decisión manual.
7. Quién puede crear clientes y presupuestos desde el portal.

## 13. Requisito de autorización

No consultar API con credenciales reales, crear clientes, contactos, presupuestos, facturas ni pagos, ni modificar la instalación, sin autorización expresa del propietario.
