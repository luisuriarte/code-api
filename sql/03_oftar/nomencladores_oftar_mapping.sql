-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Familia OFTAR
-- sql/03_oftar/nomencladores_oftar_mapping.sql
-- =============================================================================
--
-- EJECUCIÓN EN EL VPS (el rol `root` no existe en PostgreSQL):
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/03_oftar/nomencladores_oftar_mapping.sql
--
-- QUÉ HACE
--   Crea la tabla gobernada de correspondencias entre los nomencladores
--   oftalmológicos de origen y los ítems propios de OFTAR-PR.
--
--   Es el primer artefacto del orden de carga. Los dos importadores siembran
--   propuestas aquí; ninguna de ellas se publica automáticamente.
--
-- GOBERNANZA
--   · Cada par queda en `proposed` con su base objetiva y su procedencia.
--   · La revisión humana cambia `review_status` a `approved` o `rejected` y
--     registra quién y cuándo. No se borran filas: el historial se conserva.
--   · `aprobar_mapeo_nomencladores_oftar.sql` publica identificadores y
--     relaciones SOLO para las filas aprobadas, en ambos sentidos.
--   · Los pares se describen como `referencia_literal`: nunca se declara
--     equivalencia clínica asumida.
--
-- QUÉ NO HACE
--   · No crea códigos OFT-PR nuevos ni modifica los 154 existentes.
--   · No guarda precios, UVR, dominios ni rutas.
--   · No usa DROP ... CASCADE ni ALTER DEFAULT PRIVILEGES.
--   · Idempotente: una segunda ejecución no altera las filas ya cargadas.
-- PostgreSQL 18.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';

CREATE TABLE IF NOT EXISTS public.os_oftar_nomenclador_match (
    source_catalog_code VARCHAR(60) NOT NULL,
    source_code         VARCHAR(20) NOT NULL,
    target_catalog_code VARCHAR(30) NOT NULL DEFAULT 'oftar-pr',
    target_code         VARCHAR(30) NOT NULL,
    match_basis         VARCHAR(40) NOT NULL
        CHECK (match_basis IN ('texto_identico_normalizado', 'revision_manual')),
    review_status       VARCHAR(20) NOT NULL DEFAULT 'proposed'
        CHECK (review_status IN ('proposed', 'approved', 'rejected')),
    source_term         TEXT,
    target_term         TEXT,
    provenance          TEXT NOT NULL,
    notes               TEXT,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_at         TIMESTAMP WITH TIME ZONE,
    reviewed_by         VARCHAR(120),
    PRIMARY KEY (source_catalog_code, source_code)
);

COMMENT ON TABLE public.os_oftar_nomenclador_match IS
    'Correspondencias gobernadas entre nomencladores oftalmológicos de origen y OFTAR-PR. Ninguna fila publica enlaces hasta ser aprobada.';
COMMENT ON COLUMN public.os_oftar_nomenclador_match.match_basis IS
    'Base objetiva del par: texto idéntico tras normalizar, o decisión humana documentada.';
COMMENT ON COLUMN public.os_oftar_nomenclador_match.review_status IS
    'proposed = sin publicar; approved = publicable; rejected = conservado pero excluido.';

REVOKE ALL PRIVILEGES ON TABLE public.os_oftar_nomenclador_match FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_oftar_nomenclador_match FROM origen_admin';
        EXECUTE 'GRANT SELECT ON TABLE public.os_oftar_nomenclador_match TO origen_admin';
    END IF;

    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_oftar_nomenclador_match FROM origen_med';
        EXECUTE 'GRANT SELECT ON TABLE public.os_oftar_nomenclador_match TO origen_med';
    END IF;
END $$;

COMMIT;

-- =============================================================================
-- Consultas de trabajo sobre la tabla (ejecutar con BEGIN READ ONLY / ROLLBACK)
-- =============================================================================
-- BEGIN READ ONLY;
-- SELECT source_catalog_code, review_status, count(*)
--   FROM public.os_oftar_nomenclador_match GROUP BY 1, 2 ORDER BY 1, 2;
--
-- -- Aprobar un par revisado (fuera de esta transacción de solo lectura):
-- -- UPDATE public.os_oftar_nomenclador_match
-- --    SET review_status = 'approved', reviewed_by = '<actor>', reviewed_at = now(),
-- --        notes = 'Revisado: misma prestación, distinta codificación'
-- --  WHERE source_catalog_code = 'nomenclador-oftalmologico-cao-ar'
-- --    AND source_code = '460105';
-- ROLLBACK;
