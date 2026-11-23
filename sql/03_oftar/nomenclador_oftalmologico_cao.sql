-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Familia OFTAR
-- sql/03_oftar/nomenclador_oftalmologico_cao.sql
-- =============================================================================
--
-- EJECUCIÓN EN EL VPS (el rol `root` no existe en PostgreSQL):
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/03_oftar/nomenclador_oftalmologico_cao.sql
--
-- Generado por tools/generate_nomencladores_oftalmologicos_sql.py desde
-- tools/sources/oftar/cao.csv. NO EDITAR A MANO; volver a generar.
--
-- ORDEN DE CARGA EN `origen_codes`
--   1) sql/03_oftar/nomencladores_oftar_mapping.sql
--   2) sql/03_oftar/nomenclador_oftalmologico_cao.sql
--   3) el otro nomenclador (cao / regional)
--   4) sql/03_oftar/aprobar_mapeo_nomencladores_oftar.sql
--      (tras revisar la tabla de mapeo y aprobar preferred_term)
--
-- QUÉ HACE
--   · Publica el nomenclador como catálogo de origen de la familia OFTAR con
--     su numeración original como código permanente. No crea códigos OFT-PR.
--   · Conserva espejo de la fuente SIN ninguna columna de precio.
--   · Carga categorías literales y versiones es-AR con preferred_term literal.
--   · Siembra propuestas de mapeo contra oftar-pr; NO publica enlaces.
--
-- QUÉ NO HACE
--   · No guarda valor, honorario_medico, gasto ni valor_total.
--   · No publica definition ni external_display: quedan NULL.
--   · No declara equivalencia clínica: los pares son solo propuestas.
--   · No crea UVR, dominios ni rutas. No usa DROP ... CASCADE ni
--     ALTER DEFAULT PRIVILEGES. Idempotente: se puede repetir sin duplicar.
-- =============================================================================
BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

DO $$
BEGIN
    IF to_regclass('public.os_oftar_nomenclador_match') IS NULL THEN
        RAISE EXCEPTION 'Falta la tabla de mapeo gobernado.'
            USING HINT = 'Aplicar primero sql/03_oftar/nomencladores_oftar_mapping.sql.';
    END IF;
END $$;

