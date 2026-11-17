# Corte controlado multilingüe (Fase 13) — entorno de pruebas

Este documento describe el estado preparado de la Fase 13. No modifica los
cuatro documentos aprobados en `cc803b5`, no ejecuta cambios en la base y no
solicita firmas ni autorizaciones adicionales.

## Decisiones operativas vigentes

- El entorno es de **pruebas con datos no reales**. No hay producción.
- Aplica la decisión del responsable **«Sin Backups»**. No se pide backup ni
  autorización de backup para este corte.
- El corte **no se activa automáticamente**. La compuerta
  `OS_IMPORT_MODE=dual` queda como valor por defecto.
- `OS_IMPORT_MODE=new_only` existe solo como interlock: si se configura sin la
  implementación write-only verificada, los importadores fallan con un error
  explícito y revierten la transacción. No cambian silenciosamente su escritura.
- La reversibilidad no depende de un backup: se apoya en las columnas originales
  intactas, los 8 eventos de auditoría en `os_translation_review`, los
  `importer_run_id` y la reprocesión de los importadores sobre datos de prueba.

## Qué quedó implementado

- `api/services/MappingReviewReader.php` aplica dual-read condicionado a
  `external_display` y `clinical_rationale`: solo publica si hay revisión
  aprobada D-19 (`language_code='undet'`) y el `content_hash` coincide. Sin
  aprobación devuelve `null` + `untranslated=true`.
- `EditorialEvaluator::evaluateUndet()` reutiliza el evaluador editorial sin
  mezclar idiomas ni inventar `es-AR`.
- `FieldReviewRepository::contentHash()` reproduce el hash del trigger de
  Fase 3 antes de servir contenido.
- `tools/php/ImporterIdentity.php` fija `app.importer_run_id` dentro de la
  transacción y expone la compuerta `OS_IMPORT_MODE`.
- Los importadores DENTAR, nomencladores y RF2 de SNOMED registran el run id.
  `sql/03_dentar/sync_dentar_to_os.sql` conserva el run id del importador o
  genera uno propio cuando se ejecuta suelto.
- `sql/07_multilingue/16_fase12_post_d19.sql` y
  `17_fase13_verificacion_final.sql` son reportes de solo lectura.

## Verificación previa al corte

Ejecutar en este orden, sin pedir backup:

```bash
cd /var/www/html/origen.ar/code-api/
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/18_fase11_invalidacion_mapeos.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off -f sql/07_multilingue/16_fase12_post_d19.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -P pager=off -f sql/07_multilingue/17_fase13_verificacion_final.sql
php tools/php/verificar_fase11.php
php tools/php/verificar_fase12.php
php tools/php/verificar_fase13.php
```

Criterios para considerar limpia la verificación:

- `aprobadas_sin_os_field_review = 0`.
- `campos_no_vacios_sin_revision = 0`.
- `aprobaciones_con_hash_desactualizado = 0`.
- `divergencias_totales = 0` en el matriz D-36.
- `undet_en_os_language = 0`.
- Los conteos base no bajan respecto del inventario de Fase 12.

## Si aparece un hallazgo

No se corrige en Fase 13. Se vuelve a la fase que originó el dato:
revisión editorial (D-19), backfill (Fase 4/5/6) o triggers (Fase 3). Luego se
repiten los reportes. No se aplica `SET NOT NULL`, `DELETE`, `TRUNCATE` ni
`DROP` de datos desde este procedimiento.

## Reversión sin backup

1. Mantener `OS_IMPORT_MODE=dual`; las columnas originales siguen intactas.
2. Identificar el `importer_run_id` en `os_translation_review`.
3. Reprocesar el CSV original con el importador correspondiente.
4. Comparar conteos y hashes con los reportes `16` y `17`.
5. Si una aprobación quedó invalidada por cambio de texto, repetir la revisión
   editorial con un script aditivo equivalente al `15`, sin degradar filas.

## Estado actual

La Fase 13 queda **preparada pero sin corte activo**. No se cambió ningún
default de publicación, no se agregó `NOT NULL` y no se borró información.
