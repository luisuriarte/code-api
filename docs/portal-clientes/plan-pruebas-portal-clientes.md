# Plan de pruebas — Portal privado de clientes

> **Estado:** autorizado para ejecución en entorno de prueba por `acta-autorizacion-etapa-11.md`. **No ejecutado contra producción.**
> **Fecha:** 2026-11-24. Actualizado 2026-11-26.
>
> Ninguna prueba de este plan se ejecutó contra producción. Las pruebas que
> impliquen creación de datos deben hacerse en entorno de prueba o con datos
> ficticios, salvo autorización expresa.

## 1. Convenciones de estado

- **Estado actual comprobado:** resultado observado hasta ahora.
- **Propuesta:** prueba a ejecutar cuando exista implementación.
- **Decisión pendiente:** criterio que debe aprobar el propietario.
- **Riesgo:** daño potencial si la prueba no se ejecuta.
- **Dependencia:** etapa previa necesaria.
- **Requisito de autorización:** permiso para ejecutarla.

## 2. Principios de prueba

1. Ninguna prueba destructiva en producción.
2. Ningún cliente, presupuesto, factura ni pago real en pruebas.
3. Ningún secreto real en logs, fixtures ni respuestas.
4. Toda prueba de seguridad incluye un caso negativo.
5. Toda prueba de integración incluye error de red, timeout y respuesta inválida.
6. Las pruebas de regresión incluyen el portal de gobernanza y la API pública.

## 3. Matriz de cobertura

| ID | Ámbito | Tipo | Estado |
|---|---|---|---|
| T-01 | Separación de portales | Seguridad | Autorizada en entorno de prueba |
| T-02 | Multi-organización | Seguridad | Autorizada en entorno de prueba |
| T-03 | Invoice Ninja | Integración | Autorizada con token de prueba |
| T-04 | Credenciales API | Seguridad | Autorizada en entorno de prueba |
| T-05 | Seguridad general | Seguridad | Autorizada en entorno de prueba |
| T-06 | Regresión | Regresión | Autorizada; sin `/cart` |
| T-07 | I18n y rutas | Funcional | Autorizada en entorno de prueba |
| T-08 | Solicitud de Servicios | Funcional | Autorizada con datos ficticios |
| T-09 | Consumo y métricas | Datos | No aplica: sin medición real |
| T-10 | Despliegue y rollback | Operación | No autorizada; pertenece a Etapa 12 |

## 4. T-01 — Separación de portales

**Dependencia:** etapa 5.

Casos propuestos:

1. Un colaborador activo de `/portal` intenta entrar a `/portal-clientes` con su sesión de gobernanza → **acceso denegado**.
2. Un usuario de cliente intenta entrar a `/portal` con su sesión de cliente → **acceso denegado**.
3. Las cookies de sesión son distintas y no se comparten → **verificado**.
4. Un correo idéntico en ambos sistemas no produce vinculación automática → **verificado**.
5. Un rol de gobernanza no aparece como rol de cliente → **verificado**.
6. Un intento de elevación de privilegios cambiando parámetros de rol, organización o permiso → **denegado y auditado**.
7. La persona puede tener dos cuentas independientes sin heredar permisos → **verificado**.

**Riesgo mitigado:** portal mixto o escalada lateral entre ámbitos.

## 5. T-02 — Multi-organización

**Dependencia:** etapa 5.

Casos propuestos:

1. Usuario con membresía solo en la organización A lista organizaciones → ve únicamente A.
2. Usuario intenta consultar usuario, credencial, servicio, consumo o dato comercial de la organización B por ID directo → **404 o 403**, nunca filtrado parcial.
3. Usuario con membresías en A y B cambia de contexto explícitamente → permisos recalculados en backend.
4. Los permisos de B no se suman mientras el contexto activo es A.
5. Invitación de A aceptada por correo de B no otorga acceso a B.
6. Revocación de membresía invalida acceso en la misma petición siguiente.
7. Operaciones administrativas quedan en auditoría con actor, organización, IP/agent hasheados y resultado.

