# PMO Integración - Programa Médico Obligatorio

## Propósito
Integración del Programa Médico Obligatorio (Resolución 201/2002, Actualización Normativa 1/2002) al motor canonical de catálogos Origen Salud (`os_*`).

## Dependencias
- `sql/01_schema/design.sql` (extensiones pg_trgm, tipos base)
- `sql/02_catalogs/origen_catalog_engine.sql` (motor canonical, catálogo `nn-pmo` ya registrado)
- `sql/04_pmo/02_pmo_practicas.sql` (prácticas médicas)

## Ejecución

### Primera carga
```bash
# 1. Motor canonical (si no está ejecutado)
sudo -u postgres psql -d origen_salud -f sql/02_catalogs/origen_catalog_engine.sql

# 2. Integración PMO prácticas
sudo -u postgres psql -d origen_salud -f sql/04_pmo/02_pmo_practicas.sql

# 3. Validaciones
sudo -u postgres psql -d origen_salud -f sql/04_pmo/99_pmo_validaciones.sql
```

### Actualización
```bash
# Reejecutar cualquier SQL: es idempotente, no duplicará registros
sudo -u postgres psql -d origen_salud -f sql/04_pmo/02_pmo_practicas.sql
```

### Versionado
- Procedencia: `PMOE-201-2002` (Resolución 201/2002 + Actualización Normativa 1/2002)
- No asociar al release `2026-v1` sin fundamento normativo
- Los registros consultables mediante API `/v1/catalogs` y vistas correspondientes

## Validaciones
Ejecutar `99_pmo_validaciones.sql` para verificar:
- Cantidad de registros origen vs destino
- Códigos duplicados o vacíos
- Descripciones vacías
- Integridad referencial
- Conservación de códigos originales (con ceros iniciales)
- Registros con cobertura condicionada
- Registros pendientes de revisión

## Estructura de archivos
- `sql/04_pmo/README.md`
- `sql/04_pmo/01_pmo_extensions.sql`
- `sql/04_pmo/02_pmo_practicas.sql`
- `sql/04_pmo/99_pmo_validaciones.sql`

Fuente original preservada: `tools/sources/pmo/pmo_2002.sql` (SIN MODIFICAR)