# Modelo de servicios técnicos y habilitaciones

> **Estado:** propuesta arquitectónica; Etapa 7 implementada localmente en la base de prueba y pendiente de verificación en el VPS. **No desplegada en producción.**
> **Fecha:** 2026-11-24.
>
> Los nombres de tablas y estados son ilustrativos y requieren aprobación.

## 1. Convenciones de estado

- **Estado actual comprobado:** la API pública es de solo lectura; no hay `/v1/uvr` ni `/fhir/*`; los precios viven en Invoice Ninja.
- **Propuesta:** catálogo técnico de servicios y habilitaciones administradas.
- **Decisión pendiente:** política de activación y estados definitivos.
- **Riesgo:** habilitar servicios sin contrato o confundir contratación con acceso técnico.
- **Dependencia:** etapas 6 y 7.
- **Requisito de autorización:** crear entidades y ejecutar habilitaciones.

## 2. Principios

1. Producto comercial ≠ servicio técnico.
2. Invoice Ninja administra productos y precios; Origen Salud administra servicios y accesos.
3. Un producto puede habilitar varios servicios.
4. Un servicio puede venderse mediante varios productos o contratos.
5. Ningún precio se guarda en el portal de clientes.
6. Ningún importe enviado por navegador es confiable.
7. Contratar no habilita automáticamente.
8. Emitir una factura no habilita automáticamente.
9. Toda habilitación requiere decisión administrativa y auditoría.
10. Los servicios se muestran al usuario solo cuando son autorizados para su organización.

## 3. Entidades propuestas

### 3.1 `os_customer_service`

Catálogo técnico interno de servicios disponibles.

Atributos conceptuales:

- Código estable.
- Nombre y descripción.
- Dominio o familia técnica relacionada, si aplica.
- Endpoint o recurso técnico habilitable, verificado contra la API real.
- Entorno disponible: hoy solo `production`.
- Estado del servicio: `available`, `deprecated`, `retired`.
- Documentación técnica asociada.

**Regla:** no crear servicios ficticios. Solo se publican servicios que existan en el ecosistema real.

### 3.2 `os_customer_product_service`

Relación flexible entre producto comercial y servicios técnicos.

Atributos conceptuales:

- Producto de Invoice Ninja identificado por ID estable.
- Servicio técnico de Origen Salud.
- Condición comercial requerida para habilitación, como referencia a estado verificado; nunca importe local.
- Estado de la relación.

**Regla:** los productos y precios se consultan en backend desde Invoice Ninja. El portal guarda solo la relación, no el precio.

### 3.3 `os_customer_request`

Solicitud de uno o más servicios por una organización.

Atributos conceptuales:

- Organización solicitante.
- Usuario solicitante.
- Servicios solicitados.
- Estado: `received`, `under_review`, `needs_info`, `approved`, `rejected`, `converted`.
- Vínculo al cliente comercial de Invoice Ninja cuando exista.
- Registro de revisión humana.

### 3.4 `os_customer_contract`

Representa el acuerdo comercial verificado, sin duplicar facturación.

Atributos conceptuales:

- Organización.
- Cliente comercial vinculado.
- Referencia a presupuesto o factura de Invoice Ninja, si aplica.
- Estado comercial derivado de verificación, no copiado como fuente de verdad.
- Fechas de vigencia si existen datos reales.
- Quién verificó el estado comercial.

**Regla:** no copiar importes, items de factura ni pagos al portal de clientes.

### 3.5 `os_customer_entitlement`

Habilitación técnica efectiva.

Atributos conceptuales:

- Organización, servicio y contrato o solicitud origen.
- Estado: `pending_activation`, `active`, `suspended`, `expired`, `revoked`.
- Fecha de habilitación.
- Fecha de vencimiento, solo si existe fecha real.
- Usuario que habilitó, suspendió o revocó.
- Motivo y auditoría.

## 4. Estados propuestos

### 4.1 Estados comerciales

- Solicitud recibida.
- En evaluación.
- Presupuestado.
- Pendiente de aceptación.
- Contratado.
- Pendiente de pago.
- Pendiente de habilitación.
- Activo.
- Suspendido.
- Vencido.
- Cancelado.

**Regla:** son estados operativos de Origen Salud, no una copia de los estados nativos de Invoice Ninja.

