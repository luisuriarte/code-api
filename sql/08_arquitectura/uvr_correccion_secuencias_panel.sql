-- =============================================================================
-- Corrección de privilegios UVR — ruta U0–U6 del panel
-- =============================================================================
-- Se ejecuta cuando verificacion_propuesta_uvr.sql muestra usage_ok = f o
-- audit_insert_ok = f. Sin estos GRANT, propose() responde el genérico
-- "El servicio no está disponible" (admin.errors.database).
--
-- Causa 1: uvr_gobernanza_datos.sql concedió SELECT/INSERT/UPDATE sobre las
-- TABLAS, pero no USAGE sobre sus SEQUENCES.
-- Causa 2: los triggers os_uvr_audit_trigger() y os_governance_audit_trigger()
-- insertan en public.os_audit_log con los privilegios de origen_admin (no son
-- SECURITY DEFINER), pero la migración solo concedió SELECT sobre esa tabla.
--
-- Ejecutar por el responsable contra la base del PANEL (dbname de
-- PORTAL_ADMIN_DB_DSN):
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/08_arquitectura/uvr_correccion_secuencias_panel.sql
--
-- No modifica datos. No crea tablas ni funciones nuevas: solo REVOKE por
-- tabla/secuencia a PUBLIC y GRANT explícito a origen_admin. No se modifica el
-- DEFAULT ACL global. Idempotente.
-- =============================================================================

BEGIN;

-- REVOKE por tabla/secuencia (patrón ya usado en las migraciones), sin tocar
-- el DEFAULT ACL global.
REVOKE ALL PRIVILEGES ON SEQUENCE
    public.os_governance_request_id_seq,
    public.os_governance_review_id_seq,
    public.os_governance_decision_id_seq,
    public.os_uvr_valuation_id_seq,
    public.os_uvr_component_id_seq,
    public.os_uvr_conversion_id_seq,
    public.os_uvr_geo_index_id_seq,
    public.os_audit_log_id_seq
FROM PUBLIC;

REVOKE ALL PRIVILEGES ON TABLE public.os_audit_log FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE
            public.os_governance_request_id_seq,
            public.os_governance_review_id_seq,
            public.os_governance_decision_id_seq,
            public.os_uvr_valuation_id_seq,
            public.os_uvr_component_id_seq,
            public.os_uvr_conversion_id_seq,
            public.os_uvr_geo_index_id_seq,
            public.os_audit_log_id_seq
            TO origen_admin';

        -- Requerido por los triggers de auditoría de UVR y gobernanza.
        EXECUTE 'GRANT SELECT, INSERT ON TABLE public.os_audit_log TO origen_admin';
    END IF;
END $$;

COMMIT;

-- Comprobación posterior (todas las filas deben dar true):
-- SELECT s.sequence_name,
--        has_sequence_privilege('origen_admin',
--            s.sequence_schema || '.' || s.sequence_name, 'USAGE') AS usage_ok
--   FROM information_schema.sequences s
--  WHERE (s.sequence_schema, s.sequence_name) IN (
--        ('public', 'os_governance_request_id_seq'),
--        ('public', 'os_governance_review_id_seq'),
--        ('public', 'os_governance_decision_id_seq'),
--        ('public', 'os_uvr_valuation_id_seq'),
--        ('public', 'os_uvr_component_id_seq'),
--        ('public', 'os_uvr_conversion_id_seq'),
--        ('public', 'os_uvr_geo_index_id_seq'),
--        ('public', 'os_audit_log_id_seq'))
--  ORDER BY 1;
--
-- SELECT has_table_privilege('origen_admin', 'public.os_audit_log', 'INSERT') AS audit_insert_ok;