**Riesgo mitigado:** acceso horizontal entre organizaciones.

## 6. T-03 — Invoice Ninja

**Dependencia:** etapas 4 y 6. **Autorización:** entorno de prueba o autorización expresa.

Casos propuestos:

1. Buscar cliente por identificador fiscal normalizado existente.
2. Buscar por razón social y detectar coincidencia exacta.
3. Buscar por contacto/correo y detectar coincidencia ambigua → **no crear**, escalar.
4. Verificar vinculación previa antes de cualquier creación.
5. Consultar contactos del cliente vinculado.
6. Consultar productos y precios desde backend; el navegador no puede fijar importes.
7. Consultar estados comerciales y manejar respuesta sin datos.
8. Simular error 401, 403, 404, 429 y 500 del API de Invoice Ninja.
9. Simular timeout y respuesta HTML inesperada → error controlado, sin trace.
10. Reintentar creación con misma clave de idempotencia → no duplicar.
11. Verificar que el token de Invoice Ninja no aparece en HTML, JS, cookies ni logs.
12. Verificar enlace al Client Portal oficial sin construir URLs con tokens propios.

**Prohibido:** crear clientes, presupuestos, facturas o pagos reales durante esta etapa.

## 7. T-04 — Credenciales API

**Dependencia:** etapas 4 y 8.

Casos propuestos:

1. Crear credencial solo por usuario autorizado de la organización correcta.
2. La credencial queda asociada a la organización y al creador.
3. El secreto se muestra una sola vez cuando el mecanismo lo permita.
4. Después de la creación no se puede recuperar el secreto completo.
5. El secreto nunca se escribe en logs ni en URLs.
6. Rotación invalida la credencial anterior.
7. Revocación invalida access inmediato en la API real.
8. Scopes, si existen, se aplican en backend y no se pueden ampliar desde el navegador.
9. Usuario de otra organización no puede ver, rotar ni revocar la credencial.
10. Operación sensible registrada en auditoría.

**Limitación conocida:** si la API real no soporta scopes, rotación o revocación, documentar y no simular esas capacidades.

## 8. T-05 — Seguridad general

Casos propuestos:

- CSRF: todo POST sin token válido → rechazado.
- XSS: escapar salida en organización, usuarios, servicios, documentación y soporte.
- SQL injection: parámetros siempre ligados; whitelist de columnas y tablas.
- Acceso vertical: Viewer no puede invitar, cambiar roles ni gestionar credenciales.
- Sesión: expiración, regeneración de ID al login/logout, revocación.
- Recuperación: token de un solo uso, vencimiento, sin revelar existencia de cuenta.
- Invitación: token hasheado, un solo uso, vencimiento, revocación.
- Rate limiting: login, recuperación, invitaciones y solicitud comercial.
- Secretos: no aparecen en respuesta, logs ni mensajes de error.
- HTTPS: redirect y rechazo de credenciales sobre HTTP.

## 9. T-06 — Regresión

**Estado actual comprobado:** la especificación exige que nada de esto se modifique en etapas 1 y 2.

Verificar al final de cada etapa de implementación:

- `/portal`: login, logout, panel, catálogos, propuestas, revisión, aprobación y auditoría.
- API pública: rutas `/v1/*` y `/fhir/*` existentes, autenticación y formatos.
- Browse Codes: búsqueda, filtros, parámetros GET y fragments AJAX.
- DENTAR y OFTAR: páginas y navegación.
- Docs, About y Contact (sin `/cart`).
- Sitemap localizado y selector de idioma.
- Permisos de base: gobernanza no gana privilegios sobre esquemas de clientes y viceversa.

## 10. T-07 — I18n y rutas

Casos propuestos:

1. `/es-AR/portal-clientes`, `/en/portal-clientes` y `/pt-BR/portal-clientes` responden con interfaz localizada.
2. El idioma explícito de URL prevalece sobre `Accept-Language`.
3. El selector conserva la preferencia al navegar entre secciones del portal de clientes.
4. No hay textos hardcodeados en controladores, vistas ni JS.
5. Los nombres de servicios y catálogos no se confunden con traducciones clínicas aprobadas.
6. La navegación del portal público no se mezcla con la de gobernanza ni con la de clientes.

