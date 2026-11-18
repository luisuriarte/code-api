-- =============================================================================
-- PORTAL med.origen.ar · rol de solo lectura origen_med
-- =============================================================================
-- Ejecutar en el VPS con: psql -U postgres -d origen_codes -f este_archivo.sql
-- o desde DBEaver-CE con usuario postgres.
-- Aditivo e idempotente: no modifica datos, no borra objetos y no crea backups.
-- El portal NO usa la API pública: consulta estas tablas directamente.
-- =============================================================================

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'origen_med') THEN
        CREATE ROLE origen_med LOGIN PASSWORD 'CAMBIAR_CLAVE_SEGURA';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE origen_codes TO origen_med;
GRANT USAGE ON SCHEMA public TO origen_med;

-- Tablas terminológicas y catálogos leídos por Browse Codes.
GRANT SELECT ON TABLE
    public.snomed_concepts,
    public.snomed_descriptions,
    public.cie10_codes,
    public.cie10_descriptions,
    public.anmat_medicamentos,
    public.loinc,
    public.laboratorio_practicas,
    public.vacunas_catalogo,
    public.odontologia_prestaciones,
    public.prestaciones_medicas,
    public.programas_sociales,
    public.imagenes_practicas,
    public.nomencladores_argentina,
    public.vademecum_comercial
TO origen_med;

-- Motor os_catalog: búsqueda de dominios mapeados (sin dominios nuevos).
GRANT SELECT ON TABLE
    public.os_catalog,
    public.os_catalog_release,
    public.os_catalog_category,
    public.os_catalog_item,
    public.os_catalog_item_version,
    public.os_catalog_term,
    public.os_catalog_identifier
TO origen_med;

-- Configuración idiomática y estado editorial (D-27, D-30).
GRANT SELECT ON TABLE
    public.os_language,
    public.os_catalog_language,
    public.os_field_review
TO origen_med;

COMMIT;

-- Verificación: debe devolver 't' (SELECT) en las tablas listadas.
SELECT schemaname, tablename, has_table_privilege('origen_med', schemaname || '.' || tablename, 'SELECT') AS puede_leer
  FROM pg_tables
 WHERE schemaname = 'public'
   AND tablename IN (
       'snomed_concepts', 'snomed_descriptions', 'cie10_codes', 'cie10_descriptions',
       'anmat_medicamentos', 'loinc', 'laboratorio_practicas', 'vacunas_catalogo',
       'odontologia_prestaciones', 'prestaciones_medicas', 'programas_sociales',
       'imagenes_practicas', 'nomencladores_argentina', 'vademecum_comercial',
       'os_catalog', 'os_catalog_release', 'os_catalog_category',
       'os_catalog_item', 'os_catalog_item_version', 'os_catalog_term',
       'os_catalog_identifier',
       'os_language', 'os_catalog_language', 'os_field_review'
   )
 ORDER BY tablename;
