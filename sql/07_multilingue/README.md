# Scripts SQL — Implementación multilingüe (Fases 2 a 4)

Scripts ejecutables derivados del diseño aprobado en `cc803b5`. Entorno de
**pruebas con datos no reales**. Ejecutar en la base independiente (`origen_codes`),
no en producción.

## Orden de ejecución

| # | Archivo | Fase | Transacción |
|---|---|---|---|
| 1 | `01_fase2_tablas.sql` | 2 — tablas nuevas | `BEGIN/COMMIT` |
| 2 | `02_fase2_indices.sql` | 2 — índices | **FUERA de transacción** (`CONCURRENTLY`) |
| 3 | `03_fase2_datos_base.sql` | 2 — siembra de idiomas | `BEGIN/COMMIT` |
| 4 | `04_fase3_columnas.sql` | 3 — columnas aditivas | `BEGIN/COMMIT` |
| 5 | `05_fase3_triggers.sql` | 3 — triggers y auditoría | `BEGIN/COMMIT` |
| 6 | `06_fase4_backfill_seguro.sql` | 4 — backfill sin inventar procedencia | `BEGIN/COMMIT` |

Ejecutar **en orden**. Los scripts son idempotentes (`IF NOT EXISTS`,
`ON CONFLICT DO NOTHING`) salvo los `UPDATE` de Fase 4, que se repetirán sin
cambiar el resultado.

## Cómo ejecutar

### Desde el VPS como usuario `postgres` (sin clave, peer auth)

```bash
cd /var/www/html/origen.ar/code-api/
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/01_fase2_tablas.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/02_fase2_indices.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/03_fase2_datos_base.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/04_fase3_columnas.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/05_fase3_triggers.sql
sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/06_fase4_backfill_seguro.sql
```

Si tu `pg_hba.conf` usa `md5`/`scram` en localhost en vez de `peer`:

```bash
PGPASSWORD=... psql -h localhost -U postgres -d origen_codes -v ON_ERROR_STOP=1 -f sql/07_multilingue/01_fase2_tablas.sql
```

### Desde DBeaver-CE

1. Conectarse a la base `origen_codes` con el usuario `postgres`.
2. Abrir cada archivo y ejecutarlo en orden.
3. **Importante** para `02_fase2_indices.sql`: desactivar la opción de ejecutar
   el script dentro de una transacción (autocommit activo). PostgreSQL no
   permite `CREATE INDEX CONCURRENTLY` dentro de `BEGIN/COMMIT`.

## Requisitos

- PostgreSQL 14 o superior (`CREATE OR REPLACE TRIGGER`).
- Extensión `pg_trgm` (el script 02 la crea si falta).

## Puntos de control

- Antes de `02_fase2_indices.sql`, verificar que no hay índices inválidos ni
  duplicados con el nombre `uq_*`. Si aparece uno inválido o duplicado, **detener**
  y revisar; no se incluye ningún `DROP INDEX`.
- `os_concept_mapping` ya tiene `review_status` con un `CHECK` propio
  (`draft|reviewed|approved|deprecated`). No se modifica: el estado editorial
  de esa tabla se gestiona en `os_field_review`.
- Fase 4 no marca nada como `approved` ni `official_source`: cuando no hay
  evidencia se deja `unknown`/`unreviewed`/`NULL`, que no es publicable.
- `loinc_localized_text` **no** se audita en Fase 3: se incorpora en Fase 5.
- Las fases 5 a 14 requieren decisiones pendientes (LOINC, resolver/API/sitio,
  NN 2025) y no se incluyen aquí.

**Sin backup**: decisión explícita del responsable sobre datos de prueba no
reales. Estos scripts son aditivos y no destruyen tablas, columnas ni datos
existentes.
