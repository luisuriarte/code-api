# Acta de autorización — Etapa 11: Pruebas

> **Fecha:** 2026-11-26.
> **Autorizada por:** responsable del proyecto.
> **Alcance:** ejecución del plan de pruebas en entorno de prueba y comprobaciones locales. **No incluye despliegue ni publicación.**

## 1. Decisión

Se autoriza iniciar la **Etapa 11 — Pruebas** definida en `plan-implementacion-portal-clientes.md`, con `plan-pruebas-portal-clientes.md` como guía. La Etapa 12 (despliegue) queda **expresamente fuera** de esta autorización.

## 2. Límites

| Ítem | Regla |
| --- | --- |
| Entorno | Base aislada `origen_codes_portal_clientes_test`. Ninguna prueba destructiva en `origen_codes`. |
| Datos comerciales | No se crean clientes, contactos, presupuestos, facturas, pagos ni credenciales de Invoice Ninja. |
| Token | Solo token **de prueba** y con `INVOICE_NINJA_ALLOW_TEST_CALLS=true`. Nunca token real. |
| Solicitudes de prueba | Se permiten envíos con datos ficticios a `os_customer.public_service_request`. Pueden generar correo a `CONTACT_EMAIL` configurado en el servidor; `CONTACT_BCC` sigue siendo opcional y el correo del solicitante va como `Reply-To`. |
| Navegación | La Solicitud de Servicios permanece sin enlaces en nav, footer ni home. Solo se alcanza por URL directa. |
| Secretos | Ningún token, clave ni dato sensible en HTML, JS, logs, fixtures ni respuestas. |
| Producción | Sin cambios de esquema, sin despliegue y sin operaciones comerciales reales. |

## 3. Casos incluidos

- **T-01 a T-08:** autorizados en la medida en que exista implementación. Los casos que requieren cuenta privada se comprueban con el estado actual del código y la base de prueba.
- **T-08:** se ejecuta con el nombre **Solicitud de Servicios**. No se usa «cart» ni «carrito» en el plan ni en los informes.
- **T-09:** **No aplica**. No existe medición real de consumo; la sección sigue omitida deliberadamente.
- **T-10:** **no autorizado**. Rollback ya ensayado a nivel de migraciones, pero el despliegue y sus verificaciones pertenecen a la Etapa 12.

## 4. Herramientas

- `php tests/run.php`: suite local completa.
- `php tools/php/verificar_etapa11_portal_clientes.php`: informe estático y, si se le pasa `--site=https://…`, comprobaciones HTTP de solo lectura. El modo `--post` es opt-in para el caso negativo de CSRF.
- `sql/10_portal_clientes/ETAPA11__verificacion_solicitudes.sql`: consulta `SELECT`-only de solicitudes e ítems, sin correos ni importes.

## 5. Criterios de salida

La Etapa 11 se considera cerrada cuando:

1. La suite local termina sin fallos.
2. El verificador de la Etapa 11 termina sin fallos.
3. Las migraciones `V10.001` y `V10.002` vuelven a verificar en `origen_codes_portal_clientes_test`.
4. Las tres locales de `/solicitud` responden y muestran textos localizados.
5. No aparece `/solicitud` en nav, footer ni home, ni `/cart` en el sitemap.
6. Una solicitud de prueba queda registrada con sus ítems, sin precios guardados y sin creación comercial en Invoice Ninja.
7. Todo fallo queda documentado con severidad, reproducibilidad y decisión pendiente antes de habilitar la Etapa 12.