### 4.2 Estados técnicos

- `pending_activation`.
- `active`.
- `suspended`.
- `expired`.
- `revoked`.

**Regla:** el estado técnico se decide por administrador, no por webhook no verificado ni por cambio automático de factura.

## 5. Flujo propuesto

1. La organización solicita servicios desde carrito público o portal privado.
2. El backend valida la organización y detecta duplicados.
3. Se identifica o vincula el cliente comercial en Invoice Ninja.
4. Se prepara presupuesto según procedimiento comercial.
5. El cliente recibe y acepta el presupuesto por Invoice Ninja.
6. Se verifica la condición comercial requerida.
7. Un administrador de Origen Salud confirma la habilitación.
8. Se crea el `entitlement` técnico.
9. Se invita al responsable técnico si aún no tiene acceso.
10. Se pueden crear credenciales acordes al servicio habilitado.

**Regla:** la creación de credenciales no precede a la habilitación del servicio.

## 6. Visualización en el portal

La sección «Mis servicios» debe distinguir claramente:

| Concepto | Qué significa |
|---|---|
| Solicitado | La organización pidió el servicio; aún no hay habilitación. |
| Presupuestado/contratado | Estado comercial verificado desde Invoice Ninja o registro interno. |
| Habilitado | Existe `entitlement` técnico activo. |
| Suspendido/vencido/cancelado | El acceso técnico no debe considerarse vigente. |

No mostrar:

- Precios no verificados.
- Condiciones comerciales inventadas.
- Servicios que la organización no tiene autorizados.
- Consumo, salvo medición real.

## 7. Relación con credenciales

- Un `entitlement` activo habilita servicios, no automáticamente credenciales.
- La credencial pertenece a la organización.
- El portal debe verificar que el servicio siga habilitado antes de permitir gestión de credenciales asociadas.
- Una suspensión de servicio no implica borrar credenciales; debe registrar decisión y efecto.
- La API real no tiene scopes por servicio, por lo que no se debe afirmar que una clave está limitada a un servicio determinado.

## 8. Reglas anti-duplicado

- No crear dos solicitudes idénticas para la misma organización y servicios en ventana corta sin revisión.
- No crear dos contratos para el mismo presupuesto verificado.
- No crear dos `entitlement` activos para la misma organización y servicio.
- Si aparece evidencia comercial contradictoria, pasar a revisión humana.

## 9. Auditoría

Registrar, como mínimo:

- Solicitud creada y servicios incluidos.
- Cambio de estado comercial verificado.
- Habilitación, suspensión, vencimiento y revocación técnica.
- Actor, organización, motivo y resultado.
- Referencia estable al registro comercial sin copiar secretos ni datos financieros sensibles.

## 10. Riesgos

- Activar acceso por pago reportado pero no confirmado.
- Confundir `institution_name` de `api_clients` con una organización técnica verificada.
- Copiar precios y quedar desactualizado.
- Crear entidades técnicas sin producto comercial válido.
- Mostrar servicios solicitados como si estuvieran activos.
- Inventar scopes o entornos que la API no posee.

## 11. Decisiones

Resueltas por `acta-autorizacion-etapa-7.md` (solo entorno de prueba):

1. La habilitación exige **pago confirmado verificado manualmente + decisión técnica manual**; no se dispara por factura ni webhook.
2. Solo el **superadministrador de Origen Salud** puede verificar el pago y habilitar, suspender o revocar.
6. El catálogo inicial contiene **solo servicios verificables en la API actual** (rutas `GET` documentadas); no se publican `/fhir/*`, `/v1/uvr` ni `/v1/cdt`.

Sigue pendiente y **no se implementa** en esta etapa:

3. Vencimiento automático por fecha: la columna `expires_at` existe, pero el cambio a `expired` solo lo decide un superadministrador.
4. Suspensión parcial dentro de un contrato: la habilitación se decide por organización y servicio.
5. Planes institucionales con varios servicios: la relación producto ↔ servicio queda como referencia opaca, sin precios ni agrupaciones comerciales locales.

## 12. Requisito de autorización

No crear tablas, relaciones ni estados, y no habilitar servicios reales, sin aprobación expresa y sin que Invoice Ninja confirme la información comercial correspondiente.