-- -----------------------------------------------------------------------------
-- 1. Espejo de la fuente: solo identificación y agrupamiento, SIN PRECIOS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.os_source_oftar_cao (
    codigo VARCHAR(20) PRIMARY KEY,
    descripcion TEXT NOT NULL,
    categoria VARCHAR(150),
    subcategoria VARCHAR(150),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.os_source_oftar_cao IS
    'Espejo literal de la fuente oftalmológica. No contiene columnas de precio.';

REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_cao FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_cao FROM origen_admin';
        EXECUTE 'GRANT SELECT ON TABLE public.os_source_oftar_cao TO origen_admin';
    END IF;
    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_cao FROM origen_med';
        EXECUTE 'GRANT SELECT ON TABLE public.os_source_oftar_cao TO origen_med';
    END IF;
    IF to_regrole('origen_api') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_cao FROM origen_api';
        EXECUTE 'GRANT SELECT ON TABLE public.os_source_oftar_cao TO origen_api';
    END IF;
END $$;

DELETE FROM public.os_source_oftar_cao;

INSERT INTO public.os_source_oftar_cao (codigo, descripcion, categoria, subcategoria) VALUES
    ('460001', 'Primera consulta', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460002', 'Segunda consulta (seguimiento de patología)', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460003', 'Consulta de urgencia (fuera del horario de consultorio, de 20:00 a 08:00 hs.)', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460004', 'Consulta a domicilio (con traslado de aparatos)', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460006', 'Consulta pediátrica (hasta 14 años)', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460007', 'Consulta o interconsulta en internación con equipos', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460008', 'Consulta de seguimiento en internación', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460009', 'Consulta retinólogo - Avalada por SARVy y CAO', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460010', 'Consulta neuroftalmológica - Avalada por Comisión de Neuroftalmología del CAO', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460011', 'Consulta con subespecialista', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460012', 'Consulta por vía electrónica', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460013', 'Consulta vía e-mail', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460014', 'Realización de informes y/o resúmenes de historia clínica', 'CONSULTA OFTALMOLÓGICA', NULL),
    ('460101', 'Módulo de estudios bajo anestesia general (más estudios a realizar)', 'EXAMEN ESPECIAL', NULL),
    ('460102', 'Inyección subconjuntiva o subtenoniana (no incluye fármacos e insumos)', 'EXAMEN ESPECIAL', NULL),
    ('460103', 'Campimetría computarizada bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460104', 'RG bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460105', 'RFG bilateral (no incluye fluoresceína, descartables, cardiólogo ni anestesista)', 'EXAMEN ESPECIAL', NULL),
    ('460106', 'RG digital unilateral sin descartables', 'EXAMEN ESPECIAL', NULL),
    ('460107', 'RFG digital unilateral sin descartables', 'EXAMEN ESPECIAL', NULL),
    ('460108', 'Ecografía A o B unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460109', 'Ecobiometría unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460110', 'Ecobiometría por inmersión unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460111', 'Neumotonometría unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460112', 'Paquimetría bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460113', 'Topografía corneal computada bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460114', 'Visión cromática (Fansworth, Roth o similar)', 'EXAMEN ESPECIAL', NULL),
    ('460115', 'Test de ojo seco (Schirmer, Rosa de Bengala, BUT)', 'EXAMEN ESPECIAL', NULL),
    ('460116', 'Test de sensibilidad de contraste unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460117', 'Ejercicio ortópico por sesión bilateral con sinoptóforo', 'EXAMEN ESPECIAL', NULL),
    ('460118', 'Examen sensorio motor en estrabismo', 'EXAMEN ESPECIAL', NULL),
    ('460119', 'OCT (tomografía óptica coherente) posterior unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460120', 'OCT (tomografía óptica coherente) anterior bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460121', 'Test de citología de impresión (no incluye anatomopatólogo)', 'EXAMEN ESPECIAL', NULL),
    ('460123', 'Test de mirada preferencial unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460124', 'Test de Lotmar (unilateral)', 'EXAMEN ESPECIAL', NULL),
    ('460125', 'Curva diaria de presión ocular', 'EXAMEN ESPECIAL', NULL),
    ('460126', 'Curva diaria de presión ocular según Sampaolesi', 'EXAMEN ESPECIAL', NULL),
    ('460127', 'Refractometría (con autorefractómetro digital) bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460128', 'FDT (perimetría doble frecuencia) unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460129', 'UBM (biomicroscopía ultrasónica) unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460130', 'Fondo de ojo con lente de tres espejos unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460131', 'Aberrometría bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460132', 'Biometría por interferometría laser (IOL Master, Lenstar, Pentacam AXL)', 'EXAMEN ESPECIAL', NULL),
    ('460134', 'Microscopia especular (con recuento endotelial celular de córnea)', 'EXAMEN ESPECIAL', NULL),
    ('460135', 'Angio OCT bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460136', 'Angio OCT bilateral de campo amplio', 'EXAMEN ESPECIAL', NULL),
    ('460137', 'Examen de prematuros (hasta 120 días de vida, por consulta)', 'EXAMEN ESPECIAL', NULL),
    ('460138', 'HRT (tomografía confocal de retina) unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460139', 'Ecobiometría de no contacto, de coherencia óptica, unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460140', 'Medida de poder corneal central unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460142', 'Recuento endotelial unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460143', 'Exoftalmometría con Heartel', 'EXAMEN ESPECIAL', NULL),
    ('460144', 'Tonometría de aires unilateral-neumotonometría', 'EXAMEN ESPECIAL', NULL),
    ('460145', 'Oftalmoscopia binocular indirecta unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460146', 'Gonioscopia con lente tres o 4 espejos unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460148', 'Test de Lancaster unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460149', 'Test de ducciones pasivas unilateral', 'EXAMEN ESPECIAL', NULL),
    ('460150', 'HD Analizer unilateral Scattering y calidad visual', 'EXAMEN ESPECIAL', NULL),
    ('460151', 'HD Analizer unilizer unilateral función de film lagrimal', 'EXAMEN ESPECIAL', NULL),
    ('460153', 'Campimetría dinámica (con campímetro de Goldmann) bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460154', 'Electroretinograma', 'EXAMEN ESPECIAL', NULL),
    ('460155', 'Electroretinograma multifocal', 'EXAMEN ESPECIAL', NULL),
    ('460156', 'Potenciales evocados bilateral', 'EXAMEN ESPECIAL', NULL),
    ('460157', 'Meibomiografía (por ojo)', 'EXAMEN ESPECIAL', NULL),
    ('460158', 'Topografía Posterior (por ojo)', 'EXAMEN ESPECIAL', NULL),
    ('460159', 'Test de sobrecarga hídrica', 'EXAMEN ESPECIAL', NULL),
    ('460160', 'Extracción de cuerpo extraño subtarsal', 'EXAMEN ESPECIAL', NULL),
    ('460161', 'Sesiones de estimulación visual', 'EXAMEN ESPECIAL', NULL),
    ('460201', 'Lesiones maculares (edema macular diabético)', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460202', 'Lesiones vasculares con isquemia en 1 cuadrante - tratamiento completo', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460203', 'Desgarros y agujeros de retina', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460204', 'YAG Láser (capsulotomía posterior 2 sesiones incluidas) - tratamiento completo', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460205', 'Trabeculoplastia, iridotomía, iridoplastia (láser de argón)', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460206', 'Láser mediante oftalmoscopia binocular indirecta', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460207', 'Láser mediante oftalmoscopia binocular indirecta en prematuros en sala de neonatología', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460215', 'SLT trabeculoplastia selectiva para glaucoma unilateral', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460216', 'Suturolitis con YAG', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión', NULL),
    ('460208', 'Lesiones vasculares con isquemia en 2 o más cuadrantes', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren 2 o más sesiones - valor por sesión', NULL),
    ('460209', 'Obstrucciones vasculares (con isquemia en más de 3 cuadrantes)', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren 2 o más sesiones - valor por sesión', NULL),
    ('460210', 'Retinopatía diabética severa (panfotocoagulación)', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren 2 o más sesiones - valor por sesión', NULL),
    ('460211', 'Trombosis de vena central tipo isquémica', 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren 2 o más sesiones - valor por sesión', NULL),
    ('460301', 'Chalazón, resección de lesiones de piel', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460302', 'Entropión, ectropión, blefaroplastia no cosmética', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460303', 'Ptosis en adulto, retracción de párpado, colocación pesa de oro, reparación trauma palpebral (sin descartables ni implante)', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460305', 'Reconstrucción de párpados simple', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460306', 'Tratamiento inyectable con Botox (en quirófano - no incluye fármaco)', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460307', 'Reconstrucción de párpado compleja (tumor)', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460308', 'Cirugía de distiquiasis', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460310', 'Ptosis en niños, reconstrucciones de más de 50% del párpado, reposicionamiento de cejas', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460311', 'Biopsia de párpado', 'OPERACIÓN DE PÁRPADO UNILATERAL', NULL),
    ('460401', 'Escisión lesión conjuntival (pterigión, nevus, epitelioma, quiste)', 'OPERACIÓN DE CONJUNTIVA UNILATERAL', NULL),
    ('460402', 'Conjuntivoplastia (+ flapping, recubrimiento conjuntival de córnea)', 'OPERACIÓN DE CONJUNTIVA UNILATERAL', NULL),
    ('460403', 'Peritomía, peritectomía', 'OPERACIÓN DE CONJUNTIVA UNILATERAL', NULL),
    ('460404', 'Sutura conjuntiva - biopsia de conjuntiva', 'OPERACIÓN DE CONJUNTIVA UNILATERAL', NULL),
    ('460405', 'Conjuntivoplastia con injerto de limbo', 'OPERACIÓN DE CONJUNTIVA UNILATERAL', NULL),
    ('460406', 'Biopsia de conjuntiva', 'OPERACIÓN DE CONJUNTIVA UNILATERAL', NULL),
    ('460407', 'Sutura de conjuntiva', 'OPERACIÓN DE CONJUNTIVA UNILATERAL', NULL),
    ('460212', 'Cirugía refractiva con excimer láser (unilateral) LASIK', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460213', 'Láser femto asociado a cualquier práctica', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460214', 'Cirugía refractiva con excimer láser (unilateral) PRK', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460313', 'Sutura de córnea (con prolapso de iris)', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460325', 'Queratoplastia penetrante', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460326', 'Queratoplastia laminar', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460327', 'Trasplante endotelial (por presupuesto)', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460328', 'Implante de anillos intracorneales (no incluye descartables, láser femto ni anillo)', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460329', 'Crosslinking unilateral', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460330', 'Sutura de córnea (sin prolapso de iris)', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460331', 'Queratocentesis - cauterización - toma de material', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460332', 'Ablación de córnea y esclera limbar y reparación cosmética de cierre palpebral (en procedimiento de donación de órganos)', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460333', 'Recubrimiento con membrana amniótica', 'OPERACIÓN DE CÓRNEA UNILATERAL', NULL),
    ('460501', 'Estrabismo (toda técnica o cantidad de músculos - no incluye monitoreo, anestesia ni remedios)', 'OPERACIÓN DE MÚSCULO EXTRAOCULAR UNILATERAL', NULL),
    ('460502', 'Estrabismo unilateral con sutura reajustable', 'OPERACIÓN DE MÚSCULO EXTRAOCULAR UNILATERAL', NULL),
    ('460601', 'Iridectomía, iridotomía, coreoplastía', 'OPERACIÓN DE IRIS Y CUERPO CILIAR UNILATERAL', NULL),
    ('460602', 'Iridociclectomía o iridociclotomía por tumores', 'OPERACIÓN DE IRIS Y CUERPO CILIAR UNILATERAL', NULL),
    ('460603', 'Trabeculectomía - viscocanalostomía (no incluye dispositivos migs)', 'OPERACIÓN DE IRIS Y CUERPO CILIAR UNILATERAL', NULL),
    ('460604', 'Implante de dispositivo de drenaje (no incluye válvula)', 'OPERACIÓN DE IRIS Y CUERPO CILIAR UNILATERAL', NULL),
    ('460605', 'Endociclo Fotocoagulación', 'OPERACIÓN DE IRIS Y CUERPO CILIAR UNILATERAL', NULL),
    ('461206', 'Dacriocistorinostomía con láser', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461207', 'Dacriorinostomía con tubo de Jones (no incluye tubo)', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461208', 'Reubicación de tubo de Jones después de los 30 días', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461209', 'Sondaje lagrimal con anestesia local', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461210', 'Exfoliación, canalización e inyección de sustancias en glándulas de Meibomio', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461211', 'Estudio de las glándulas de Meibomio, capa líquidos, NIBUT con imágenes infrarrojas', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461212', 'Estudio parasitológico de pestañas (demódex)', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461213', 'Dacriocistorinostomía endoscópica', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461214', 'Canuloplastia', 'OPERACIÓN DE VÍAS LAGRIMALES', NULL),
    ('461301', 'Extracción cuerpo extraño subconjuntival o subtenoniano', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461302', 'Extracción de cuerpo extraño intracorneal', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461304', 'Herida perforante con cuerpo extraño en cámara anterior', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461305', 'Lavado de cámara anterior (como única operación)', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461306', 'Herida perforante con lesión de córnea, esclera, iris y cristalino (puede ir LIO)', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461307', 'Herida perforante c/ cuerpo extraño intraocular q/ requiera extracción y procedimientos s/ retina y/o vitreo (láser, gas, aceite)', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461308', 'Sutura de herida palpebral sin compromiso de vía lagrimal', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461309', 'Sutura herida palpebral c/ compromiso vía lagrimal (intubación c/ silicón y extracción a los 2 meses)', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461311', 'Herida escleral + 4mm por detrás del limbo q/ requiera tratamiento profiláctico de DR (implante silicón, crio, diatermia, láser)', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461312', 'Fractura de piso orbitario (no incluye prótesis)', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461313', 'Lipectomía uni o bilateral', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461314', 'Descompresión uni o bilateral', 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL', NULL),
    ('461401', 'Primera consulta de baja visión - Diagnóstico y receta de lentes especiales y/o ayudas', 'MÓDULO BAJA VISIÓN BILATERAL Y LENTES DE CONTACTO', NULL),
    ('461402', 'Consultas siguientes (seguimiento de patología)', 'MÓDULO BAJA VISIÓN BILATERAL Y LENTES DE CONTACTO', NULL),
    ('461403', 'Adaptación de lentes de contacto', 'MÓDULO BAJA VISIÓN BILATERAL Y LENTES DE CONTACTO', NULL),
    ('461404', 'Eventuales controles post adaptación', 'MÓDULO BAJA VISIÓN BILATERAL Y LENTES DE CONTACTO', NULL);

-- -----------------------------------------------------------------------------
-- 2. Catálogo de origen dentro de la familia OFTAR
-- -----------------------------------------------------------------------------
INSERT INTO public.os_catalog
    (code, name, organization, country_code, domain_type, family_code,
     product_role, short_name, description, is_active)
VALUES (
    'nomenclador-oftalmologico-cao-ar',
    'Nomenclador Nacional de Oftalmología · Consejo Argentino de Oftalmología',
    'Consejo Argentino de Oftalmología (CAO)',
    'AR', 'medical', 'oftar', 'catalog', 'NOM-CAO-AR',
    'Nomenclador oftalmológico de origen. Publica su numeración histórica y se vincula a OFT-PR solo por mapeo gobernado; sin precios, sin UVR y sin equivalencia clínica asumida.',
    TRUE
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    organization = EXCLUDED.organization,
    family_code = EXCLUDED.family_code,
    product_role = EXCLUDED.product_role,
    short_name = EXCLUDED.short_name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

-- La fecha registra la carga, no una fecha normativa declarada por la fuente.
INSERT INTO public.os_catalog_release
    (catalog_id, version_tag, valid_from, official_norm_reference, status)
SELECT id, 'NOM-CAO-AR-v1', CURRENT_DATE, 'Fuente: tools/sources/oftar/cao.csv', 'published'
  FROM public.os_catalog WHERE code = 'nomenclador-oftalmologico-cao-ar'
ON CONFLICT (catalog_id, version_tag) DO UPDATE SET
    status = EXCLUDED.status,
    official_norm_reference = EXCLUDED.official_norm_reference;

-- -----------------------------------------------------------------------------
-- 3. Categorías: agrupamientos literales de la fuente (no categorías internas)
-- -----------------------------------------------------------------------------
CREATE TEMP TABLE _oftar_source_categoria (
    code VARCHAR(50) PRIMARY KEY,
    parent_code VARCHAR(50),
    name VARCHAR(150) NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE _oftar_source_clasificacion (
    codigo VARCHAR(20) PRIMARY KEY,
    categoria_code VARCHAR(50) NOT NULL
) ON COMMIT DROP;

INSERT INTO _oftar_source_categoria (code, parent_code, name) VALUES
    ('consulta-oftalmologica-6554a637', NULL, 'CONSULTA OFTALMOLÓGICA'),
    ('examen-especial-7086e6fd', NULL, 'EXAMEN ESPECIAL'),
    ('modulo-baja-vision-bilateral-y-lentes-de--cc5ab383', NULL, 'MÓDULO BAJA VISIÓN BILATERAL Y LENTES DE CONTACTO'),
    ('operacion-de-conjuntiva-unilateral-63798851', NULL, 'OPERACIÓN DE CONJUNTIVA UNILATERAL'),
    ('operacion-de-cornea-unilateral-17e8a1db', NULL, 'OPERACIÓN DE CÓRNEA UNILATERAL'),
    ('operacion-de-iris-y-cuerpo-ciliar-unilate-ad2cef7a', NULL, 'OPERACIÓN DE IRIS Y CUERPO CILIAR UNILATERAL'),
    ('operacion-de-musculo-extraocular-unilater-5a1e05be', NULL, 'OPERACIÓN DE MÚSCULO EXTRAOCULAR UNILATERAL'),
    ('operacion-de-parpado-unilateral-f568d5d9', NULL, 'OPERACIÓN DE PÁRPADO UNILATERAL'),
    ('operacion-de-vias-lagrimales-14656dc8', NULL, 'OPERACIÓN DE VÍAS LAGRIMALES'),
    ('operacion-por-trauma-ocular-unilateral-a36d1a50', NULL, 'OPERACIÓN POR TRAUMA OCULAR UNILATERAL'),
    ('tratamiento-con-laser-unilateral-patologi-200fcc23', NULL, 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren 2 o más sesiones - valor por sesión'),
    ('tratamiento-con-laser-unilateral-patologi-5fd67d9f', NULL, 'TRATAMIENTO CON LÁSER UNILATERAL - Patologías que requieren una sola sesión');

INSERT INTO _oftar_source_clasificacion (codigo, categoria_code) VALUES
    ('460001', 'consulta-oftalmologica-6554a637'),
    ('460002', 'consulta-oftalmologica-6554a637'),
    ('460003', 'consulta-oftalmologica-6554a637'),
    ('460004', 'consulta-oftalmologica-6554a637'),
    ('460006', 'consulta-oftalmologica-6554a637'),
    ('460007', 'consulta-oftalmologica-6554a637'),
    ('460008', 'consulta-oftalmologica-6554a637'),
    ('460009', 'consulta-oftalmologica-6554a637'),
    ('460010', 'consulta-oftalmologica-6554a637'),
    ('460011', 'consulta-oftalmologica-6554a637'),
    ('460012', 'consulta-oftalmologica-6554a637'),
    ('460013', 'consulta-oftalmologica-6554a637'),
    ('460014', 'consulta-oftalmologica-6554a637'),
    ('460101', 'examen-especial-7086e6fd'),
    ('460102', 'examen-especial-7086e6fd'),
    ('460103', 'examen-especial-7086e6fd'),
    ('460104', 'examen-especial-7086e6fd'),
    ('460105', 'examen-especial-7086e6fd'),
    ('460106', 'examen-especial-7086e6fd'),
    ('460107', 'examen-especial-7086e6fd'),
    ('460108', 'examen-especial-7086e6fd'),
    ('460109', 'examen-especial-7086e6fd'),
    ('460110', 'examen-especial-7086e6fd'),
    ('460111', 'examen-especial-7086e6fd'),
    ('460112', 'examen-especial-7086e6fd'),
    ('460113', 'examen-especial-7086e6fd'),
    ('460114', 'examen-especial-7086e6fd'),
    ('460115', 'examen-especial-7086e6fd'),
    ('460116', 'examen-especial-7086e6fd'),
    ('460117', 'examen-especial-7086e6fd'),
    ('460118', 'examen-especial-7086e6fd'),
    ('460119', 'examen-especial-7086e6fd'),
    ('460120', 'examen-especial-7086e6fd'),
    ('460121', 'examen-especial-7086e6fd'),
    ('460123', 'examen-especial-7086e6fd'),
    ('460124', 'examen-especial-7086e6fd'),
    ('460125', 'examen-especial-7086e6fd'),
    ('460126', 'examen-especial-7086e6fd'),
    ('460127', 'examen-especial-7086e6fd'),
    ('460128', 'examen-especial-7086e6fd'),
    ('460129', 'examen-especial-7086e6fd'),
    ('460130', 'examen-especial-7086e6fd'),
    ('460131', 'examen-especial-7086e6fd'),
    ('460132', 'examen-especial-7086e6fd'),
    ('460134', 'examen-especial-7086e6fd'),
    ('460135', 'examen-especial-7086e6fd'),
    ('460136', 'examen-especial-7086e6fd'),
    ('460137', 'examen-especial-7086e6fd'),
    ('460138', 'examen-especial-7086e6fd'),
    ('460139', 'examen-especial-7086e6fd'),
    ('460140', 'examen-especial-7086e6fd'),
    ('460142', 'examen-especial-7086e6fd'),
    ('460143', 'examen-especial-7086e6fd'),
    ('460144', 'examen-especial-7086e6fd'),
    ('460145', 'examen-especial-7086e6fd'),
    ('460146', 'examen-especial-7086e6fd'),
    ('460148', 'examen-especial-7086e6fd'),
    ('460149', 'examen-especial-7086e6fd'),
    ('460150', 'examen-especial-7086e6fd'),
    ('460151', 'examen-especial-7086e6fd'),
    ('460153', 'examen-especial-7086e6fd'),
    ('460154', 'examen-especial-7086e6fd'),
    ('460155', 'examen-especial-7086e6fd'),
    ('460156', 'examen-especial-7086e6fd'),
    ('460157', 'examen-especial-7086e6fd'),
    ('460158', 'examen-especial-7086e6fd'),
    ('460159', 'examen-especial-7086e6fd'),
    ('460160', 'examen-especial-7086e6fd'),
    ('460161', 'examen-especial-7086e6fd'),
    ('460201', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460202', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460203', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460204', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460205', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460206', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460207', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460215', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460216', 'tratamiento-con-laser-unilateral-patologi-5fd67d9f'),
    ('460208', 'tratamiento-con-laser-unilateral-patologi-200fcc23'),
    ('460209', 'tratamiento-con-laser-unilateral-patologi-200fcc23'),
    ('460210', 'tratamiento-con-laser-unilateral-patologi-200fcc23'),
    ('460211', 'tratamiento-con-laser-unilateral-patologi-200fcc23'),
    ('460301', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460302', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460303', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460305', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460306', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460307', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460308', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460310', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460311', 'operacion-de-parpado-unilateral-f568d5d9'),
    ('460401', 'operacion-de-conjuntiva-unilateral-63798851'),
    ('460402', 'operacion-de-conjuntiva-unilateral-63798851'),
    ('460403', 'operacion-de-conjuntiva-unilateral-63798851'),
    ('460404', 'operacion-de-conjuntiva-unilateral-63798851'),
    ('460405', 'operacion-de-conjuntiva-unilateral-63798851'),
    ('460406', 'operacion-de-conjuntiva-unilateral-63798851'),
    ('460407', 'operacion-de-conjuntiva-unilateral-63798851'),
    ('460212', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460213', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460214', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460313', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460325', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460326', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460327', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460328', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460329', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460330', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460331', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460332', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460333', 'operacion-de-cornea-unilateral-17e8a1db'),
    ('460501', 'operacion-de-musculo-extraocular-unilater-5a1e05be'),
    ('460502', 'operacion-de-musculo-extraocular-unilater-5a1e05be'),
    ('460601', 'operacion-de-iris-y-cuerpo-ciliar-unilate-ad2cef7a'),
    ('460602', 'operacion-de-iris-y-cuerpo-ciliar-unilate-ad2cef7a'),
    ('460603', 'operacion-de-iris-y-cuerpo-ciliar-unilate-ad2cef7a'),
    ('460604', 'operacion-de-iris-y-cuerpo-ciliar-unilate-ad2cef7a'),
    ('460605', 'operacion-de-iris-y-cuerpo-ciliar-unilate-ad2cef7a'),
    ('461206', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461207', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461208', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461209', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461210', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461211', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461212', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461213', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461214', 'operacion-de-vias-lagrimales-14656dc8'),
    ('461301', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461302', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461304', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461305', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461306', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461307', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461308', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461309', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461311', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461312', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461313', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461314', 'operacion-por-trauma-ocular-unilateral-a36d1a50'),
    ('461401', 'modulo-baja-vision-bilateral-y-lentes-de--cc5ab383'),
    ('461402', 'modulo-baja-vision-bilateral-y-lentes-de--cc5ab383'),
    ('461403', 'modulo-baja-vision-bilateral-y-lentes-de--cc5ab383'),
    ('461404', 'modulo-baja-vision-bilateral-y-lentes-de--cc5ab383');

INSERT INTO public.os_catalog_category (catalog_id, code, name, parent_category_id)
SELECT c.id, k.code, k.name,
       (SELECT p.id FROM public.os_catalog_category p
          WHERE p.catalog_id = c.id AND p.code = k.parent_code)
  FROM public.os_catalog c CROSS JOIN _oftar_source_categoria k
 WHERE c.code = 'nomenclador-oftalmologico-cao-ar'
ON CONFLICT (catalog_id, code) DO UPDATE SET
    name = EXCLUDED.name,
    parent_category_id = EXCLUDED.parent_category_id;

-- -----------------------------------------------------------------------------
-- 4. Ítems y versiones: el código original es el código permanente
-- -----------------------------------------------------------------------------
INSERT INTO public.os_catalog_item (catalog_id, permanent_code, status)
SELECT c.id, s.codigo, 'active'
  FROM public.os_source_oftar_cao s CROSS JOIN public.os_catalog c
 WHERE c.code = 'nomenclador-oftalmologico-cao-ar'
ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = 'active';

INSERT INTO public.os_catalog_item_version
    (item_id, release_id, category_id, preferred_term, definition, clinical_criteria,
     language_code, source_language_code, language_evidence, provenance,
     review_status, source_reference, valid_from)
SELECT i.id, r.id, cat.id, left(s.descripcion, 255), NULL, NULL,
       'es-AR', 'es-AR', 'explicit', 'imported_oftar_cao',
       'unknown', 'Nomenclador Nacional de Oftalmología · CAO', CURRENT_DATE
  FROM public.os_source_oftar_cao s
  JOIN public.os_catalog c ON c.code = 'nomenclador-oftalmologico-cao-ar'
  JOIN public.os_catalog_release r ON r.catalog_id = c.id AND r.version_tag = 'NOM-CAO-AR-v1'
  JOIN public.os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.codigo
  LEFT JOIN _oftar_source_clasificacion k ON k.codigo = s.codigo
  LEFT JOIN public.os_catalog_category cat
         ON cat.catalog_id = c.id AND cat.code = k.categoria_code
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    preferred_term = EXCLUDED.preferred_term,
    source_language_code = EXCLUDED.source_language_code,
    language_evidence = EXCLUDED.language_evidence,
    provenance = EXCLUDED.provenance,
    source_reference = EXCLUDED.source_reference,
    valid_from = EXCLUDED.valid_from;

-- -----------------------------------------------------------------------------
-- 5. Revisión de campo: SOLO preferred_term (definition queda pendiente)
-- -----------------------------------------------------------------------------
INSERT INTO public.os_field_review
    (target_table, target_id, field_name, language_code, scope_release_id,
     source_language_code, language_evidence, provenance, review_status,
     source_reference, reviewed_by, reviewed_at)
SELECT 'os_catalog_item_version', iv.id, 'preferred_term', iv.language_code,
       iv.release_id, iv.source_language_code, iv.language_evidence, iv.provenance,
       'unknown', iv.source_reference, NULL, NULL
  FROM public.os_catalog_item_version iv
  JOIN public.os_catalog_item i ON i.id = iv.item_id
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'nomenclador-oftalmologico-cao-ar'
 WHERE iv.provenance = 'imported_oftar_cao'
   AND NULLIF(btrim(iv.preferred_term), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- 6. Propuestas de mapeo en tabla gobernada (sin publicar enlaces)
-- -----------------------------------------------------------------------------
INSERT INTO public.os_oftar_nomenclador_match
    (source_catalog_code, source_code, target_catalog_code, target_code,
     match_basis, review_status, source_term, target_term, provenance, notes)
VALUES
    ('nomenclador-oftalmologico-cao-ar', '460105', 'oftar-pr', '306002', 'texto_identico_normalizado', 'proposed', 'RFG bilateral (no incluye fluoresceína, descartables, cardiólogo ni anestesista)', 'RFG bilateral (no incluye fluoresceina, descartables, cardiologo ni anestesista)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460118', 'oftar-pr', '300120', 'texto_identico_normalizado', 'proposed', 'Examen sensorio motor en estrabismo', 'Examen sensorio motor en estrabismo', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460137', 'oftar-pr', '306003', 'texto_identico_normalizado', 'proposed', 'Examen de prematuros (hasta 120 días de vida, por consulta)', 'Examen de prematuros (hasta 120 días de vida, por consulta)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460139', 'oftar-pr', '306004', 'texto_identico_normalizado', 'proposed', 'Ecobiometría de no contacto, de coherencia óptica, unilateral', 'Ecobiometría de no contacto, de coherencia optica, unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460140', 'oftar-pr', '306005', 'texto_identico_normalizado', 'proposed', 'Medida de poder corneal central unilateral', 'Medida de poder corneal central unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460142', 'oftar-pr', '306006', 'texto_identico_normalizado', 'proposed', 'Recuento endotelial unilateral', 'Recuento endotelial unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460143', 'oftar-pr', '306007', 'texto_identico_normalizado', 'proposed', 'Exoftalmometría con Heartel', 'Exoftalmometría con heartel', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460144', 'oftar-pr', '306129', 'texto_identico_normalizado', 'proposed', 'Tonometría de aires unilateral-neumotonometría', 'Tonometría de aires unilateral-neumotonometría', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460145', 'oftar-pr', '306130', 'texto_identico_normalizado', 'proposed', 'Oftalmoscopia binocular indirecta unilateral', 'Oftalmoscopia binocular indirecta unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460146', 'oftar-pr', '306131', 'texto_identico_normalizado', 'proposed', 'Gonioscopia con lente tres o 4 espejos unilateral', 'Gonioscopia con lente tres o 4 espejos unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460148', 'oftar-pr', '306008', 'texto_identico_normalizado', 'proposed', 'Test de Lancaster unilateral', 'Test de lancaster unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460149', 'oftar-pr', '306009', 'texto_identico_normalizado', 'proposed', 'Test de ducciones pasivas unilateral', 'Test de ducciones pasivas unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460150', 'oftar-pr', '306010', 'texto_identico_normalizado', 'proposed', 'HD Analizer unilateral Scattering y calidad visual', 'HD analizer unilateral scattering y calidad visual', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460151', 'oftar-pr', '306011', 'texto_identico_normalizado', 'proposed', 'HD Analizer unilizer unilateral función de film lagrimal', 'HD analizer unilizer unilateral función de film lagrimal', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460153', 'oftar-pr', '306012', 'texto_identico_normalizado', 'proposed', 'Campimetría dinámica (con campímetro de Goldmann) bilateral', 'Campimetría dinamica (con campimetro de goldmann) bilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460154', 'oftar-pr', '306013', 'texto_identico_normalizado', 'proposed', 'Electroretinograma', 'Electroretinograma', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460155', 'oftar-pr', '306014', 'texto_identico_normalizado', 'proposed', 'Electroretinograma multifocal', 'Electroretinograma multifocal', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460156', 'oftar-pr', '306015', 'texto_identico_normalizado', 'proposed', 'Potenciales evocados bilateral', 'Potenciales evocados bilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460157', 'oftar-pr', '306016', 'texto_identico_normalizado', 'proposed', 'Meibomiografía (por ojo)', 'Meibomiografía (por ojo)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460158', 'oftar-pr', '306132', 'texto_identico_normalizado', 'proposed', 'Topografía Posterior (por ojo)', 'Topografía posterior (por ojo)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460159', 'oftar-pr', '306017', 'texto_identico_normalizado', 'proposed', 'Test de sobrecarga hídrica', 'Test de sobrecarga hidrica', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460160', 'oftar-pr', '306018', 'texto_identico_normalizado', 'proposed', 'Extracción de cuerpo extraño subtarsal', 'Extracción de cuerpo extraño subtarsal', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460161', 'oftar-pr', '306019', 'texto_identico_normalizado', 'proposed', 'Sesiones de estimulación visual', 'Sesiones de estimulación visual', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460201', 'oftar-pr', '306020', 'texto_identico_normalizado', 'proposed', 'Lesiones maculares (edema macular diabético)', 'Lesiones maculares (edema macular diabetico)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460202', 'oftar-pr', '306021', 'texto_identico_normalizado', 'proposed', 'Lesiones vasculares con isquemia en 1 cuadrante - tratamiento completo', 'Lesiones vasculares con isquemia en 1 cuadrante - tratamiento completo', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460203', 'oftar-pr', '306022', 'texto_identico_normalizado', 'proposed', 'Desgarros y agujeros de retina', 'Desgarros y agujeros de retina', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460205', 'oftar-pr', '306023', 'texto_identico_normalizado', 'proposed', 'Trabeculoplastia, iridotomía, iridoplastia (láser de argón)', 'Trabeculoplastia, iridotomía, iridoplastia (láser de argon)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460206', 'oftar-pr', '306024', 'texto_identico_normalizado', 'proposed', 'Láser mediante oftalmoscopia binocular indirecta', 'Láser mediante oftalmoscopia binocular indirecta', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460207', 'oftar-pr', '306025', 'texto_identico_normalizado', 'proposed', 'Láser mediante oftalmoscopia binocular indirecta en prematuros en sala de neonatología', 'Láser mediante oftalmoscopia binocular indirecta en prematuros en sala de neonatología *****', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460215', 'oftar-pr', '306033', 'texto_identico_normalizado', 'proposed', 'SLT trabeculoplastia selectiva para glaucoma unilateral', 'SLT trabeculoplastia selectiva para glaucoma unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460216', 'oftar-pr', '306034', 'texto_identico_normalizado', 'proposed', 'Suturolitis con YAG', 'Suturolitis con yag', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460208', 'oftar-pr', '306026', 'texto_identico_normalizado', 'proposed', 'Lesiones vasculares con isquemia en 2 o más cuadrantes', 'Lesiones vasculares con isquemia en 2 o mas cuadrantes', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460209', 'oftar-pr', '306027', 'texto_identico_normalizado', 'proposed', 'Obstrucciones vasculares (con isquemia en más de 3 cuadrantes)', 'Obstrucciones vasculares (con isquemia en mas de 3 cuadrantes)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460210', 'oftar-pr', '306028', 'texto_identico_normalizado', 'proposed', 'Retinopatía diabética severa (panfotocoagulación)', 'Retinopatía diabetica severa (panfotocoagulación)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460211', 'oftar-pr', '306029', 'texto_identico_normalizado', 'proposed', 'Trombosis de vena central tipo isquémica', 'Trombosis de vena central tipo isquemica', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460302', 'oftar-pr', '306036', 'texto_identico_normalizado', 'proposed', 'Entropión, ectropión, blefaroplastia no cosmética', 'Entropion, ectropion, blefaroplastia no cosmetica', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460303', 'oftar-pr', '306037', 'texto_identico_normalizado', 'proposed', 'Ptosis en adulto, retracción de párpado, colocación pesa de oro, reparación trauma palpebral (sin descartables ni implante)', 'Ptosis en adulto, retracción de párpado, colocación pesa de oro, reparación trauma palpebral (sin descartables ni implante)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460305', 'oftar-pr', '306038', 'texto_identico_normalizado', 'proposed', 'Reconstrucción de párpados simple', 'Reconstrucción de párpados simple', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460306', 'oftar-pr', '306039', 'texto_identico_normalizado', 'proposed', 'Tratamiento inyectable con Botox (en quirófano - no incluye fármaco)', 'Tratamiento inyectable con botox (en quirofano - no incluye fármaco)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460307', 'oftar-pr', '306040', 'texto_identico_normalizado', 'proposed', 'Reconstrucción de párpado compleja (tumor)', 'Reconstrucción de párpado compleja (tumor)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460308', 'oftar-pr', '306041', 'texto_identico_normalizado', 'proposed', 'Cirugía de distiquiasis', 'Cirugia de distiquiasis', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460310', 'oftar-pr', '306042', 'texto_identico_normalizado', 'proposed', 'Ptosis en niños, reconstrucciones de más de 50% del párpado, reposicionamiento de cejas', 'Ptosis en niños, reconstrucciones de mas de 50% del párpado, reposicionamiento de cejas', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460311', 'oftar-pr', '306043', 'texto_identico_normalizado', 'proposed', 'Biopsia de párpado', 'Biopsia de párpado', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460401', 'oftar-pr', '306054', 'texto_identico_normalizado', 'proposed', 'Escisión lesión conjuntival (pterigión, nevus, epitelioma, quiste)', 'Escisión lesión conjuntival (pterigion, nevus, epitelioma, quiste)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460402', 'oftar-pr', '306055', 'texto_identico_normalizado', 'proposed', 'Conjuntivoplastia (+ flapping, recubrimiento conjuntival de córnea)', 'Conjuntivoplastia (+ flapping, recubrimiento conjuntival de córnea)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460403', 'oftar-pr', '306056', 'texto_identico_normalizado', 'proposed', 'Peritomía, peritectomía', 'Peritomía, peritectomía', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460404', 'oftar-pr', '306057', 'texto_identico_normalizado', 'proposed', 'Sutura conjuntiva - biopsia de conjuntiva', 'Sutura conjuntiva - biopsia de conjuntiva', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460405', 'oftar-pr', '306058', 'texto_identico_normalizado', 'proposed', 'Conjuntivoplastia con injerto de limbo', 'Conjuntivoplastia con injerto de limbo', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460406', 'oftar-pr', '306059', 'texto_identico_normalizado', 'proposed', 'Biopsia de conjuntiva', 'Biopsia de conjuntiva', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460407', 'oftar-pr', '306060', 'texto_identico_normalizado', 'proposed', 'Sutura de conjuntiva', 'Sutura de conjuntiva', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460212', 'oftar-pr', '306030', 'texto_identico_normalizado', 'proposed', 'Cirugía refractiva con excimer láser (unilateral) LASIK', 'Cirugia refractiva con excimer láser (unilateral) lasik', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460213', 'oftar-pr', '306031', 'texto_identico_normalizado', 'proposed', 'Láser femto asociado a cualquier práctica', 'Láser femto asociado a cualquier practica', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460214', 'oftar-pr', '306032', 'texto_identico_normalizado', 'proposed', 'Cirugía refractiva con excimer láser (unilateral) PRK', 'Cirugia refractiva con excimer láser (unilateral) PRK', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460313', 'oftar-pr', '306044', 'texto_identico_normalizado', 'proposed', 'Sutura de córnea (con prolapso de iris)', 'Sutura de córnea (con prolapso de iris)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460325', 'oftar-pr', '306045', 'texto_identico_normalizado', 'proposed', 'Queratoplastia penetrante', 'Queratoplastia penetrante', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460326', 'oftar-pr', '306046', 'texto_identico_normalizado', 'proposed', 'Queratoplastia laminar', 'Queratoplastia laminar', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460328', 'oftar-pr', '306048', 'texto_identico_normalizado', 'proposed', 'Implante de anillos intracorneales (no incluye descartables, láser femto ni anillo)', 'Implante de anillos intracorneales (no incluye descartables, láser femto ni anillo)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460329', 'oftar-pr', '306049', 'texto_identico_normalizado', 'proposed', 'Crosslinking unilateral', 'Crosslinking unilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460330', 'oftar-pr', '306050', 'texto_identico_normalizado', 'proposed', 'Sutura de córnea (sin prolapso de iris)', 'Sutura de córnea (sin prolapso de iris)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460331', 'oftar-pr', '306051', 'texto_identico_normalizado', 'proposed', 'Queratocentesis - cauterización - toma de material', 'Queratocentesis - cauterización - toma de material', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460332', 'oftar-pr', '306052', 'texto_identico_normalizado', 'proposed', 'Ablación de córnea y esclera limbar y reparación cosmética de cierre palpebral (en procedimiento de donación de órganos)', 'Ablación de córnea y esclera limbar y reparación cosmetica de cierre palpebral (en procedimiento de donación de organos)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460333', 'oftar-pr', '306053', 'texto_identico_normalizado', 'proposed', 'Recubrimiento con membrana amniótica', 'Recubrimiento con membrana amniotica', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460501', 'oftar-pr', '306061', 'texto_identico_normalizado', 'proposed', 'Estrabismo (toda técnica o cantidad de músculos - no incluye monitoreo, anestesia ni remedios)', 'Estrabismo (toda técnica o cantidad de músculos - no incluye monitoreo, anestesia ni remedios)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460502', 'oftar-pr', '306062', 'texto_identico_normalizado', 'proposed', 'Estrabismo unilateral con sutura reajustable', 'Estrabismo unilateral con sutura reajustable', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460601', 'oftar-pr', '306063', 'texto_identico_normalizado', 'proposed', 'Iridectomía, iridotomía, coreoplastía', 'Iridectomía, iridotomía, coreoplastia', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460602', 'oftar-pr', '306064', 'texto_identico_normalizado', 'proposed', 'Iridociclectomía o iridociclotomía por tumores', 'Iridociclectomía o iridociclotomía por tumores', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460604', 'oftar-pr', '306066', 'texto_identico_normalizado', 'proposed', 'Implante de dispositivo de drenaje (no incluye válvula)', 'Implante de dispositivo de drenaje (no incluye válvula)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '460605', 'oftar-pr', '306067', 'texto_identico_normalizado', 'proposed', 'Endociclo Fotocoagulación', 'Endociclo fotocoagulación', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461206', 'oftar-pr', '306103', 'texto_identico_normalizado', 'proposed', 'Dacriocistorinostomía con láser', 'Dacriocistorinostomía con láser', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461207', 'oftar-pr', '306104', 'texto_identico_normalizado', 'proposed', 'Dacriorinostomía con tubo de Jones (no incluye tubo)', 'Dacriorinostomía con tubo de jones (no incluye tubo)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461208', 'oftar-pr', '306105', 'texto_identico_normalizado', 'proposed', 'Reubicación de tubo de Jones después de los 30 días', 'Reubicación de tubo de jones despues de los 30 días', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461209', 'oftar-pr', '306106', 'texto_identico_normalizado', 'proposed', 'Sondaje lagrimal con anestesia local', 'Sondaje lagrimal con anestesia local', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461210', 'oftar-pr', '306107', 'texto_identico_normalizado', 'proposed', 'Exfoliación, canalización e inyección de sustancias en glándulas de Meibomio', 'Exfoliación, canalización e inyección de sustancias en glandulas de meibomio', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461212', 'oftar-pr', '306109', 'texto_identico_normalizado', 'proposed', 'Estudio parasitológico de pestañas (demódex)', 'Estudio parasitológico de pestañas (demodex)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461214', 'oftar-pr', '306111', 'texto_identico_normalizado', 'proposed', 'Canuloplastia', 'Canuloplastia', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461301', 'oftar-pr', '306112', 'texto_identico_normalizado', 'proposed', 'Extracción cuerpo extraño subconjuntival o subtenoniano', 'Extracción cuerpo extraño subconjuntival o subtenoniano', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461302', 'oftar-pr', '306113', 'texto_identico_normalizado', 'proposed', 'Extracción de cuerpo extraño intracorneal', 'Extracción de cuerpo extraño intracorneal', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461304', 'oftar-pr', '306114', 'texto_identico_normalizado', 'proposed', 'Herida perforante con cuerpo extraño en cámara anterior', 'Herida perforante con cuerpo extraño en camara anterior', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461305', 'oftar-pr', '306115', 'texto_identico_normalizado', 'proposed', 'Lavado de cámara anterior (como única operación)', 'Lavado de camara anterior (como única operación)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461306', 'oftar-pr', '306116', 'texto_identico_normalizado', 'proposed', 'Herida perforante con lesión de córnea, esclera, iris y cristalino (puede ir LIO)', 'Herida perforante con lesión de córnea, esclera, iris y cristalino (puede ir lio)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461307', 'oftar-pr', '306117', 'texto_identico_normalizado', 'proposed', 'Herida perforante c/ cuerpo extraño intraocular q/ requiera extracción y procedimientos s/ retina y/o vitreo (láser, gas, aceite)', 'Herida perforante C/ cuerpo extraño intraocular Q/ requiera extracción y procedimientos S/ retina y/o vítreo (láser, gas, aceite)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461308', 'oftar-pr', '306118', 'texto_identico_normalizado', 'proposed', 'Sutura de herida palpebral sin compromiso de vía lagrimal', 'Sutura de herida palpebral sin compromiso de via lagrimal', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461309', 'oftar-pr', '306119', 'texto_identico_normalizado', 'proposed', 'Sutura herida palpebral c/ compromiso vía lagrimal (intubación c/ silicón y extracción a los 2 meses)', 'Sutura herida palpebral C/ compromiso via lagrimal (intubación C/ silicon y extracción a los 2 meses)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461311', 'oftar-pr', '306120', 'texto_identico_normalizado', 'proposed', 'Herida escleral + 4mm por detrás del limbo q/ requiera tratamiento profiláctico de DR (implante silicón, crio, diatermia, láser)', 'Herida escleral + 4MM por detras del limbo Q/ requiera tratamiento profilactico de DR (implante silicon, crio, diatermia, láser)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461312', 'oftar-pr', '306121', 'texto_identico_normalizado', 'proposed', 'Fractura de piso orbitario (no incluye prótesis)', 'Fractura de piso orbitario (no incluye prótesis)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461313', 'oftar-pr', '306122', 'texto_identico_normalizado', 'proposed', 'Lipectomía uni o bilateral', 'Lipectomía uni o bilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461314', 'oftar-pr', '306123', 'texto_identico_normalizado', 'proposed', 'Descompresión uni o bilateral', 'Descompresión uni o bilateral', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461401', 'oftar-pr', '306124', 'texto_identico_normalizado', 'proposed', 'Primera consulta de baja visión - Diagnóstico y receta de lentes especiales y/o ayudas', 'Primera consulta de baja visión - diagnóstico y receta de lentes especiales y/o ayudas', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461402', 'oftar-pr', '306125', 'texto_identico_normalizado', 'proposed', 'Consultas siguientes (seguimiento de patología)', 'Consultas siguientes (seguimiento de patología)', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461403', 'oftar-pr', '306126', 'texto_identico_normalizado', 'proposed', 'Adaptación de lentes de contacto', 'Adaptación de lentes de contacto', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL),
    ('nomenclador-oftalmologico-cao-ar', '461404', 'oftar-pr', '306127', 'texto_identico_normalizado', 'proposed', 'Eventuales controles post adaptación', 'Eventuales controles post adaptación', 'Coincidencia literal de descripción normalizada entre tools/sources/oftar/cao.csv y sql/03_oftar/fuente_nomenclador_oftar_pr.sql', NULL) ON CONFLICT (source_catalog_code, source_code) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 7. Verificación (solo lectura; ejecutar por separado)
-- -----------------------------------------------------------------------------
-- SELECT count(*) FROM public.os_source_oftar_cao;  -- esperado: 143
-- SELECT count(*) FROM public.os_catalog_item i JOIN public.os_catalog c
--   ON c.id = i.catalog_id WHERE c.code = 'nomenclador-oftalmologico-cao-ar';  -- esperado: 143
-- SELECT count(*) FROM public.os_field_review WHERE provenance = 'imported_oftar_cao';  -- esperado: 143
-- SELECT count(*) FROM public.os_oftar_nomenclador_match WHERE source_catalog_code = 'nomenclador-oftalmologico-cao-ar';  -- esperado: 91 propuestas

COMMIT;

