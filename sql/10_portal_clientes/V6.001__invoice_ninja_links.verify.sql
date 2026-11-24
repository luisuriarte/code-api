-- Verificación SELECT-only de V6.001.
-- No modifica datos. No consulta secretos ni tokens.

BEGIN READ ONLY;

SELECT current_database() AS base, current_user AS usuario, version() AS version_pg;

SELECT tablename
FROM pg_tables
WHERE schemaname = 'os_customer'
  AND tablename IN ('invoice_ninja_client_link', 'invoice_ninja_duplicate_review')
ORDER BY tablename;

SELECT tgname, tgrelid::regclass AS tabla
FROM pg_trigger
WHERE tgrelid::regclass::text IN (
    'os_customer.invoice_ninja_client_link',
    'os_customer.invoice_ninja_duplicate_review'
)
  AND NOT tgisinternal
ORDER BY tgrelid::regclass::text, tgname;

-- Solo identificadores y metadatos técnicos: ningún campo comercial duplicado.
-- Esta consulta debe devolver 0 filas.
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name IN ('invoice_ninja_client_link', 'invoice_ninja_duplicate_review')
  AND column_name ~* '(price|amount|total|product|invoice_number|payment|email|legal_name|tax_id)'
ORDER BY table_name, ordinal_position;

SELECT count(*) AS columnas_prohibidas
FROM information_schema.columns
WHERE table_schema = 'os_customer'
  AND table_name IN ('invoice_ninja_client_link', 'invoice_ninja_duplicate_review')
  AND column_name ~* '(price|amount|total|product|invoice_number|payment|email|legal_name|tax_id)';

SELECT has_table_privilege('origen_customer', 'os_customer.invoice_ninja_client_link', 'SELECT') AS lee_vinculos,
       has_table_privilege('origen_customer', 'os_customer.invoice_ninja_client_link', 'INSERT') AS inserta_vinculos,
       has_table_privilege('origen_customer', 'os_customer.invoice_ninja_duplicate_review', 'SELECT') AS lee_revisiones,
       has_table_privilege('origen_customer', 'os_customer.invoice_ninja_duplicate_review', 'INSERT') AS inserta_revisiones,
       has_sequence_privilege('origen_customer', 'os_customer.invoice_ninja_client_link_id_seq', 'USAGE') AS usa_secuencia;

SELECT count(*) AS total_tablas
FROM pg_tables
WHERE schemaname = 'os_customer';

ROLLBACK;
