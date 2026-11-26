# Informe de ejecución — Etapa 11: Pruebas

> **Fecha:** 2026-11-26.
> **Entorno:** `origen_codes_portal_clientes_test` y sitio público `https://med.origen.ar`.
> **Autorización:** `acta-autorizacion-etapa-11.md`.
> **Estado:** en curso. T-01…T-07 y comprobaciones de migración, OK. T-08 pendiente de envío manual.

## 1. Migraciones

Comandos ejecutados en el VPS:

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.001__public_service_requests.verify.sql
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/V10.002__origen_med_no_superuser.verify.sql
```

Resultado observado:

| Comprobación | V10.001 | V10.002 |
| --- | --- | --- |
| `current_database()` | `origen_codes_portal_clientes_test` | `origen_codes_portal_clientes_test` |
| `tablas_v10` | 2 | 2 |
| `columnas_prohibidas` | 0 | — |
| `servicios_verificados` | 15 | — |
| `capacidades_inexistentes` | 0 | — |
| `sin_superuser` | — | `t` |
| `usa_esquema` | `t` | `t` |
| `lee_solicitudes` / `escribe_solicitudes` | `t` / `t` | `t` / `t` |
| `sin_update` / `sin_delete` | `t` / `t` | `t` / `t` |
| `sin_insert_en_servicios` / `sin_insert_en_habilitaciones` | `t` / `t` | `t` / `t` |
| `total_tablas` | 23 | 23 |

Conclusión: la corrección de privilegios queda verificada en el entorno de prueba.

## 2. Verificador de la Etapa 11

Primera ejecución:

```text
php tools/php/verificar_etapa11_portal_clientes.php --site=https://med.origen.ar
FALLOS (5 de 35)
```

Cinco fallos, todos estáticos: `T-00` (acta/plan) y `T-08`/`T-09` (nombre del flujo y T-09). Las comprobaciones HTTP pasaron. Causa: los documentos actualizados todavía no estaban en el VPS.

Segunda ejecución, después de subir los archivos:

```text
php tools/php/verificar_etapa11_portal_clientes.php --site=https://med.origen.ar
OK: 35 comprobaciones de la Etapa 11.
```

Con el caso negativo de CSRF habilitado:

```text
php tools/php/verificar_etapa11_portal_clientes.php --site=https://med.origen.ar --post
OK: 37 comprobaciones de la Etapa 11.
```

Cubierto: las tres locales de `/solicitud`, ausencia de enlace en la home, ausencia de secretos en HTML y rechazo `303` de un POST sin CSRF.

## 3. Estado de la base antes de T-08

```bash
sudo -u postgres psql -d origen_codes_portal_clientes_test -v ON_ERROR_STOP=1 \
  -f sql/10_portal_clientes/ETAPA11__verificacion_solicitudes.sql
```

Resultado:

```text
solicitudes | marcadas_duplicadas | para_revision
-------------+---------------------+---------------
           0 |                   0 |             0

items | solicitudes_con_items
-------+-----------------------
     0 |                     0

solicitudes_sin_items = 0
columnas_prohibidas   = 0
```

No hay solicitudes de prueba todavía. No se crearon clientes, facturas ni pagos.

## 4. Pendiente para cerrar T-08

1. Confirmar en `.env` del servidor: token **de prueba**, `INVOICE_NINJA_ALLOW_TEST_CALLS=true`, `RATE_REQUEST=5` y `CONTACT_EMAIL=med@origen.ar`; recargar `php-fpm`.
2. Abrir `/es-AR/solicitud` por URL directa y confirmar que el catálogo muestra productos. Si dice “Catálogo no disponible”, revisar el opt-in y el token antes de continuar.
3. Enviar una solicitud con datos ficticios; guardar el número de referencia.
4. Repetir el SQL de la sección 3: esperado `solicitudes = 1`, `items >= 1`, `solicitudes_sin_items = 0`, `columnas_prohibidas = 0`.
5. Confirmar el correo recibido en `CONTACT_EMAIL`, con `Reply-To` del correo ficticio y sin copias ocultas expuestas como cabecera.
6. Verificar en Invoice Ninja que no se creó cliente, presupuesto, factura ni pago.
7. Repetir el envío con los mismos datos dentro de los 30 días: esperado `marcadas_duplicadas = 1`, la segunda solicitud en `needs_review`, y ningún cliente duplicado en Invoice Ninja.
8. Documentar cualquier falla con severidad, reproducibilidad y decisión pendiente.

## 5. Cierre

La Etapa 11 no se considera cerrada hasta completar el punto 4. La Etapa 12 (despliegue) sigue sin autorización.
