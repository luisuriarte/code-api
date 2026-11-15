-- =============================================================================
-- Origen Salud · Terminología Dental Interoperable
-- Argentina_dental_cdt_codes_2025.sql :: Nomenclador Argentino + CDT 2025 + SNOMED CT
-- =============================================================================
--
-- CONTENIDO:
--   1. odontologia_cdt_categorias: 12 Categorías Oficiales ADA CDT adaptadas a Argentina.
--   2. odontologia_cdt_catalogo: Catálogo CDT 2025 en inglés y español.
--   3. odontologia_nomenclador: 138 prestaciones oficiales del Nomenclador Odontológico
--      Argentino (Capítulos I a XI) con sus reglas de auditoría clínica:
--      requiere_pieza, face_specification (caras), requiere_rx_pre, requiere_rx_post,
--      ficha_odontologica, ficha_periodontal, material, maxilar y normas particulares.
--   4. odontologia_mapeo_argentina_cdt: Mapeo cruzado (cross-walk) Nomenclador <-> CDT.
--   5. odontologia_prestaciones: Tabla unificada con índices pg_trgm para el endpoint
--      REST /v1/search/odontologia de la API.
--
-- COMPATIBILIDAD: PostgreSQL 18
-- EJECUCIÓN: psql -d origen_salud -f sql/Argentina_dental_cdt_codes_2025.sql
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 1. CATEGORÍAS CDT (AMERICAN DENTAL ASSOCIATION) ADAPTADAS A ARGENTINA
-- =============================================================================
CREATE TABLE IF NOT EXISTS odontologia_cdt_categorias (
    codigo VARCHAR(50) PRIMARY KEY,
    rango_cdt VARCHAR(20) NOT NULL,
    nombre_en VARCHAR(100) NOT NULL,
    nombre_es VARCHAR(150) NOT NULL,
    descripcion TEXT
);

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'DIAGNOSTIC', E'D0100-D0999', E'Diagnostic', E'Diagnóstico y Exámenes Clínicos', E'Evaluaciones clínicas orales, exámenes diagnósticos, imágenes radiográficas e interconsultas diagnósticas.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'PREVENTIVE', E'D1000-D1999', E'Preventive', E'Odontología Preventiva', E'Higiene bucal, profilaxis dental, aplicaciones tópicas de flúor, selladores de fisuras y mantenedores de espacio.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'RESTORATIVE', E'D2000-D2999', E'Restorative', E'Operatoria Dental y Restauradora', E'Restauraciones con amalgama, resinas compuestas/fotocurado, incrustaciones inlay/onlay y reconstrucción de muñón.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'ENDODONTICS', E'D3000-D3999', E'Endodontics', E'Endodoncia', E'Tratamientos pulpares, biopulpectomías, terapia de conductos radiculares anteriores/premolares/molares y cirugías periapicales.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'PERIODONTICS', E'D4000-D4999', E'Periodontics', E'Periodoncia', E'Tratamiento de gingivitis, raspado y alisado radicular, cirugías periodontales, gingivectomías y mantenimiento periodontal.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'PROSTHODONTICS_REMOVABLE', E'D5000-D5899', E'Prosthodontics, removable', E'Prótesis Parcial y Completa Removible', E'Prótesis completas superiores e inferiores, parciales en acrílico o cromo-cobalto, prótesis inmediatas y composturas.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'MAXILLOFACIAL_PROSTHETICS', E'D5900-D5999', E'Maxillofacial prosthetics', E'Prótesis Maxilofacial', E'Prótesis faciales, nasales, auriculares, obturadores palatinos y guías quirúrgicas complejas.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'IMPLANT_SERVICES', E'D6000-D6199', E'Implant services', E'Implantología Odontológica', E'Colocación quirúrgica de implantes intraóseos, pilares protésicos, injertos óseos y coronas sobre implante.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'PROSTHODONTICS_FIXED', E'D6200-D6999', E'Prosthodontics, fixed', E'Prótesis Fija', E'Coronas forjadas, coladas, con frente estético, de porcelana pura o sobre metal, pernos muñón y tramos de puente.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'ORAL_MAXILLOFACIAL_SURGERY', E'D7000-D7999', E'Oral & maxillofacial surgery', E'Cirugía Bucal y Maxilofacial', E'Extracciones simples y quirúrgicas de dientes erupcionados o retenidos, germectomías, apicectomías, frenectomías, biopsias y drenaje de abscesos.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'ORTHODONTICS', E'D8000-D8999', E'Orthodontics', E'Ortodoncia y Ortopedia Funcional', E'Estudios de ortodoncia, tratamientos de dentición primaria/mixta/permanente y aparatos de corrección de malposiciones.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;

INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)
VALUES (E'ADJUNCTIVE_GENERAL_SERVICES', E'D9000-D9999', E'Adjunctive general services', E'Servicios Complementarios de Odontología', E'Consultas de urgencia, visitas domiciliarias, sedación, placas de estabilización oclusal (bruxismo/ATM), desensibilizaciones y peritajes.')
ON CONFLICT (codigo) DO UPDATE SET
    rango_cdt = EXCLUDED.rango_cdt,
    nombre_en = EXCLUDED.nombre_en,
    nombre_es = EXCLUDED.nombre_es,
    descripcion = EXCLUDED.descripcion;