## 11. T-08 — Contratación pública

Casos propuestos:

1. Visitante sin cuenta selecciona servicios y envía una Solicitud de Servicios.
2. Productos y precios se validan contra Invoice Ninja desde backend.
3. Manipular importes o IDs en el navegador → rechazado.
4. CSRF, rate limiting y anti-spam activos.
5. Solicitudes duplicadas detectadas y no crean cliente duplicado.
6. La Solicitud de Servicios no crea cuenta técnica ni habilita API.
7. La solicitud queda registrada para revisión humana.

## 12. T-09 — Consumo y métricas

**Regla:** si no hay medición real, la sección no se publica.

Casos propuestos solo si existe medición:

1. Los datos provienen de solicitudes reales registradas.
2. El conteo está filtrado por organización autenticada.
3. No se muestran estimaciones como mediciones.
4. Período, endpoint y credencial se derivan de datos reales.
5. Errores y latencia, si se muestran, tienen definición documentada.

**Si no existe medición:** la prueba esperada es que la sección esté ausente o deshabilitada con mensaje honesto.

## 13. T-10 — Despliegue y rollback

Casos propuestos:

1. Diff revisado antes de aplicar.
2. Backup previo verificado.
3. Rollback ensayado en entorno de prueba.
4. Tras desplegar, ejecutar T-06 completo.
5. Logs sin secretos ni datos sensibles.
6. Si falla una verificación, ejecutar rollback y documentar.

## 14. Criterios de aceptación

- Todas las pruebas de seguridad tienen caso positivo y negativo.
- No hay salida de secretos en ningún canal.
- No se crearon datos comerciales reales sin autorización.
- No hay regresión en `/portal`, Browse Codes, DENTAR ni API.
- Cada falla queda registrada con severidad, reproducibilidad y decisión pendiente.

## 15. Autorización

Ninguna prueba de este plan faculta por sí sola a ejecutar cambios. La ejecución de pruebas con datos reales, creación de clientes, modificación de infraestructura o despliegue requiere autorización expresa del propietario del proyecto. La autorización vigente para la Etapa 11 está en `acta-autorizacion-etapa-11.md`.

## 16. Ejecución de la Etapa 11

Local, sin red:

```bash
php tests/run.php
php tools/php/verificar_etapa11_portal_clientes.php
```

VPS, después de subir los archivos:

```bash
cd /var/www/html/origen.ar/code-api

sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.001__public_service_requests.verify.sql
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.002__origen_med_no_superuser.verify.sql

php tools/php/verificar_etapa11_portal_clientes.php --site=https://med.origen.ar
php tools/php/verificar_etapa11_portal_clientes.php --site=https://med.origen.ar --post
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/ETAPA11__verificacion_solicitudes.sql
```

Secuencia manual de T-08 con datos ficticios:

0. Requisito previo: configurar `SERVICE_REQUEST_DB_DSN` en el servidor apuntando a `origen_codes_portal_clientes_test`. El límite de conexiones de `origen_med` (`rolconnlimit`) es un cambio cluster-wide y requiere autorización expresa antes de modificarse; sin él, el formulario debe mostrar el mensaje localizado `database_unavailable`, no un 500.
1. Abrir `/es-AR/solicitud` por URL directa.
2. Agregar servicios, quitar uno y mantener al menos uno.
3. Enviar con organización, contacto y correo ficticios.
4. Verificar la fila con el SQL de solo lectura indicado arriba.
5. Confirmar en Invoice Ninja que **no** se creó cliente, presupuesto, factura ni pago.
6. Repetir el envío con los mismos datos dentro de los 30 días y comprobar que la segunda solicitud queda marcada para revisión, sin duplicar nada en Invoice Ninja.

Si alguna comprobación falla, documentar severidad, reproducibilidad y decisión pendiente. No habilitar la Etapa 12 hasta que todas estén cerradas.
