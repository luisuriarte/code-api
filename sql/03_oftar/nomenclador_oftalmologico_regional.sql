-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Familia OFTAR
-- sql/03_oftar/nomenclador_oftalmologico_regional.sql
-- =============================================================================
--
-- EJECUCIÓN EN EL VPS (el rol `root` no existe en PostgreSQL):
--   cd /var/www/html/origen.ar/code-api
--   sudo -u postgres psql -d origen_codes -v ON_ERROR_STOP=1 -f sql/03_oftar/nomenclador_oftalmologico_regional.sql
--
-- Generado por tools/generate_nomencladores_oftalmologicos_sql.py desde
-- tools/sources/oftar/oftal2.csv. NO EDITAR A MANO; volver a generar.
--
-- ORDEN DE CARGA EN `origen_codes`
--   1) sql/03_oftar/nomencladores_oftar_mapping.sql
--   2) sql/03_oftar/nomenclador_oftalmologico_regional.sql
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
CREATE TABLE IF NOT EXISTS public.os_source_oftar_regional (
    codigo VARCHAR(20) PRIMARY KEY,
    descripcion TEXT NOT NULL,
    categoria VARCHAR(150),
    subcategoria VARCHAR(150),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE public.os_source_oftar_regional IS
    'Espejo literal de la fuente oftalmológica. No contiene columnas de precio.';

REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_regional FROM PUBLIC;

DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_regional FROM origen_admin';
        EXECUTE 'GRANT SELECT ON TABLE public.os_source_oftar_regional TO origen_admin';
    END IF;
    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_regional FROM origen_med';
        EXECUTE 'GRANT SELECT ON TABLE public.os_source_oftar_regional TO origen_med';
    END IF;
    IF to_regrole('origen_api') IS NOT NULL THEN
        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE public.os_source_oftar_regional FROM origen_api';
        EXECUTE 'GRANT SELECT ON TABLE public.os_source_oftar_regional TO origen_api';
    END IF;
END $$;

DELETE FROM public.os_source_oftar_regional;

INSERT INTO public.os_source_oftar_regional (codigo, descripcion, categoria, subcategoria) VALUES
    ('425001', 'Consulta oftalmológica de adultos (15 años de edad en adelante)', 'CONSULTAS', NULL),
    ('425002', 'Consulta oftalmoneonatologia o hasta 120 dias de vida inclusive', 'CONSULTAS', NULL),
    ('425003', 'Consulta oftalmopediatría de 121 dias hasta 14 años de edad inclusive', 'CONSULTAS', NULL),
    ('425004', 'Consulta a domicilio o a otra institución (con traslado de aparatos)', 'CONSULTAS', NULL),
    ('425005', 'Consulta o interconsulta en internación dentro de la misma institución (con o sin traslado de aparatos)', 'CONSULTAS', NULL),
    ('425006', 'Consulta por vía electrónica o Telemedicina', 'CONSULTAS', NULL),
    ('425007', 'Consulta de baja visión ‐ Diagnóstico y receta de lentes y/o ayudas especiales y/o su seguimiento y control', 'CONSULTAS', NULL),
    ('425008', 'Realización de informes y/o resumenes de historia clínica', 'CONSULTAS', NULL),
    ('425009', 'Segunda consulta oftalmológica o de seguimiento (dentro del mismo periodo de facturación)', 'CONSULTAS', NULL),
    ('305001', 'Angiografía / RFG (Retinofluoresceinografia) - Bilateral (incluye retinografia) (No incluye material de contraste)', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305003', 'Autofluorescencia - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305004', 'Autorefractometría – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305005', 'Biometría por interferometría láser / IOL Master, Lenstar o similar - Unilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305006', 'Campo visual computado - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305007', 'Capsulotomía y/o sinequiolisis y/o iridotomía con YAG-Laser - Unilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305008', 'Curva tensional – Prueba de tolerancia hídrica para glaucoma – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305009', 'Dilatación de puntos lagrimales, sondaje o plombaje de las vías lagrimal con anestesia local en consultorio - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305010', 'Ecografía ocular y/u orbitaria modo A y/o B - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305011', 'Ecometría - Unilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305012', 'Ejercicios ortópticos - por sesión', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305013', 'Electrooculograma o videooculograma - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305014', 'Electroretinograma – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305015', 'Estudio del mapa endotelial corneal - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305016', 'Estudio Seguimiento en Miopía Infantil. (Incluye Autorefractometria y/o biometría (cualquier método) y/o topografía corneal) - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305017', 'Examen oftalmológico bajo anestesia general (más los estudios a realizar)', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305018', 'Examen sensorial y motor en estrabismo (test de fusión y/o test de estereopsia y/o test de nistagmus optocinético y/o registro de motilidad ocular y/o test de Krimsky y/o cover test con prisma y/o test de ducción pasiva y/o test de fuerzas generadas) - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305019', 'Exoftalmometria – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305020', 'Exoftalmologia – (Incluye prescripción de cristales)', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305021', 'Extracción de cuerpo extraño en superficie corneal o en conjuntiva tarsal o de pestañas o Toma de muestra corneal, en consultorio – Unilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305022', 'Fondo de ojo con oftalmoscopio binocular indirecto en neonatos o hasta completar la vascularización retinal - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305023', 'Fondo de ojo con oftalmoscopio directo o indirecto en mayores de 120 dias de vida - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305024', 'Fotocoagulación Laser de la retina - Unilateral (por sesión)', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305025', 'Gonioscopía – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305026', 'Iconografías  - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305027', 'Informe estimado de Agudeza Visual máxima o Test de Lotmar  - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305028', 'Meibomiografia - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305029', 'Neumotonometría o tonometría de rebote - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305030', 'Paquimetría - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305031', 'Potenciales evocados visuales - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305032', 'Recuento endotelial - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305033', 'Retinografía / RG - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305035', 'Test de citología de impresión (no incluye anatomopatólogo) - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305036', 'Test de visión cromática de Ishihara, Farnsworth o similar – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305037', 'Test de Lancaster  - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305038', 'Test de mirada preferencial  - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305039', 'Test de ojo seco (BUT, test de Schirmer, Rosa de Bengala, Verde de Lisamina, etc) - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305040', 'Test computarizado de ojo seco y calidad visual (HD Analyzer o Tearscope o similar) - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305041', 'Test sensibilidad al contraste  - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305042', 'Tomografía confocal de papila HRT - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305043', 'Tomografía de coherencia óptica OCT de cámara anterior y/o posterior – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305044', 'Tomografía de coherencia óptica OCT con angiografia (ANGIO-OCT) bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305045', 'Tonometría de aplanación – Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305046', 'Topografía corneal computada - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305047', 'Topografía corneal de curvatura y elevación / Aberrometría (Pentacam, Galilei, Orbscan II o similar) - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305048', 'Ultrabiomicroscopia UBM - Bilateral', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('305049', 'Visuscopía – Estudio de fijación con Visuscopio', 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS', NULL),
    ('025001', 'Ablación de córnea y/o esclera y/o globo ocular en procedimiento de trasplante de órganos y tejidos', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025002', 'Descompresión orbitaria - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025003', 'Enucleación o Evisceración  - Unilateral (NO incluye implante)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025004', 'Exenteración del contenido orbitario – Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025005', 'Fractura orbitaria de piso o una pared orbitaria - Unilateral (NO incluye material de osteosíntesis)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025006', 'Fractura orbitaria de dos o mas paredes orbitarias o que comprometen el reborde orbitario  - Unilateral  (NO incluye material de osteosíntesis)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025007', 'Inyección de sustancia subconjuntival y/o parabulbar y/o retrobulbar  - Unilateral - Por sesión (NO incluye sustancia a inyectar)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025008', 'Orbitotomía y exéresis o biopsia de tumor orbitario anterior al ecuador del globo ocular - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025009', 'Orbitotomía y exéresis o biopsia de tumor orbitario posterior al ecuador del globo ocular - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025010', 'Reparación plástica de cavidad anoftálmica con implantes o injertos - Unilateral (NO incluye implantes)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la órbita'),
    ('025101', 'Blefaroplastia terapéutica no cosmética, blefarochalasis - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025102', 'Cejapexia funcional - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025103', 'Ectropion, entropion, distriquiasis, tarsorrafia - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025104', 'Escisión de lesión de párpado, nevus, quiste, chalazión o biopsia de lesión - Por párpado', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025105', 'IPL - Luz Pulsada Intensa - Por sesión', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025106', 'Microexfoliación del borde palpebral - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025107', 'Ptosis palpebral - Cirugía de lagoftalmo - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025108', 'Reconstrucción compleja de párpados por tumor o traumatismo (mayor al 50% del párpado) - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025109', 'Reconstrucción simple de párpados por tumor o traumatismo (menor al 50% del párpado) - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025110', 'Retracción palpebral - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025111', 'Sutura simple de párpado que no compromete la vía lagrimal - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025112', 'Termoterapia mecánica palpebral (Ilux o lipid flow o similar) Por sesión (no incluye insumos)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025113', 'Tratamiento inyectable de toxina botulínica no cosmético - Por sesión (NO incluye la toxina)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de los párpados'),
    ('025201', 'Canaliculoplastía, puntoplastía con o sin intubación – Unilateral (NO incluye el set de intubación o implante)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025202', 'Conjuntivorrinostomía / cirugía de Jones – Unilateral (NO incluye el implante)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025203', 'Dacriocistorrinostomía endoscópica con o sin intubación – Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025204', 'Dacriocistorrinostomía externa con o sin intubación, Dacriocistectomía – Unilateral (NO incluye el set de intubación)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025205', 'Drenaje de saco lagrimal - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025206', 'Oclusión, cauterización o taponamiento del punto lagrimal - Unilateral (NO incluye implantes)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025207', 'Reconstrucción postraumática de la vía lagrimal – Unilateral (NO Incluye el set de intubación)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025208', 'Reubicación o recolocación del tubo de Jones después del primer mes', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025209', 'Sondaje lagrimal bajo anestesia general con o sin intubación – Unilateral (NO incluye el set de intubación)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025210', 'Sondaje lagrimal bajo anestesia general en neonatos o hasta 120 dias de vida - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('025301', 'Conjuntivoplastia, Pterigión con injerto o colgajo conjuntival - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la conjuntiva'),
    ('025302', 'Biopsia de lesión conjuntival y/o sutura de conjuntiva - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la conjuntiva'),
    ('025303', 'Biopsia Escisional de lesión tumoral  conjuntival con crioterapia de los bordes - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la conjuntiva'),
    ('025304', 'Pterigion sin injerto o colgajo conjuntival, peritomía conjuntival, pannus  - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la conjuntiva'),
    ('025401', 'Aspiración o toma de muestra vítrea - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025402', 'Retinopexia neumática, Buckling escleral o similar por desprendimiento de retina – Unilateral (No incluye implante o insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025403', 'Vitrectomia posterior por desprendimiento de retina o hemovítreo o extracción de cuerpo extraño intraocular, con endolaser – Unilateral (NO incluye set de vitrectomía, sonda de endolaser ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025404', 'Vitrectomia posterior por desprendimiento de retina con endolaser e inyección de sustancias expansoras – Unilateral (No incluye sustancia expansora)  (NO incluye set de vitrectomía, sonda de endolaser ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025405', 'Vitrectomía posterior en neonatos o hasta 120 días de vida – Unilateral (NO incluye set de vitrectomía, sonda de endolaser ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025406', 'Fotocoagulación Laser mediante oftalmoscopía binocular indirecta en neonatos o hasta completar la vascularizacion retinal - Por sesión - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025407', 'Inyección intravítrea en adultos o implante de dispositivo intravítreo - Unilateral (NO incluye sustancia ni dispositivo)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025408', 'Inyección intravítrea en neonatos o hasta completar la vascularizacion retinal - Unilateral  (NO incluye set de vitrectomía, sonda de endolaser ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025409', 'Vitrectomia en niños de 121 dias a 15 años inclusive. – Unilateral (NO incluye set de vitrectomía, sonda de endolaser ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025410', 'Vitrectomía en patología maculares, con disección y/o peeling de membrana – Unilateral (NO incluye set de vitrectomía, sonda de endolaser ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025411', 'Vitrectomia anterior - Unilateral – (NO incluye set de vitrectomía, sonda de endolaser ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('025501', 'Aspiración de masas de cristalino en cámara anterior y/o lavado de cámara anterior y/o extraccion de cuerpo extraño en cámara anterior - Unilateral (Como única intervención) (NO incluye sustancia viscoelástica, cassette de faco ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del cristalino'),
    ('025502', 'Catarata en neonatos o hasta 120 días de vida', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del cristalino'),
    ('025503', 'Catarata en adultos extracapsular con implante de LIO monofocal esférico estándar de PMMA - Unilateral (NO incluye sustancia viscoelástica, cassette de faco ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del cristalino'),
    ('025504', 'Catarata en adultos por facoemulsificación con implante de LIO monofocal esférico estándar de PMMA - Unilateral (NO incluye sustancia viscoelástica, cassette de faco ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del cristalino'),
    ('025505', 'Catarata en adultos por facoemulsificación con implante de LIO multifocal o tórico (NO INCLUYE EL LENTE) - Unilateral (NO incluye sustancia viscoelástica, cassette de faco, ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del cristalino'),
    ('025506', 'Extracción de lente en cámara anterior o posterior - Unilateral (Como única intervención, NO incluye sustancia viscoelástica ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del cristalino'),
    ('025507', 'Implante secundario de LIO en cámara anterior o posterior, rotación o cambio de LIO - Unilateral  (Como única intervención, NO incluye lente, sustancia viscoelástica ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del cristalino'),
    ('025601', 'Cirugía refractiva con EXCIMER-Laser – Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025602', 'Cirugía refractiva corneal lamelar con Laser de Femtosegundo (SMILE o similar) – Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025603', 'Cross-linking corneal – Unilateral (No incluye Riboflavina) – Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025604', 'Cross-linking corneal combinado con EXCIMER-Laser (PRK+CXL o LASIK Xtra o similar) (No incluye Riboflavina) – Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025605', 'Extracción de cuerpo extraño corneal - Queratocentesis – Toma de muestra o biopsia corneal en quirófano. - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025606', 'Implante de lente intraocular fáquico – Unilateral (No incluye lente)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025607', 'Implante de segmentos intraestromales - Unilateral (NO incluye segmentos ni uso de FEMTO-Laser)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025608', 'Inyección Intraestromal corneal en queratitis infecciosas - Unilateral (No incluye la medicación)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025609', 'Recubrimiento corneal con flap conjuntival o membrana amniótica o esclera - (NO incluye membrana amniótica ni esclera) - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025610', 'Sutura simple de córnea y/o esclera - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025611', 'Sutura compleja de córnea y/o esclera con prolapso de úvea y/o extracción de cuerpo extraño en cámara anterior - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025612', 'Trasplante de córnea endotelial – Unilateral (NO incluye insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025613', 'Trasplante de córnea penetrante, queratoplastia penetrante – Unilateral (NO incluye insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025614', 'Trasplante Simplificado de Células Germinales Limbares ( SLET) - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025615', 'Uso de Laser de Femtosegundo. Adicional a la práctica principal.', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('025701', 'Estrabismo  - Cirugía cualquier técnica -- Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas por estrabismo'),
    ('025702', 'Estrabismo - Adicional por técnica de suturas ajustables.', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas por estrabismo'),
    ('025703', 'Estrabismo - Tratamiento con Toxina Botulínica. (No incluye la toxina)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas por estrabismo'),
    ('025801', 'Trabeculoplastia, Iridectomía, iridotomía, coreoplastía – Unilateral (NO incluye sustancia viscoelástica ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del Iris y cuerpo ciliar'),
    ('025802', 'Iridociclectomía – iridociclotomía – ciclodestrucción – ciclofotocoagulación – Unilateral (NO incluye sustancia viscoelástica, sonda de Laser, ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del Iris y cuerpo ciliar'),
    ('025803', 'Revisión de ampolla filtrante, needling, en consultorio - Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del Iris y cuerpo ciliar'),
    ('025804', 'Revisión de ampolla filtrante, needling, en quirófano- Unilateral', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del Iris y cuerpo ciliar'),
    ('025805', 'SLT - Trabeculectomia Laser Selectiva - Unilateral (No incluye la sonda laser)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del Iris y cuerpo ciliar'),
    ('025806', 'Trabeculectomía, trabeculotomía, viscocanalostomía – Unilateral (NO incluye sustancia viscoelástica, ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del Iris y cuerpo ciliar'),
    ('025807', 'Válvula o dispositivo de drenaje para glaucoma, implante o explante, MIGS - Unilateral (NO incluye el dispositivo) (NO incluye sustancia viscoelástica ni insumos especiales)', 'PRACTICAS QUIRURGICAS', 'Prácticas quirúrgicas del Iris y cuerpo ciliar');

-- -----------------------------------------------------------------------------
-- 2. Catálogo de origen dentro de la familia OFTAR
-- -----------------------------------------------------------------------------
INSERT INTO public.os_catalog
    (code, name, organization, country_code, domain_type, family_code,
     product_role, short_name, description, is_active)
VALUES (
    'nomenclador-oftalmologico-regional-ar',
    'Nomenclador Oftalmológico de Referencia Regional (Argentina NOA)',
    'Nomencladores oftalmológicos de referencia regional (NOA)',
    'AR', 'medical', 'oftar', 'catalog', 'NOM-OFTAL-REG',
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
SELECT id, 'NOM-OFTAL-REG-v1', CURRENT_DATE, 'Fuente: tools/sources/oftar/oftal2.csv', 'published'
  FROM public.os_catalog WHERE code = 'nomenclador-oftalmologico-regional-ar'
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
    ('consultas-5dc1c896', NULL, 'CONSULTAS'),
    ('practicas-quirurgicas-2316dc98', NULL, 'PRACTICAS QUIRURGICAS'),
    ('practicas-quirurgicas-practicas-q-187a3b56', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas de la órbita'),
    ('practicas-quirurgicas-practicas-q-302f6a01', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas por estrabismo'),
    ('practicas-quirurgicas-practicas-q-4333eae1', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas de los párpados'),
    ('practicas-quirurgicas-practicas-q-4414b755', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas de la retina y el cuerpo vítreo'),
    ('practicas-quirurgicas-practicas-q-6debbcf4', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas del Iris y cuerpo ciliar'),
    ('practicas-quirurgicas-practicas-q-814fd875', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas del sistema lagrimal'),
    ('practicas-quirurgicas-practicas-q-8cdf9409', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas de la córnea y refractivas'),
    ('practicas-quirurgicas-practicas-q-a148b264', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas de la conjuntiva'),
    ('practicas-quirurgicas-practicas-q-f3e0e8b3', 'practicas-quirurgicas-2316dc98', 'Prácticas quirúrgicas del cristalino'),
    ('practicas-y-estudios-complementarios-61cd68d9', NULL, 'PRACTICAS Y ESTUDIOS COMPLEMENTARIOS');

INSERT INTO _oftar_source_clasificacion (codigo, categoria_code) VALUES
    ('425001', 'consultas-5dc1c896'),
    ('425002', 'consultas-5dc1c896'),
    ('425003', 'consultas-5dc1c896'),
    ('425004', 'consultas-5dc1c896'),
    ('425005', 'consultas-5dc1c896'),
    ('425006', 'consultas-5dc1c896'),
    ('425007', 'consultas-5dc1c896'),
    ('425008', 'consultas-5dc1c896'),
    ('425009', 'consultas-5dc1c896'),
    ('305001', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305003', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305004', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305005', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305006', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305007', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305008', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305009', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305010', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305011', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305012', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305013', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305014', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305015', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305016', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305017', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305018', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305019', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305020', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305021', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305022', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305023', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305024', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305025', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305026', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305027', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305028', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305029', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305030', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305031', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305032', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305033', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305035', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305036', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305037', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305038', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305039', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305040', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305041', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305042', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305043', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305044', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305045', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305046', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305047', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305048', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('305049', 'practicas-y-estudios-complementarios-61cd68d9'),
    ('025001', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025002', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025003', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025004', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025005', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025006', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025007', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025008', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025009', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025010', 'practicas-quirurgicas-practicas-q-187a3b56'),
    ('025101', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025102', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025103', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025104', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025105', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025106', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025107', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025108', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025109', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025110', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025111', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025112', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025113', 'practicas-quirurgicas-practicas-q-4333eae1'),
    ('025201', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025202', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025203', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025204', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025205', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025206', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025207', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025208', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025209', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025210', 'practicas-quirurgicas-practicas-q-814fd875'),
    ('025301', 'practicas-quirurgicas-practicas-q-a148b264'),
    ('025302', 'practicas-quirurgicas-practicas-q-a148b264'),
    ('025303', 'practicas-quirurgicas-practicas-q-a148b264'),
    ('025304', 'practicas-quirurgicas-practicas-q-a148b264'),
    ('025401', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025402', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025403', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025404', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025405', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025406', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025407', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025408', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025409', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025410', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025411', 'practicas-quirurgicas-practicas-q-4414b755'),
    ('025501', 'practicas-quirurgicas-practicas-q-f3e0e8b3'),
    ('025502', 'practicas-quirurgicas-practicas-q-f3e0e8b3'),
    ('025503', 'practicas-quirurgicas-practicas-q-f3e0e8b3'),
    ('025504', 'practicas-quirurgicas-practicas-q-f3e0e8b3'),
    ('025505', 'practicas-quirurgicas-practicas-q-f3e0e8b3'),
    ('025506', 'practicas-quirurgicas-practicas-q-f3e0e8b3'),
    ('025507', 'practicas-quirurgicas-practicas-q-f3e0e8b3'),
    ('025601', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025602', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025603', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025604', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025605', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025606', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025607', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025608', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025609', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025610', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025611', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025612', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025613', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025614', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025615', 'practicas-quirurgicas-practicas-q-8cdf9409'),
    ('025701', 'practicas-quirurgicas-practicas-q-302f6a01'),
    ('025702', 'practicas-quirurgicas-practicas-q-302f6a01'),
    ('025703', 'practicas-quirurgicas-practicas-q-302f6a01'),
    ('025801', 'practicas-quirurgicas-practicas-q-6debbcf4'),
    ('025802', 'practicas-quirurgicas-practicas-q-6debbcf4'),
    ('025803', 'practicas-quirurgicas-practicas-q-6debbcf4'),
    ('025804', 'practicas-quirurgicas-practicas-q-6debbcf4'),
    ('025805', 'practicas-quirurgicas-practicas-q-6debbcf4'),
    ('025806', 'practicas-quirurgicas-practicas-q-6debbcf4'),
    ('025807', 'practicas-quirurgicas-practicas-q-6debbcf4');

INSERT INTO public.os_catalog_category (catalog_id, code, name, parent_category_id)
SELECT c.id, k.code, k.name,
       (SELECT p.id FROM public.os_catalog_category p
          WHERE p.catalog_id = c.id AND p.code = k.parent_code)
  FROM public.os_catalog c CROSS JOIN _oftar_source_categoria k
 WHERE c.code = 'nomenclador-oftalmologico-regional-ar'
ON CONFLICT (catalog_id, code) DO UPDATE SET
    name = EXCLUDED.name,
    parent_category_id = EXCLUDED.parent_category_id;

-- -----------------------------------------------------------------------------
-- 4. Ítems y versiones: el código original es el código permanente
-- -----------------------------------------------------------------------------
INSERT INTO public.os_catalog_item (catalog_id, permanent_code, status)
SELECT c.id, s.codigo, 'active'
  FROM public.os_source_oftar_regional s CROSS JOIN public.os_catalog c
 WHERE c.code = 'nomenclador-oftalmologico-regional-ar'
ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = 'active';

INSERT INTO public.os_catalog_item_version
    (item_id, release_id, category_id, preferred_term, definition, clinical_criteria,
     language_code, source_language_code, language_evidence, provenance,
     review_status, source_reference, valid_from)
SELECT i.id, r.id, cat.id, left(s.descripcion, 255), NULL, NULL,
       'es-AR', 'es-AR', 'explicit', 'imported_oftar_regional',
       'unknown', 'Nomenclador Oftalmológico de Referencia Regional', CURRENT_DATE
  FROM public.os_source_oftar_regional s
  JOIN public.os_catalog c ON c.code = 'nomenclador-oftalmologico-regional-ar'
  JOIN public.os_catalog_release r ON r.catalog_id = c.id AND r.version_tag = 'NOM-OFTAL-REG-v1'
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
  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = 'nomenclador-oftalmologico-regional-ar'
 WHERE iv.provenance = 'imported_oftar_regional'
   AND NULLIF(btrim(iv.preferred_term), '') IS NOT NULL
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- 6. Propuestas de mapeo en tabla gobernada (sin publicar enlaces)
-- -----------------------------------------------------------------------------
-- Sin coincidencias exactas de descripción: 0 propuestas generadas.
-- Completar la tabla de mapeo a mano antes de ejecutar la aprobación.

-- -----------------------------------------------------------------------------
-- 7. Verificación (solo lectura; ejecutar por separado)
-- -----------------------------------------------------------------------------
-- SELECT count(*) FROM public.os_source_oftar_regional;  -- esperado: 136
-- SELECT count(*) FROM public.os_catalog_item i JOIN public.os_catalog c
--   ON c.id = i.catalog_id WHERE c.code = 'nomenclador-oftalmologico-regional-ar';  -- esperado: 136
-- SELECT count(*) FROM public.os_field_review WHERE provenance = 'imported_oftar_regional';  -- esperado: 136
-- SELECT count(*) FROM public.os_oftar_nomenclador_match WHERE source_catalog_code = 'nomenclador-oftalmologico-regional-ar';  -- esperado: 0 propuestas

COMMIT;

