-- =============================================================================
-- SOLO LECTURA · Origen Salud · Familia OFTAR
-- sql/03_oftar/revision_pares_nomencladores_oftar.sql
-- =============================================================================
--
-- EJECUCIÓN EN EL VPS (el rol `root` no existe en PostgreSQL):
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 \
--     -f sql/03_oftar/revision_pares_nomencladores_oftar.sql
--
-- Lista las 91 propuestas CAO pendientes de revisión.
-- `observacion = 'difiere_literalmente'` marca pares cuyo texto normalizado
-- coincide pero el literal no (tildes, mayúsculas, puntuación o el sufijo
-- `*****` del código 306025). Ninguno de estos pares afirma equivalencia
-- clínica: son solo candidatos a revisión humana.
-- PostgreSQL 18.
-- =============================================================================
BEGIN READ ONLY;

SELECT m.source_code,
       m.target_code,
       m.source_term,
       m.target_term,
       CASE
           WHEN m.source_term IS DISTINCT FROM m.target_term
           THEN 'difiere_literalmente'
           ELSE 'identico'
       END AS observacion
  FROM public.os_oftar_nomenclador_match m
 WHERE m.source_catalog_code = 'nomenclador-oftalmologico-cao-ar'
   AND m.review_status = 'proposed'
 ORDER BY m.source_code;

ROLLBACK;
