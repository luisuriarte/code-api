-- =============================================================================
-- Origen Salud · Propuesta LOCAL · DENTAR-AN y DENTAR-CL
-- dentar-an-cl-propuerto.sql
-- =============================================================================
-- NO EJECUTADO. Generado desde SNOMED CT Argentina Snapshot 2026-08-20 (RF2).
-- Requiere autorización explícita para DDL/carga y validación en entorno controlado.
-- Los códigos DNT-AN/DNT-CL son nuevos, secuenciales y no reutilizan otros prefijos.
-- =============================================================================
SET client_encoding = 'UTF8';

BEGIN;

-- 1. Registro editorial de los dos nuevos catálogos activos.
INSERT INTO dentar_catalog
    (family_code, code, short_name, name, code_prefix, concept_kind, description, status, sort_order)
VALUES
    ('dentar', 'dentar-an', 'DENTAR-AN', 'DENTAR-AN · Anatomía odontológica',
     'DNT-AN', 'anatomy',
     'Estructuras anatómicas bucomaxilofaciales identificadas por SNOMED CT Argentina.',
     'active', 30),
    ('dentar', 'dentar-cl', 'DENTAR-CL', 'DENTAR-CL · Hallazgos clínicos odontológicos',
     'DNT-CL', 'clinical_finding',
     'Hallazgos, situaciones y caries morfológicas identificadas por SNOMED CT Argentina.',
     'active', 40)
ON CONFLICT (code) DO UPDATE
   SET family_code  = EXCLUDED.family_code,
       short_name   = EXCLUDED.short_name,
       name         = EXCLUDED.name,
       code_prefix  = EXCLUDED.code_prefix,
       concept_kind = EXCLUDED.concept_kind,
       description  = EXCLUDED.description,
       status       = EXCLUDED.status,
       sort_order   = EXCLUDED.sort_order;

CREATE OR REPLACE FUNCTION dentar_catalog_id(p_code TEXT)
RETURNS INT
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_id INT;
BEGIN
    SELECT id INTO v_id
      FROM dentar_catalog
     WHERE code = lower(btrim(p_code));

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'Catálogo DENTAR desconocido: %', p_code
            USING HINT = 'Códigos válidos: dentar-pr, dentar-dx, dentar-an, dentar-cl.';
    END IF;

    RETURN v_id;
END;
$$;

-- 2. El modelo editorial ya declara anatomy/clinical_finding en dentar_catalog,
--    pero la CHECK de dentar_concept sólo permitía tipos de procedimiento.
DO $$
DECLARE
    v_constraint TEXT;
BEGIN
    FOR v_constraint IN
        SELECT conname
          FROM pg_constraint
         WHERE conrelid = 'dentar_concept'::regclass
           AND contype = 'c'
           AND pg_get_constraintdef(oid) ILIKE '%concept_type%'
    LOOP
        EXECUTE format('ALTER TABLE dentar_concept DROP CONSTRAINT %I', v_constraint);
    END LOOP;

    ALTER TABLE dentar_concept
        ADD CONSTRAINT dentar_concept_concept_type_check
        CHECK (concept_type IN (
            'procedure', 'service', 'evaluation', 'diagnostic_service',
            'rehabilitation', 'anatomy', 'clinical_finding'
        ));
END $$;

-- 3. Categorías propias y reglas de mapeo: SNOMED-CT es obligatorio en AN y CL.
INSERT INTO dentar_category (code, sort_order, catalog_id)
VALUES
    ('CAT-AN', 300, dentar_catalog_id('dentar-an')),
    ('CAT-CL', 310, dentar_catalog_id('dentar-cl'))
ON CONFLICT (code) DO UPDATE
   SET sort_order = EXCLUDED.sort_order,
       catalog_id = EXCLUDED.catalog_id;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', 'Anatomía odontológica (SNOMED CT)',
       'Estructuras anatómicas bucomaxilofaciales auditadas desde SNOMED CT Argentina.'
  FROM dentar_category WHERE code = 'CAT-AN'
ON CONFLICT (category_id, version_number, language)
DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', 'Hallazgos clínicos odontológicos (SNOMED CT)',
       'Hallazgos, situaciones y caries morfológicas auditadas desde SNOMED CT Argentina.'
  FROM dentar_category WHERE code = 'CAT-CL'
ON CONFLICT (category_id, version_number, language)
DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO dentar_catalog_mapping_rule (catalog_id, system_code, is_required, is_allowed)
VALUES
    (dentar_catalog_id('dentar-an'), 'SNOMED-CT', TRUE, TRUE),
    (dentar_catalog_id('dentar-cl'), 'SNOMED-CT', TRUE, TRUE)
ON CONFLICT (catalog_id, system_code) DO UPDATE
   SET is_required = EXCLUDED.is_required,
       is_allowed  = EXCLUDED.is_allowed;

-- 4. Registro en el Origen Catalog Engine.
INSERT INTO os_catalog
    (code, name, organization, country_code, domain_type, family_code,
     product_role, short_name, description, is_active)
VALUES
    ('dentar-an', 'DENTAR-AN · Anatomía odontológica',
     'Origen Salud / Comité Odontológico', 'AR', 'dental', 'dentar',
     'catalog', 'DENTAR-AN', 'Estructuras anatómicas bucomaxilofaciales (SNOMED CT).', TRUE),
    ('dentar-cl', 'DENTAR-CL · Hallazgos clínicos odontológicos',
     'Origen Salud / Comité Odontológico', 'AR', 'dental', 'dentar',
     'catalog', 'DENTAR-CL', 'Hallazgos odontológicos auditados (SNOMED CT).', TRUE)
ON CONFLICT (code) DO UPDATE
   SET name = EXCLUDED.name,
       organization = EXCLUDED.organization,
       country_code = EXCLUDED.country_code,
       domain_type = EXCLUDED.domain_type,
       family_code = EXCLUDED.family_code,
       product_role = EXCLUDED.product_role,
       short_name = EXCLUDED.short_name,
       description = EXCLUDED.description,
       is_active = EXCLUDED.is_active;

INSERT INTO os_catalog_release
    (catalog_id, version_tag, valid_from, official_norm_reference, status)
SELECT c.id, 'snomed-ar-20260820', DATE '2026-08-20', 'SNOMED CT Argentina Snapshot 2026-08-20 (RF2)', 'published'
  FROM os_catalog c
 WHERE c.code IN ('dentar-an', 'dentar-cl')
ON CONFLICT (catalog_id, version_tag) DO UPDATE
   SET valid_from = EXCLUDED.valid_from,
       official_norm_reference = EXCLUDED.official_norm_reference,
       status = EXCLUDED.status;

INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT c.id, 'CAT-AN', 'Anatomía odontológica (SNOMED CT)'
  FROM os_catalog c WHERE c.code = 'dentar-an'