-- =============================================================================
-- 2. CATÁLOGO CDT 2025 (CÓDIGOS BUCALES ESTÁNDAR INTERNACIONALES)
-- =============================================================================
CREATE TABLE IF NOT EXISTS odontologia_cdt_catalogo (
    codigo_cdt VARCHAR(10) PRIMARY KEY,
    categoria_codigo VARCHAR(50) NOT NULL REFERENCES odontologia_cdt_categorias(codigo),
    descripcion_en TEXT NOT NULL,
    descripcion_es TEXT NOT NULL,
    snomed_concept_id BIGINT
);

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0120', E'DIAGNOSTIC', E'Periodic oral evaluation - established patient', E'Evaluación oral periódica - paciente establecido', 399120002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0140', E'DIAGNOSTIC', E'Limited oral evaluation - problem focused', E'Evaluación oral limitada - focalizada en problema', 399120002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0145', E'DIAGNOSTIC', E'Oral evaluation for a patient under three years of age', E'Evaluación oral para paciente pediátrico / motivación', 399120002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0150', E'DIAGNOSTIC', E'Comprehensive oral evaluation - new or established patient', E'Examen diagnóstico completo, fichado y plan de tratamiento', 424759004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0160', E'DIAGNOSTIC', E'Detailed and extensive oral evaluation - problem focused', E'Consulta de estomatología / evaluación oral detallada para especialistas', 386053000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0180', E'DIAGNOSTIC', E'Comprehensive periodontal evaluation - new or established patient', E'Evaluación y examen periodontal integral con periodontograma', 424759004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0210', E'DIAGNOSTIC', E'Intraoral - comprehensive series of radiographic images', E'Serie radiográfica intraoral completa / seriada periapical', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0220', E'DIAGNOSTIC', E'Intraoral - periapical first radiographic image', E'Radiografía intraoral periapical primera exposición', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0230', E'DIAGNOSTIC', E'Intraoral - periapical each additional radiographic image', E'Radiografía intraoral periapical cada exposición adicional', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0240', E'DIAGNOSTIC', E'Intraoral - occlusal radiographic image', E'Radiografía intraoral oclusal (6x8 cm)', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0250', E'DIAGNOSTIC', E'Extra-oral - 2D projection radiographic image', E'Radiografía extraoral - primera exposición', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0272', E'DIAGNOSTIC', E'Bitewings - two radiographic images', E'Radiografía coronal / Bite-Wing (2 películas)', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0310', E'DIAGNOSTIC', E'Sialography', E'Sialografía de glándulas salivales', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0320', E'DIAGNOSTIC', E'Temporomandibular joint arthrogram', E'Radiografía comparativa de articulación temporomandibular (ATM)', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0330', E'DIAGNOSTIC', E'Panoramic radiographic image', E'Radiografía panorámica / pantomografía maxilofacial', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0340', E'DIAGNOSTIC', E'2D cephalometric radiographic image', E'Telerradiografía cefalométrica / trazado cefalométrico', 399195000)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D0425', E'DIAGNOSTIC', E'Caries susceptibility tests', E'Test de susceptibilidad de caries y placa bacteriana', NULL)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1110', E'PREVENTIVE', E'Prophylaxis - adult', E'Tartrectomía, raspado y cepillado mecánico en adultos', 22769002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1120', E'PREVENTIVE', E'Prophylaxis - child', E'Profilaxis y limpieza dental en niños', 22769002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1206', E'PREVENTIVE', E'Topical application of fluoride varnish', E'Aplicación tópica de barniz de flúor', 110462007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1208', E'PREVENTIVE', E'Topical application of fluoride - excluding varnish', E'Aplicación de flúor tópico (gel/colutorios)', 110462007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1330', E'PREVENTIVE', E'Oral hygiene instructions', E'Enseñanza de técnicas de higiene bucal y control de placa', 399047006)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1351', E'PREVENTIVE', E'Sealant - per tooth', E'Sellador de puntos y fisuras por pieza dentaria', 234735005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1354', E'PREVENTIVE', E'Interim caries arresting medicament application - per tooth', E'Aplicación de cariostáticos / detención no invasiva de caries', 713601007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1510', E'PREVENTIVE', E'Space maintainer - fixed, unilateral - per quadrant', E'Mantenedor de espacio fijo unilateral', 274437007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D1520', E'PREVENTIVE', E'Space maintainer - removable, unilateral', E'Mantenedor de espacio removible', 274437007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2140', E'RESTORATIVE', E'Amalgam - one surface, primary or permanent', E'Obturación con amalgama: cavidad simple (1 cara)', 80891009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2150', E'RESTORATIVE', E'Amalgam - two surfaces, primary or permanent', E'Obturación con amalgama: cavidad compuesta (2 caras)', 80891009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2160', E'RESTORATIVE', E'Amalgam - three surfaces, primary or permanent', E'Obturación con amalgama: cavidad compleja (3 caras)', 80891009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2161', E'RESTORATIVE', E'Amalgam - four or more surfaces, primary or permanent', E'Obturación con amalgama: reconstrucción compleja con anclaje', 80891009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2330', E'RESTORATIVE', E'Resin-based composite - one surface, anterior', E'Obturación estética / composite simple en sector anterior (1 cara)', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2331', E'RESTORATIVE', E'Resin-based composite - two surfaces, anterior', E'Obturación estética / composite compuesto en sector anterior (2 caras)', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2332', E'RESTORATIVE', E'Resin-based composite - three surfaces, anterior', E'Obturación estética / composite complejo en sector anterior (3 caras)', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2335', E'RESTORATIVE', E'Resin-based composite crown, anterior (involving incisal angle)', E'Reconstrucción de ángulo incisal en dientes anteriores con composite', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2391', E'RESTORATIVE', E'Resin-based composite - one surface, posterior', E'Obturación con resina fotocurado en sector posterior (1 cara)', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2392', E'RESTORATIVE', E'Resin-based composite - two surfaces, posterior', E'Obturación con resina fotocurado en sector posterior (2 caras)', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2393', E'RESTORATIVE', E'Resin-based composite - three surfaces, posterior', E'Obturación con resina fotocurado en sector posterior (3 caras)', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2394', E'RESTORATIVE', E'Resin-based composite - four or more surfaces, posterior', E'Obturación con resina fotocurado en sector posterior (4 o más caras)', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2610', E'RESTORATIVE', E'Inlay - porcelain/ceramic - one surface', E'Incrustación de porcelana/cerámica: cavidad simple', 111163002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2620', E'RESTORATIVE', E'Inlay - porcelain/ceramic - two surfaces', E'Incrustación de porcelana/cerámica: cavidad compuesta', 111163002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2630', E'RESTORATIVE', E'Inlay - porcelain/ceramic - three or more surfaces', E'Incrustación de porcelana/cerámica: cavidad compleja', 111163002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2710', E'RESTORATIVE', E'Crown - resin-based composite (indirect)', E'Corona de acrílico o resina compuesta', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2740', E'RESTORATIVE', E'Crown - porcelain/ceramic', E'Corona colada revestida en porcelana pura', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2751', E'RESTORATIVE', E'Crown - porcelain fused to predominantly base metal', E'Corona colada con frente estético en acrílico o metal-cerámica', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2752', E'RESTORATIVE', E'Crown - noble metal with porcelain/resin', E'Corona colada revestida en acrílico / metal noble', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2790', E'RESTORATIVE', E'Crown - full cast predominantly base metal', E'Corona colada totalmente metálica', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2799', E'RESTORATIVE', E'Provisional crown - further treatment or completion of diagnosis necessary prior to final impression', E'Corona provisoria de acrílico', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2930', E'RESTORATIVE', E'Prefabricated stainless steel crown - primary tooth', E'Corona de acero inoxidable preformada en diente temporario', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2951', E'RESTORATIVE', E'Pin retention - per tooth, in addition to restoration', E'Reconstrucción con tornillo / perno en conducto', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2952', E'RESTORATIVE', E'Post and core in addition to crown, indirectly fabricated', E'Perno muñón colado simple o seccionado', 234736006)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D2970', E'RESTORATIVE', E'Temporary crown (fractured tooth)', E'Carilla provisoria / corona temporal por traumatismo', 111164008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3110', E'ENDODONTICS', E'Pulp cap - direct (excluding final restoration)', E'Protección pulpar directa', 234737002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3220', E'ENDODONTICS', E'Therapeutic pulpotomy (excluding final restoration)', E'Biopulpectomía parcial / pulpotomía con formocresol', 234737002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3221', E'ENDODONTICS', E'Pulpal debridement, primary and permanent teeth', E'Necropulpectomía parcial / momificación / debridamiento pulpar', 234737002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3310', E'ENDODONTICS', E'Endodontic therapy, anterior tooth (excluding final restoration)', E'Tratamiento de conducto en diente anterior (un conducto)', 68673005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3320', E'ENDODONTICS', E'Endodontic therapy, premolar tooth (excluding final restoration)', E'Tratamiento de conductos en diente premolar (dos conductos)', 68673005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3330', E'ENDODONTICS', E'Endodontic therapy, molar tooth (excluding final restoration)', E'Tratamiento de conductos en molar (tres o cuatro conductos)', 68673005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3410', E'ENDODONTICS', E'Apicoectomy - anterior', E'Apicectomía con o sin obturación retrógrada', 234737002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D3920', E'ENDODONTICS', E'Hemisection (including any root removal), not including root canal therapy', E'Radectomía / hemisección radicular', 234737002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4210', E'PERIODONTICS', E'Gingivectomy or gingivoplasty - four or more contiguous teeth', E'Gingivectomía o gingivoplastia / cirugía periodontal', 234740008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4249', E'PERIODONTICS', E'Clinical crown lengthening - hard tissue', E'Alargamiento quirúrgico de la corona clínica', 234740008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4260', E'PERIODONTICS', E'Osseous surgery (including elevation of a full thickness flap and scaling)', E'Tratamiento quirúrgico de periodontitis destructiva severa (bolsas 6mm+)', 234740008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4322', E'PERIODONTICS', E'Splint - intra-coronal; natural teeth or in conjunction with prostheses', E'Ferulización intracoronal por causas periodontales', 274438002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4323', E'PERIODONTICS', E'Splint - extra-coronal; natural teeth or in conjunction with prostheses', E'Ferulización extracoronal por causas periodontales', 274438002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4341', E'PERIODONTICS', E'Periodontal scaling and root planing - four or more teeth per quadrant', E'Tratamiento de periodontitis destructiva leve/moderada (bolsas hasta 5mm)', 110463002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4346', E'PERIODONTICS', E'Scaling in presence of generalized moderate or severe gingival inflammation', E'Tratamiento de gingivitis marginal crónica', 110463002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D4910', E'PERIODONTICS', E'Periodontal maintenance', E'Mantenimiento periódico post-tratamiento periodontal', 110463002)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5110', E'PROSTHODONTICS_REMOVABLE', E'Complete denture - maxillary', E'Prótesis completa superior en acrílico', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5120', E'PROSTHODONTICS_REMOVABLE', E'Complete denture - mandibular', E'Prótesis completa inferior en acrílico', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5130', E'PROSTHODONTICS_REMOVABLE', E'Immediate denture - maxillary', E'Prótesis completa inmediata superior (temporaria)', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5140', E'PROSTHODONTICS_REMOVABLE', E'Immediate denture - mandibular', E'Prótesis completa inmediata inferior (temporaria)', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5211', E'PROSTHODONTICS_REMOVABLE', E'Maxillary partial denture - resin base', E'Prótesis parcial removible de acrílico superior', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5212', E'PROSTHODONTICS_REMOVABLE', E'Mandibular partial denture - resin base', E'Prótesis parcial removible de acrílico inferior', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5213', E'PROSTHODONTICS_REMOVABLE', E'Maxillary partial denture - cast metal framework with resin denture bases', E'Prótesis parcial removible de cromo cobalto superior', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5214', E'PROSTHODONTICS_REMOVABLE', E'Mandibular partial denture - cast metal framework with resin denture bases', E'Prótesis parcial removible de cromo cobalto inferior', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5221', E'PROSTHODONTICS_REMOVABLE', E'Immediate maxillary partial denture - resin base', E'Prótesis parcial inmediata temporaria', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5611', E'PROSTHODONTICS_REMOVABLE', E'Repair acrylic denture base, mandibular', E'Compostura simple de base acrílica', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5621', E'PROSTHODONTICS_REMOVABLE', E'Repair cast partial framework, mandibular', E'Soldado de retención en aparatos de cromo cobalto', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5630', E'PROSTHODONTICS_REMOVABLE', E'Repair or replace broken retentive clasping materials - per tooth', E'Compostura con agregado o reparación de retenedor', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5640', E'PROSTHODONTICS_REMOVABLE', E'Replace broken teeth - per tooth', E'Compostura con agregado de diente artificial', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5750', E'PROSTHODONTICS_REMOVABLE', E'Reline complete maxillary denture (laboratory)', E'Rebasado de prótesis completa', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5751', E'PROSTHODONTICS_REMOVABLE', E'Reline complete mandibular denture (laboratory)', E'Rebasado de prótesis parcial', 274440007)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5862', E'PROSTHODONTICS_REMOVABLE', E'Precision attachment, each', E'Ataches de precisión o barra tangencial tipo Dolder', 274439005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5867', E'PROSTHODONTICS_REMOVABLE', E'Replacement of replaceable part of semi-precision or precision attachment', E'Poste bola o repuesto de anclaje de precisión', 274439005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D5899', E'PROSTHODONTICS_REMOVABLE', E'Unspecified removable prosthodontic procedure, by report', E'Cubeta individual para toma de impresiones', NULL)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6240', E'PROSTHODONTICS_FIXED', E'Pontic - porcelain/ceramic', E'Tramo de puente colado revestido en porcelana', 274439005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6241', E'PROSTHODONTICS_FIXED', E'Pontic - porcelain fused to predominantly base metal', E'Tramo de puente colado metálico / acrílico', 274439005)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6010', E'IMPLANT_SERVICES', E'Surgical placement of implant body: endosteal implant', E'Colocación quirúrgica de implante dentario intraóseo', 234745003)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6053', E'IMPLANT_SERVICES', E'Implant/abutment supported removable denture for completely edentulous arch', E'Prótesis completa o parcial removible sobre implantes', 234745003)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6056', E'IMPLANT_SERVICES', E'Prefabricated abutment - includes modification and placement', E'Emergente o intermediario sobre implantes dentales', 234745003)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6058', E'IMPLANT_SERVICES', E'Abutment supported porcelain/ceramic crown', E'Corona de porcelana/cerámica sobre implante', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6085', E'IMPLANT_SERVICES', E'Provisional implant crown', E'Corona provisoria sobre implante dentario', 36830009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D6104', E'IMPLANT_SERVICES', E'Bone graft at time of implant placement', E'Relleno óseo / injerto óseo en sitio de implante', 234745003)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7140', E'ORAL_MAXILLOFACIAL_SURGERY', E'Extraction, erupted tooth or exposed root', E'Extracción dentaria simple de pieza erupcionada o raíz', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7210', E'ORAL_MAXILLOFACIAL_SURGERY', E'Extraction, erupted tooth requiring removal of bone and/or sectioning of tooth', E'Extracción dentaria con alveolectomía externa / remoción ósea', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7240', E'ORAL_MAXILLOFACIAL_SURGERY', E'Removal of impacted tooth - completely bony', E'Extracción de diente en retención ósea completa', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7251', E'ORAL_MAXILLOFACIAL_SURGERY', E'Coronectomy - intentional partial tooth removal', E'Germectomía / coronectomía intencional', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7260', E'ORAL_MAXILLOFACIAL_SURGERY', E'Oral antral fistula closure', E'Plástica de comunicación buco-sinusal', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7270', E'ORAL_MAXILLOFACIAL_SURGERY', E'Tooth reimplantation and/or stabilization of accidentally evulsed or displaced tooth', E'Reimplante dentario inmediato al traumatismo y fijación', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7280', E'ORAL_MAXILLOFACIAL_SURGERY', E'Exposure of an unerupted tooth', E'Liberación quirúrgica de diente retenido para tracción', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7285', E'ORAL_MAXILLOFACIAL_SURGERY', E'Incisional biopsy of oral tissue - hard (bone, tooth)', E'Biopsia de tejido duro (óseo o dentario) por punción/aspiración', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7286', E'ORAL_MAXILLOFACIAL_SURGERY', E'Incisional biopsy of oral tissue - soft', E'Biopsia por escisión de tejido blando bucal', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7310', E'ORAL_MAXILLOFACIAL_SURGERY', E'Alveoloplasty in conjunction with extractions - four or more teeth or tooth spaces, per quadrant', E'Alveolectomía estabilizadora o correctiva por zona', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7440', E'ORAL_MAXILLOFACIAL_SURGERY', E'Excision of malignant tumor - lesion diameter greater than 1.25 cm', E'Tratamiento quirúrgico de osteomielitis maxilar', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7510', E'ORAL_MAXILLOFACIAL_SURGERY', E'Incision and drainage of abscess - intraoral soft tissue', E'Incisión y drenaje de abscesos por vía intrabucal', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7530', E'ORAL_MAXILLOFACIAL_SURGERY', E'Removal of foreign body from mucosa, skin, or subcutaneous alveolar tissue', E'Extracción de cuerpo extraño en cavidad bucal', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7880', E'ORAL_MAXILLOFACIAL_SURGERY', E'Occlusal orthotic device, by report', E'Aparato de estabilización oclusal / terapia de ATM', 274441006)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7910', E'ORAL_MAXILLOFACIAL_SURGERY', E'Dentofacial simple suture of recent wounds up to 5 cm', E'Sutura de encías como tratamiento de lesión traumática', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D7961', E'ORAL_MAXILLOFACIAL_SURGERY', E'Buccal / labial frenectomy (frenulectomy)', E'Frenectomía labial o lingual', 234744004)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D8020', E'ORTHODONTICS', E'Interceptive orthodontic treatment of the transitional dentition', E'Tratamiento de ortodoncia interceptiva en dentición primaria o mixta', 401267008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D8050', E'ORTHODONTICS', E'Interceptive orthodontic treatment of the adolescent dentition', E'Corrección de malposiciones simples con espacio', 401267008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D8070', E'ORTHODONTICS', E'Comprehensive orthodontic treatment of the transitional dentition', E'Tratamiento de ortodoncia en dentición mixta / hemi-arcada', 401267008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D8080', E'ORTHODONTICS', E'Comprehensive orthodontic treatment of the adolescent dentition', E'Tratamiento integral de ortodoncia de dentición permanente', 401267008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D8660', E'ORTHODONTICS', E'Pre-orthodontic treatment examination to monitor growth and development', E'Consulta de estudio y diagnóstico para ortodoncia', 401267008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D9110', E'ADJUNCTIVE_GENERAL_SERVICES', E'Palliative treatment of dental pain - minor procedure', E'Consultas de urgencia / tratamiento paliativo del dolor', 275932009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D9410', E'ADJUNCTIVE_GENERAL_SERVICES', E'House/extended care facility call', E'Visita odontológica a domicilio / fuera de radio urbano', 308335008)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D9440', E'ADJUNCTIVE_GENERAL_SERVICES', E'Office visit - after regularly scheduled hours', E'Consulta nocturna, domingos y feriados (urgencias)', 185347001)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D9944', E'ADJUNCTIVE_GENERAL_SERVICES', E'Occlusal guard - hard appliance, full arch', E'Placa oclusal rígida para bruxismo / levante de articulación', 274441006)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D9951', E'ADJUNCTIVE_GENERAL_SERVICES', E'Occlusal adjustment - limited', E'Desgaste selectivo o armonización oclusal', 274441006)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)
VALUES (E'D9999', E'ADJUNCTIVE_GENERAL_SERVICES', E'Unspecified adjunctive procedure, by report', E'Procedimiento odontológico complementario no clasificado', 275932009)
ON CONFLICT (codigo_cdt) DO UPDATE SET
    categoria_codigo = EXCLUDED.categoria_codigo,
    descripcion_en = EXCLUDED.descripcion_en,
    descripcion_es = EXCLUDED.descripcion_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id;


