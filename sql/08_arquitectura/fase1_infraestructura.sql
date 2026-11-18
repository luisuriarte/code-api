-- FASE 1 — Infraestructura compartida (propuesta, NO EJECUTAR sin aprobación)
-- Base objetivo: origen_codes. Requiere backup verificado y fase aprobada.
-- Aditivo: no elimina tablas, columnas ni datos.

BEGIN;

-- Registro de dominios: sustituye las constantes PHP como fuente de verdad.
-- Los códigos, etiquetas y modos provienen de TerminologySearchService::DOMAINS
-- y DOMAIN_CATALOG; no se crean dominios nuevos.
CREATE TABLE IF NOT EXISTS os_domain_registry (
    code VARCHAR(50) PRIMARY KEY,
    label_es VARCHAR(150) NOT NULL,
    label_en VARCHAR(150) NOT NULL,
    mode VARCHAR(20) NOT NULL CHECK (mode IN ('full', 'catalog')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    source_of_truth TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE os_domain_registry IS
    'Registro de dominios expuestos por la API. Debe alimentarse desde datos, no desde constantes PHP.';

INSERT INTO os_domain_registry (code, label_es, label_en, mode, source_of_truth) VALUES
    ('snomed',       'SNOMED-CT',                              'SNOMED-CT',                              'full',    'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('cie10',        'CIE-10',                                 'ICD-10',                                 'full',    'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('anmat',        'ANMAT',                                  'ANMAT',                                  'full',    'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('laboratorio',  'Laboratorio',                            'Laboratory',                             'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('vacunas',      'Vacunas',                                'Vaccines',                               'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('odontologia',  'Odontología',                            'Dentistry',                              'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('prestaciones', 'Prestaciones médicas',                   'Medical procedures',                    'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('programas',    'Programas sociales',                     'Social programs',                       'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('imagenes',     'Diagnóstico por imágenes',               'Diagnostic imaging',                    'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('nomenclador',  'Nomencladores de Argentina',             'Argentine Healthcare Nomenclators',     'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('vademecum',    'Vademécum Comercial',                    'Commercial Drug Formulary',             'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG'),
    ('loinc',        'LOINC (Observaciones y Laboratorio)',    'LOINC (Observations & Laboratory)',     'catalog', 'TerminologySearchService::DOMAINS/DOMAIN_CATALOG')
ON CONFLICT (code) DO NOTHING;

-- Clasificación de relaciones. Los valores son los propuestos en §7.2;
-- 'unclassified' conserva las filas actuales hasta su revisión editorial.
CREATE TABLE IF NOT EXISTS os_relation_kind (
    code VARCHAR(30) PRIMARY KEY,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO os_relation_kind (code, description) VALUES
    ('unclassified', 'Tipo aún no clasificado; conserva la procedencia original.'),
    ('structural',   'Estructura del catálogo o de la terminología.'),
    ('clinical',     'Relación clínica entre conceptos.'),
    ('editorial',    'Decisión editorial de la familia.'),
    ('billing',      'Relación de facturación o cobertura.'),
    ('regulatory',   'Relación regulatoria.'),
    ('mapping',      'Correspondencia con otra terminología.')
ON CONFLICT (code) DO NOTHING;

-- Tipos de relación. No se inventan códigos: se derivan de os_catalog_relation
-- solo cuando la tabla ya existe en la base.
CREATE TABLE IF NOT EXISTS os_relation_type (
    code VARCHAR(60) PRIMARY KEY,
    relation_kind VARCHAR(30) NOT NULL DEFAULT 'unclassified'
        REFERENCES os_relation_kind(code) ON UPDATE CASCADE,
    source TEXT NOT NULL,
    inverse_code VARCHAR(60) REFERENCES os_relation_type(code) ON UPDATE CASCADE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DO $$
BEGIN
    IF to_regclass('public.os_catalog_relation') IS NOT NULL THEN
        EXECUTE '
            INSERT INTO os_relation_type (code, source)
            SELECT DISTINCT r.relation_type,
                            ''os_catalog_relation:'' || r.source_system_code
              FROM os_catalog_relation r
            ON CONFLICT (code) DO NOTHING
        ';
    END IF;
END $$;

-- Estados de revisión. 'unknown' y 'unreviewed' cubren procedencia no
-- demostrada (D-01); ninguno de los estados implica aprobación automática.
CREATE TABLE IF NOT EXISTS os_review_state (
    code VARCHAR(30) PRIMARY KEY,
    description TEXT,
    is_publication_allowed BOOLEAN NOT NULL DEFAULT FALSE
);

INSERT INTO os_review_state (code, description, is_publication_allowed) VALUES
    ('unknown',     'Procedencia o estado no demostrado.', FALSE),
    ('unreviewed',  'Sin revisión editorial.', FALSE),
    ('draft',       'Borrador.', FALSE),
    ('in_review',   'En revisión.', FALSE),
    ('reviewed',    'Revisado, sin aprobación formal.', FALSE),
    ('approved',    'Aprobado por el comité.', TRUE),
    ('published',   'Publicado.', TRUE),
    ('retired',     'Retirado.', FALSE),
    ('obsolete',    'Obsoleto.', FALSE),
    ('deprecated',  'Obsoleto por reemplazo.', FALSE)
ON CONFLICT (code) DO NOTHING;

COMMIT;

-- Verificación sugerida (no ejecutar automáticamente):
-- SELECT code, mode FROM os_domain_registry ORDER BY code;
-- SELECT count(*) AS relation_types FROM os_relation_type;
-- SELECT code FROM os_review_state WHERE is_publication_allowed;