ON CONFLICT (catalog_id, code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT c.id, 'CAT-CL', 'Hallazgos clínicos odontológicos (SNOMED CT)'
  FROM os_catalog c WHERE c.code = 'dentar-cl'
ON CONFLICT (catalog_id, code) DO UPDATE SET name = EXCLUDED.name;

-- 5. Lote auditado. Una fila por concepto; términos preferidos es/en del RF2.
CREATE TEMP TABLE _dentar_an_cl_import (
    codigo VARCHAR(20) NOT NULL,
    catalog_code VARCHAR(20) NOT NULL,
    concept_type VARCHAR(30) NOT NULL,
    categoria VARCHAR(30) NOT NULL,
    termino_es VARCHAR(500) NOT NULL,
    termino_en VARCHAR(500) NOT NULL,
    sctid VARCHAR(30) NOT NULL
) ON COMMIT DROP;

INSERT INTO _dentar_an_cl_import
    (codigo, catalog_code, concept_type, categoria, termino_es, termino_en, sctid)
VALUES
('DNT-AN-000001', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis coronoides de la mandíbula (estructura corporal)', 'Structure of coronoid process of mandible (body structure)', '124002'),
('DNT-AN-000002', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tejido celular subcutáneo del filtro (estructura corporal)', 'Subcutaneous tissue structure of philtrum (body structure)', '608002'),
('DNT-AN-000003', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del cíngulo (estructura corporal)', 'Structure of cingulum dentis (body structure)', '1997009'),
('DNT-AN-000004', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer premolar mandibular permanente izquierdo (estructura corporal)', 'Structure of permanent mandibular left first premolar tooth (body structure)', '2400006'),
('DNT-AN-000005', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de orificio apical de diente (estructura corporal)', 'Structure of apical foramen of tooth (body structure)', '2718005'),
('DNT-AN-000006', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de corona clínica de diente (estructura corporal)', 'Structure of clinical crown of tooth (body structure)', '3100007'),
('DNT-AN-000007', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del rafe del velo del paladar (estructura corporal)', 'Structure of raphe of soft palate (body structure)', '3178004'),
('DNT-AN-000008', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto de raíz dental (estructura corporal)', 'Structure of root canal of tooth (body structure)', '3262009'),
('DNT-AN-000009', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del orificio bucal (estructura corporal)', 'Structure of rima oris (body structure)', '3382006'),
('DNT-AN-000010', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del maxilar superior (estructura corporal)', 'Upper jaw region structure (body structure)', '4335006'),
('DNT-AN-000011', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tejido celular subcutáneo de la barbilla (estructura corporal)', 'Subcutaneous tissue structure of chin (body structure)', '5520004'),
('DNT-AN-000012', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del triángulo submandibular (estructura corporal)', 'Submandibular triangle structure (body structure)', '5713008'),
('DNT-AN-000013', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del canino deciduo inferior derecho (estructura corporal)', 'Structure of deciduous mandibular right canine tooth (body structure)', '6062009'),
('DNT-AN-000014', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cápsula de articulación temporomandibular (estructura corporal)', 'Structure of capsule of temporomandibular joint (body structure)', '6074008'),
('DNT-AN-000015', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cara lateral de glándula sublingual (estructura corporal)', 'Structure of lateral surface of sublingual gland (body structure)', '7471001'),
('DNT-AN-000016', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de frenillo de labio (estructura corporal)', 'Structure of frenulum labii (body structure)', '7652006'),
('DNT-AN-000017', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto palatino (estructura corporal)', 'Structure of palatine duct (body structure)', '7742001'),
('DNT-AN-000018', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto mandibular (estructura corporal)', 'Structure of mandibular canal (body structure)', '7854005'),
('DNT-AN-000019', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cara mesial de diente (estructura corporal)', 'Structure of mesial surface of tooth (body structure)', '8483002'),
('DNT-AN-000020', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo premolar mandibular derecho permanente (estructura corporal)', 'Structure of permanent mandibular right second premolar tooth (body structure)', '8873007'),
('DNT-AN-000021', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de los pliegues transversales del paladar (estructura corporal)', 'Structure of transverse folds of palate (body structure)', '9127001'),
('DNT-AN-000022', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la vena labial (estructura corporal)', 'Structure of labial vein of face (body structure)', '9305001'),
('DNT-AN-000023', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento lateral de articulación temporomandibular (estructura corporal)', 'Structure of lateral ligament of temporomandibular joint (body structure)', '9332006'),
('DNT-AN-000024', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes permanentes (estructura corporal)', 'All permanent teeth (body structure)', '9379006'),
('DNT-AN-000025', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de depresión coronal de diente (estructura corporal)', 'Structure of coronal depression of tooth (body structure)', '9502002'),
('DNT-AN-000026', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del cuerpo de la mandíbula (estructura corporal)', 'Structure of body of mandible (body structure)', '11048003'),
('DNT-AN-000027', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la pulpa coronal de diente (estructura corporal)', 'Structure of coronal pulp of tooth (body structure)', '11326003'),
('DNT-AN-000028', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de labio superior (estructura corporal)', 'Upper lip structure (body structure)', '11681001'),
('DNT-AN-000029', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del ángulo de la mandíbula (estructura corporal)', 'Structure of angle of mandible (body structure)', '11843008'),
('DNT-AN-000030', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco lateral mandibular izquierdo (estructura corporal)', 'Structure of deciduous mandibular left lateral incisor tooth (body structure)', '14770005'),
('DNT-AN-000031', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la piel de labio superior (estructura corporal)', 'Skin structure of upper lip (body structure)', '16251004'),
('DNT-AN-000032', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de vértice de raíz de diente (estructura corporal)', 'Structure of apex of root of tooth (body structure)', '16626007'),
('DNT-AN-000033', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer molar caduco maxilar derecho (estructura corporal)', 'Structure of deciduous maxillary right first molar tooth (body structure)', '17505006'),
('DNT-AN-000034', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mucosa de labio superior (estructura corporal)', 'Structure of mucous membrane of upper lip (body structure)', '18444004'),
('DNT-AN-000035', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de disco articular de articulación temporomandibular (estructura corporal)', 'Structure of articular disc of temporomandibular joint (body structure)', '18948006'),
('DNT-AN-000036', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de unión cutaneomucosa de labio superior (estructura corporal)', 'Structure of mucocutaneous junction of upper lip (body structure)', '20043004'),
('DNT-AN-000037', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del rafe del paladar duro (estructura corporal)', 'Structure of raphe of hard palate (body structure)', '20546004'),
('DNT-AN-000038', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tubérculo dental (estructura corporal)', 'Structure of dental tubercle (body structure)', '21332009'),
('DNT-AN-000039', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cara lateral de la raíz del diente (estructura corporal)', 'Structure of lateral surface of root of tooth (body structure)', '21475004'),
('DNT-AN-000040', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente deciduo (estructura corporal)', 'Structure of deciduous tooth (body structure)', '21644001'),
('DNT-AN-000041', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco lateral mandibular derecho (estructura corporal)', 'Structure of deciduous mandibular right lateral incisor tooth (body structure)', '22445006'),
('DNT-AN-000042', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del ángulo de la boca (estructura corporal)', 'Structure of angle of mouth (body structure)', '23161009'),
('DNT-AN-000043', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis cigomática del maxilar (estructura corporal)', 'Structure of zygomatic process of maxilla (body structure)', '23224007'),
('DNT-AN-000044', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo premolar maxilar izquierdo permanente (estructura corporal)', 'Structure of permanent maxillary left second premolar tooth (body structure)', '23226009'),
('DNT-AN-000045', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la piel de la barbilla (estructura corporal)', 'Skin structure of chin (body structure)', '23747009'),
('DNT-AN-000046', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de rama de la mandíbula (estructura corporal)', 'Structure of ramus of mandible (body structure)', '23938008'),
('DNT-AN-000047', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de lobulillo de la glándula salival (estructura corporal)', 'Structure of salivary gland lobule (body structure)', '24106005'),
('DNT-AN-000048', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo premolar mandibular izquierdo permanente (estructura corporal)', 'Structure of permanent mandibular left second premolar tooth (body structure)', '24573005'),
('DNT-AN-000049', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la úvula del paladar (estructura corporal)', 'Uvula palatina structure (body structure)', '26140008'),
('DNT-AN-000050', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de pulpa de diente (estructura corporal)', 'Structure of pulp of tooth (body structure)', '26671000'),
('DNT-AN-000051', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cara interna de la glándula sublingual (estructura corporal)', 'Structure of medial surface of sublingual gland (body structure)', '27039001'),
('DNT-AN-000052', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula de la membrana mucosa de labio inferior (estructura corporal)', 'Structure of gland of mucous membrane of lower lip (body structure)', '27114007'),
('DNT-AN-000053', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del margen infraorbitario del maxilar (estructura corporal)', 'Structure of infraorbital margin of maxilla (body structure)', '27549009'),
('DNT-AN-000054', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo molar caduco maxilar derecho (estructura corporal)', 'Structure of deciduous maxillary right second molar tooth (body structure)', '27855007'),
('DNT-AN-000055', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de vértice de cúspide dental (estructura corporal)', 'Structure of apex of cusp of tooth (body structure)', '28255003'),
('DNT-AN-000056', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de lámina horizontal de hueso palatino (estructura corporal)', 'Structure of lamina horizontalis of palatine bone (body structure)', '28346004'),
('DNT-AN-000057', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tejido celular subcutáneo del borde bermellón (estructura corporal)', 'Subcutaneous tissue structure of vermilion border (body structure)', '30152002'),
('DNT-AN-000058', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de lóbulo de glándula parótida (estructura corporal)', 'Structure of lobe of parotid gland (body structure)', '30181001'),
('DNT-AN-000059', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula mucosa salival (estructura corporal)', 'Structure of salivary mucous gland (body structure)', '30210003'),
('DNT-AN-000060', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del mentón (estructura corporal)', 'Chin structure (body structure)', '30291003'),
('DNT-AN-000061', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente molar deciduo (estructura corporal)', 'Structure of deciduous molar tooth (body structure)', '30314009'),
('DNT-AN-000062', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del músculo de la úvula (estructura corporal)', 'Structure of uvular muscle (body structure)', '30501007'),
('DNT-AN-000063', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del canino deciduo superior derecho (estructura corporal)', 'Structure of deciduous maxillary right canine tooth (body structure)', '30618001'),
('DNT-AN-000064', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula de la membrana mucosa de labio superior (estructura corporal)', 'Structure of gland of mucous membrane of upper lip (body structure)', '31660005'),
('DNT-AN-000065', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de labio inferior (estructura corporal)', 'Lower lip structure (body structure)', '32032005'),
('DNT-AN-000066', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del filtro (estructura corporal)', 'Philtrum structure (body structure)', '32087006'),
('DNT-AN-000067', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz clínica de diente (estructura corporal)', 'Structure of clinical root of tooth (body structure)', '32820005'),
('DNT-AN-000068', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cara superior del velo del paladar (estructura corporal)', 'Structure of superior surface of soft palate (body structure)', '33360007'),
('DNT-AN-000069', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de frenillo de labio inferior (estructura corporal)', 'Structure of frenulum labii inferioris (body structure)', '34148009'),
('DNT-AN-000070', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto de glándula lingual anterior (estructura corporal)', 'Structure of duct of anterior lingual gland (body structure)', '34181005'),
('DNT-AN-000071', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel de triángulo submandibular (estructura corporal)', 'Skin structure of submandibular triangle (body structure)', '34799006'),
('DNT-AN-000072', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del vestíbulo de la boca (estructura corporal)', 'Structure of vestibule of mouth (body structure)', '34810001'),
('DNT-AN-000073', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cutícula dental (estructura corporal)', 'Structure of dental cuticle (body structure)', '35945001'),
('DNT-AN-000074', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la papila incisiva de la boca (estructura corporal)', 'Structure of papilla incisiva of mouth (body structure)', '36451009'),
('DNT-AN-000075', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo premolar maxilar derecho (estructura corporal)', 'Structure of permanent maxillary right second premolar tooth (body structure)', '36492000'),
('DNT-AN-000076', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del arco alveolar de la mandíbula (estructura corporal)', 'Structure of alveolar arch of mandible (body structure)', '37728002'),
('DNT-AN-000077', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente permanente (estructura corporal)', 'Structure of permanent tooth (body structure)', '37977002'),
('DNT-AN-000078', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente (estructura corporal)', 'Tooth structure (body structure)', '38199008'),
('DNT-AN-000079', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de proceso alveolar de mandíbula (estructura corporal)', 'Structure of alveolar process of mandible (body structure)', '38754007'),
('DNT-AN-000080', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer molar caduco mandibular izquierdo (estructura corporal)', 'Structure of deciduous mandibular left first molar tooth (body structure)', '38896004'),
('DNT-AN-000081', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tercer molar mandibular derecho permanente (estructura corporal)', 'Structure of permanent mandibular right third molar tooth (body structure)', '38994002'),
('DNT-AN-000082', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes deciduos (estructura corporal)', 'All deciduous teeth (body structure)', '39151000'),
('DNT-AN-000083', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tubérculo labial (estructura corporal)', 'Structure of labial tubercle (body structure)', '39604001'),
('DNT-AN-000084', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la tuberosidad maxilar (estructura corporal)', 'Structure of maxillary tuberosity (body structure)', '41151001'),
('DNT-AN-000085', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del canino deciduo inferior izquierdo (estructura corporal)', 'Structure of deciduous mandibular left canine tooth (body structure)', '43281008'),
('DNT-AN-000086', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco lateral maxilar izquierdo (estructura corporal)', 'Structure of deciduous maxillary left lateral incisor tooth (body structure)', '43622005'),
('DNT-AN-000087', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula parótida izquierda (estructura corporal)', 'Structure of left parotid gland (body structure)', '44178003'),
('DNT-AN-000088', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la espina del mentón (estructura corporal)', 'Structure of spina mentalis (body structure)', '44736000'),
('DNT-AN-000089', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la porción superficial de glándula parótida (estructura corporal)', 'Structure of superficial portion of parotid gland (body structure)', '44989006'),
('DNT-AN-000090', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente canino (estructura corporal)', 'Structure of canine tooth (body structure)', '45208001'),
('DNT-AN-000091', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer molar caduco maxilar izquierdo (estructura corporal)', 'Structure of deciduous maxillary left first molar tooth (body structure)', '45234009'),
('DNT-AN-000092', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula parótida (estructura corporal)', 'Parotid gland structure (body structure)', '45289007'),
('DNT-AN-000093', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de frenillo de labio superior (estructura corporal)', 'Structure of frenulum labii superioris (body structure)', '45825006'),
('DNT-AN-000094', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de unión mucocutánea de labio inferior (estructura corporal)', 'Structure of mucocutaneous junction of lower lip (body structure)', '46005001'),
('DNT-AN-000095', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mucosa de labio inferior (estructura corporal)', 'Structure of mucous membrane of lower lip (body structure)', '46353006'),
('DNT-AN-000096', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ácino de glándula parótida (estructura corporal)', 'Structure of acinus of parotid gland (body structure)', '46926004'),
('DNT-AN-000097', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del cuerpo del maxilar (estructura corporal)', 'Structure of body of maxilla (body structure)', '47480008'),
('DNT-AN-000098', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula submaxilar izquierda (estructura corporal)', 'Structure of left submandibular gland (body structure)', '48065005'),
('DNT-AN-000099', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del maxilar inferior (estructura corporal)', 'Lower jaw region structure (body structure)', '48077000'),
('DNT-AN-000100', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de espacios interglobulares del diente (estructura corporal)', 'Structure of interglobular spaces of tooth (body structure)', '48360008'),
('DNT-AN-000101', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de pulpa radicular de diente (estructura corporal)', 'Structure of radicular pulp of tooth (body structure)', '48363005'),
('DNT-AN-000102', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de labio (estructura corporal)', 'Lip structure (body structure)', '48477009'),
('DNT-AN-000103', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del cuello de la mandíbula (estructura corporal)', 'Structure of neck of mandible (body structure)', '49200000'),
('DNT-AN-000104', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo molar caduco mandibular izquierdo (estructura corporal)', 'Structure of deciduous mandibular left second molar tooth (body structure)', '49330006'),
('DNT-AN-000105', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de paladar blando (estructura corporal)', 'Soft palate structure (body structure)', '49460000'),
('DNT-AN-000106', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento esfenomandibular de articulación temporomandibular (estructura corporal)', 'Structure of sphenomandibular ligament of temporomandibular joint (body structure)', '50478008'),
('DNT-AN-000107', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tejido intersticial de la glándula parótida (estructura corporal)', 'Structure of interstitial tissue of parotid gland (body structure)', '51091007'),
('DNT-AN-000108', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel de pliegue labiomentoniano (estructura corporal)', 'Skin structure of labiomental crease (body structure)', '51215006'),
('DNT-AN-000109', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cabeza de la mandíbula (estructura corporal)', 'Structure of head of mandible (body structure)', '51354009'),
('DNT-AN-000110', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco central maxilar izquierdo (estructura corporal)', 'Structure of deciduous maxillary left central incisor tooth (body structure)', '51678005'),
('DNT-AN-000111', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo molar caduco maxilar izquierdo (estructura corporal)', 'Structure of deciduous maxillary left second molar tooth (body structure)', '51943008'),
('DNT-AN-000112', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido celular subcutáneo de labio superior (estructura corporal)', 'Subcutaneous tissue structure of upper lip (body structure)', '52780009'),
('DNT-AN-000113', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del arco alveolar del maxilar (estructura corporal)', 'Structure of alveolar arch of maxilla (body structure)', '52982007'),
('DNT-AN-000114', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de esbozo de diente (estructura corporal)', 'Structure of tooth bud (body structure)', '53301001'),
('DNT-AN-000115', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de articulación temporomandibular (estructura corporal)', 'Temporomandibular joint structure (body structure)', '53620006'),
('DNT-AN-000116', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento estilomandibular de articulación temporomandibular (estructura corporal)', 'Structure of stylomandibular ligament of temporomandibular joint (body structure)', '53674000'),
('DNT-AN-000117', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de aparato salival submaxilar (estructura corporal)', 'Structure of submandibular salivary apparatus (body structure)', '54019009'),
('DNT-AN-000118', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido intersticial de la glándula salival (estructura corporal)', 'Structure of salivary gland interstitial tissue (body structure)', '54829003'),
('DNT-AN-000119', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde incisal de diente (estructura corporal)', 'Structure of incisal border of tooth (body structure)', '56671003'),
('DNT-AN-000120', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer premolar maxilar derecho permanente (estructura corporal)', 'Structure of permanent maxillary right first premolar tooth (body structure)', '57826002'),
('DNT-AN-000121', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de los dientes inferiores (estructura corporal)', 'Structure of mandibular teeth (body structure)', '58280001'),
('DNT-AN-000122', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la unión cemento - esmalte (estructura corporal)', 'Structure of cementoenamel junction (body structure)', '58592000'),
('DNT-AN-000123', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer molar caduco mandibular derecho (estructura corporal)', 'Structure of deciduous mandibular right first molar tooth (body structure)', '58646007'),
('DNT-AN-000124', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mucosa labial (estructura corporal)', 'Structure of mucous membrane of lip (body structure)', '59641005'),
('DNT-AN-000125', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercer molar permanente (estructura corporal)', 'Structure of permanent third molar tooth (body structure)', '59966007'),
('DNT-AN-000126', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo molar caduco mandibular derecho (estructura corporal)', 'Structure of deciduous mandibular right second molar tooth (body structure)', '61868007'),
('DNT-AN-000127', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer premolar maxilar izquierdo permanente (estructura corporal)', 'Structure of permanent maxillary left first premolar tooth (body structure)', '61897005'),
('DNT-AN-000128', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de unión amelodentinaria (estructura corporal)', 'Structure of dentinoenamel junction (body structure)', '61990008'),
('DNT-AN-000129', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis frontal del maxilar (estructura corporal)', 'Structure of frontal process of maxilla (body structure)', '62380005'),
('DNT-AN-000130', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cara vestibular de diente (estructura corporal)', 'Structure of vestibular surface of tooth (body structure)', '62579006'),
('DNT-AN-000131', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis palatina del maxilar (estructura corporal)', 'Structure of palatine process of maxilla (body structure)', '63231007'),
('DNT-AN-000132', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula sublingual izquierda (estructura corporal)', 'Structure of left sublingual gland (body structure)', '64303008'),
('DNT-AN-000133', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido celular subcutáneo de triángulo submandibular (estructura corporal)', 'Subcutaneous tissue structure of submandibular triangle (body structure)', '64577007'),
('DNT-AN-000134', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula serosa salival (estructura corporal)', 'Structure of salivary serous gland (body structure)', '65067005'),
('DNT-AN-000135', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco lateral maxilar derecho (estructura corporal)', 'Structure of deciduous maxillary right lateral incisor tooth (body structure)', '65624003'),
('DNT-AN-000136', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula lingual anterior (estructura corporal)', 'Anterior lingual gland structure (body structure)', '65750006'),
('DNT-AN-000137', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del lobulillo de la glándula parótida (estructura corporal)', 'Structure of lobule of parotid gland (body structure)', '66268002'),
('DNT-AN-000138', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula labial (estructura corporal)', 'Structure of labial gland (body structure)', '66436008'),
('DNT-AN-000139', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la piel de labio inferior (estructura corporal)', 'Skin structure of lower lip (body structure)', '66934001'),
('DNT-AN-000140', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis condílea de la mandíbula (estructura corporal)', 'Structure of condyloid process of mandible (body structure)', '67183008'),
('DNT-AN-000141', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco central mandibular derecho (estructura corporal)', 'Structure of deciduous mandibular right central incisor tooth (body structure)', '67834006'),
('DNT-AN-000142', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tercer molar superior derecho (estructura corporal)', 'Structure of permanent maxillary right third molar tooth (body structure)', '68085002'),
('DNT-AN-000143', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de los dientes superiores (estructura corporal)', 'Structure of maxillary teeth (body structure)', '68137000'),
('DNT-AN-000144', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido celular subcutáneo de labio (estructura corporal)', 'Subcutaneous tissue structure of lip (body structure)', '68889007'),
('DNT-AN-000145', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del agujero de la mandíbula (estructura corporal)', 'Structure of mandibular foramen (body structure)', '69000004'),
('DNT-AN-000146', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta triangular de diente (estructura corporal)', 'Structure of crista triangularis of tooth (body structure)', '69786002'),
('DNT-AN-000147', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura ósea de maxilar superior (estructura corporal)', 'Bone structure of maxilla (body structure)', '70925003'),
('DNT-AN-000148', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cápsula de la glándula parótida (estructura corporal)', 'Structure of parotid gland capsule (body structure)', '71097005'),
('DNT-AN-000149', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cavidad oral propiamente dicha (estructura corporal)', 'Structure of oral cavity proper (body structure)', '71617008'),
('DNT-AN-000150', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cara lingual de diente (estructura corporal)', 'Structure of lingual surface of tooth (body structure)', '72203008'),
('DNT-AN-000151', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cavidad dentaria (estructura corporal)', 'Structure of cavity of tooth (body structure)', '72236009'),
('DNT-AN-000152', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de unión dentinocementaria (estructura corporal)', 'Structure of dentinocemental junction (body structure)', '72257001'),
('DNT-AN-000153', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de túbulo de dentina (estructura corporal)', 'Structure of dentinal tubule (body structure)', '72725001'),
('DNT-AN-000154', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del canino deciduo superior izquierdo (estructura corporal)', 'Structure of deciduous maxillary left canine tooth (body structure)', '73937000'),
('DNT-AN-000155', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula de la membrana mucosa de la lengua (estructura corporal)', 'Structure of gland of mucous membrane of tongue (body structure)', '74163002'),
('DNT-AN-000156', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cavidad oral (estructura corporal)', 'Oral cavity structure (body structure)', '74262004'),
('DNT-AN-000157', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tercer molar mandibular izquierdo permanente (estructura corporal)', 'Structure of permanent mandibular left third molar tooth (body structure)', '74344005'),
('DNT-AN-000158', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la porción profunda de glándula parótida (estructura corporal)', 'Structure of deep portion of parotid gland (body structure)', '75606001'),
('DNT-AN-000159', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de corona de diente (estructura corporal)', 'Structure of crown of tooth (body structure)', '75628001'),
('DNT-AN-000160', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente premolar (estructura corporal)', 'Structure of premolar tooth (body structure)', '76424003'),
('DNT-AN-000161', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cara nasofaríngea del paladar blando (estructura corporal)', 'Structure of nasopharyngeal surface of soft palate (body structure)', '76786004'),
('DNT-AN-000162', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de lóbulo de glándula salival (estructura corporal)', 'Salivary gland lobe structure (body structure)', '76837008'),
('DNT-AN-000163', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente molar (estructura corporal)', 'Structure of molar tooth (body structure)', '76928009'),
('DNT-AN-000164', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del esmalte dental (estructura corporal)', 'Enamel structure (body structure)', '76993005'),
('DNT-AN-000165', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tubérculo oclusal del diente molar (estructura corporal)', 'Structure of occlusal tubercle of molar tooth (body structure)', '78063009'),
('DNT-AN-000166', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo (estructura corporal)', 'Structure of incisor tooth (body structure)', '78509001'),
('DNT-AN-000167', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido celular subcutáneo de labio inferior (estructura corporal)', 'Subcutaneous tissue structure of lower lip (body structure)', '79275001'),
('DNT-AN-000168', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer premolar mandibular permanente derecho (estructura corporal)', 'Structure of permanent mandibular right first premolar tooth (body structure)', '80140008'),
('DNT-AN-000169', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del cemento (estructura corporal)', 'Cementum structure (body structure)', '80541002'),
('DNT-AN-000170', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula sublingual derecha (estructura corporal)', 'Structure of right sublingual gland (body structure)', '81831003'),
('DNT-AN-000171', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de comisura de los labios (estructura corporal)', 'Structure of commissure of lips (body structure)', '83299001'),
('DNT-AN-000172', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de bastoncillo del esmalte (estructura corporal)', 'Structure of enamel rod (body structure)', '83303006'),
('DNT-AN-000173', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cara oclusal de diente (estructura corporal)', 'Structure of occlusal surface of tooth (body structure)', '83473006'),
('DNT-AN-000174', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la piel del filtro (estructura corporal)', 'Skin structure of philtrum (body structure)', '84365009'),
('DNT-AN-000175', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la dentina (estructura corporal)', 'Dentin structure (body structure)', '84540008'),
('DNT-AN-000176', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz de diente (estructura corporal)', 'Tooth root structure (body structure)', '85077000'),
('DNT-AN-000177', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de unión cutaneomucosa de labio (estructura corporal)', 'Structure of mucocutaneous junction of lip (body structure)', '85193007'),
('DNT-AN-000178', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la superficie de contacto del diente (estructura corporal)', 'Structure of contact surface of tooth (body structure)', '85464000'),
('DNT-AN-000179', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula parótida derecha (estructura corporal)', 'Structure of right parotid gland (body structure)', '85706002'),
('DNT-AN-000180', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto submaxilar (estructura corporal)', 'Structure of submandibular duct (body structure)', '86391007'),
('DNT-AN-000181', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cápsula de glándula salival (estructura corporal)', 'Structure of salivary gland capsule (body structure)', '86442000'),
('DNT-AN-000182', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel del borde bermellón (estructura corporal)', 'Skin structure of vermilion border (body structure)', '87320006'),
('DNT-AN-000183', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula salival menor (estructura corporal)', 'Minor salivary gland structure (body structure)', '87626005'),
('DNT-AN-000184', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del tercer molar permanente maxilar izquierdo (estructura corporal)', 'Structure of permanent maxillary left third molar tooth (body structure)', '87704003'),
('DNT-AN-000185', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la piel de labio (estructura corporal)', 'Skin structure of lip (body structure)', '88089004'),
('DNT-AN-000186', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la glándula sublingual (estructura corporal)', 'Sublingual gland structure (body structure)', '88481005'),
('DNT-AN-000187', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco central maxilar derecho (estructura corporal)', 'Structure of deciduous maxillary right central incisor tooth (body structure)', '88824007'),
('DNT-AN-000188', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del incisivo caduco central mandibular izquierdo (estructura corporal)', 'Structure of deciduous mandibular left central incisor tooth (body structure)', '89552004'),
('DNT-AN-000189', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cúspide dentaria (estructura corporal)', 'Structure of cusp of tooth (body structure)', '89690004'),
('DNT-AN-000190', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta transversal de diente (estructura corporal)', 'Structure of crista transversalis of tooth (body structure)', '89992009'),
('DNT-AN-000191', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del paladar duro (estructura corporal)', 'Hard palate structure (body structure)', '90228003'),
('DNT-AN-000192', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente en desarrollo (estructura corporal)', 'Structure of developing tooth (body structure)', '90555008'),
('DNT-AN-000193', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distal de diente (estructura corporal)', 'Structure of distal surface of tooth (body structure)', '90933009'),
('DNT-AN-000194', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la pulpa del canal auxiliar del diente (estructura corporal)', 'Structure of pulp of auxiliary canal of tooth (body structure)', '90956000'),
('DNT-AN-000195', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula submaxilar derecha (estructura corporal)', 'Structure of right submandibular gland (body structure)', '91590006'),
('DNT-AN-000196', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura ósea de maxilar inferior (estructura corporal)', 'Bone structure of mandible (body structure)', '91609006'),
('DNT-AN-000197', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de vestíbulo maxilar (estructura corporal)', 'Structure of maxillary vestibule (body structure)', '110570003'),
('DNT-AN-000198', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de vestíbulo mandibular (estructura corporal)', 'Structure of mandibular vestibule (body structure)', '110571004'),
('DNT-AN-000199', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cúspide dentaria mesiobucal (estructura corporal)', 'Structure of mesiobuccal cusp (body structure)', '110578005'),
('DNT-AN-000200', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cúspide dentaria mesiolingual (estructura corporal)', 'Structure of mesiolingual cusp (body structure)', '110579002'),
('DNT-AN-000201', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cúspide dentaria lingual (estructura corporal)', 'Structure of lingual cusp (body structure)', '110580004'),
('DNT-AN-000202', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cúspide distobucal (estructura corporal)', 'Structure of distobuccal cusp (body structure)', '110581000'),
('DNT-AN-000203', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cúspide distolingual (estructura corporal)', 'Structure of distolingual cusp (body structure)', '110582007'),
('DNT-AN-000204', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cúspide bucal (estructura corporal)', 'Structure of buccal cusp (body structure)', '110583002'),
('DNT-AN-000205', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cúspide de Carabelli (estructura corporal)', 'Structure of cusp of Carabelli (body structure)', '110584008'),
('DNT-AN-000206', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de división de las raíces dentales (estructura corporal)', 'Structure of tooth furcation (body structure)', '110585009'),
('DNT-AN-000207', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de bifurcación de las raíces dentales (estructura corporal)', 'Structure of bifurcation of tooth (body structure)', '110586005'),
('DNT-AN-000208', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco de desarrollo dental (estructura corporal)', 'Structure of developmental groove of tooth (body structure)', '110588006'),
('DNT-AN-000209', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco bucal de diente (estructura corporal)', 'Structure of buccal groove of tooth (body structure)', '110589003'),
('DNT-AN-000210', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco distobucal de diente (estructura corporal)', 'Structure of distobuccal groove of tooth (body structure)', '110590007'),
('DNT-AN-000211', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco mesiobucal de diente (estructura corporal)', 'Structure of mesiobuccal groove of tooth (body structure)', '110591006'),
('DNT-AN-000212', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco central de diente (estructura corporal)', 'Structure of central groove of tooth (body structure)', '110592004'),
('DNT-AN-000213', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco lingual de diente (estructura corporal)', 'Structure of lingual groove of tooth (body structure)', '110593009'),
('DNT-AN-000214', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco distolingual de diente (estructura corporal)', 'Structure of distolingual groove of tooth (body structure)', '110594003'),
('DNT-AN-000215', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco mesiolingual de diente (estructura corporal)', 'Structure of mesiolingual groove of tooth (body structure)', '110595002'),
('DNT-AN-000216', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco suplementario de diente (estructura corporal)', 'Structure of supplemental groove of tooth (body structure)', '110596001'),
('DNT-AN-000217', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de folículo de diente (estructura corporal)', 'Structure of follicle of tooth (body structure)', '110975002'),
('DNT-AN-000218', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la sínfisis del maxilar inferior (estructura corporal)', 'Symphysis structure of mandible (body structure)', '113236004'),
('DNT-AN-000219', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de glándula salival (estructura corporal)', 'Salivary gland part (body structure)', '119215009'),
('DNT-AN-000220', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival mayor (estructura corporal)', 'Major salivary gland structure (body structure)', '119282003'),
('DNT-AN-000221', 'dentar-an', 'anatomy', 'CAT-AN', 'parte del maxilar superior (estructura corporal)', 'Maxilla part (body structure)', '119532009'),
('DNT-AN-000222', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de la mandíbula (estructura corporal)', 'Mandible part (body structure)', '119533004'),
('DNT-AN-000223', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de porción orbitaria de maxilar superior (estructura corporal)', 'Structure of orbital portion of maxilla (body structure)', '123868004'),
('DNT-AN-000224', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de pared interna de seno maxilar (estructura corporal)', 'Structure of medial wall of maxillary antrum (body structure)', '123871007'),
('DNT-AN-000225', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento de articulación temporomandibular (estructura corporal)', 'Structure of ligament of temporomandibular joint (body structure)', '127861009'),
('DNT-AN-000226', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de bermellón y piel de labio (estructura corporal)', 'Structure of border of vermilion and skin of lip (body structure)', '128249007'),
('DNT-AN-000227', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de bermellón y piel de labio superior (estructura corporal)', 'Structure of border of vermilion and skin of upper lip (body structure)', '128250007'),
('DNT-AN-000228', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de bermellón y piel de labio inferior (estructura corporal)', 'Structure of border of vermilion and skin of lower lip (body structure)', '128251006'),
('DNT-AN-000229', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido duro de diente (estructura corporal)', 'Structure of hard tissue of tooth (body structure)', '128456003'),
('DNT-AN-000230', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel del costado del mentón (estructura corporal)', 'Skin structure of side of chin (body structure)', '244099001'),
('DNT-AN-000231', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel de punta de mentón (estructura corporal)', 'Structure of skin of point of chin (body structure)', '244100009'),
('DNT-AN-000232', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel debajo del mentón (estructura corporal)', 'Skin structure under chin (body structure)', '244101008'),
('DNT-AN-000233', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento extracapsular de articulación temporomandibular (estructura corporal)', 'Structure of extracapsular ligament of temporomandibular joint (body structure)', '244581002'),
('DNT-AN-000234', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de toro maxilar (estructura corporal)', 'Structure of maxillary torus (body structure)', '244683008'),
('DNT-AN-000235', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de agujero mentoniano (estructura corporal)', 'Structure of mental foramen (body structure)', '244686000'),
('DNT-AN-000236', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde del cuerpo mandibular (estructura corporal)', 'Structure of border of body of mandible (body structure)', '244688004'),
('DNT-AN-000237', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde inferior de la mandíbula (estructura corporal)', 'Structure of lower border of mandible (body structure)', '244689007'),
('DNT-AN-000238', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de la rama mandibular (estructura corporal)', 'Structure of border of ramus of mandible (body structure)', '244690003'),
('DNT-AN-000239', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dentición (estructura corporal)', 'Structure of dentition (body structure)', '245543004'),
('DNT-AN-000240', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dentición mixta (estructura corporal)', 'Structure of mixed dentition (body structure)', '245545006'),
('DNT-AN-000241', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes superiores (estructura corporal)', 'All maxillary teeth (body structure)', '245546007'),
('DNT-AN-000242', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes inferiores (estructura corporal)', 'All mandibular teeth (body structure)', '245547003'),
('DNT-AN-000243', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie de diente (estructura corporal)', 'Structure of tooth surface (body structure)', '245643006'),
('DNT-AN-000244', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mamelón (estructura corporal)', 'Structure of mamelon (body structure)', '245646003'),
('DNT-AN-000245', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de fosita bucal (estructura corporal)', 'Structure of buccal pit (body structure)', '245648002'),
('DNT-AN-000246', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie proximal del diente (estructura corporal)', 'Structure of proximal surface of tooth (body structure)', '245651009'),
('DNT-AN-000247', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestibuloclusal de diente (estructura corporal)', 'Structure of buccal occlusal tooth surfaces (body structure)', '245655000'),
('DNT-AN-000248', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie palatoclusal de diente (estructura corporal)', 'Structure of palatal occlusal tooth surfaces (body structure)', '245656004'),
('DNT-AN-000249', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie linguoclusal de diente (estructura corporal)', 'Structure of lingual occlusal tooth surfaces (body structure)', '245657008'),
('DNT-AN-000250', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesioclusal de diente (estructura corporal)', 'Structure of mesial occlusal tooth surfaces (body structure)', '245658003'),
('DNT-AN-000251', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distoclusal de diente (estructura corporal)', 'Structure of distal occlusal tooth surfaces (body structure)', '245659006'),
('DNT-AN-000252', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesioincisal de diente (estructura corporal)', 'Structure of mesial incisal tooth surfaces (body structure)', '245660001'),
('DNT-AN-000253', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distoincisal de diente (estructura corporal)', 'Structure of distal incisal tooth surfaces (body structure)', '245661002'),
('DNT-AN-000254', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesiovestibular de diente (estructura corporal)', 'Structure of mesial buccal tooth surfaces (body structure)', '245662009'),
('DNT-AN-000255', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesiopalatina de diente (estructura corporal)', 'Structure of mesial palatal tooth surfaces (body structure)', '245663004'),
('DNT-AN-000256', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesiolingual de diente (estructura corporal)', 'Structure of mesial lingual tooth surfaces (body structure)', '245664005'),
('DNT-AN-000257', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distovestibular de diente (estructura corporal)', 'Structure of distal buccal tooth surfaces (body structure)', '245665006'),
('DNT-AN-000258', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distopalatina de diente (estructura corporal)', 'Structure of distal palatal tooth surfaces (body structure)', '245666007'),
('DNT-AN-000259', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distolingual de diente (estructura corporal)', 'Structure of distal lingual tooth surfaces (body structure)', '245668008'),
('DNT-AN-000260', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-distal de diente (estructura corporal)', 'Structure of mesial occlusal distal tooth surfaces (body structure)', '245670004'),
('DNT-AN-000261', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-palatina de diente (estructura corporal)', 'Structure of mesial occlusal palatal tooth surfaces (body structure)', '245671000'),
('DNT-AN-000262', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-lingual de diente (estructura corporal)', 'Structure of mesial occlusal lingual tooth surfaces (body structure)', '245672007'),
('DNT-AN-000263', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-distal de diente (estructura corporal)', 'Structure of mesial incisal distal tooth surfaces (body structure)', '245673002'),
('DNT-AN-000264', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-vestibular de diente (estructura corporal)', 'Structure of mesial occlusal buccal tooth surfaces (body structure)', '245674008'),
('DNT-AN-000265', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-ocluso-palatina de diente (estructura corporal)', 'Structure of distal occlusal palatal tooth surfaces (body structure)', '245675009'),
('DNT-AN-000266', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-ocluso-lingual de diente (estructura corporal)', 'Structure of distal occlusal lingual tooth surfaces (body structure)', '245676005'),
('DNT-AN-000267', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-ocluso-vestibular de diente (estructura corporal)', 'Structure of distal occlusal buccal tooth surfaces (body structure)', '245677001'),
('DNT-AN-000268', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-vestíbulo-distal de diente (estructura corporal)', 'Structure of mesial buccal distal tooth surfaces (body structure)', '245678006'),
('DNT-AN-000269', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-palato-distal de diente (estructura corporal)', 'Structure of mesial palatal distal tooth surfaces (body structure)', '245679003'),
('DNT-AN-000270', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-linguo-distal de diente (estructura corporal)', 'Structure of mesial lingual distal tooth surfaces (body structure)', '245680000'),
('DNT-AN-000271', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-mesio-palatina de diente (estructura corporal)', 'Structure of buccal mesial palatal tooth surfaces (body structure)', '245681001'),
('DNT-AN-000272', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-mesio-lingual de diente (estructura corporal)', 'Structure of buccal mesial lingual tooth surfaces (body structure)', '245682008'),
('DNT-AN-000273', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-disto-palatina de diente (estructura corporal)', 'Structure of buccal distal palatal tooth surfaces (body structure)', '245683003'),
('DNT-AN-000274', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-disto-lingual de diente (estructura corporal)', 'Structure of buccal distal lingual tooth surfaces (body structure)', '245684009'),
('DNT-AN-000275', 'dentar-an', 'anatomy', 'CAT-AN', 'esctructura de superficie mesio-ocluso-disto-vestibular de diente (estructura corporal)', 'Structure of mesial occlusal distal buccal tooth surfaces (body structure)', '245686006'),
('DNT-AN-000276', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-disto-palatina de diente (estructura corporal)', 'Structure of mesial occlusal distal palatal tooth surfaces (body structure)', '245687002'),
('DNT-AN-000277', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-disto-lingual de diente (estructura corporal)', 'Structure of mesial occlusal distal lingual tooth surfaces (body structure)', '245688007'),
('DNT-AN-000278', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-vestíbulo-palatina de diente (estructura corporal)', 'Structure of mesial occlusal buccal palatal tooth surfaces (body structure)', '245689004'),
('DNT-AN-000279', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-vestíbulo-lingual de diente (estructura corporal)', 'Structure of mesial occlusal buccal lingual tooth surfaces (body structure)', '245690008'),
('DNT-AN-000280', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-ocluso-vestíbulo-palatina de diente (estructura corporal)', 'Structure of distal occlusal buccal palatal tooth surfaces (body structure)', '245691007'),
('DNT-AN-000281', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-ocluso-vestíbulo-lingual de diente (estructura corporal)', 'Structure of distal occlusal buccal lingual tooth surfaces (body structure)', '245692000'),
('DNT-AN-000282', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-vestíbulo-disto-palatina de diente (estructura corporal)', 'Structure of mesial buccal distal palatal tooth surfaces (body structure)', '245694004'),
('DNT-AN-000283', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-vestíbulo-disto-lingual de diente (estructura corporal)', 'Structure of mesial buccal distal lingual tooth surfaces (body structure)', '245695003'),
('DNT-AN-000284', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-disto-vestíbulo-palatina de diente (estructura corporal)', 'Structure of mesial occlusal distal buccal palatal tooth surfaces (body structure)', '245697006'),
('DNT-AN-000285', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-ocluso-disto-vestíbulo-lingual de diente (estructura corporal)', 'Structure of mesial occlusal distal buccal lingual tooth surfaces (body structure)', '245698001'),
('DNT-AN-000286', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta dental (estructura corporal)', 'Structure of tooth ridge (body structure)', '245699009'),
('DNT-AN-000287', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta marginal de diente (estructura corporal)', 'Structure of marginal ridge of tooth (body structure)', '245700005'),
('DNT-AN-000288', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta de diente oblicua (estructura corporal)', 'Structure of oblique ridge of tooth (body structure)', '245701009'),
('DNT-AN-000289', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta marginal transversal de diente (estructura corporal)', 'Structure of transverse marginal ridge of tooth (body structure)', '245702002'),
('DNT-AN-000290', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco dental (estructura corporal)', 'Structure of tooth fissure (body structure)', '245703007'),
('DNT-AN-000291', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco oclusal (estructura corporal)', 'Structure of occlusal fissure (body structure)', '245704001'),
('DNT-AN-000292', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco palatino (estructura corporal)', 'Structure of palatal fissure (body structure)', '245705000'),
('DNT-AN-000293', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco vestibular (estructura corporal)', 'Structure of buccal fissure (body structure)', '245706004'),
('DNT-AN-000294', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de raíz dental (estructura corporal)', 'Part of root of tooth (body structure)', '245709006'),
('DNT-AN-000295', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio coronal de una raíz dental (estructura corporal)', 'Structure of coronal third of root (body structure)', '245710001'),
('DNT-AN-000296', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio medio de raíz de diente (estructura corporal)', 'Structure of middle third of root (body structure)', '245711002'),
('DNT-AN-000297', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie de raíz de diente (estructura corporal)', 'Structure of surface of tooth root (body structure)', '245712009'),
('DNT-AN-000298', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie palatina de raíz dental (estructura corporal)', 'Structure of palatal surface of tooth root (body structure)', '245714005'),
('DNT-AN-000299', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie lingual de la raíz dental (estructura corporal)', 'Structure of lingual surface of tooth root (body structure)', '245715006'),
('DNT-AN-000300', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesial de raíz dental (estructura corporal)', 'Structure of mesial surface of tooth root (body structure)', '245716007'),
('DNT-AN-000301', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distal de raíz de diente (estructura corporal)', 'Structure of distal surface of tooth root (body structure)', '245717003'),
('DNT-AN-000302', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cúspide palatina de diente (estructura corporal)', 'Structure of palatal cusp of tooth (body structure)', '245719000'),
('DNT-AN-000303', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cúspide mesiopalatina (estructura corporal)', 'Structure of mesiopalatal cusp (body structure)', '245722003'),
('DNT-AN-000304', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cúspide distopalatina de diente (estructura corporal)', 'Structure of distopalatal cusp of tooth (body structure)', '245725001'),
('DNT-AN-000305', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cúspide distal (estructura corporal)', 'Structure of distal cusp (body structure)', '245727009'),
('DNT-AN-000306', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental única (estructura corporal)', 'Structure of single tooth root (body structure)', '245729007'),
('DNT-AN-000307', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental vestibular (estructura corporal)', 'Structure of buccal tooth root (body structure)', '245730002'),
('DNT-AN-000308', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental palatina (estructura corporal)', 'Structure of palatal tooth root (body structure)', '245731003'),
('DNT-AN-000309', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental lingual (estructura corporal)', 'Structure of lingual tooth root (body structure)', '245732005'),
('DNT-AN-000310', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental mesiovestibular (estructura corporal)', 'Structure of mesiobuccal tooth root (body structure)', '245733000'),
('DNT-AN-000311', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental distovestibular (estructura corporal)', 'Structure of distobuccal tooth root (body structure)', '245734006'),
('DNT-AN-000312', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental mesial (estructura corporal)', 'Structure of mesial tooth root (body structure)', '245735007'),
('DNT-AN-000313', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de raíz dental distal (estructura corporal)', 'Structure of distal tooth root (body structure)', '245736008'),
('DNT-AN-000314', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de bifurcación de raíz dental (estructura corporal)', 'Structure of tooth root bifurcation (body structure)', '245737004'),
('DNT-AN-000315', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de trifurcación de raíz dental (estructura corporal)', 'Structure of tooth root trifurcation (body structure)', '245738009'),
('DNT-AN-000316', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco congénito de la raíz (estructura corporal)', 'Structure of developmental groove of root (body structure)', '245739001'),
('DNT-AN-000317', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cámara pulpar dental (estructura corporal)', 'Structure of pulp chamber of tooth (body structure)', '245740004'),
('DNT-AN-000318', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cuerno pulpar (estructura corporal)', 'Structure of pulp horn (body structure)', '245742007'),
('DNT-AN-000319', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar mesial (estructura corporal)', 'Structure of mesial pulp canal of tooth (body structure)', '245744008'),
('DNT-AN-000320', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar distal (estructura corporal)', 'Structure of distal pulp canal of tooth (body structure)', '245745009'),
('DNT-AN-000321', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar palatino (estructura corporal)', 'Structure of palatal pulp canal of tooth (body structure)', '245746005'),
('DNT-AN-000322', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar vestibular (estructura corporal)', 'Structure of buccal pulp canal of tooth (body structure)', '245747001'),
('DNT-AN-000323', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar mesiovestibular (estructura corporal)', 'Structure of mesiobuccal pulp canal of tooth (body structure)', '245748006'),
('DNT-AN-000324', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar mesiolingual (estructura corporal)', 'Structure of mesiolingual pulp canal of tooth (body structure)', '245749003'),
('DNT-AN-000325', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar distovestibular (estructura corporal)', 'Structure of distobuccal pulp canal of tooth (body structure)', '245750003'),
('DNT-AN-000326', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto pulpar distolingual (estructura corporal)', 'Structure of distolingual pulp canal of tooth (body structure)', '245751004'),
('DNT-AN-000327', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento periodontal (estructura corporal)', 'Structure of periodontal ligament (body structure)', '245775004'),
('DNT-AN-000328', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de línea media del paladar duro (estructura corporal)', 'Structure of midline of hard palate (body structure)', '245781007'),
('DNT-AN-000329', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de porción anterior de proceso alveolar de maxilar (estructura corporal)', 'Structure of anterior part of alveolar process of maxilla (body structure)', '245793003'),
('DNT-AN-000330', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de porción posterior de proceso alveolar de maxilar (estructura corporal)', 'Structure of posterior part of alveolar process of maxilla (body structure)', '245794009'),
('DNT-AN-000331', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de porción anterior de proceso alveolar de mandíbula (estructura corporal)', 'Structure of anterior part of alveolar process of mandible (body structure)', '245796006'),
('DNT-AN-000332', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de porción posterior de proceso alveolar de mandíbula (estructura corporal)', 'Structure of posterior part of alveolar process of mandible (body structure)', '245797002'),
('DNT-AN-000333', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mucosa de la comisura labial (estructura corporal)', 'Structure of mucosa of labial commissure (body structure)', '245801001'),
('DNT-AN-000334', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mucosa del paladar duro (estructura corporal)', 'Structure of mucosa of hard palate (body structure)', '245841005'),
('DNT-AN-000335', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mucosa del paladar blando (estructura corporal)', 'Structure of mucosa of soft palate (body structure)', '245842003'),
('DNT-AN-000336', 'dentar-an', 'anatomy', 'CAT-AN', 'surco yugal (estructura corporal)', 'Entire buccal sulcus (body structure)', '245846000'),
('DNT-AN-000337', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de apófisis condílea extracapsular de la mandíbula (estructura corporal)', 'Structure of extracapsular condyle of mandible (body structure)', '263994007'),
('DNT-AN-000338', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta alveolar (estructura corporal)', 'Alveolar ridge structure (body structure)', '272661000'),
('DNT-AN-000339', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de maxilar superior (estructura corporal)', 'Maxillary alveolus structure (body structure)', '272686009'),
('DNT-AN-000340', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de región parasinfisiaria de mandíbula (estructura corporal)', 'Structure of parasymphyseal region of mandible (body structure)', '272689002'),
('DNT-AN-000341', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de la mandíbula (estructura corporal)', 'Structure of border of mandible (body structure)', '272690006'),
('DNT-AN-000342', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta marginal mesial de diente (estructura corporal)', 'Structure of mesial marginal ridge of tooth (body structure)', '278475009'),
('DNT-AN-000343', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta marginal distal de diente (estructura corporal)', 'Structure of distal marginal ridge of tooth (body structure)', '278476005'),
('DNT-AN-000344', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de diente superior permanente (estructura corporal)', 'Structure of permanent upper tooth socket (body structure)', '280461008'),
('DNT-AN-000345', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de diente superior temporario (estructura corporal)', 'Structure of primary upper tooth socket (body structure)', '280463006'),
('DNT-AN-000346', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de segundo molar superior temporario (estructura corporal)', 'Structure of primary upper second molar tooth socket (body structure)', '280465004'),
('DNT-AN-000347', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de primer molar superior temporario (estructura corporal)', 'Structure of primary upper first molar tooth socket (body structure)', '280467007'),
('DNT-AN-000348', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de canino superior temporario (estructura corporal)', 'Structure of primary upper canine tooth socket (body structure)', '280471005'),
('DNT-AN-000349', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo lateral superior temporario (estructura corporal)', 'Structure of primary upper lateral incisor tooth socket (body structure)', '280472003'),
('DNT-AN-000350', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo central superior temporario (estructura corporal)', 'Structure of primary upper central incisor tooth socket (body structure)', '280473008'),
('DNT-AN-000351', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de tercer molar superior permanente (estructura corporal)', 'Structure of permanent upper third molar tooth socket (body structure)', '280474002'),
('DNT-AN-000352', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de segundo molar superior permanente (estructura corporal)', 'Structure of permanent upper second molar tooth socket (body structure)', '280476000'),
('DNT-AN-000353', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de primer molar superior permanente (estructura corporal)', 'Structure of permanent upper first molar tooth socket (body structure)', '280477009'),
('DNT-AN-000354', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de segundo premolar superior permanente (estructura corporal)', 'Structure of permanent upper second premolar tooth socket (body structure)', '280479007'),
('DNT-AN-000355', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de primer premolar superior permanente (estructura corporal)', 'Structure of permanent upper first premolar tooth socket (body structure)', '280481009'),
('DNT-AN-000356', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de canino superior permanente (estructura corporal)', 'Structure of permanent upper canine tooth socket (body structure)', '280482002'),
('DNT-AN-000357', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo lateral superior permanente (estructura corporal)', 'Structure of permanent upper lateral incisor tooth socket (body structure)', '280484001'),
('DNT-AN-000358', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo central superior permanente (estructura corporal)', 'Structure of permanent upper central incisor tooth socket (body structure)', '280485000'),
('DNT-AN-000359', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de diente inferior permanente (estructura corporal)', 'Structure of permanent lower tooth socket (body structure)', '280487008'),
('DNT-AN-000360', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de diente inferior temporario (estructura corporal)', 'Structure of primary lower tooth socket (body structure)', '280488003'),
('DNT-AN-000361', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de segundo molar inferior temporario (estructura corporal)', 'Structure of primary lower second molar tooth socket (body structure)', '280489006'),
('DNT-AN-000362', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de primer molar inferior temporario (estructura corporal)', 'Structure of primary lower first molar tooth socket (body structure)', '280490002'),
('DNT-AN-000363', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo dental de canino inferior temporario (estructura corporal)', 'Structure of primary lower canine tooth socket (body structure)', '280491003'),
('DNT-AN-000364', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo lateral inferior temporario (estructura corporal)', 'Structure of primary lower lateral incisor tooth socket (body structure)', '280492005'),
('DNT-AN-000365', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo central inferior temporario (estructura corporal)', 'Structure of primary lower central incisor tooth socket (body structure)', '280493000'),
('DNT-AN-000366', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de tercer molar inferior permanente (estructura corporal)', 'Structure of permanent lower third molar tooth socket (body structure)', '280494006'),
('DNT-AN-000367', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de segundo molar inferior permanente (estructura corporal)', 'Structure of permanent lower second molar tooth socket (body structure)', '280495007'),
('DNT-AN-000368', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de primer molar inferior permanente (estructura corporal)', 'Structure of permanent lower first molar tooth socket (body structure)', '280496008'),
('DNT-AN-000369', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de segundo premolar inferior permanente (estructura corporal)', 'Structure of permanent lower second premolar tooth socket (body structure)', '280497004'),
('DNT-AN-000370', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de primer premolar inferior permanente (estructura corporal)', 'Structure of permanent lower first premolar tooth socket (body structure)', '280498009'),
('DNT-AN-000371', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo dental de canino inferior permanente (estructura corporal)', 'Structure of permanent lower canine tooth socket (body structure)', '280499001'),
('DNT-AN-000372', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo lateral inferior permanente (estructura corporal)', 'Structure of permanent lower lateral incisor tooth socket (body structure)', '280500005'),
('DNT-AN-000373', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de incisivo central inferior permanente (estructura corporal)', 'Structure of permanent lower central incisor tooth socket (body structure)', '280501009'),
('DNT-AN-000374', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segmento anterior del maxilar superior (estructura corporal)', 'Structure of anterior segment of maxilla (body structure)', '280709009'),
('DNT-AN-000375', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segmento posterior del maxilar superior (estructura corporal)', 'Structure of posterior segment of maxilla (body structure)', '280710004'),
('DNT-AN-000376', 'dentar-an', 'anatomy', 'CAT-AN', 'piel de parte de labio (estructura corporal)', 'Skin of part of lip (body structure)', '281715002'),
('DNT-AN-000377', 'dentar-an', 'anatomy', 'CAT-AN', 'piel de parte de la espinilla (estructura corporal)', 'Skin of part of chin (body structure)', '281718000'),
('DNT-AN-000378', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-ocluso-palatina de diente (estructura corporal)', 'Structure of buccal occlusal palatal tooth surfaces (body structure)', '281819003'),
('DNT-AN-000379', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-ocluso-lingual de diente (estructura corporal)', 'Structure of buccal occlusal lingual tooth surfaces (body structure)', '283869001'),
('DNT-AN-000380', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-incisal de diente (estructura corporal)', 'Structure of buccal incisal tooth surfaces (body structure)', '288536007'),
('DNT-AN-000381', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie inciso lingual de diente (estructura corporal)', 'Structure of incisal lingual tooth surfaces (body structure)', '288537003'),
('DNT-AN-000382', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie inciso palatina de diente (estructura corporal)', 'Structure of incisal palatal tooth surfaces (body structure)', '288538008'),
('DNT-AN-000383', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-inciso-lingual de diente (estructura corporal)', 'Structure of buccal incisal lingual tooth surfaces (body structure)', '288539000'),
('DNT-AN-000384', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie vestíbulo-inciso-palatina de diente (estructura corporal)', 'Structure of buccal incisal palatal tooth surfaces (body structure)', '288540003'),
('DNT-AN-000385', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cara mesiovestibular de la raíz dental (estructura corporal)', 'Structure of mesiobuccal surface of tooth root (body structure)', '289911001'),
('DNT-AN-000386', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distovestibular de raíz de diente (estructura corporal)', 'Structure of distobuccal surface of tooth root (body structure)', '289912008'),
('DNT-AN-000387', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesiopalatina de raíz dental (estructura corporal)', 'Structure of mesiopalatal surface of tooth root (body structure)', '289913003'),
('DNT-AN-000388', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie distopalatina de raíz de diente (estructura corporal)', 'Structure of distopalatal surface of tooth root (body structure)', '289914009'),
('DNT-AN-000389', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie inferior del paladar blando (estructura corporal)', 'Structure of inferior surface of soft palate (body structure)', '303339004'),
('DNT-AN-000390', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tubérculo articular de hueso temporal (estructura corporal)', 'Structure of articular tubercle of temporal bone (body structure)', '303403006'),
('DNT-AN-000391', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de membrana sinovial de articulación temporomandibular (estructura corporal)', 'Structure of synovial membrane of temporomandibular joint (body structure)', '303405004'),
('DNT-AN-000392', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-inciso-palatina de diente (estructura corporal)', 'Structure of distal incisal palatal tooth surfaces (body structure)', '307344007'),
('DNT-AN-000393', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-inciso-vestibular de diente (estructura corporal)', 'Structure of distal incisal buccal tooth surfaces (body structure)', '307345008'),
('DNT-AN-000394', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-inciso-lingual de diente (estructura corporal)', 'Structure of distal incisal lingual tooth surfaces (body structure)', '307346009'),
('DNT-AN-000395', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-vestibular de diente (estructura corporal)', 'Structure of mesial incisal buccal tooth surfaces (body structure)', '307347000'),
('DNT-AN-000396', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-palatina de diente (estructura corporal)', 'Structure of mesial incisal palatal tooth surfaces (body structure)', '307348005'),
('DNT-AN-000397', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-lingual de diente (estructura corporal)', 'Structure of mesial incisal lingual tooth surfaces (body structure)', '307349002'),
('DNT-AN-000398', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-inciso-vestíbulo-palatina de diente (estructura corporal)', 'Structure of distal incisal buccal palatal tooth surfaces (body structure)', '307350002'),
('DNT-AN-000399', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie disto-inciso-vestíbulo-lingual de diente (estructura corporal)', 'Structure of distal incisal buccal lingual tooth surfaces (body structure)', '307351003'),
('DNT-AN-000400', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-disto-vestibular de diente (estructura corporal)', 'Structure of mesial incisal distal buccal tooth surfaces (body structure)', '307352005'),
('DNT-AN-000401', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-disto-palatina de diente (estructura corporal)', 'Structure of mesial incisal distal palatal tooth surfaces (body structure)', '307353000'),
('DNT-AN-000402', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-disto-lingual de diente (estructura corporal)', 'Structure of mesial incisal distal lingual tooth surfaces (body structure)', '307354006'),
('DNT-AN-000403', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-disto-vestíbulo-palatina de diente (estructura corporal)', 'Structure of mesial incisal distal buccal palatal tooth surfaces (body structure)', '307611007'),
('DNT-AN-000404', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-disto-vestíbulo-lingual de diente (estructura corporal)', 'Structure of mesial incisal distal buccal lingual tooth surfaces (body structure)', '307612000'),
('DNT-AN-000405', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie mesio-inciso-vestíbulo-lingual de diente (estructura corporal)', 'Structure of mesial incisal buccal lingual tooth surfaces (body structure)', '307613005'),
('DNT-AN-000406', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de supeficie mesio-inciso-vestíbulo-palatina de diente (estructura corporal)', 'Structure of mesial incisal buccal palatal tooth surfaces (body structure)', '307614004'),
('DNT-AN-000407', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de orificio de conducto submaxilar (estructura corporal)', 'Structure of submandibular duct orifice (body structure)', '311398007'),
('DNT-AN-000408', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segmento del maxilar superior (estructura corporal)', 'Structure of segment of maxilla (body structure)', '314718006'),
('DNT-AN-000409', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie del paladar blando (estructura corporal)', 'Structure of surface of soft palate (body structure)', '314722001'),
('DNT-AN-000410', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis del maxilar (estructura corporal)', 'Structure of process of maxilla (body structure)', '360889008'),
('DNT-AN-000411', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de región superficial de triángulo submandibular (estructura corporal)', 'Structure of surface region of submandibular triangle (body structure)', '362650006'),
('DNT-AN-000412', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura faucial (estructura corporal)', 'Structure of fauces space (body structure)', '367601008'),
('DNT-AN-000413', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de vértice de pulpa radicular de diente (estructura corporal)', 'Structure of apex of radicular pulp of tooth (body structure)', '368699001'),
('DNT-AN-000414', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del diente incisivo deciduo (estructura corporal)', 'Structure of deciduous incisor tooth (body structure)', '368701001'),
('DNT-AN-000415', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente canino deciduo (estructura corporal)', 'Structure of deciduous canine tooth (body structure)', '368702008'),
('DNT-AN-000416', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de orificio de conducto de glándula lingual anterior (estructura corporal)', 'Structure of orifice of duct of anterior lingual gland (body structure)', '368747009'),
('DNT-AN-000417', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad de mandíbula (estructura corporal)', 'Structure of half of mandible (body structure)', '372186007'),
('DNT-AN-000418', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad de diente (estructura corporal)', 'Structure of half of tooth (body structure)', '372187003'),
('DNT-AN-000419', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de labio (estructura corporal)', 'Lip part (body structure)', '372197007'),
('DNT-AN-000420', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de glándula parótida (estructura corporal)', 'Parotid gland part (body structure)', '372203005'),
('DNT-AN-000421', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de disco articular de articulación temporomandibular (estructura corporal)', 'Part of articular disc of temporomandibular joint (body structure)', '372205003'),
('DNT-AN-000422', 'dentar-an', 'anatomy', 'CAT-AN', 'parte del alvéolo maxilar (estructura corporal)', 'Part of maxillary alveolus (body structure)', '373608004'),
('DNT-AN-000423', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie interproximal de diente (estructura corporal)', 'Structure of interproximal surface of tooth (body structure)', '373652007'),
('DNT-AN-000424', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival (estructura corporal)', 'Salivary gland structure (body structure)', '385294005'),
('DNT-AN-000425', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de glándula sublingual (estructura corporal)', 'Sublingual gland part (body structure)', '385295006'),
('DNT-AN-000426', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival submaxilar (estructura corporal)', 'Submandibular salivary gland structure (body structure)', '385296007'),
('DNT-AN-000427', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del agujero infraorbitario (estructura corporal)', 'Infraorbital foramen structure (body structure)', '409994008'),
('DNT-AN-000428', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de escotadura mandibular (estructura corporal)', 'Structure of mandibular notch (body structure)', '410000007'),
('DNT-AN-000429', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de espacio interdental (estructura corporal)', 'Structure of interdental space (body structure)', '410002004'),
('DNT-AN-000430', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de diente (estructura corporal)', 'Tooth part (body structure)', '410613002'),
('DNT-AN-000431', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo de maxilar inferior (estructura corporal)', 'Mandibular alveolus structure (body structure)', '414650007'),
('DNT-AN-000432', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta alveolar de maxilar superior (estructura corporal)', 'Structure of alveolar process of maxilla (body structure)', '415636008'),
('DNT-AN-000433', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del surco labial maxilar (estructura corporal)', 'Structure of maxillary labial sulcus (body structure)', '417954005'),
('DNT-AN-000434', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del surco labial inferior (estructura corporal)', 'Structure of mandibular labial sulcus (body structure)', '418271003'),
('DNT-AN-000435', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del surco bucal (estructura corporal)', 'Structure of buccal sulcus (body structure)', '419133006'),
('DNT-AN-000436', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del surco vestibulogingival (estructura corporal)', 'Structure of vestibulogingival sulcus (body structure)', '419428002'),
('DNT-AN-000437', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del surco labial (estructura corporal)', 'Structure of labial sulcus (body structure)', '419500006'),
('DNT-AN-000438', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del surco maxilar bucal (estructura corporal)', 'Structure of maxillary buccal sulcus (body structure)', '419755007'),
('DNT-AN-000439', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de surco gingivobucal mandibular (estructura corporal)', 'Structure of mandibular buccal sulcus (body structure)', '420055006'),
('DNT-AN-000440', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente inferior primario (estructura corporal)', 'Structure of primary lower tooth (body structure)', '420361003'),
('DNT-AN-000441', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente de maxilar superior (estructura corporal)', 'Structure of maxillary tooth (body structure)', '420393006'),
('DNT-AN-000442', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente superior primario (estructura corporal)', 'Structure of primary upper tooth (body structure)', '420568005'),
('DNT-AN-000443', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente mandibular (estructura corporal)', 'Structure of mandibular tooth (body structure)', '420730005'),
('DNT-AN-000444', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente canino permanente (estructura corporal)', 'Structure of permanent canine tooth (body structure)', '421097009'),
('DNT-AN-000445', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar permanente (estructura corporal)', 'Structure of permanent molar tooth (body structure)', '421456005'),
('DNT-AN-000446', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo central (estructura corporal)', 'Structure of central incisor tooth (body structure)', '422363006'),
('DNT-AN-000447', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo lateral (estructura corporal)', 'Structure of lateral incisor tooth (body structure)', '422365004'),
('DNT-AN-000448', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer premolar (estructura corporal)', 'Structure of first premolar tooth (body structure)', '422367007'),
('DNT-AN-000449', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo premolar (estructura corporal)', 'Structure of second premolar tooth (body structure)', '422369005'),
('DNT-AN-000450', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del primer molar (estructura corporal)', 'Structure of first molar tooth (body structure)', '422371005'),
('DNT-AN-000451', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del segundo molar (estructura corporal)', 'Structure of second molar tooth (body structure)', '422373008'),
('DNT-AN-000452', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo central derecho maxilar permanente (estructura corporal)', 'Structure of permanent maxillary right central incisor tooth (body structure)', '422653006'),
('DNT-AN-000453', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo permanente (estructura corporal)', 'Structure of permanent incisor tooth (body structure)', '422727008'),
('DNT-AN-000454', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la vena labial superior (estructura corporal)', 'Structure of superior labial vein (body structure)', '422755007'),
('DNT-AN-000455', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de vena labial inferior (estructura corporal)', 'Structure of inferior labial vein (body structure)', '422955002'),
('DNT-AN-000456', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo lateral izquierdo maxilar permanente (estructura corporal)', 'Structure of permanent maxillary left lateral incisor tooth (body structure)', '423185002'),
('DNT-AN-000457', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo lateral izquierdo mandibular permanente (estructura corporal)', 'Structure of permanent mandibular left lateral incisor tooth (body structure)', '423331005'),
('DNT-AN-000458', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo lateral derecho mandibular permanente (estructura corporal)', 'Structure of permanent mandibular right lateral incisor tooth (body structure)', '423937004'),
('DNT-AN-000459', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo central izquierdo maxilar permanente (estructura corporal)', 'Structure of permanent maxillary left central incisor tooth (body structure)', '424399000'),
('DNT-AN-000460', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo central derecho mandibular permanente (estructura corporal)', 'Structure of permanent mandibular right central incisor tooth (body structure)', '424575004'),
('DNT-AN-000461', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo lateral derecho maxilar permanente (estructura corporal)', 'Structure of permanent maxillary right lateral incisor tooth (body structure)', '424877001'),
('DNT-AN-000462', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo central izquierdo mandibular permanente (estructura corporal)', 'Structure of permanent mandibular left central incisor tooth (body structure)', '425106001'),
('DNT-AN-000463', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo maxilar (estructura corporal)', 'Structure of maxillary incisor tooth (body structure)', '442100006'),
('DNT-AN-000464', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente incisivo mandibular (estructura corporal)', 'Structure of mandibular incisor tooth (body structure)', '442274007'),
('DNT-AN-000465', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dentición mixta tardía (estructura corporal)', 'Structure of late mixed dentition (body structure)', '697980008'),
('DNT-AN-000466', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dentición mixta temprana (estructura corporal)', 'Structure of early mixed dentition (body structure)', '697981007'),
('DNT-AN-000467', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de agujeros de Scarpa (estructura corporal)', 'Structure of foramina of Scarpa (body structure)', '698778007'),
('DNT-AN-000468', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio interno de la dentina (estructura corporal)', 'Structure of inner third of dentin (body structure)', '708579004'),
('DNT-AN-000469', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio medio de la dentina (estructura corporal)', 'Structure of middle third of dentin (body structure)', '708580001'),
('DNT-AN-000470', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio externo de la dentina (estructura corporal)', 'Structure of outer third of dentin (body structure)', '708581002'),
('DNT-AN-000471', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad interior del esmalte (estructura corporal)', 'Structure of inner half of enamel (body structure)', '708584005'),
('DNT-AN-000472', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad externa del esmalte (estructura corporal)', 'Structure of outer half of enamel (body structure)', '708585006'),
('DNT-AN-000473', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de unión dentino-pulpar (estructura corporal)', 'Structure of dentinopulpal junction (body structure)', '708586007'),
('DNT-AN-000474', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie de diente con fosas y fisuras (estructura corporal)', 'Structure of pit and fissure surface of tooth (body structure)', '716359008'),
('DNT-AN-000475', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie de cuello de diente (estructura corporal)', 'Structure of surface of cervical margin of tooth (body structure)', '716360003'),
('DNT-AN-000476', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de superficie lisa de diente (estructura corporal)', 'Structure of smooth surface of tooth (body structure)', '716361004'),
('DNT-AN-000477', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival izquierda (estructura corporal)', 'Structure of left salivary gland (body structure)', '725037009'),
('DNT-AN-000478', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival derecha (estructura corporal)', 'Structure of right salivary gland (body structure)', '725038004'),
('DNT-AN-000479', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de articulación temporomandibular izquierda (estructura corporal)', 'Structure of left temporomandibular joint (body structure)', '725284004'),
('DNT-AN-000480', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de articulación temporomandibular derecha (estructura corporal)', 'Structure of right temporomandibular joint (body structure)', '725285003'),
('DNT-AN-000481', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de rama izquierda de la mandíbula (estructura corporal)', 'Structure of left ramus of mandible (body structure)', '735177008'),
('DNT-AN-000482', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de rama derecha de la mandíbula (estructura corporal)', 'Structure of right ramus of mandible (body structure)', '735178003'),
('DNT-AN-000483', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido conjuntivo fibroso de tuberosidad maxilar (estructura corporal)', 'Structure of fibrous connective tissue of maxillary tuberosity (body structure)', '735388009'),
('DNT-AN-000484', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cóndilo izquierdo de maxilar inferior (estructura corporal)', 'Structure of left condyloid process of mandible (body structure)', '736779005'),
('DNT-AN-000485', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cóndilo derecho de maxilar inferior (estructura corporal)', 'Structure of right condyloid process of mandible (body structure)', '736780008'),
('DNT-AN-000486', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cápsula de articulación temporomandibular izquierda (estructura corporal)', 'Structure of capsule of left temporomandibular joint (body structure)', '764112006'),
('DNT-AN-000487', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cápsula de articulación temporomandibular derecha (estructura corporal)', 'Structure of capsule of right temporomandibular joint (body structure)', '764113001'),
('DNT-AN-000488', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cuello de diente (estructura corporal)', 'Structure of neck of tooth (body structure)', '765050009'),
('DNT-AN-000489', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura ósea de espina nasal anterior de maxilar superior (estructura corporal)', 'Bone structure of anterior nasal spine of maxilla (body structure)', '767495006'),
('DNT-AN-000490', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de disco articular de articulación temporomandibular derecha (estructura corporal)', 'Structure of articular disc of right temporomandibular joint (body structure)', '773206000'),
('DNT-AN-000491', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de disco articular de articulación temporomandibular izquierda (estructura corporal)', 'Structure of articular disc of left temporomandibular joint (body structure)', '773207009'),
('DNT-AN-000492', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cara vestibular de raíz dental (estructura corporal)', 'Structure of vestibular surface of root of tooth (body structure)', '773297003'),
('DNT-AN-000493', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad izquierda de región de maxilar inferior (estructura corporal)', 'Structure of left half of lower jaw region (body structure)', '773561008'),
('DNT-AN-000494', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad derecha de región de maxilar inferior (estructura corporal)', 'Structure of right half of lower jaw region (body structure)', '773563006'),
('DNT-AN-000495', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad izquierda de región de maxilar superior (estructura corporal)', 'Structure of left half of upper jaw region (body structure)', '773564000'),
('DNT-AN-000496', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad derecha de región de maxilar superior (estructura corporal)', 'Structure of right half of upper jaw region (body structure)', '773565004'),
('DNT-AN-000497', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura ósea de maxilar superior derecho (estructura corporal)', 'Bone structure of right maxilla (body structure)', '773936003'),
('DNT-AN-000498', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura ósea de maxilar superior izquierdo (estructura corporal)', 'Bone structure of left maxilla (body structure)', '773937007'),
('DNT-AN-000499', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis coronoides de la mandíbula izquierda (estructura corporal)', 'Structure of coronoid process of left mandible (body structure)', '778033007'),
('DNT-AN-000500', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la apófisis coronoides de la mandíbula derecha (estructura corporal)', 'Structure of coronoid process of right mandible (body structure)', '778034001'),
('DNT-AN-000501', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad izquierda de proceso alveolar de mandíbula (estructura corporal)', 'Structure of left half of alveolar process of mandible (body structure)', '778035000'),
('DNT-AN-000502', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad derecha de proceso alveolar de mandíbula (estructura corporal)', 'Structure of right half of alveolar process of mandible (body structure)', '778036004'),
('DNT-AN-000503', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura ósea de mitad izquierda de la mandíbula (estructura corporal)', 'Bone structure of left half of mandible (body structure)', '782962006'),
('DNT-AN-000504', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura ósea de mitad derecha de la mandíbula (estructura corporal)', 'Bone structure of right half of mandible (body structure)', '782963001'),
('DNT-AN-000505', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la cara inferior del paladar duro (estructura corporal)', 'Structure of inferior aspect of hard palate (body structure)', '783039003'),
('DNT-AN-000506', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mitad izquierda de labio superior (estructura corporal)', 'Structure of left half of upper lip (body structure)', '783394004'),
('DNT-AN-000507', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mitad derecha de labio superior (estructura corporal)', 'Structure of right half of upper lip (body structure)', '783395003'),
('DNT-AN-000508', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad izquierda de proceso alveolar de maxilar (estructura corporal)', 'Structure of left half of alveolar process of maxilla (body structure)', '783398001'),
('DNT-AN-000509', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de mitad derecha de proceso alveolar de maxilar (estructura corporal)', 'Structure of right half of alveolar process of maxilla (body structure)', '783399009'),
('DNT-AN-000510', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mitad izquierda del paladar duro (estructura corporal)', 'Structure of left half of hard palate (body structure)', '783401003'),
('DNT-AN-000511', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mitad derecha del paladar duro (estructura corporal)', 'Structure of right half of hard palate (body structure)', '783402005'),
('DNT-AN-000512', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mitad izquierda del paladar blando (estructura corporal)', 'Structure of left half of soft palate (body structure)', '783403000'),
('DNT-AN-000513', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de la mitad derecha del paladar blando (estructura corporal)', 'Structure of right half of soft palate (body structure)', '783404006'),
('DNT-AN-000514', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del cuerpo de la mitad derecha del maxilar inferior (estructura corporal)', 'Structure of body of right half of mandible (body structure)', '784261005'),
('DNT-AN-000515', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura del cuerpo de la mitad izquierda del maxilar inferior (estructura corporal)', 'Structure of body of left half of mandible (body structure)', '784262003'),
('DNT-AN-000516', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cuello de maxilar inferior izquierdo (estructura corporal)', 'Structure of neck of left mandible (body structure)', '786888005'),
('DNT-AN-000517', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cuello de maxilar inferior derecho (estructura corporal)', 'Structure of neck of right mandible (body structure)', '786889002'),
('DNT-AN-000518', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de folículo piloso del mentón (estructura corporal)', 'Structure of hair follicle of chin (body structure)', '788184000'),
('DNT-AN-000519', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de región articular temporomandibular (estructura corporal)', 'Structure of temporomandibular joint region (body structure)', '788434003'),
('DNT-AN-000520', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercer molar permanente maxilar (estructura corporal)', 'Structure of permanent maxillary third molar tooth (body structure)', '789599001'),
('DNT-AN-000521', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercer molar permanente mandibular (estructura corporal)', 'Structure of permanent mandibular third molar tooth (body structure)', '789600003'),
('DNT-AN-000522', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente canino maxilar superior derecho permanente (estructura corporal)', 'Structure of permanent maxillary right canine tooth (body structure)', '860767006'),
('DNT-AN-000523', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente superior permanente (estructura corporal)', 'Structure of permanent maxillary tooth (body structure)', '860768001'),
('DNT-AN-000524', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente canino maxilar superior izquierdo permanente (estructura corporal)', 'Structure of permanent maxillary left canine tooth (body structure)', '860780009'),
('DNT-AN-000525', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente canino maxilar inferior izquierdo permanente (estructura corporal)', 'Structure of permanent mandibular left canine tooth (body structure)', '860782001'),
('DNT-AN-000526', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente canino maxilar inferior derecho permanente (estructura corporal)', 'Structure of permanent mandibular right canine tooth (body structure)', '860785004'),
('DNT-AN-000527', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segundo molar maxilar inferior izquierdo permanente (estructura corporal)', 'Structure of permanent mandibular left second molar tooth (body structure)', '863898000'),
('DNT-AN-000528', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segundo molar maxilar inferior derecho permanente (estructura corporal)', 'Structure of permanent mandibular right second molar tooth (body structure)', '863899008'),
('DNT-AN-000529', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segundo molar maxilar superior izquierdo permanente (estructura corporal)', 'Structure of permanent maxillary left second molar tooth (body structure)', '863901004'),
('DNT-AN-000530', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segundo molar maxilar superior derecho permanente (estructura corporal)', 'Structure of permanent maxillary right second molar tooth (body structure)', '863902006'),
('DNT-AN-000531', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer molar maxilar superior izquierdo permanente (estructura corporal)', 'Structure of permanent maxillary left first molar tooth (body structure)', '865988009'),
('DNT-AN-000532', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer molar maxilar superior derecho permanente (estructura corporal)', 'Structure of permanent maxillary right first molar tooth (body structure)', '865995000'),
('DNT-AN-000533', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer molar maxilar inferior derecho permanente (estructura corporal)', 'Structure of permanent mandibular right first molar tooth (body structure)', '866005003'),
('DNT-AN-000534', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer molar maxilar inferior izquierdo permanente (estructura corporal)', 'Structure of permanent mandibular left first molar tooth (body structure)', '866006002'),
('DNT-AN-000535', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula sabácea de labio (estructura corporal)', 'Structure of sebaceous gland of lip (body structure)', '878873003'),
('DNT-AN-000536', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel y/o tejido celular subcutáneo de mentón (estructura corporal)', 'Structure of skin and/or subcutaneous tissue of chin (body structure)', '897081006'),
('DNT-AN-000537', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel y/o tejido celular subcutáneo de labio inferior (estructura corporal)', 'Structure of skin and/or subcutaneous tissue of lower lip (body structure)', '897086001'),
('DNT-AN-000538', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel y/o tejido celular subcutáneo de labio superior (estructura corporal)', 'Structure of skin and/or subcutaneous tissue of upper lip (body structure)', '897091000'),
('DNT-AN-000539', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de piel y/o tejido celular subcutáneo de labio (estructura corporal)', 'Structure of skin and/or subcutaneous tissue of lip (body structure)', '897096005'),
('DNT-AN-000540', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de comisura derecha de los labios (estructura corporal)', 'Structure of right commissure of lips (body structure)', '1004037009'),
('DNT-AN-000541', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de comisura izquierda de los labios (estructura corporal)', 'Structure of left commissure of lips (body structure)', '1004038004'),
('DNT-AN-000542', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cartílago articular de articulación temporomandibular (estructura corporal)', 'Structure of articular cartilage of temporomandibular joint (body structure)', '1004039007'),
('DNT-AN-000543', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de bermellón de labio (estructura corporal)', 'Structure of vermilion of lip (body structure)', '1141975009'),
('DNT-AN-000544', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de bermellón de labio superior (estructura corporal)', 'Structure of vermilion of upper lip (body structure)', '1141977001'),
('DNT-AN-000545', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de bermellón de labio inferior (estructura corporal)', 'Structure of vermilion of lower lip (body structure)', '1141978006'),
('DNT-AN-000546', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente inferior permanente (estructura corporal)', 'Structure of permanent mandibular tooth (body structure)', '1149356007'),
('DNT-AN-000547', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento de articulación temporomandibular izquierda (estructura corporal)', 'Structure of ligament of left temporomandibular joint (body structure)', '1156175000'),
('DNT-AN-000548', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ligamento de articulación temporomandibular derecha (estructura corporal)', 'Structure of ligament of right temporomandibular joint (body structure)', '1156176004'),
('DNT-AN-000549', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes (estructura corporal)', 'All teeth (body structure)', '1162715001'),
('DNT-AN-000550', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes inferiores posteriores (estructura corporal)', 'Structure of posterior mandibular teeth (body structure)', '1178996002'),
('DNT-AN-000551', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes inferiores anteriores (estructura corporal)', 'Structure of anterior mandibular teeth (body structure)', '1178997006'),
('DNT-AN-000552', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes superiores anteriores (estructura corporal)', 'Structure of anterior maxillary teeth (body structure)', '1178999009'),
('DNT-AN-000553', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes superiores posteriores (estructura corporal)', 'Structure of posterior maxillary teeth (body structure)', '1179000006'),
('DNT-AN-000554', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes inferiores posteriores (estructura corporal)', 'All posterior mandibular teeth (body structure)', '1179001005'),
('DNT-AN-000555', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes superiores anteriores (estructura corporal)', 'All anterior maxillary teeth (body structure)', '1179002003'),
('DNT-AN-000556', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes superiores posteriores (estructura corporal)', 'All posterior maxillary teeth (body structure)', '1179003008'),
('DNT-AN-000557', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes inferiores anteriores (estructura corporal)', 'All anterior mandibular teeth (body structure)', '1179004002'),
('DNT-AN-000558', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente de dentición anterior (estructura corporal)', 'Structure of tooth of anterior dentition (body structure)', '1179138007'),
('DNT-AN-000559', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes de dentición anterior (estructura corporal)', 'Structure of teeth of anterior dentition (body structure)', '1179144006'),
('DNT-AN-000560', 'dentar-an', 'anatomy', 'CAT-AN', 'todos los dientes de dentición anterior (estructura corporal)', 'All teeth of anterior dentition (body structure)', '1179147004'),
('DNT-AN-000561', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes deciduos (estructura corporal)', 'Structure of deciduous teeth (body structure)', '1179287003'),
('DNT-AN-000562', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de diente de dentición posterior (estructura corporal)', 'Structure of tooth of posterior dentition (body structure)', '1179289000'),
('DNT-AN-000563', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes de dentición posterior (estructura corporal)', 'Structure of teeth of posterior dentition (body structure)', '1179291008'),
('DNT-AN-000564', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de dientes permanentes (estructura corporal)', 'Structure of permanent teeth (body structure)', '1179292001'),
('DNT-AN-000565', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula seromucosa salival (estructura corporal)', 'Structure of salivary seromucous gland (body structure)', '1179672003'),
('DNT-AN-000566', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer molar deciduo (estructura corporal)', 'Structure of deciduous first molar tooth (body structure)', '1186773006'),
('DNT-AN-000567', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segundo molar deciduo (estructura corporal)', 'Structure of deciduous second molar tooth (body structure)', '1186775004'),
('DNT-AN-000568', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer canino inferior (estructura corporal)', 'Structure of primary lower canine tooth (body structure)', '1187091001'),
('DNT-AN-000569', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de segundo molar permanente (estructura corporal)', 'Structure of permanent second molar tooth (body structure)', '1187093003'),
('DNT-AN-000570', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer incisivo inferior primario (estructura corporal)', 'Structure of primary lower incisor tooth (body structure)', '1187094009'),
('DNT-AN-000571', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar inferior primario (estructura corporal)', 'Structure of primary lower molar tooth (body structure)', '1187105002'),
('DNT-AN-000572', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo izquierdo inferior deciduo (estructura corporal)', 'Structure of primary lower left incisor tooth (body structure)', '1187404009'),
('DNT-AN-000573', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar izquierdo inferior deciduo (estructura corporal)', 'Structure of primary lower left molar tooth (body structure)', '1187405005'),
('DNT-AN-000574', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo derecho inferior deciduo (estructura corporal)', 'Structure of primary lower right incisor tooth (body structure)', '1187406006'),
('DNT-AN-000575', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar derecho inferior deciduo (estructura corporal)', 'Structure of primary lower right molar tooth (body structure)', '1187407002'),
('DNT-AN-000576', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de canino superior izquierdo deciduo (estructura corporal)', 'Structure of primary upper canine tooth (body structure)', '1187408007'),
('DNT-AN-000577', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo superior deciduo (estructura corporal)', 'Structure of primary upper incisor tooth (body structure)', '1187409004'),
('DNT-AN-000578', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo izquierdo superior deciduo (estructura corporal)', 'Structure of primary upper left incisor tooth (body structure)', '1187410009'),
('DNT-AN-000579', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar izquierdo superior deciduo (estructura corporal)', 'Structure of primary upper left molar tooth (body structure)', '1187411008'),
('DNT-AN-000580', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar superior deciduo (estructura corporal)', 'Structure of primary upper molar tooth (body structure)', '1187412001'),
('DNT-AN-000581', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo derecho superior deciduo (estructura corporal)', 'Structure of primary upper right incisor tooth (body structure)', '1187413006'),
('DNT-AN-000582', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar derecho superior deciduo (estructura corporal)', 'Structure of primary upper right molar tooth (body structure)', '1187414000'),
('DNT-AN-000583', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de primer molar permanente (estructura corporal)', 'Structure of permanent first molar tooth (body structure)', '1187417007'),
('DNT-AN-000584', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo izquierdo inferior permanente (estructura corporal)', 'Structure of permanent lower left incisor tooth (body structure)', '1187418002'),
('DNT-AN-000585', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar izquierdo inferior permanente (estructura corporal)', 'Structure of permanent lower left molar tooth (body structure)', '1187419005'),
('DNT-AN-000586', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo derecho inferior permanente (estructura corporal)', 'Structure of permanent lower right incisor tooth (body structure)', '1187420004'),
('DNT-AN-000587', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar derecho inferior permanente (estructura corporal)', 'Structure of permanent lower right molar tooth (body structure)', '1187421000'),
('DNT-AN-000588', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo superior izquierdo permanente (estructura corporal)', 'Structure of permanent upper left incisor tooth (body structure)', '1187422007'),
('DNT-AN-000589', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar izquierdo superior permanente (estructura corporal)', 'Structure of permanent upper left molar tooth (body structure)', '1187424008'),
('DNT-AN-000590', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de incisivo superior derecho permanente (estructura corporal)', 'Structure of permanent upper right incisor tooth (body structure)', '1187426005'),
('DNT-AN-000591', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de molar derecho superior permanente (estructura corporal)', 'Structure of permanent upper right molar tooth (body structure)', '1187427001'),
('DNT-AN-000592', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo dental de mandíbula (estructura corporal)', 'Structure of mandibular tooth socket (body structure)', '1251480001'),
('DNT-AN-000593', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de alvéolo dental maxilar (estructura corporal)', 'Structure of maxillary tooth socket (body structure)', '1251481002'),
('DNT-AN-000594', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio izquierdo de labio superior (estructura corporal)', 'Structure of left third of upper lip (body structure)', '1260451003'),
('DNT-AN-000595', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio medio de labio superior (estructura corporal)', 'Structure of middle third of upper lip (body structure)', '1260452005'),
('DNT-AN-000596', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio derecho de labio superior (estructura corporal)', 'Structure of right third of upper lip (body structure)', '1260453000'),
('DNT-AN-000597', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio derecho de labio inferior (estructura corporal)', 'Structure of right third of lower lip (body structure)', '1260454006'),
('DNT-AN-000598', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio medio de labio inferior (estructura corporal)', 'Structure of middle third of lower lip (body structure)', '1260455007'),
('DNT-AN-000599', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tercio izquierdo de labio inferior (estructura corporal)', 'Structure of left third of lower lip (body structure)', '1260456008'),
('DNT-AN-000600', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de triángulo submandibular izquierdo (estructura corporal)', 'Structure of left submandibular triangle (body structure)', '1279600008'),
('DNT-AN-000601', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de triángulo submandibular derecho (estructura corporal)', 'Structure of right submandibular triangle (body structure)', '1279602000'),
('DNT-AN-000602', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de periostio de maxilar inferior (estructura corporal)', 'Structure of periosteum of mandible (body structure)', '1290292000'),
('DNT-AN-000603', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de periostio de maxilar superior (estructura corporal)', 'Structure of periosteum of maxilla (body structure)', '1290293005'),
('DNT-AN-000604', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de esmalte de diente molar (estructura corporal)', 'Structure of enamel of molar tooth (body structure)', '1290401001'),
('DNT-AN-000605', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de esmalte dental de segundo molar deciduo (estructura corporal)', 'Structure of enamel of deciduous second molar tooth (body structure)', '1290403003'),
('DNT-AN-000606', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de esmalte de diente incisivo (estructura corporal)', 'Structure of enamel of incisor tooth (body structure)', '1290405005'),
('DNT-AN-000607', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto submandibular derecho (estructura corporal)', 'Structure of right submandibular duct (body structure)', '1304242005'),
('DNT-AN-000608', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de conducto submandibular izquierdo (estructura corporal)', 'Structure of left submandibular duct (body structure)', '1304243000'),
('DNT-AN-000609', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival trasplantada (estructura corporal)', 'Structure of transplanted salivary gland (body structure)', '1344814000'),
('DNT-AN-000610', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de cresta milohioidea (estructura corporal)', 'Structure of mylohyoid ridge (body structure)', '1348244001'),
('DNT-AN-000611', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de proceso glenoide de glándula parótida (estructura corporal)', 'Structure of glenoid process of parotid gland (body structure)', '1351360004'),
('DNT-AN-000612', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de proceso pterigoide de glándula parótida (estructura corporal)', 'Structure of pterygoid process of parotid gland (body structure)', '1351361000'),
('DNT-AN-000613', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de escotadura antegonial (estructura corporal)', 'Antegonial notch structure (body structure)', '1380422006'),
('DNT-AN-000614', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de eminencia canina de maxilar superior (estructura corporal)', 'Structure of canine eminence of maxilla (body structure)', '1381876005'),
('DNT-AN-000615', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de paladar duro (estructura corporal)', 'Part of hard palate (body structure)', '1382328002'),
('DNT-AN-000616', 'dentar-an', 'anatomy', 'CAT-AN', 'parte de úvula palatina (estructura corporal)', 'Part of uvula palatina (body structure)', '1384144003'),
('DNT-AN-000617', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de tejido duro de dientes (estructura corporal)', 'Structure of hard tissue of teeth (body structure)', '1389020004'),
('DNT-AN-000618', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de bermellón y mucosa de labio (estructura corporal)', 'Structure of border of vermilion and mucosa of lip (body structure)', '1395933001'),
('DNT-AN-000619', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de bermellón y mucosa de labio superior (estructura corporal)', 'Structure of border of vermilion and mucosa of upper lip (body structure)', '1395935008'),
('DNT-AN-000620', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de borde de bermellón y mucosa de labio inferior (estructura corporal)', 'Structure of border of vermilion and mucosa of lower lip (body structure)', '1395936009'),
('DNT-AN-000621', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival menor de parte interna de boca (estructura corporal)', 'Structure of minor salivary gland of internal mouth (body structure)', '1397380002'),
('DNT-AN-000622', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de glándula salival menor de orofaringe (estructura corporal)', 'Structure of minor salivary gland of oropharynx (body structure)', '1397381003'),
('DNT-AN-000623', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ángulo del lado izquierdo de la mandíbula (estructura corporal)', 'Structure of angle of left side of mandible (body structure)', '458621000124106'),
('DNT-AN-000624', 'dentar-an', 'anatomy', 'CAT-AN', 'estructura de ángulo del lado derecho de la mandíbula (estructura corporal)', 'Structure of angle of right side of mandible (body structure)', '458631000124109'),
('DNT-CL-000001', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'recesión gingival (trastorno)', 'Gingival recession (disorder)', '4356008'),
('DNT-CL-000002', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'herpes zóster (trastorno)', 'Herpes zoster (disorder)', '4740000'),
('DNT-CL-000003', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'síndrome de dentición (hallazgo)', 'Teething syndrome (finding)', '8004003'),
('DNT-CL-000004', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'dientes supernumerarios (trastorno)', 'Supernumerary teeth (disorder)', '8666004'),
('DNT-CL-000005', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'quiste dentígero (trastorno)', 'Dentigerous cyst (disorder)', '9245008'),
('DNT-CL-000006', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'ausencia congénita completa de dientes (trastorno)', 'Complete congenital absence of teeth (disorder)', '16958000'),
('DNT-CL-000007', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'anodoncia (trastorno)', 'Anodontia (disorder)', '26624006'),
('DNT-CL-000008', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'fractura de diente (trastorno)', 'Fracture of tooth (disorder)', '36202009'),
('DNT-CL-000009', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'trastorno de articulación temporomandibular (trastorno)', 'Temporomandibular joint disorder (disorder)', '41888000'),
('DNT-CL-000010', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'abrasión de diente (trastorno)', 'Friction injury of tooth (disorder)', '47222000'),
('DNT-CL-000011', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'resorción interna de diente (trastorno)', 'Internal resorption of tooth (disorder)', '52994003'),
('DNT-CL-000012', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'fricción excesiva de los dientes (trastorno)', 'Excessive attrition of teeth (disorder)', '53963006'),
('DNT-CL-000013', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diente primario persistente (trastorno)', 'Persistent primary tooth (disorder)', '57650002'),
('DNT-CL-000014', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'estomatitis (trastorno)', 'Stomatitis (disorder)', '61170000'),
('DNT-CL-000015', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'mordida abierta anterior (trastorno)', 'Anterior open bite (disorder)', '67289000'),
('DNT-CL-000016', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'candidiasis de la boca (trastorno)', 'Candidiasis of mouth (disorder)', '79740000'),
('DNT-CL-000017', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries del esmalte (trastorno)', 'Enamel caries (disorder)', '80353004'),
('DNT-CL-000018', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental (trastorno)', 'Dental caries (disorder)', '80967001'),
('DNT-CL-000019', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'xerostomía (hallazgo)', 'Xerostomia (finding)', '87715008'),
('DNT-CL-000020', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'enfermedad gingival causada por el embarazo (trastorno)', 'Gingival disease due to pregnancy (disorder)', '95212006'),
('DNT-CL-000021', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'mala oclusión, clase II de Angle (trastorno)', 'Malocclusion, Angle class II (disorder)', '109501002'),
('DNT-CL-000022', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'absceso apical crónico (trastorno)', 'Chronic apical abscess (disorder)', '109603007'),
('DNT-CL-000023', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'avulsión dental completa (trastorno)', 'Complete avulsion of tooth (disorder)', '109671008'),
('DNT-CL-000024', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'exostosis de la mandíbula hacia la región bucal (trastorno)', 'Exostosis of jaw toward buccal region (disorder)', '109700003'),
('DNT-CL-000025', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pérdida horizontal de hueso alveolar (trastorno)', 'Horizontal alveolar bone loss (disorder)', '109709002'),
('DNT-CL-000026', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pérdida vertical de hueso alveolar (trastorno)', 'Vertical alveolar bone loss (disorder)', '109710007'),
('DNT-CL-000027', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'restauración dental que ya no puede repararse (hallazgo)', 'Dental restoration cannot be expected to continue to be serviceable (finding)', '109743006'),
('DNT-CL-000028', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'consumidor de tabaco (hallazgo)', 'Tobacco user (finding)', '110483000'),
('DNT-CL-000029', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'mordida en cruz posterior (trastorno)', 'Posterior crossbite (disorder)', '111326002'),
('DNT-CL-000030', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'neuralgia atípica (hallazgo)', 'Atypical neuralgia (finding)', '112102006'),
('DNT-CL-000031', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'sin problema dental (situación)', 'No tooth problem (situation)', '162005007'),
('DNT-CL-000032', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'procedimiento de estudio radiográfico realizado (situación)', 'Radiographic imaging procedure carried out (situation)', '168496002'),
('DNT-CL-000033', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'dislocación de diente (trastorno)', 'Dislocation of tooth (disorder)', '210366009'),
('DNT-CL-000034', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'trastorno de la erupción dentaria (trastorno)', 'Tooth eruption disorder (disorder)', '234949000'),
('DNT-CL-000035', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caída dentaria prematura (trastorno)', 'Early tooth exfoliation (disorder)', '234974002'),
('DNT-CL-000036', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pólipo fibroepitelial gingival (trastorno)', 'Gingival fibroepithelial polyp (disorder)', '235001002'),
('DNT-CL-000037', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'lesión periodóncica y endodóncica (trastorno)', 'Periodontal and endodontic lesion (disorder)', '235006007'),
('DNT-CL-000038', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'queilitis angular (trastorno)', 'Angular cheilitis (disorder)', '266429005'),
('DNT-CL-000039', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'bruxismo durante el sueño (trastorno)', 'Sleep related bruxism (disorder)', '274950005'),
('DNT-CL-000040', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental inestable (hallazgo)', 'Denture unstable (finding)', '278630001'),
('DNT-CL-000041', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diente supernumerario (trastorno)', 'Supernumerary tooth (disorder)', '367534004'),
('DNT-CL-000042', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'síndrome de disfunción dolorosa de articulación temporomandibular (trastorno)', 'Temporomandibular joint-pain-dysfunction syndrome (disorder)', '386207004'),
('DNT-CL-000043', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'úlcera necrosante aguda de estructura gingival (trastorno)', 'Acute necrotizing ulcer of gingiva (disorder)', '399050001'),
('DNT-CL-000044', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'síndrome de ardor bucal (trastorno)', 'Burning mouth syndrome (disorder)', '399165002'),
('DNT-CL-000045', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'desplazamiento dental (trastorno)', 'Displacement of tooth (disorder)', '405258007'),
('DNT-CL-000046', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'dieta con alto contenido de azúcar (hallazgo)', 'High sugar diet (finding)', '412744006'),
('DNT-CL-000047', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'leucoplasia de la mucosa oral (trastorno)', 'Leukoplakia of oral mucosa (disorder)', '414603003'),
('DNT-CL-000048', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'arreglo dental perdido (hallazgo)', 'Dental restoration lost (finding)', '416673002'),
('DNT-CL-000049', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'malformación de diente (trastorno)', 'Malformation of tooth (disorder)', '422775003'),
('DNT-CL-000050', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'úlcera aftosa de la cavidad bucal (trastorno)', 'Aphthous ulcer of mouth (disorder)', '426965005'),
('DNT-CL-000051', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'hiperplasia de encías (trastorno)', 'Hyperplasia of gingiva (disorder)', '441798003'),
('DNT-CL-000052', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pérdida de todos los dientes (trastorno)', 'Loss of all teeth (disorder)', '441935006'),
('DNT-CL-000053', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'falla en la osteointegración de implante dental (trastorno)', 'Failure of osseointegration of dental implant (disorder)', '442437005'),
('DNT-CL-000054', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental que se extiende hasta la dentina (trastorno)', 'Dental caries extending into dentin (disorder)', '442551007'),
('DNT-CL-000055', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'hallazgo clínico posible (situación)', 'Possible clinical finding (situation)', '443859009'),
('DNT-CL-000056', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'edentulismo parcial (trastorno)', 'Partial edentulism (disorder)', '444818007'),
('DNT-CL-000057', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'encía adherida delgada (trastorno)', 'Thin attached gingiva (disorder)', '449785009'),
('DNT-CL-000058', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'apiñamiento de dientes inferiores anteriores (trastorno)', 'Crowding of anterior mandibular teeth (disorder)', '449789003'),
('DNT-CL-000059', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'apiñamiento de dientes superiores anteriores (trastorno)', 'Crowding of anterior maxillary teeth (disorder)', '449798000'),
('DNT-CL-000060', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'calificación del comportamiento según la escala de Frankl definidamente negativa (hallazgo)', 'Frankl behavioral rating definitely negative (finding)', '609370009'),
('DNT-CL-000061', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'escala de calificación del comportamiento de Frankl negativa (hallazgo)', 'Frankl behavioral rating negative (finding)', '609371008'),
('DNT-CL-000062', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'con bajo riesgo de caries dentales (hallazgo)', 'At low risk for dental caries (finding)', '609400006'),
('DNT-CL-000063', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'con riesgo moderado de caries dentales (hallazgo)', 'At moderate risk for dental caries (finding)', '609401005'),
('DNT-CL-000064', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'con alto riesgo de caries dental (hallazgo)', 'At high risk for dental caries (finding)', '609402003'),
('DNT-CL-000065', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'con riesgo extremo de caries dentales (hallazgo)', 'At extreme risk for dental caries (finding)', '609403008'),
('DNT-CL-000066', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'fractura de diente incompleta (trastorno)', 'Incomplete fracture of tooth (disorder)', '698039001'),
('DNT-CL-000067', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'metamorfosis calcificante de pulpa de diente (trastorno)', 'Calcific metamorphosis of pulp of tooth (disorder)', '698072001'),
('DNT-CL-000068', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'resalto dental aumentado (trastorno)', 'Increased overjet (disorder)', '699274002'),
('DNT-CL-000069', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periimplantitis dental (trastorno)', 'Dental peri-implantitis (disorder)', '699422003'),
('DNT-CL-000070', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'hiperoclusión (trastorno)', 'Hyperocclusion (disorder)', '699423008'),
('DNT-CL-000071', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diente cariado no restaurable (trastorno)', 'Nonrestorable carious tooth (disorder)', '699683004'),
('DNT-CL-000072', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'mucositis periimplante dental (trastorno)', 'Dental peri-implant mucositis (disorder)', '699684005'),
('DNT-CL-000073', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'surco oclusal profundo (hallazgo)', 'Deep occlusal groove (finding)', '699685006'),
('DNT-CL-000074', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'aflojamiento de tornillo de implante dental (trastorno)', 'Loosening of dental implant screw (disorder)', '699686007'),
('DNT-CL-000075', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'obliteración de conducto radicular de diente debido a mineralización anormal de pulpa dental (trastorno)', 'Obliteration of root canal of tooth due to abnormal mineralization of tooth pulp (disorder)', '699701005'),
('DNT-CL-000076', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'sobredentadura maxilar defectuosa (hallazgo)', 'Defective maxillary overdenture (finding)', '699709007'),
('DNT-CL-000077', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'sobredentadura mandibular defectuosa (hallazgo)', 'Defective mandibular overdenture (finding)', '699710002'),
('DNT-CL-000078', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental mandibular completa defectuosa (hallazgo)', 'Defective mandibular complete denture (finding)', '699711003'),
('DNT-CL-000079', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental maxilar completa defectuosa (hallazgo)', 'Defective maxillary complete denture (finding)', '699712005'),
('DNT-CL-000080', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental mandibular parcial removible defectuosa (hallazgo)', 'Defective mandibular removable partial denture (finding)', '699713000'),
('DNT-CL-000081', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental maxilar parcial removible defectuosa (hallazgo)', 'Defective maxillary removable partial denture (finding)', '699714006'),
('DNT-CL-000082', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'fractura vertical de diente sin compromiso de la pulpa (trastorno)', 'Vertical fracture of tooth without pulp involvement (disorder)', '699773007'),
('DNT-CL-000083', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'oclusión céntrica - discrepancia en la relación céntrica (trastorno)', 'Centric occlusion - Centric relation discrepancy (disorder)', '699777008'),
('DNT-CL-000084', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'fractura vertical de diente con compromiso de la pulpa (trastorno)', 'Vertical fracture of tooth extending into pulp of tooth (disorder)', '699816004'),
('DNT-CL-000085', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pérdida de relación oclusal con prótesis completa (hallazgo)', 'Loss of occlusal relationship with complete denture (finding)', '699828007'),
('DNT-CL-000086', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diente ectópico en surco labial (trastorno)', 'Ectopic tooth in labial sulcus (disorder)', '699853005'),
('DNT-CL-000087', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental parcial removible antiestética (hallazgo)', 'Removable partial denture not esthetic (finding)', '699856002'),
('DNT-CL-000088', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental completa no estética (hallazgo)', 'Complete denture not esthetic (finding)', '699857006'),
('DNT-CL-000089', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries en la primera infancia (trastorno)', 'Early childhood caries (disorder)', '702402003'),
('DNT-CL-000090', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'sobrextensión de prótesis dental completa (hallazgo)', 'Over extension of complete denture (finding)', '702529006'),
('DNT-CL-000091', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'sobrextensión de prótesis dental parcial removible (hallazgo)', 'Over extension of removable partial denture (finding)', '702530001'),
('DNT-CL-000092', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'alta provocación bacteriana (hallazgo)', 'High bacterial challenge (finding)', '702555007'),
('DNT-CL-000093', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'falla de cohesión de restauración dental (hallazgo)', 'Cohesive failure of dental restoration (finding)', '702645001'),
('DNT-CL-000094', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'falla de adhesivo de restauración dental (hallazgo)', 'Adhesive failure of dental restoration (finding)', '702745006'),
('DNT-CL-000095', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diente ectópico lingual (trastorno)', 'Lingual ectopic tooth (disorder)', '703132007'),
('DNT-CL-000096', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'fijación supracrestal insuficiente (trastorno)', 'Insufficient supracrestal attachment (disorder)', '703401001'),
('DNT-CL-000097', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'ausencia de encía queratinizada (trastorno)', 'Lack of keratinized gingiva (disorder)', '707219007'),
('DNT-CL-000098', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries cavitada (anomalía morfológica)', 'Cavitated caries (morphologic abnormality)', '708573003'),
('DNT-CL-000099', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries no cavitada (anomalía morfológica)', 'Non-cavitated caries (morphologic abnormality)', '708574009'),
('DNT-CL-000100', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries no activa (anomalía morfológica)', 'Non-active caries (morphologic abnormality)', '708577002'),
('DNT-CL-000101', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries activa (anomalía morfológica)', 'Active caries (morphologic abnormality)', '708578007'),
('DNT-CL-000102', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis dental parcial removible con pérdida de relación oclusal (hallazgo)', 'Removable partial denture with loss of occlusal relationship (finding)', '710783007'),
('DNT-CL-000103', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'prótesis parcial removible con pérdida de retención (hallazgo)', 'Removable partial denture with loss of retention (finding)', '710784001'),
('DNT-CL-000104', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries de fosas y fisuras (trastorno)', 'Pit and fissure caries (disorder)', '711173006'),
('DNT-CL-000105', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries de superficie lisa de diente (trastorno)', 'Caries of smooth surface of tooth (disorder)', '711175004'),
('DNT-CL-000106', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pérdida de dimensión de oclusión vertical debida a prótesis dental completa desgastada (hallazgo)', 'Loss of vertical dimension of occlusion due to worn complete denture (finding)', '711285008'),
('DNT-CL-000107', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'relación entre corona y raíz dental comprometida (hallazgo)', 'Compromised crown and root of tooth ratio (finding)', '711467003'),
('DNT-CL-000108', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'restauración dental biológicamente inaceptable (hallazgo)', 'Biologically unacceptable dental restoration (finding)', '711469000'),
('DNT-CL-000109', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'tejido periapical normal (hallazgo)', 'Normal periapical tissue (finding)', '711635006'),
('DNT-CL-000110', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pulpa de diente normal (hallazgo)', 'Normal pulp of tooth (finding)', '711636007'),
('DNT-CL-000111', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pulpitis irreversible sintomática (trastorno)', 'Symptomatic irreversible pulpitis (disorder)', '711638008'),
('DNT-CL-000112', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pulpitis irreversible asintomática (trastorno)', 'Asymptomatic irreversible pulpitis (disorder)', '711639000'),
('DNT-CL-000113', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pulpitis reversible asintomática (trastorno)', 'Asymptomatic reversible pulpitis (disorder)', '711640003'),
('DNT-CL-000114', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pulpitis reversible sintomática (trastorno)', 'Symptomatic reversible pulpitis (disorder)', '711641004'),
('DNT-CL-000115', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis debida a placa dental (trastorno)', 'Gingivitis due to dental plaque (disorder)', '713245008'),
('DNT-CL-000116', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis debida a placa dental con factor contribuyente local (trastorno)', 'Gingivitis due to dental plaque with local contributing factor (disorder)', '713879003'),
('DNT-CL-000117', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis generalizada (trastorno)', 'Generalized gingivitis (disorder)', '714126004'),
('DNT-CL-000118', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis leve (trastorno)', 'Mild gingivitis (disorder)', '714249007'),
('DNT-CL-000119', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis severa (trastorno)', 'Severe gingivitis (disorder)', '714477000'),
('DNT-CL-000120', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis moderada (trastorno)', 'Moderate gingivitis (disorder)', '714478005'),
('DNT-CL-000121', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'tejido periodontal normal (hallazgo)', 'Normal periodontal tissue (finding)', '714482007'),
('DNT-CL-000122', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis localizada (trastorno)', 'Localized gingivitis (disorder)', '714485009'),
('DNT-CL-000123', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'deformidad de la unión mucogingival (trastorno)', 'Deformity of mucogingival junction (disorder)', '714635005'),
('DNT-CL-000124', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis crónica localizada leve (trastorno)', 'Localized slight chronic periodontitis (disorder)', '715285004'),
('DNT-CL-000125', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis crónica moderada localizada (trastorno)', 'Localized moderate chronic periodontitis (disorder)', '715286003'),
('DNT-CL-000126', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis crónica localizada severa (trastorno)', 'Localized severe chronic periodontitis (disorder)', '715287007'),
('DNT-CL-000127', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'deformidad mucogingival sobre cresta alveolar desdentada debida a falta de encía queratinizada (trastorno)', 'Mucogingival deformity on edentulous ridge due to lack of keratinized gingiva (disorder)', '715838001'),
('DNT-CL-000128', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'tejido periodontal normal con pérdida de inserción (hallazgo)', 'Normal periodontal tissue with attachment loss (finding)', '715842003'),
('DNT-CL-000129', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis aguda localizada leve (trastorno)', 'Localized slight acute periodontitis (disorder)', '715843008'),
('DNT-CL-000130', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis aguda moderada localizada (trastorno)', 'Localized moderate acute periodontitis (disorder)', '715859008'),
('DNT-CL-000131', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis aguda severa localizada (trastorno)', 'Localized severe acute periodontitis (disorder)', '715860003'),
('DNT-CL-000132', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'radiolucidez radiográfica de diente (hallazgo)', 'Radiographic radiolucency of tooth (finding)', '716292004'),
('DNT-CL-000133', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'radiopacidad radiográfica de diente (hallazgo)', 'Radiographic radiopacity of tooth (finding)', '716293009'),
('DNT-CL-000134', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'restauración dental oclusal inadecuada (hallazgo)', 'Dental restoration occlusally inadequate (finding)', '716294003'),
('DNT-CL-000135', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'perforación de restauración dental (hallazgo)', 'Perforation of dental restoration (finding)', '716296001'),
('DNT-CL-000136', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'retención de dispositivo dental en diente después de procedimiento odontológico (trastorno)', 'Retention of dental device on tooth following dental procedure (disorder)', '716299008'),
('DNT-CL-000137', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'enfermedad gingival concomitante con diabetes mellitus (trastorno)', 'Gingival disease co-occurrent with diabetes mellitus (disorder)', '716362006'),
('DNT-CL-000138', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'con mayor riesgo de fractura de diente (hallazgo)', 'At increased risk of fracture of tooth (finding)', '716363001'),
('DNT-CL-000139', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries de borde cervical de diente (trastorno)', 'Caries of cervical margin of tooth (disorder)', '716364007'),
('DNT-CL-000140', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'lesión no cariada en margen cervical de diente (trastorno)', 'Non carious lesion at cervical margin of tooth (disorder)', '717062009'),
('DNT-CL-000141', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis periapical asintomática (trastorno)', 'Asymptomatic periapical periodontitis (disorder)', '718052004'),
('DNT-CL-000142', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis periapical sintomática (trastorno)', 'Symptomatic periapical periodontitis (disorder)', '718053009'),
('DNT-CL-000143', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis crónica generalizada leve (trastorno)', 'Generalized slight chronic periodontitis (disorder)', '718060003'),
('DNT-CL-000144', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis crónica generalizada severa (trastorno)', 'Generalized severe chronic periodontitis (disorder)', '718061004'),
('DNT-CL-000145', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis crónica moderada generalizada (trastorno)', 'Generalized moderate chronic periodontitis (disorder)', '718062006'),
('DNT-CL-000146', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis aguda generalizada leve (trastorno)', 'Generalized slight acute periodontitis (disorder)', '718064007'),
('DNT-CL-000147', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis aguda severa generalizada (trastorno)', 'Generalized severe acute periodontitis (disorder)', '718065008'),
('DNT-CL-000148', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis moderada aguda generalizada (trastorno)', 'Generalized moderate acute periodontitis (disorder)', '718066009'),
('DNT-CL-000149', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'liquen plano de encía (trastorno)', 'Lichen planus of gingiva (disorder)', '718068005'),
('DNT-CL-000150', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'membrana mucosa bucal y tejido óseo osteointegrado alrededor de implante dental normales (hallazgo)', 'Normal oral mucous membrane and osseointegrated bone tissue surrounding dental implant (finding)', '718070001'),
('DNT-CL-000151', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'tratamiento odontológico iniciado previamente completado (situación)', 'Previously initiated dental therapy completed (situation)', '718356008'),
('DNT-CL-000152', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diente permanente normal (hallazgo)', 'Permanent tooth normal (finding)', '718375003'),
('DNT-CL-000153', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'tratamiento endodóncico iniciado previamente completado (situación)', 'Previously initiated endodontic therapy completed (situation)', '718392007'),
('DNT-CL-000154', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'tratamiento odontológico iniciado previamente no completado (situación)', 'Previously initiated dental therapy not completed (situation)', '733035008'),
('DNT-CL-000155', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa primaria que se extiende hasta la mitad externa del esmalte (trastorno)', 'Primary active dental caries extending into outer half of enamel (disorder)', '733939000'),
('DNT-CL-000156', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa primaria que se extiende hasta la mitad interna del esmalte (trastorno)', 'Primary active dental caries extending into inner half of enamel (disorder)', '733940003'),
('DNT-CL-000157', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa primaria que se extiende hasta el tercio externo de la dentina (trastorno)', 'Primary active dental caries extending into outer third of dentin (disorder)', '733941004'),
('DNT-CL-000158', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa primaria que se extiende hasta el tercio medio de la dentina (trastorno)', 'Primary active dental caries extending into middle third of dentin (disorder)', '733942006'),
('DNT-CL-000159', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa primaria que se extiende hasta el tercio interno de la dentina (trastorno)', 'Primary active dental caries extending into inner third of dentin (disorder)', '733943001'),
('DNT-CL-000160', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa secundaria que se extiende hasta el tercio externo de la dentina (trastorno)', 'Secondary active dental caries extending into outer third of dentin (disorder)', '733946009'),
('DNT-CL-000161', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa secundaria que se extiende hasta el tercio medio de la dentina (trastorno)', 'Secondary active dental caries extending into middle third of dentin (disorder)', '733947000'),
('DNT-CL-000162', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa secundaria que se extiende hasta el tercio interno de la dentina (trastorno)', 'Secondary active dental caries extending into inner third of dentin (disorder)', '733948005'),
('DNT-CL-000163', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental primaria inactiva que se extiende hasta el tercio externo de la dentina (trastorno)', 'Primary non-active dental caries extending into outer third of dentin (disorder)', '733951003'),
('DNT-CL-000164', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental primaria inactiva que se extiende hasta el tercio medio de la dentina (trastorno)', 'Primary non-active dental caries extending into middle third of dentin (disorder)', '733952005'),
('DNT-CL-000165', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental inactiva secundaria que se extiende hasta la mitad externa del esmalte (trastorno)', 'Secondary non-active dental caries extending into outer half of enamel (disorder)', '733954006'),
('DNT-CL-000166', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental inactiva secundaria que se extiende hasta el tercio medio de la dentina (trastorno)', 'Secondary non-active dental caries extending into middle third of dentin (disorder)', '733958009'),
('DNT-CL-000167', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental primaria inactiva que se extiende hasta el tercio interno de la dentina (trastorno)', 'Primary non-active dental caries extending into inner third of dentin (disorder)', '733961005'),
('DNT-CL-000168', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental primaria inactiva que se extiende hasta la pulpa (trastorno)', 'Primary non-active dental caries extending into pulp (disorder)', '733978001'),
('DNT-CL-000169', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa primaria que se extiende hasta la pulpa (trastorno)', 'Primary active dental caries extending into pulp (disorder)', '733980007'),
('DNT-CL-000170', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries dental activa secundaria que se extiende hasta la pulpa (trastorno)', 'Secondary active dental caries extending into pulp (disorder)', '733982004'),
('DNT-CL-000171', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'separación de dientes (entidad observable)', 'Spacing of teeth (observable entity)', '734008008'),
('DNT-CL-000172', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diastema (hallazgo)', 'Diastema of teeth (finding)', '734009000'),
('DNT-CL-000173', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'hábito de higiene de la cavidad bucal perjudicial (hallazgo)', 'Harmful oral hygiene habit (finding)', '735237008'),
('DNT-CL-000174', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries cavitada activa de raíz dental (trastorno)', 'Active cavitated caries of tooth root (disorder)', '769017001'),
('DNT-CL-000175', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'caries no cavitada activa de raíz dental (trastorno)', 'Active non-cavitated caries of tooth root (disorder)', '769021008'),
('DNT-CL-000176', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'restauración completa de corona dental necesaria debida a tratamiento endodóncico previo (situación)', 'Full restoration of crown of tooth needed due to previous endodontic treatment (situation)', '769044006'),
('DNT-CL-000177', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis con patrón en molares e incisivos (trastorno)', 'Molar and incisor pattern periodontitis (disorder)', '787448000'),
('DNT-CL-000178', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'extracción de diente requerida (situación)', 'Extraction of tooth needed (situation)', '895213007'),
('DNT-CL-000179', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'hiperplasia fibroepitelial inflamatoria de membrana mucosa oral (trastorno)', 'Inflammatory fibroepithelial hyperplasia of oral mucous membrane (disorder)', '1137560004'),
('DNT-CL-000180', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'hiperplasia fibroepitelial inflamatoria de membrana mucosa oral causada por prótesis dental (trastorno)', 'Inflammatory fibroepithelial hyperplasia of oral mucous membrane caused by denture (disorder)', '1137562007'),
('DNT-CL-000181', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 1 grado C según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 1 Grade C (disorder)', '1149439000'),
('DNT-CL-000182', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 2 grado A según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 2 Grade A (disorder)', '1149440003'),
('DNT-CL-000183', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 2 grado B según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 2 Grade B (disorder)', '1149441004'),
('DNT-CL-000184', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 2 grado C según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 2 Grade C (disorder)', '1149442006'),
('DNT-CL-000185', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 3 grado A según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 3 Grade A (disorder)', '1149443001'),
('DNT-CL-000186', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 3 grado B según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 3 Grade B (disorder)', '1149444007'),
('DNT-CL-000187', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 3 grado C según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 3 Grade C (disorder)', '1149445008'),
('DNT-CL-000188', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 1 grado A según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 1 Grade A (disorder)', '1149446009'),
('DNT-CL-000189', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis localizada estadio 1 grado B según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions localized periodontitis Stage 1 Grade B (disorder)', '1149447000'),
('DNT-CL-000190', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 4 grado C según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 4 Grade C (disorder)', '1149448005'),
('DNT-CL-000191', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 4 grado B según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 4 Grade B (disorder)', '1149449002'),
('DNT-CL-000192', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 4 grado A según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 4 Grade A (disorder)', '1149450002'),
('DNT-CL-000193', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 3 grado B según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 3 Grade B (disorder)', '1149451003'),
('DNT-CL-000194', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 3 grado C según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 3 Grade C (disorder)', '1149452005'),
('DNT-CL-000195', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 3 grado A según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 3 Grade A (disorder)', '1149453000'),
('DNT-CL-000196', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 2 grado C según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 2 Grade C (disorder)', '1149455007'),
('DNT-CL-000197', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 2 grado B según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 2 Grade B (disorder)', '1149456008'),
('DNT-CL-000198', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 2 grado A según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 2 Grade A (disorder)', '1149457004'),
('DNT-CL-000199', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 1 grado C según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 1 Grade C (disorder)', '1149458009'),
('DNT-CL-000200', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 1 grado B según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 1 Grade B (disorder)', '1149459001'),
('DNT-CL-000201', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'periodontitis generalizada estadio 1 grado A según la Clasificación de las Enfermedades y Alteraciones Periodontales y Periimplantarias de 2017 de la Academia Estadounidense de Periodontología y la Federación Europea de Periodontología (trastorno)', 'American Academy of Periodontology and European Federation of Periodontology 2017 Classification of Periodontal and Peri‐implant Diseases and Conditions generalized periodontitis Stage 1 Grade A (disorder)', '1149460006'),
('DNT-CL-000202', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'opacidad de diente evidenciada en radiografía simple (hallazgo)', 'Opacity of tooth on plain X-ray (finding)', '1290857004'),
('DNT-CL-000203', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'radiolucencia de diente en radiografía simple (hallazgo)', 'Radiolucency of tooth on plain X-ray (finding)', '1290861005'),
('DNT-CL-000204', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'radiografía simple realizada (situación)', 'Plain X-ray done (situation)', '1295421002'),
('DNT-CL-000205', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis localizada debida a placa dental con tejido periodontal intacto (trastorno)', 'Localized gingivitis due to dental biofilm with intact periodontal tissue (disorder)', '1359925001'),
('DNT-CL-000206', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis generalizada con tejido periodontal reducido y periodontitis estable (trastorno)', 'Generalized gingivitis with reduced periodontal tissue and stable periodontitis (disorder)', '1359926000'),
('DNT-CL-000207', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis localizada con tejido periodontal disminuido sin periodontitis (trastorno)', 'Localized gingivitis with reduced periodontal tissue without periodontitis (disorder)', '1360031007'),
('DNT-CL-000208', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis localizada con tejido periodontal disminuido y periodontitis estable (trastorno)', 'Localized gingivitis with reduced periodontal tissue and stable periodontitis (disorder)', '1362081007'),
('DNT-CL-000209', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'gingivitis generalizada con tejido periodontal disminuido sin periodontitis (trastorno)', 'Generalized gingivitis with reduced periodontal tissue without periodontitis (disorder)', '1362082000'),
('DNT-CL-000210', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'diente no funcional (hallazgo)', 'Non-functional tooth (finding)', '1363166008'),
('DNT-CL-000211', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'dientes saludables (hallazgo)', 'Healthy teeth (finding)', '1363459003'),
('DNT-CL-000212', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'desarrollo y erupción normal de dientes (hallazgo)', 'Normal development and eruption of teeth (finding)', '1363465003'),
('DNT-CL-000213', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'recesión gingival limitada a caras facial y lingual de diente (trastorno)', 'Gingival recession limited to facial and lingual surfaces of tooth (disorder)', '1366139001'),
('DNT-CL-000214', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'pérdida de estabilidad de prótesis dental completa (hallazgo)', 'Loss of stability of complete denture (finding)', '1366182000'),
('DNT-CL-000215', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'absceso de encía (trastorno)', 'Abscess of gingiva (disorder)', '1370925005'),
('DNT-CL-000216', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'párulis (trastorno)', 'Parulis (disorder)', '1370926006'),
('DNT-CL-000217', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'dieta y hábitos alimentarios inapropiados (hallazgo)', 'Inappropriate diet and eating habits (finding)', '1181000119106'),
('DNT-CL-000218', 'dentar-cl', 'clinical_finding', 'CAT-CL', 'contorno de restauración dental existente biológicamente incompatible con la salud bucal (hallazgo)', 'Contour of existing restoration of tooth biologically incompatible with oral health (finding)', '1085741000119102');

-- 6. Publicación editorial.
INSERT INTO dentar_concept (catalog_id, code, concept_type, lifecycle_status)
SELECT dc.id, s.codigo, s.concept_type, 'active'
  FROM _dentar_an_cl_import s
  JOIN dentar_catalog dc ON dc.code = s.catalog_code
ON CONFLICT (code) DO UPDATE
   SET catalog_id = EXCLUDED.catalog_id,
       concept_type = EXCLUDED.concept_type,
       lifecycle_status = 'active';

INSERT INTO dentar_concept_version
    (concept_id, version_number, definition, approval_status)
SELECT c.id, 1, s.termino_es, 'approved'
  FROM _dentar_an_cl_import s
  JOIN dentar_concept c ON c.code = s.codigo
ON CONFLICT (concept_id, version_number) DO UPDATE
   SET definition = EXCLUDED.definition,
       approval_status = EXCLUDED.approval_status;

INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', s.termino_es, 'preferred'
  FROM _dentar_an_cl_import s
  JOIN dentar_concept c ON c.code = s.codigo
  JOIN dentar_concept_version cv ON cv.concept_id = c.id AND cv.version_number = 1
 WHERE NOT EXISTS (
    SELECT 1 FROM dentar_term t
     WHERE t.concept_version_id = cv.id
       AND t.language = 'es-AR'
       AND t.term = s.termino_es
       AND t.term_type = 'preferred'
 );

INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'en', s.termino_en, 'synonym'
  FROM _dentar_an_cl_import s
  JOIN dentar_concept c ON c.code = s.codigo
  JOIN dentar_concept_version cv ON cv.concept_id = c.id AND cv.version_number = 1
 WHERE NOT EXISTS (
    SELECT 1 FROM dentar_term t
     WHERE t.concept_version_id = cv.id
       AND t.language = 'en'
       AND t.term = s.termino_en
       AND t.term_type = 'synonym'
 );

INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
  FROM _dentar_an_cl_import s
  JOIN dentar_concept c ON c.code = s.codigo
  JOIN dentar_concept_version cv ON cv.concept_id = c.id AND cv.version_number = 1
  JOIN dentar_category cat ON cat.code = s.categoria
ON CONFLICT DO NOTHING;

INSERT INTO dentar_concept_mapping
    (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', s.sctid, s.termino_es, 'equivalent'
  FROM _dentar_an_cl_import s
  JOIN dentar_concept c ON c.code = s.codigo
  JOIN dentar_concept_version cv ON cv.concept_id = c.id AND cv.version_number = 1
ON CONFLICT (concept_version_id, system_code, external_code) DO UPDATE
   SET external_display = EXCLUDED.external_display,
       relationship = EXCLUDED.relationship;

-- 7. Publicación en el motor de catálogos.
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT c.id, s.codigo, 'active'
  FROM _dentar_an_cl_import s
  JOIN os_catalog c ON c.code = s.catalog_code
ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = EXCLUDED.status;

INSERT INTO os_catalog_item_version
    (item_id, release_id, category_id, preferred_term, definition, language_code)
SELECT i.id, rel.id, cat.id, s.termino_es, s.termino_es, 'es-AR'
  FROM _dentar_an_cl_import s
  JOIN os_catalog c ON c.code = s.catalog_code
  JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.codigo
  JOIN os_catalog_release rel ON rel.catalog_id = c.id AND rel.version_tag = 'snomed-ar-20260820'
  JOIN os_catalog_category cat ON cat.catalog_id = c.id AND cat.code = s.categoria
ON CONFLICT (item_id, release_id, language_code) DO UPDATE
   SET category_id = EXCLUDED.category_id,
       preferred_term = EXCLUDED.preferred_term,
       definition = EXCLUDED.definition;

INSERT INTO os_catalog_term (item_version_id, term, term_type, language_code)
SELECT v.id, s.termino_en, 'synonym', 'en'
  FROM _dentar_an_cl_import s
  JOIN os_catalog c ON c.code = s.catalog_code
  JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.codigo
  JOIN os_catalog_release rel ON rel.catalog_id = c.id AND rel.version_tag = 'snomed-ar-20260820'
  JOIN os_catalog_item_version v ON v.item_id = i.id AND v.release_id = rel.id AND v.language_code = 'es-AR'
 WHERE NOT EXISTS (
    SELECT 1 FROM os_catalog_term t
     WHERE t.item_version_id = v.id AND t.term = s.termino_en AND t.language_code = 'en'
 );

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SNOMED-CT', s.sctid, TRUE
  FROM _dentar_an_cl_import s
  JOIN os_catalog c ON c.code = s.catalog_code
  JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.codigo
ON CONFLICT (item_id, system_name, value) DO UPDATE SET is_primary = EXCLUDED.is_primary;

COMMIT;

-- Verificación posterior sugerida (no ejecutar automáticamente):
-- SELECT c.code, count(*) FROM os_catalog_item i JOIN os_catalog c ON c.id=i.catalog_id
--  WHERE c.code IN ('dentar-an','dentar-cl') GROUP BY c.code ORDER BY c.code;