-- =============================================================================
-- 3. NOMENCLADOR ODONTOLÓGICO ARGENTINO (138 PRESTACIONES CON AUDITORÍA)
-- =============================================================================
CREATE TABLE IF NOT EXISTS odontologia_nomenclador (
    codigo VARCHAR(30) PRIMARY KEY,
    descripcion TEXT NOT NULL,
    capitulo VARCHAR(150) NOT NULL,
    facturable BOOLEAN DEFAULT TRUE,
    requiere_pieza BOOLEAN DEFAULT FALSE,
    requiere_caras BOOLEAN DEFAULT FALSE,
    requiere_rx_pre BOOLEAN DEFAULT FALSE,
    requiere_rx_post BOOLEAN DEFAULT FALSE,
    ficha_odontologica BOOLEAN DEFAULT FALSE,
    ficha_periodontal BOOLEAN DEFAULT FALSE,
    material VARCHAR(100),
    maxilar VARCHAR(50),
    norma_particular TEXT,
    cdt_code_default VARCHAR(10) REFERENCES odontologia_cdt_catalogo(codigo_cdt),
    snomed_concept_id BIGINT
);

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'01.01', E'Examen-Diagnóstico-Fichado y plan de tratamiento', E'Capítulo I - Consultas', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se considera primera consulta al examen, diagnóstico, el fichado y plan de tratamiento. Como consecuencia del examen, el fichado deberá reflejar el estado actual de la boca, previo al tratamiento a efectuarse. El código 01.01 podrá facturarse hasta una vez por año, salvo para menores de dieciocho años cuyo tope serán dos consultas por año, cualquiera fuese el número de veces que en dicho período el beneficiario demande servicios con el mismo prestador, no pudiendo facturarlo los especialistas que efectúen determinada práctica derivada de otro prestador y/o profesional. Sólo se reconocerá cuando no se realice la práctica indicada', E'D0150', 424759004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'01.02', E'Consulta nocturna-Domingo y feriado (urgencias)', E'Capítulo I - Consultas', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D9440', 275932009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'01.03', E'Visitas a domicilio', E'Capítulo I - Consultas', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se considera consulta domiciliaria a la atención de pacientes impedidos de trasladarse al consultorio del prestador, fuera del radio urbano.', E'D9410', 308335008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'01.04', E'Consultas de urgencia, prestación que no constituya paso intermedio de tratamiento.', E'Capítulo I - Consultas', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se considera consulta de urgencia a toda prestación que no constituye paso intermedio o final de tratamiento. Se debe establecer en todos los casos el motivo de la misma, Ej.: Pericoronaritis, estomatitis, cementado de coronas y puentes, punción y drenaje de abscesos, flemones, hemorragias y alveolitis, etc.', E'D9110', 275932009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'01.05', E'Consulta de estomatología (sólo para especialistas)', E'Capítulo I - Consultas', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconoce para lesiones propias de la mucosa bucal. Se permite facturar en forma independiente del código 01.01 (Ej.: patologías: Papilomas épulis, lesiones precancerosas y cancerosas, micosis, etc.). Incluye diagnóstico e indicación de tratamiento', E'D0160', 386053000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'01.06', E'Consulta preventiva periódica', E'Capítulo I - Consultas', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D0120', 424759004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'01.07', E'Bonos otras Obras Sociales', E'Capítulo I - Consultas', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D9999', 275932009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.01', E'Obturación con amalgama: cavidad simple', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá para cavidad simple habiéndose practicado correcto diagnóstico y adecuado tallado de la cavidad.', E'D2140', 80891009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.02', E'Obturación con amalgama: cavidad compuesta', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad.', E'D2150', 80891009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.03', E'Obturación con amalgama: cavidad compleja', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad.', E'D2160', 80891009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.04', E'Obturación con amalgama: reconstrucción con tornillo en conducto', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá en piezas posteriores y con Rx post-operatoria que se incluye.', E'D2161', 80891009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.05', E'Obturación Estética - Cavidad simple', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá para cavidad simple y previo diagnóstico pulpar, y se aplica a piezas TEMPORARIAS.', E'D2330', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.06', E'Obturación Estética- Cavidad compuesta o Compuesta', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá para cavidades compuestas o complejas previo diagnóstico pulpar. y se aplica a piezas TEMPORARIAS.', E'D2331', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.08', E'Obturación resina fotocurado sector Anterior y Posterior', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá en piezas permanentes anteriores y posteriores previo diagnóstico pulpar', E'D2391', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.09', E'Reconstrucción de ángulo en dientes anteriores', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá en piezas anteriores, previo diagnóstico pulpar e incluye técnicas de grabado ácido.', E'D2335', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.10', E'Obturación resina fotocurado sector Posterior', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá en piezas permanentes posteriores previo diagnóstico pulpar.', E'D2391', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.15', E'Composite simple ( incluye fotocurado )', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D2391', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.16', E'Composite compuesto ( incluye fotocurado )', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D2391', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.17', E'Composite compuesto con tornillo en conducto', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D2951', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'02.15 F', E'Ferulización por causas periodontales', E'Capítulo II - Operatoria Dental', TRUE, TRUE, TRUE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá con autorización previa, análisis de los factores traumatizantes, remitiéndose los elementos de juicio necesarios para su evaluación. Periodo de cobertura mínima de tres (3) años.', E'D4322', 274438002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'03.01', E'Tratamiento de un conducto', E'Capítulo III - Endodoncia', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D3310', 68673005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'03.02', E'Tratamiento de dos conductos', E'Capítulo III - Endodoncia', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D3320', 68673005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'03.03', E'Tratamiento de tres conductos', E'Capítulo III - Endodoncia', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D3330', 68673005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'03.04', E'Tratamiento de cuatro conductos', E'Capítulo III - Endodoncia', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D3330', 68673005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'03.05', E'Biopulpectomía parcial', E'Capítulo III - Endodoncia', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Cuando se realice esta práctica no se reconocerá otro tratamiento de endodoncia y su  correspondiente restauración coronaria hasta un año después de efectuada la misma, si  es realizado por el mismo profesional. Solamente para piezas con foramen apical abierto o en formación.', E'D3220', 234737002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'03.06', E'Necropulpectomía parcial ( momificación )', E'Capítulo III - Endodoncia', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá solamente en dientes posteriores.', E'D3221', 234737002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.01', E'Incrustaciones:  cavidad simple', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D2610', 111163002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.02', E'Incrustaciones: cavidad compuesta o compleja', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D2620', 111163002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.03', E'Corona forjada', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'No incluye corona provisoria. Para su reconocimiento deberá fundamentarse el motivo de su confección.', E'D2790', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.04', E'Corona colada', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'No incluye corona provisoria.', E'D2790', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.05', E'Corona colada con frente estético', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'No incluye corona provisoria. Incluye la carilla de acrílico.', E'D2751', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.06', E'Corona espiga', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Incluye pieza metálica y acrílico.', E'D2790', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.07', E'Corona colada revestida en acrílico', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'No incluye corona provisoria. Incluye pieza metálica y acrílica y metálica.', E'D2751', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.07 bis', E'Corona colada revestida en porcelana', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D2740', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.07 bis i', E'Corona colada revestida en porcelana sobre implante', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D6058', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.08', E'Perno muñón simple', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias.', E'D2952', 234736006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.08 i', E'Emergente o intermediario sobre implantes', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D6056', 234736006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.09', E'Perno muñon seccionado', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias.', E'D2952', 234736006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.10', E'Tramo de puente colado', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Incluye pieza metálica y acrílico.', E'D6241', 274439005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.10 bis', E'Tramo puente colado ( porcelana )', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D6240', 274439005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.11', E'Corona de acrílico', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'No incluye corona provisoria.', E'D2751', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.12', E'Corona provisoria', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Para su reconocimiento podrá requerirse su presentación.', E'D2799', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.12 i', E'Corona provisoria sobre implantes', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D6085', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.15', E'Ataches', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D5862', 274439005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.16', E'Poste bola', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D5862', 274439005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.01.17', E'Barra tangencial tipo Dolder', E'Capítulo IV – Prótesis Fija', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D5862', 274439005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.02.01', E'De acrílico: hasta cuatro dientes', E'Prótesis parcial removible', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, E'1', NULL, E'Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'D5211', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.02.02', E'De acrílico: de cinco o más dientes', E'Prótesis parcial removible', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, E'1', NULL, E'Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'D5211', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.02.03', E'Cromo cobalto: hasta cuatro dientes', E'Prótesis parcial removible', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, E'1', NULL, E'Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'D5213', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.02.04', E'Cromo cobalto: de cinco o más dientes', E'Prótesis parcial removible', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, E'1', NULL, E'Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.', E'D5213', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.02.04 i', E'Cromo cobalto sobre implantes', E'Prótesis parcial removible', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, E'1', NULL, NULL, E'D5213', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.02.05', E'Prótesis parcial inmediata ( temporaria )', E'Prótesis parcial removible', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye cubeta individual, retenedores, cualquier número dientes, eventual rebasado y controles posteriores. No podrá reconocerse la facturación de la prótesis definitiva, hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.', E'D5221', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.02.05 i', E'Prótesis parcial inmediata ( temporaria ) sobre implantes', E'Prótesis parcial removible', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5221', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.03.01', E'Superior', E'Prótesis completa - 04.03', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye las consultas posteriores a su instalación para los retoques necesarios.', E'D5110', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.03.01 i', E'Superior sobre implantes', E'Prótesis completa - 04.04', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5110', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.03.02', E'Inferior', E'Prótesis completa - 04.05', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye las consultas posteriores a su instalación para los retoques necesarios.', E'D5120', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.03.02 i', E'Inferior sobre implantes', E'Prótesis completa - 04.06', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5120', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.03.03', E'Prótesis completa inmediata ( temporaria )', E'Prótesis completa - 04.07', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye cubeta individual, eventual rebasado y controles posteriores a su instalación. No podrá reconocerse la facturación de la prótesis definitiva hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.', E'D5130', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.03.03 i', E'Prótesis completa inmediata sobre implantes ( temporaria )', E'Prótesis completa - 04.08', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5130', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.01', E'Compostura simple', E'Varios', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, E'1', NULL, E'D5611', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.02', E'Compostura con agregado de un diente', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5640', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.03', E'Compostura con agregado de un retenedor', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5630', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.04', E'Compostura simple con agregado de un diente y un retenedor', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5640', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.05', E'Diente subsiguiente, c/u', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5211', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.06', E'Retenedor subsiguiente, c/u', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5211', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.07', E'Soldado de retención en aparatos de cromo', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye el montaje del diente artificial.', E'D5621', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.08', E'Retención subsiguiente', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5211', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.09', E'Carilla de acrílico', E'Varios', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D5611', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.10', E'Rebasado de prótesis, c/u', E'Varios', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, E'1', NULL, E'D5750', 274440007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.11', E'Cubeta individual', E'Varios', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, E'1', E'Se reconocerá cuando se efectúe con acrílico termocurable, pudiendo requerirse su presentación para su reconocimiento.', E'D5899', NULL)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'04.04.12', E'Levante de articulación, en acrílico traslucido y retenedores forjados en acero.', E'Varios', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye cubeta individual y controles posteriores. Gramos estimados de los metales utilizados en las siguientes prácticas según código', E'D9944', 274441006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'05.00', E'Ficha de prevención.', E'Capítulo V - Odontología Preventiva', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D0150', NULL)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'05.01', E'Tartrectomía y cepillado mecánico', E'Capítulo V - Odontología Preventiva', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'No incluye blanqueamiento de piezas dentarias.  Se cubre una vez por año a pacientes mayores de 18 años.', E'D1110', 22769002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'05.02', E'Aplicación de fluor, incluye cepillado previo y tartrectomía', E'Capítulo V - Odontología Preventiva', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye Tartrectomía y cepillado mecánico, detección y control de placa bacteriana,  enseñanza de técnicas de higiene. Comprende aplicación de flúor tópico, barniz y  colutorios. O sea, incluye código 05.04.  Se cubrirá hasta los 18 años y semestralmente.', E'D1206', 110462007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'05.03', E'Detección de placa bacteriana y test de susceptibilidad de caries', E'Capítulo V - Odontología Preventiva', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D0425', NULL)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'05.04', E'Enseñanzas de técnicas de higiene bucal.Incluye control de placa y test de suscep.', E'Capítulo V - Odontología Preventiva', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye detección de placa bacteriana y enseñanza de técnica de higiene bucal.  Comprende uso de elementos como interdentarios, asesoramiento dietético y revelado  de placa, se aplica en mayores de 18 años.', E'D1330', 399047006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'05.05', E'Sellantes de puntos y fisuras', E'Capítulo V - Odontología Preventiva', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconoce hasta los 15 años en premolares y molares permanentes enteros con un  período de responsabilidad de dos años, no pudiendo facturar el mismo profesional prestador obturaciones ni extracciones de las piezas tratadas en dicho período de  tiempo. No se acepta en caras libres.', E'D1351', 234735005)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'05.06', E'Aplicación de cariostáticos en piezas dentarias permanentes', E'Capítulo V - Odontología Preventiva', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se cubrirá para aquellos casos que sea necesario curar infección de ulceras,  estabilización de procesos de destrucción, mineralización, etc. Se contempla en piezas  permanentes, hasta una vez por año por pieza (incluye las aplicaciones necesarias),  aclarando diagnóstico.', E'D1354', 713601007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'06.01', E'Consulta de estudio', E'Capítulo VI - Ortodoncia y ortopedia funcional', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D8660', 401267008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'06.02', E'Tratamiento de la dentición primaria o mixta *', E'Capítulo VI - Ortodoncia y ortopedia funcional', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D8020', 401267008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'06.03', E'Tratamiento de la dentición permanente *', E'Capítulo VI - Ortodoncia y ortopedia funcional', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D8080', 401267008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'06.04', E'Corrección de malposiciones simples con espacio', E'Capítulo VI - Ortodoncia y ortopedia funcional', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D8050', 401267008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'06.05', E'Tratamiento de la dentición permanente: hemi - arcada.', E'Capítulo VI - Ortodoncia y ortopedia funcional', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D8080', 401267008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.01', E'Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 13 años', E'Capítulo VII - Odontopediatría', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerán hasta los 13 años de edad. Incluye 01.01 y comprende hasta tres visitas  al consultorio', E'D0145', 399120002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.02', E'Mantenedor de espacio fijo', E'Capítulo VII - Odontopediatría', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Incluye corona en pieza dentaria y ansa de alambre de apoyo. Deberá acompañar  radiografía post-operatoria. Se cubre por única vez y en pacientes hasta 8 años de  edad. Requiere autorización previa.', E'D1510', 274437007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.03', E'Mantenedor de espacio removible', E'Capítulo VII - Odontopediatría', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá cuando falten dos o más dientes primarios contiguos o más de dos  dientes alternados en la misma arcada dental. Se cubre por única vez y en pacientes  hasta 8 años de edad. Requiere autorización previa.', E'D1520', 274437007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.04', E'Tratamiento de dientes primarios con formocresol', E'Capítulo VII - Odontopediatría', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconoce con radiografía post-operatoria, y cuando el diente tratado no se encuentre  en período de exfoliación normal.', E'D3220', 234737002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.05', E'Corona de acero y similares', E'Capítulo VII - Odontopediatría', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá en dientes primarios con gran destrucción coronaria y que no se  encuentre en período de exfoliación normal. Incluye toda obturación realizada por el  mismo profesional y deberá acompañar radiografía post-operatoria. En primeros  molares permanentes hasta los 15 años de edad. Requiere autorización previa.', E'D2930', 36830009)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.06.01', E'Reducción de luxación con inmovilización dentaria', E'Odontopediatría (Traumatismos dentarios)', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D7270', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.06.02', E'Luxación total ( reimplante ) o inmovilización dentaria', E'Odontopediatría (Traumatismos dentarios)', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'No incluye el tratamiento endodónticos.', E'D7270', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.06.04', E'Fractura amelodentinaria, protección pulpar con coronas provisorias', E'Odontopediatría (Traumatismos dentarios)', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Incluye corona provisoria y se reconocerá con Rx pre y post operatoria.', E'D2970', 111164008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.07', E'Protección pulpar directa', E'Odontopediatría (Traumatismos dentarios)', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconoce en piezas molares permanentes con Rx post-operatoria incluida en valor de  la prestación. Por el término de seis (6) meses no se reconocerá otro tratamiento pulpar.  Se aplica hasta los 18 años.', E'D3110', 234737002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'07.08', E'Aplicación de cariostáticos', E'Odontopediatría (Traumatismos dentarios)', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se aplicará ante la presencia de caries rampantes en dientes temporarios, por única  vez y hasta los seis (6) años.', E'D1354', 713601007)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.01', E'Consulta de estudio-Diagnóstico-Pronóstico', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Incluye la confección de la ficha periodontal respectiva (de acuerdo al modelo que se  adopte), la cual deberá acompañar a los códigos 08.03. y 08.04. Se reconocerá una vez  cada dos años e incluye código 0101.', E'D0180', 424759004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.02', E'Tratamiento de gingivitis, marginal crónica', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Comprende todos los cuadros gingivales cualquiera fuese su etiología. Incluye Tartrectomía, raspado, control de placas, enseñanza de cepillado y FLUOR ambas  arcadas. Como única patología se reconocerá una vez por año. Cuando en la ficha  periodontal correspondiente a los códigos 08.03. y 08.04.; se señale esta patología en  otros sectores de la boca, se podrá sumar este código para el resto de las piezas.', E'D4346', 110463002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.03', E'Trat. periodontitis destructiva leve o mod. Bolsas hasta  5mm por sector (6 sec)', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, NULL, NULL, E'En bolsas de hasta 5 mm., pérdida ósea alveolar de hasta 2/3 de la raíz, por sector.  Incluye 05.01; 05.04; 08.02 y 08.05 alisado radicular eventual gingivectomía o colgajo.  Periodo de cobertura: 2 años, excepto casos especiales a considerar por auditoria.  Mínimo de cuatro (4) piezas por sector. Se reconocerá con Radiografías preoperatorias y ficha periodontal debidamente  confeccionada', E'D4341', 110463002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.04', E'Trat. periodontitis destructiva severa. Bolsas de 6mm o más. Por sector (6 sec)', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, TRUE, NULL, NULL, E'En bolsas de 6 mm. o más, pérdida ósea alveolar de más de 2/3 y/o lesión de  furcación en grados 3 y 4 , por sector. Incluye 05.01; 05.04 ; 08.02, 08.03 y 08.05 más eventual cirugía mucogingival e  injerto.  Periodo de cobertura: 2 años., excepto casos especiales a considerar por auditoria.  Mínimo cuatro (4) piezas por sector. Se reconocerá con Radiografías preoperatorias y ficha periodontal debidamente  confeccionada', E'D4260', 234740008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.04 C', E'Cirugía Periodontal', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D4210', 234740008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.05', E'Desgaste selectivo o armonización oclusal', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá cuando se detalle el estudio de la oclusión y el análisis de los factores  traumatizantes, remitiendo los elementos de juicio necesarios para su evaluación.', E'D9951', 274441006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.05.01', E'ATM. y bruxismo, terapia farmacológica y fisioterapia.', E'Capítulo VIII - Periodoncia', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D7880', 274441006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.05.02', E'Aparato de estabilización oclusal y en relación céntrica.', E'Capítulo VIII - Periodoncia', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D7880', 274441006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.05.03', E'Aparato oclusal pivotante.', E'Capítulo VIII - Periodoncia', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D7880', 274441006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.06', E'Placas oclusales ( temporarias ) removibles de acrílico, cualquier tipo', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D9944', 274441006)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'08.07', E'Mantenimiento de tratamiento periodontal', E'Capítulo VIII - Periodoncia', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconocerá cada seis (6) meses siempre que exista tratamiento previo de 08.03 u  08.04, y con el mismo profesional. Incluye 05.01; 05.04 y 08.02', E'D4910', 110463002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.01.01', E'Periapical, técnicas de cono corto o cono largo', E'Capítulo IX – Radiología (Intraorales – 09.01)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'Se admite como máximo cuatro veces la suma. De cinco a siete películas se facturará como  código 09.01.04., de ocho a nueve películas se facturará como código 09.01.04., más una o dos  veces el código 09.01.01. según corresponda. De diez a catorce películas se facturará como código 09.01. 05.', E'D0220', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.01.02', E'Bite-Wing', E'Capítulo IX – Radiología (Intraorales – 09.01)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D0272', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.01.03', E'Oclusal de 6 x 8 cm.', E'Capítulo IX – Radiología (Intraorales – 09.01)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D0240', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.01.04', E'Media seriada: 7 películas- Técnicas de cono corto o largo', E'Capítulo IX – Radiología (Intraorales – 09.01)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'Se reconocerá cuando la integren siete películas.', E'D0210', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.01.05', E'Seriada de 14 péliculas- técnicas de cono corto o largo', E'Capítulo IX – Radiología (Intraorales – 09.01)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'Se reconocerá cuando la integren 14 películas.', E'D0210', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.02.01', E'Extraorales: primera exposición', E'Capítulo IX – Radiología (Extraorales – 09.02)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'Comprende todas las radiografías extraorales de la especialidad, exceptuadas las  señaladas con los códigos 09.02.03., 09.02.04., 09.02.05 y 09.02.06.', E'D0250', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.02.02', E'Extraorales: por exposición subsiguiente', E'Capítulo IX – Radiología (Extraorales – 09.02)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'Comprende todas las radiografías extraorales de la especialidad, 09.02.05 y 09.02.06.', E'D0250', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.02.03', E'Articulación Temporo-maxilar ( 6 tomas )', E'Capítulo IX – Radiología (Extraorales – 09.02)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'Técnica de Schuller Modificada. Incluye seis tomas comparativas, tres por lado.', E'D0320', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.02.04', E'Pantomografía ( radiografícas panorámicas )', E'Capítulo IX – Radiología (Extraorales – 09.02)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'Radiografía panorámica. Es el estudio panorámico de la cavidad bucal y zonas vecinas.', E'D0330', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.02.05', E'Telerradiografía cefalométrica', E'Capítulo IX – Radiología (Extraorales – 09.02)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D0340', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.02.05 bis', E'Estudio o trazado cefalométrico', E'Capítulo IX – Radiología (Extraorales – 09.02)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D0340', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'09.02.06', E'Sialografía', E'Capítulo IX – Radiología (Extraorales – 09.02)', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, E'No incluye la sustancia de contraste. Comprende el estudio con un mínimo de tres placas,  por glándula y por lado.', E'D0310', 399195000)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.01', E'Extracción dentaria', E'Capítulo X - Cirugía Bucal', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'No se contempla su cobertura en piezas temporarias en su periodo de exfoliación.', E'D7140', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.02', E'Plástica de comunicación buco-sinusal como riesgo previsto simultáneo a la extracción', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, NULL, NULL, E'Para su reconocimiento deberá acompañarse la radiografía preoperatoria que justifique  la realización de la práctica.', E'D7260', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.03', E'Biopsia por punción o aspiración', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'No incluye el estudio Anatomopatológico.', E'D7285', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.04', E'Alveolectomia estabilizadora ( 6 zonas ): por zona', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Podrá requerir autorización previa.', E'D7310', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.05', E'Reimplante dentario inmediato al traumatismo', E'Capítulo X - Cirugía Bucal', TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconoce con radiografía post-operatoria.', E'D7270', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.06', E'Incisión y drenaje de abscesos por via intrabucal', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, NULL, E'D7510', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.07', E'Biopsia por escisión', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'No incluye el estudio Anatomopatológico.', E'D7286', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.08', E'Alargamiento quirúrgico de la corona clínica', E'Capítulo X - Cirugía Bucal', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, NULL, E'Se reconoce solo asociado a práctica de la misma facturación.', E'D4249', 234740008)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.09', E'Extracción de dientes retenidos o restos radiculares retenidos', E'Capítulo X - Cirugía Bucal', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá con radiografía pre y post-operatoria.', E'D7210', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.10', E'Germectomía', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá con radiografía pre y post-operatoria. Podrá requerirse autorización previa.', E'D7251', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.11', E'Libreración de dientes retenidos', E'Capítulo X - Cirugía Bucal', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá con radiografía pre-operatoria y post-operatoria.', E'D7280', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.12', E'Apicectomía', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá con radiografía pre y post-operatoria.', E'D3410', 234737002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.13', E'Tratamiento de osteomielitis', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D7440', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.14', E'Extracción de cuerpo extraño', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá con radiografía pre y post-operatoria.', E'D7530', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.15', E'Alveolectomía correctiva( 6 zonas ): por zona', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, E'Se reconocerá con radiografía pre y post-operatoria.', E'D7310', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.16', E'Frenectomía', E'Capítulo X - Cirugía Bucal', TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, NULL, E'1', NULL, E'D7961', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.17', E'Radectomía', E'Capítulo X - Cirugía Bucal', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D3920', 234737002)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.18', E'Extracción por alveolectomía externa (complicación de extracción).', E'Capítulo X - Cirugía Bucal', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D7210', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.19', E'Extracción de dientes en retención ósea.', E'Capítulo X - Cirugía Bucal', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D7240', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'10.20', E'Sutura de encías como tratamiento de lesión traumática.', E'Capítulo X - Cirugía Bucal', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, NULL, NULL, NULL, E'D7910', 234744004)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'11.01.01', E'Implante dentario', E'Capítulo XI – Implantes', TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D6010', 234745003)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;

INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)
VALUES (E'11.02', E'Relleno óseo', E'Capítulo XI – Implantes', TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, NULL, NULL, NULL, E'D6104', 234745003)
ON CONFLICT (codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    facturable = EXCLUDED.facturable,
    requiere_pieza = EXCLUDED.requiere_pieza,
    requiere_caras = EXCLUDED.requiere_caras,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    cdt_code_default = EXCLUDED.cdt_code_default,
    snomed_concept_id = EXCLUDED.snomed_concept_id;


-- =============================================================================
-- 4. MAPEO CRUZADO (CROSSWALK) NOMENCLADOR ARGENTINO <-> CDT 2025
-- =============================================================================
CREATE TABLE IF NOT EXISTS odontologia_mapeo_argentina_cdt (
    id SERIAL PRIMARY KEY,
    codigo_nomenclador VARCHAR(30) NOT NULL REFERENCES odontologia_nomenclador(codigo) ON DELETE CASCADE,
    codigo_cdt VARCHAR(10) NOT NULL REFERENCES odontologia_cdt_catalogo(codigo_cdt) ON DELETE CASCADE,
    relationship VARCHAR(30) NOT NULL DEFAULT 'equivalent',
    snomed_concept_id BIGINT,
    notas TEXT,
    UNIQUE (codigo_nomenclador, codigo_cdt)
);

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'01.01', E'D0150', E'equivalent', 424759004, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'01.02', E'D9440', E'equivalent', 275932009, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'01.03', E'D9410', E'equivalent', 308335008, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'01.04', E'D9110', E'equivalent', 275932009, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'01.05', E'D0160', E'equivalent', 386053000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'01.06', E'D0120', E'equivalent', 424759004, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'01.07', E'D9999', E'related', 275932009, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.01', E'D2140', E'equivalent', 80891009, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.02', E'D2150', E'equivalent', 80891009, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.03', E'D2160', E'equivalent', 80891009, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.04', E'D2161', E'equivalent', 80891009, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.05', E'D2330', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.06', E'D2331', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.08', E'D2391', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.09', E'D2335', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.10', E'D2391', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.15', E'D2391', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.16', E'D2391', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.17', E'D2951', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'02.15 F', E'D4322', E'equivalent', 274438002, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'03.01', E'D3310', E'equivalent', 68673005, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'03.02', E'D3320', E'equivalent', 68673005, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'03.03', E'D3330', E'equivalent', 68673005, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'03.04', E'D3330', E'equivalent', 68673005, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'03.05', E'D3220', E'equivalent', 234737002, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'03.06', E'D3221', E'equivalent', 234737002, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.01', E'D2610', E'equivalent', 111163002, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.02', E'D2620', E'equivalent', 111163002, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.03', E'D2790', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.04', E'D2790', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.05', E'D2751', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.06', E'D2790', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.07', E'D2751', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.07 bis', E'D2740', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.07 bis i', E'D6058', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.08', E'D2952', E'equivalent', 234736006, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.08 i', E'D6056', E'equivalent', 234736006, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.09', E'D2952', E'equivalent', 234736006, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.10', E'D6241', E'equivalent', 274439005, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.10 bis', E'D6240', E'equivalent', 274439005, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.11', E'D2751', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.12', E'D2799', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.12 i', E'D6085', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.15', E'D5862', E'equivalent', 274439005, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.16', E'D5862', E'equivalent', 274439005, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.01.17', E'D5862', E'equivalent', 274439005, E'Mapeo oficial DENTAR / CDT Prótesis Fija')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.02.01', E'D5211', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.02.02', E'D5211', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.02.03', E'D5213', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.02.04', E'D5213', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.02.04 i', E'D5213', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.02.05', E'D5221', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.02.05 i', E'D5221', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.03.01', E'D5110', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.03.01 i', E'D5110', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.03.02', E'D5120', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.03.02 i', E'D5120', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.03.03', E'D5130', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.03.03 i', E'D5130', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.01', E'D5611', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.02', E'D5640', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.03', E'D5630', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.04', E'D5640', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.05', E'D5211', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.06', E'D5211', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.07', E'D5621', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.08', E'D5211', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.09', E'D5611', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.10', E'D5750', E'equivalent', 274440007, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.11', E'D5899', E'related', NULL, E'Mapeo oficial DENTAR / CDT Prótesis Parcial y Completa Removible')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'04.04.12', E'D9944', E'equivalent', 274441006, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'05.00', E'D0150', E'related', NULL, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'05.01', E'D1110', E'equivalent', 22769002, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'05.02', E'D1206', E'equivalent', 110462007, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'05.03', E'D0425', E'related', NULL, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'05.04', E'D1330', E'equivalent', 399047006, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'05.05', E'D1351', E'equivalent', 234735005, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'05.06', E'D1354', E'equivalent', 713601007, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'06.01', E'D8660', E'equivalent', 401267008, E'Mapeo oficial DENTAR / CDT Ortodoncia y Ortopedia Funcional')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'06.02', E'D8020', E'equivalent', 401267008, E'Mapeo oficial DENTAR / CDT Ortodoncia y Ortopedia Funcional')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'06.03', E'D8080', E'equivalent', 401267008, E'Mapeo oficial DENTAR / CDT Ortodoncia y Ortopedia Funcional')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'06.04', E'D8050', E'equivalent', 401267008, E'Mapeo oficial DENTAR / CDT Ortodoncia y Ortopedia Funcional')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'06.05', E'D8080', E'equivalent', 401267008, E'Mapeo oficial DENTAR / CDT Ortodoncia y Ortopedia Funcional')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.01', E'D0145', E'equivalent', 399120002, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.02', E'D1510', E'equivalent', 274437007, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.03', E'D1520', E'equivalent', 274437007, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.04', E'D3220', E'equivalent', 234737002, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.05', E'D2930', E'equivalent', 36830009, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.06.01', E'D7270', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.06.02', E'D7270', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.06.04', E'D2970', E'equivalent', 111164008, E'Mapeo oficial DENTAR / CDT Operatoria Dental y Restauradora')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.07', E'D3110', E'equivalent', 234737002, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'07.08', E'D1354', E'equivalent', 713601007, E'Mapeo oficial DENTAR / CDT Odontología Preventiva')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.01', E'D0180', E'equivalent', 424759004, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.02', E'D4346', E'equivalent', 110463002, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.03', E'D4341', E'equivalent', 110463002, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.04', E'D4260', E'equivalent', 234740008, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.04 C', E'D4210', E'equivalent', 234740008, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.05', E'D9951', E'equivalent', 274441006, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.05.01', E'D7880', E'equivalent', 274441006, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.05.02', E'D7880', E'equivalent', 274441006, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.05.03', E'D7880', E'equivalent', 274441006, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.06', E'D9944', E'equivalent', 274441006, E'Mapeo oficial DENTAR / CDT Servicios Complementarios de Odontología')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'08.07', E'D4910', E'equivalent', 110463002, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.01.01', E'D0220', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.01.02', E'D0272', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.01.03', E'D0240', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.01.04', E'D0210', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.01.05', E'D0210', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.02.01', E'D0250', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.02.02', E'D0250', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.02.03', E'D0320', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.02.04', E'D0330', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.02.05', E'D0340', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.02.05 bis', E'D0340', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'09.02.06', E'D0310', E'equivalent', 399195000, E'Mapeo oficial DENTAR / CDT Diagnóstico y Exámenes Clínicos')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.01', E'D7140', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.02', E'D7260', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.03', E'D7285', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.04', E'D7310', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.05', E'D7270', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.06', E'D7510', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.07', E'D7286', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.08', E'D4249', E'equivalent', 234740008, E'Mapeo oficial DENTAR / CDT Periodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.09', E'D7210', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.10', E'D7251', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.11', E'D7280', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.12', E'D3410', E'equivalent', 234737002, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.13', E'D7440', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.14', E'D7530', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.15', E'D7310', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.16', E'D7961', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.17', E'D3920', E'equivalent', 234737002, E'Mapeo oficial DENTAR / CDT Endodoncia')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.18', E'D7210', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.19', E'D7240', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'10.20', E'D7910', E'equivalent', 234744004, E'Mapeo oficial DENTAR / CDT Cirugía Bucal y Maxilofacial')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'11.01.01', E'D6010', E'equivalent', 234745003, E'Mapeo oficial DENTAR / CDT Implantología Odontológica')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;

INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)
VALUES (E'11.02', E'D6104', E'equivalent', 234745003, E'Mapeo oficial DENTAR / CDT Implantología Odontológica')
ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET
    relationship = EXCLUDED.relationship,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    notas = EXCLUDED.notas;


-- =============================================================================
-- 5. TABLA DE CONSUMO DE LA API: odontologia_prestaciones
-- =============================================================================
CREATE TABLE IF NOT EXISTS odontologia_prestaciones (
    id SERIAL PRIMARY KEY,
    codigo_nomenclador VARCHAR(30) UNIQUE NOT NULL,
    descripcion TEXT NOT NULL,
    capitulo VARCHAR(150),
    cdt_code VARCHAR(20),
    cdt_categoria VARCHAR(50),
    cdt_categoria_es VARCHAR(150),
    snomed_concept_id BIGINT,
    requiere_pieza BOOLEAN DEFAULT FALSE,
    face_specification BOOLEAN DEFAULT FALSE,
    requiere_rx_pre BOOLEAN DEFAULT FALSE,
    requiere_rx_post BOOLEAN DEFAULT FALSE,
    ficha_odontologica BOOLEAN DEFAULT FALSE,
    ficha_periodontal BOOLEAN DEFAULT FALSE,
    material VARCHAR(100),
    maxilar VARCHAR(50),
    norma_particular TEXT,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Migración idempotente si la tabla ya existía con esquema previo:
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS capitulo VARCHAR(150);
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS cdt_code VARCHAR(20);
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS cdt_categoria VARCHAR(50);
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS cdt_categoria_es VARCHAR(150);
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS requiere_pieza BOOLEAN DEFAULT FALSE;
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS requiere_rx_pre BOOLEAN DEFAULT FALSE;
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS requiere_rx_post BOOLEAN DEFAULT FALSE;
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS ficha_odontologica BOOLEAN DEFAULT FALSE;
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS ficha_periodontal BOOLEAN DEFAULT FALSE;
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS material VARCHAR(100);
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS maxilar VARCHAR(50);
ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS norma_particular TEXT;

-- Sincronización desde odontologia_nomenclador hacia odontologia_prestaciones:
INSERT INTO odontologia_prestaciones (
    codigo_nomenclador, descripcion, capitulo, cdt_code, cdt_categoria, cdt_categoria_es,
    snomed_concept_id, requiere_pieza, face_specification, requiere_rx_pre, requiere_rx_post,
    ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, activo
)
SELECT
    n.codigo,
    n.descripcion,
    n.capitulo,
    n.cdt_code_default,
    cat.codigo,
    cat.nombre_es,
    n.snomed_concept_id,
    n.requiere_pieza,
    n.requiere_caras,
    n.requiere_rx_pre,
    n.requiere_rx_post,
    n.ficha_odontologica,
    n.ficha_periodontal,
    n.material,
    n.maxilar,
    n.norma_particular,
    TRUE
FROM odontologia_nomenclador n
LEFT JOIN odontologia_cdt_catalogo cdt ON cdt.codigo_cdt = n.cdt_code_default
LEFT JOIN odontologia_cdt_categorias cat ON cat.codigo = cdt.categoria_codigo
ON CONFLICT (codigo_nomenclador) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    capitulo = EXCLUDED.capitulo,
    cdt_code = EXCLUDED.cdt_code,
    cdt_categoria = EXCLUDED.cdt_categoria,
    cdt_categoria_es = EXCLUDED.cdt_categoria_es,
    snomed_concept_id = EXCLUDED.snomed_concept_id,
    requiere_pieza = EXCLUDED.requiere_pieza,
    face_specification = EXCLUDED.face_specification,
    requiere_rx_pre = EXCLUDED.requiere_rx_pre,
    requiere_rx_post = EXCLUDED.requiere_rx_post,
    ficha_odontologica = EXCLUDED.ficha_odontologica,
    ficha_periodontal = EXCLUDED.ficha_periodontal,
    material = EXCLUDED.material,
    maxilar = EXCLUDED.maxilar,
    norma_particular = EXCLUDED.norma_particular,
    activo = EXCLUDED.activo;

-- Índices de alto rendimiento para búsquedas y autocompletado en la API:
CREATE INDEX IF NOT EXISTS idx_odontologia_trgm ON odontologia_prestaciones USING gin (descripcion gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_odontologia_codigo ON odontologia_prestaciones(codigo_nomenclador);
CREATE INDEX IF NOT EXISTS idx_odontologia_cdt ON odontologia_prestaciones(cdt_code);
CREATE INDEX IF NOT EXISTS idx_odontologia_snomed ON odontologia_prestaciones(snomed_concept_id);

ANALYZE odontologia_cdt_categorias;
ANALYZE odontologia_cdt_catalogo;
ANALYZE odontologia_nomenclador;
ANALYZE odontologia_mapeo_argentina_cdt;
ANALYZE odontologia_prestaciones;

SELECT 'odontologia_cdt_categorias' AS tabla, count(*) AS filas FROM odontologia_cdt_categorias
UNION ALL SELECT 'odontologia_cdt_catalogo', count(*) FROM odontologia_cdt_catalogo
UNION ALL SELECT 'odontologia_nomenclador', count(*) FROM odontologia_nomenclador
UNION ALL SELECT 'odontologia_mapeo_argentina_cdt', count(*) FROM odontologia_mapeo_argentina_cdt
UNION ALL SELECT 'odontologia_prestaciones', count(*) FROM odontologia_prestaciones;
