-- =============================================================================
-- Corrección de privilegios UVR — secuencias de la ruta U0–U6 del panel
-- =============================================================================
-- Se ejecuta SOLO cuando verificacion_propuesta_uvr.sql (sección 4) devuelve
-- usage_ok = f en alguna de estas secuencias. Sin este GRANT, el primer INSERT
-- de propose() (os_uvr_valuation) falla con "permission denied for sequence" y
-- el panel muestra el genérico "El servicio no está disponible".
--
-- Causa: uvr_gobernanza_datos.sql concedió SELECT/INSERT/UPDATE sobre las
-- TABLAS, pero no concedió USAGE sobre sus SEQUENCES. La migración transversal
-- (uvr_transversal_prestaciones.sql) sí lo hizo, por eso esas secuencias están
-- en verde y estas tres no.
--
-- Ejecutar por el responsable contra la base del PANEL (dbname de
-- PORTAL_ADMIN_DB_DSN):
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/08_arquitectura/uvr_correccion_secuencias_panel.sql
--
-- No modifica datos. No crea tablas ni funciones nuevas: solo REVOKE por
-- secuencia a PUBLIC y GRANT explícito a origen_admin. No se modifica el
-- DEFAULT ACL global. Idempotente.
-- =============================================================================

BEGIN;

-- REVOKE por secuencia (equivalente al patrón ya usado en la migración
-- transversal), sin tocar el DEFAULT ACL global.
REVOKE ALL PRIVILEGES ON SEQUENCE
    public.os_governance_request_id_seq,
    public.os_uvr_valuation_id_seq,
    public.os_uvr_component_id_seq
FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE
            public.os_governance_request_id_seq,
            public.os_uvr_valuation_id_seq,
            public.os_uvr_component_id_seq
            TO origen_admin';
    END IF;
END $$;

COMMIT;

-- Comprobación posterior (debe devolver usage_ok = t en las tres filas):
-- SELECT s.sequence_name,
--        has_sequence_privilege('origen_admin',
--            s.sequence_schema || '.' || s.sequence_name, 'USAGE') AS usage_ok
--   FROM information_schema.sequences s
--  WHERE (s.sequence_schema, s.sequence_name) IN (
--        ('public', 'os_governance_request_id_seq'),
--        ('public', 'os_uvr_valuation_id_seq'),
--        ('public', 'os_uvr_component_id_seq'))
--  ORDER BY 1;
