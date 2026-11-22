-- =============================================================================
-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud
-- sql/03_oftar/fuente_nomenclador_oftar_pr.sql
-- =============================================================================
--
-- QUÉ HACE
--   Crea `public.oftar_nomenclador_source` con SOLO la sección OFTALMOLOGIA del
--   Nomenclador Nacional 2025, copiada literalmente de
--   tools/sources/nn/Nomenclador_Nacional_2025.sql (sin tocar ese archivo).
--
--   Si `public.nomenclador_2025` ya existe en la base, primero intenta poblar
--   desde ella; después aplica los literales de este archivo. Quien gana es
--   este archivo, para que la carga sea reproducible aunque la fuente completa
--   no esté instalada (es el caso actual de `origen_codes`).
--
-- QUÉ NO HACE
--   · No ejecuta DROP TABLE ... CASCADE.
--   · No modifica la fuente original ni otros importadores.
--   · No crea UVR ni rutas nuevas. No hay ALTER DEFAULT PRIVILEGES.
--   · Idempotente: una segunda ejecución no duplica ni pierde filas.
--
-- REQUIERE: oftar_family.sql y oftar_core.sql ya aplicados.
-- =============================================================================

BEGIN;

SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;

CREATE TABLE IF NOT EXISTS public.oftar_nomenclador_source (
    codigo VARCHAR(20) PRIMARY KEY,
    descripcion TEXT NOT NULL,
    valor NUMERIC(14,2),
    categoria TEXT NOT NULL DEFAULT 'OFTALMOLOGIA'
);

COMMENT ON TABLE public.oftar_nomenclador_source IS
    'Sección OFTALMOLOGIA del Nomenclador Nacional 2025, fuente acotada para oftar-pr. No contiene UVR.';

-- Si está disponible la fuente completa, se toma de ella primero.
DO $$
BEGIN
    IF to_regclass('public.nomenclador_2025') IS NOT NULL THEN
        EXECUTE '
            INSERT INTO public.oftar_nomenclador_source (codigo, descripcion, valor, categoria)
            SELECT codigo, descripcion, valor, categoria
              FROM public.nomenclador_2025
             WHERE categoria = ''OFTALMOLOGIA''
               AND codigo ~ ''^[0-9]{6}$''
               AND NULLIF(btrim(descripcion), '''') IS NOT NULL
            ON CONFLICT (codigo) DO UPDATE
               SET descripcion = EXCLUDED.descripcion,
                   valor = EXCLUDED.valor,
                   categoria = EXCLUDED.categoria
        ';
    END IF;
END $$;

-- Literales extraídos de la fuente original. Se aplican siempre para que la
-- carga sea idéntica con o sin nomenclador_2025 instalado.
INSERT INTO public.oftar_nomenclador_source (codigo, descripcion, valor, categoria) VALUES
    ('300102', 'Campo visual comput.(campimetría y/o perimet.)', 54526.00, 'OFTALMOLOGIA'),
    ('300104', 'Fondo de ojo mas esquiascopia', 30523.00, 'OFTALMOLOGIA'),
    ('300105', 'Tonometría', 44895.00, 'OFTALMOLOGIA'),
    ('300107', 'Ejercicio ortoptico por sesión bilateral con sinoptoforo', 45207.00, 'OFTALMOLOGIA'),
    ('300108', 'Gonioscopia', 44895.00, 'OFTALMOLOGIA'),
    ('300109', 'Curva tensional', 73542.00, 'OFTALMOLOGIA'),
    ('300113', 'Retinofluoresceinografía (unilateral)RFG', 166345.00, 'OFTALMOLOGIA'),
    ('300115', 'Extracción cuerpo extr.conjuntiva I/C', 25436.00, 'OFTALMOLOGIA'),
    ('300116', 'Extracción cuerpo extran.en córnea.', 25436.00, 'OFTALMOLOGIA'),
    ('300118', 'Dilatac.conduc.lacrimonasal C/intubación', 109646.00, 'OFTALMOLOGIA'),
    ('300119', 'Oftalmoscopia binocular indirecta(obi)', 44895.00, 'OFTALMOLOGIA'),
    ('300120', 'Examen sensorio motor en estrabismo', 74426.00, 'OFTALMOLOGIA'),
    ('300122', 'Exoftalmología', 44648.00, 'OFTALMOLOGIA'),
    ('300127', 'Ecometría (cada ojo)', 100311.00, 'OFTALMOLOGIA'),
    ('300131', 'Test de lotmar', 36697.00, 'OFTALMOLOGIA'),
    ('300135', 'Test de ojo seco', 32696.00, 'OFTALMOLOGIA'),
    ('300202', 'Paquimetría', 59367.00, 'OFTALMOLOGIA'),
    ('300204', 'Topografía', 110337.00, 'OFTALMOLOGIA'),
    ('305022', 'Test de la visión de los colores', 29041.00, 'OFTALMOLOGIA'),
    ('305025', 'Test de amsler', 44648.00, 'OFTALMOLOGIA'),
    ('305047', 'Autorrefractometría computarizada(arm)', 34277.00, 'OFTALMOLOGIA'),
    ('305111', 'Oct(tomografía de coherencia optica)', 295747.00, 'OFTALMOLOGIA'),
    ('305148', 'Ecobiometría(ecogr.-ecometría-queratometría)', 90334.00, 'OFTALMOLOGIA'),
    ('306001', 'Retinografía bilateral - of', 124322.00, 'OFTALMOLOGIA'),
    ('306002', 'RFG bilateral (no incluye fluoresceina, descartables, cardiologo ni anestesista)', 245819.00, 'OFTALMOLOGIA'),
    ('306003', 'Examen de prematuros (hasta 120 días de vida, por consulta)', 169712.00, 'OFTALMOLOGIA'),
    ('306004', 'Ecobiometría de no contacto, de coherencia optica, unilateral', 225891.00, 'OFTALMOLOGIA'),
    ('306005', 'Medida de poder corneal central unilateral', 122147.00, 'OFTALMOLOGIA'),
    ('306006', 'Recuento endotelial unilateral', 216120.00, 'OFTALMOLOGIA'),
    ('306007', 'Exoftalmometría con heartel', 41870.00, 'OFTALMOLOGIA'),
    ('306008', 'Test de lancaster unilateral', 117987.00, 'OFTALMOLOGIA'),
    ('306009', 'Test de ducciones pasivas unilateral', 63283.00, 'OFTALMOLOGIA'),
    ('306010', 'HD analizer unilateral scattering y calidad visual', 244295.00, 'OFTALMOLOGIA'),
    ('306011', 'HD analizer unilizer unilateral función de film lagrimal', 260581.00, 'OFTALMOLOGIA'),
    ('306012', 'Campimetría dinamica (con campimetro de goldmann) bilateral', 214740.00, 'OFTALMOLOGIA'),
    ('306013', 'Electroretinograma', 162863.00, 'OFTALMOLOGIA'),
    ('306014', 'Electroretinograma multifocal', 439731.00, 'OFTALMOLOGIA'),
    ('306015', 'Potenciales evocados bilateral', 203579.00, 'OFTALMOLOGIA'),
    ('306016', 'Meibomiografía (por ojo)', 175389.00, 'OFTALMOLOGIA'),
    ('306017', 'Test de sobrecarga hidrica', 121527.00, 'OFTALMOLOGIA'),
    ('306018', 'Extracción de cuerpo extraño subtarsal', 50843.00, 'OFTALMOLOGIA'),
    ('306019', 'Sesiones de estimulación visual', 50843.00, 'OFTALMOLOGIA'),
    ('306020', 'Lesiones maculares (edema macular diabetico)', 543579.00, 'OFTALMOLOGIA'),
    ('306021', 'Lesiones vasculares con isquemia en 1 cuadrante - tratamiento completo', 543579.00, 'OFTALMOLOGIA'),
    ('306022', 'Desgarros y agujeros de retina', 543579.00, 'OFTALMOLOGIA'),
    ('306023', 'Trabeculoplastia, iridotomía, iridoplastia (láser de argon)', 543579.00, 'OFTALMOLOGIA'),
    ('306024', 'Láser mediante oftalmoscopia binocular indirecta', 662224.00, 'OFTALMOLOGIA'),
    ('306025', 'Láser mediante oftalmoscopia binocular indirecta en prematuros en sala de neonatología *****', 3366321.00, 'OFTALMOLOGIA'),
    ('306026', 'Lesiones vasculares con isquemia en 2 o mas cuadrantes', 882969.00, 'OFTALMOLOGIA'),
    ('306027', 'Obstrucciones vasculares (con isquemia en mas de 3 cuadrantes)', 882969.00, 'OFTALMOLOGIA'),
    ('306028', 'Retinopatía diabetica severa (panfotocoagulación)', 1103711.00, 'OFTALMOLOGIA'),
    ('306029', 'Trombosis de vena central tipo isquemica', 662224.00, 'OFTALMOLOGIA'),
    ('306030', 'Cirugia refractiva con excimer láser (unilateral) lasik', 2012245.00, 'OFTALMOLOGIA'),
    ('306031', 'Láser femto asociado a cualquier practica', 1484630.00, 'OFTALMOLOGIA'),
    ('306032', 'Cirugia refractiva con excimer láser (unilateral) PRK', 2012245.00, 'OFTALMOLOGIA'),
    ('306033', 'SLT trabeculoplastia selectiva para glaucoma unilateral', 936464.00, 'OFTALMOLOGIA'),
    ('306034', 'Suturolitis con yag', 543579.00, 'OFTALMOLOGIA'),
    ('306035', 'Chalazion,resección de lesiones de piel', 460169.00, 'OFTALMOLOGIA'),
    ('306036', 'Entropion, ectropion, blefaroplastia no cosmetica', 1073733.00, 'OFTALMOLOGIA'),
    ('306037', 'Ptosis en adulto, retracción de párpado, colocación pesa de oro, reparación trauma palpebral (sin descartables ni implante)', 1870322.00, 'OFTALMOLOGIA'),
    ('306038', 'Reconstrucción de párpados simple', 921819.00, 'OFTALMOLOGIA'),
    ('306039', 'Tratamiento inyectable con botox (en quirofano - no incluye fármaco)', 1152275.00, 'OFTALMOLOGIA'),
    ('306040', 'Reconstrucción de párpado compleja (tumor)', 2008045.00, 'OFTALMOLOGIA'),
    ('306041', 'Cirugia de distiquiasis', 460908.00, 'OFTALMOLOGIA'),
    ('306042', 'Ptosis en niños, reconstrucciones de mas de 50% del párpado, reposicionamiento de cejas', 3400586.00, 'OFTALMOLOGIA'),
    ('306043', 'Biopsia de párpado', 460169.00, 'OFTALMOLOGIA'),
    ('306044', 'Sutura de córnea (con prolapso de iris)', 1057381.00, 'OFTALMOLOGIA'),
    ('306045', 'Queratoplastia penetrante', 7813845.00, 'OFTALMOLOGIA'),
    ('306046', 'Queratoplastia laminar', 12502153.00, 'OFTALMOLOGIA'),
    ('306047', 'Trasplante endotelial', NULL, 'OFTALMOLOGIA'),
    ('306048', 'Implante de anillos intracorneales (no incluye descartables, láser femto ni anillo)', 2734846.00, 'OFTALMOLOGIA'),
    ('306049', 'Crosslinking unilateral', 2500431.00, 'OFTALMOLOGIA'),
    ('306050', 'Sutura de córnea (sin prolapso de iris)', 704922.00, 'OFTALMOLOGIA'),
    ('306051', 'Queratocentesis - cauterización - toma de material', 596471.00, 'OFTALMOLOGIA'),
    ('306052', 'Ablación de córnea y esclera limbar y reparación cosmetica de cierre palpebral (en procedimiento de donación de organos)', 859523.00, 'OFTALMOLOGIA'),
    ('306053', 'Recubrimiento con membrana amniotica', 7813845.00, 'OFTALMOLOGIA'),
    ('306054', 'Escisión lesión conjuntival (pterigion, nevus, epitelioma, quiste)', 650694.00, 'OFTALMOLOGIA'),
    ('306055', 'Conjuntivoplastia (+ flapping, recubrimiento conjuntival de córnea)', 976047.00, 'OFTALMOLOGIA'),
    ('306056', 'Peritomía, peritectomía', 488021.00, 'OFTALMOLOGIA'),
    ('306057', 'Sutura conjuntiva - biopsia de conjuntiva', 488021.00, 'OFTALMOLOGIA'),
    ('306058', 'Conjuntivoplastia con injerto de limbo', 1084494.00, 'OFTALMOLOGIA'),
    ('306059', 'Biopsia de conjuntiva', 437575.00, 'OFTALMOLOGIA'),
    ('306060', 'Sutura de conjuntiva', 375064.00, 'OFTALMOLOGIA'),
    ('306061', 'Estrabismo (toda técnica o cantidad de músculos - no incluye monitoreo, anestesia ni remedios)', 1801091.00, 'OFTALMOLOGIA'),
    ('306062', 'Estrabismo unilateral con sutura reajustable', 2344153.00, 'OFTALMOLOGIA'),
    ('306063', 'Iridectomía, iridotomía, coreoplastia', 921819.00, 'OFTALMOLOGIA'),
    ('306064', 'Iridociclectomía o iridociclotomía por tumores', 2277436.00, 'OFTALMOLOGIA'),
    ('306065', 'Trabeculectomía - trabeculotomía - viscocanalostomía (no incluye dispositivos migs)', 1554407.00, 'OFTALMOLOGIA'),
    ('306066', 'Implante de dispositivo de drenaje (no incluye válvula)', 1952086.00, 'OFTALMOLOGIA'),
    ('306067', 'Endociclo fotocoagulación', 1554407.00, 'OFTALMOLOGIA'),
    ('306068', 'Needling en consultorio', 390693.00, 'OFTALMOLOGIA'),
    ('306069', 'Needling en quirofano', 650694.00, 'OFTALMOLOGIA'),
    ('306070', 'Inyección subconguntival de 5FU', 423629.00, 'OFTALMOLOGIA'),
    ('306071', 'Ciclofotocoagulación transescleral con micropulso (no incluye sonda ni descartables)', 1554407.00, 'OFTALMOLOGIA'),
    ('306072', 'Colocación de dispositivos tipo migs (no incluye dispositivo)', 2083165.00, 'OFTALMOLOGIA'),
    ('306073', 'Extracción intracapsular', 1518290.00, 'OFTALMOLOGIA'),
    ('306074', 'Catarata + implante lio, manual (lente pmma)', 1789414.00, 'OFTALMOLOGIA'),
    ('306075', 'Facoemulsificación + implante de lio (lente pmma)', 2331663.00, 'OFTALMOLOGIA'),
    ('306076', 'Catarata congenita (incluye vitrectomía) con lio hasta 7 años', 4688308.00, 'OFTALMOLOGIA'),
    ('306077', 'Implante secundario en camara anterior (no incluye vitrectomía)', 2467222.00, 'OFTALMOLOGIA'),
    ('306078', 'Implante secundario de lio suturado a esclera o iris en paciente afaquico (no incluye vitrectomía)', 3125538.00, 'OFTALMOLOGIA'),
    ('306079', 'Implante secundario de lio suturado a esclera o iris en paciente afaquico (incluye vitrectomía)', 4688308.00, 'OFTALMOLOGIA'),
    ('306080', 'Extracción de lio de camara anterior o posterior', 948539.00, 'OFTALMOLOGIA'),
    ('306081', 'Implante faquico de camara anterior o posterior (no incluye lente)', 2397690.00, 'OFTALMOLOGIA'),
    ('306082', 'Retinopexia neumatica (mas crio, diatermia o fotocoagulación)', 2277436.00, 'OFTALMOLOGIA'),
    ('306083', 'Retinopexia con esclerectomía e implante', 3017061.00, 'OFTALMOLOGIA'),
    ('306084', 'Inyección intravitrea unilateral (en quirofano - no incluye fármacos e insumos)', 1172077.00, 'OFTALMOLOGIA'),
    ('306085', 'Implante intravitreo (incluye implante intravitreo de fármacos correspondientes e insumos quirúrgicos)', 788279.00, 'OFTALMOLOGIA'),
    ('306086', 'Inyección antiangiogenicos intravitreos por retinopatía del prematuro, en sala neonatología o quirofano*****', 1172077.00, 'OFTALMOLOGIA'),
    ('306087', 'Vitrectomía compleja con peeling de membrana, retinotomía/retinectomía/endolaser, gas y aceite', 1749333.00, 'OFTALMOLOGIA'),
    ('306088', 'Extracción de aceite post vitrectomía compleja', 1836799.00, 'OFTALMOLOGIA'),
    ('306089', 'Vitrectomía compleja en endoftalmitis', 1924265.00, 'OFTALMOLOGIA'),
    ('306090', 'Vitrectomía compleja en pacientes con nucleo luxado', 2011731.00, 'OFTALMOLOGIA'),
    ('306091', 'Vitrectomía y catarata', 2099197.00, 'OFTALMOLOGIA'),
    ('306092', 'Inyección orbitaria en quirofano', 390693.00, 'OFTALMOLOGIA'),
    ('306093', 'Enucleación - evisceración (no incluye prótesis)', 1953462.00, 'OFTALMOLOGIA'),
    ('306094', 'Reconstrucción cavidad anoftalmica, orbitotomía P/ biopsia, extracción tumor orbitario, descompresión orbitaria, fractura órbita, descompresión de vaina nervio optico', 4236302.00, 'OFTALMOLOGIA'),
    ('306095', 'Excenteración orbitaria', 6354455.00, 'OFTALMOLOGIA'),
    ('306096', 'Ablación del globo ocular y reparación cosmetica de cierre palpebral (en procedimiento de donación de organos)', 859523.00, 'OFTALMOLOGIA'),
    ('306097', 'Sondaje lagrimal bajo anestesia general (no incluye anestesia ni sus gastos)', 1719046.00, 'OFTALMOLOGIA'),
    ('306098', 'Oclusión, cauterización, taponamiento punto lagrimal (no incluye punctum plug)', 476583.00, 'OFTALMOLOGIA'),
    ('306099', 'Drenaje de absceso de saco o glandula', 937662.00, 'OFTALMOLOGIA'),
    ('306101', 'Reconstrucción post traumatica de via lagrimal', 2112857.00, 'OFTALMOLOGIA'),
    ('306102', 'Dacriocistorinostomía externa', 2112857.00, 'OFTALMOLOGIA'),
    ('306103', 'Dacriocistorinostomía con láser', 2859506.00, 'OFTALMOLOGIA'),
    ('306104', 'Dacriorinostomía con tubo de jones (no incluye tubo)', 1906333.00, 'OFTALMOLOGIA'),
    ('306105', 'Reubicación de tubo de jones despues de los 30 días', 582491.00, 'OFTALMOLOGIA'),
    ('306106', 'Sondaje lagrimal con anestesia local', 468830.00, 'OFTALMOLOGIA'),
    ('306107', 'Exfoliación, canalización e inyección de sustancias en glandulas de meibomio', 1445561.00, 'OFTALMOLOGIA'),
    ('306108', 'Estudio de las glandulas de meibomio, capa liquidos, nibut con imagenes infra rojas', 183626.00, 'OFTALMOLOGIA'),
    ('306109', 'Estudio parasitológico de pestañas (demodex)', 54696.00, 'OFTALMOLOGIA'),
    ('306111', 'Canuloplastia', 937662.00, 'OFTALMOLOGIA'),
    ('306112', 'Extracción cuerpo extraño subconjuntival o subtenoniano', 847260.00, 'OFTALMOLOGIA'),
    ('306113', 'Extracción de cuerpo extraño intracorneal', 317725.00, 'OFTALMOLOGIA'),
    ('306114', 'Herida perforante con cuerpo extraño en camara anterior', 1164984.00, 'OFTALMOLOGIA'),
    ('306115', 'Lavado de camara anterior (como única operación)', 688400.00, 'OFTALMOLOGIA'),
    ('306116', 'Herida perforante con lesión de córnea, esclera, iris y cristalino (puede ir lio)', 3171932.00, 'OFTALMOLOGIA'),
    ('306117', 'Herida perforante C/ cuerpo extraño intraocular Q/ requiera extracción y procedimientos S/ retina y/o vítreo (láser, gas, aceite)', 5030608.00, 'OFTALMOLOGIA'),
    ('306118', 'Sutura de herida palpebral sin compromiso de via lagrimal', 635443.00, 'OFTALMOLOGIA'),
    ('306119', 'Sutura herida palpebral C/ compromiso via lagrimal (intubación C/ silicon y extracción a los 2 meses)', 1270890.00, 'OFTALMOLOGIA'),
    ('306120', 'Herida escleral + 4MM por detras del limbo Q/ requiera tratamiento profilactico de DR (implante silicon, crio, diatermia, láser)', 2435876.00, 'OFTALMOLOGIA'),
    ('306121', 'Fractura de piso orbitario (no incluye prótesis)', 2912458.00, 'OFTALMOLOGIA'),
    ('306122', 'Lipectomía uni o bilateral', 4236302.00, 'OFTALMOLOGIA'),
    ('306123', 'Descompresión uni o bilateral', 4236302.00, 'OFTALMOLOGIA'),
    ('306124', 'Primera consulta de baja visión - diagnóstico y receta de lentes especiales y/o ayudas', 273484.00, 'OFTALMOLOGIA'),
    ('306125', 'Consultas siguientes (seguimiento de patología)', 136742.00, 'OFTALMOLOGIA'),
    ('306126', 'Adaptación de lentes de contacto', 312554.00, 'OFTALMOLOGIA'),
    ('306127', 'Eventuales controles post adaptación', 78139.00, 'OFTALMOLOGIA'),
    ('306128', 'Anestesia para practicas oftalmológicas (excluye practica oftalmológica)', 407159.00, 'OFTALMOLOGIA'),
    ('306129', 'Tonometría de aires unilateral-neumotonometría', 16953.00, 'OFTALMOLOGIA'),
    ('306130', 'Oftalmoscopia binocular indirecta unilateral', 30292.00, 'OFTALMOLOGIA'),
    ('306131', 'Gonioscopia con lente tres o 4 espejos unilateral', 26824.00, 'OFTALMOLOGIA'),
    ('306132', 'Topografía posterior (por ojo)', 137806.00, 'OFTALMOLOGIA'),
    ('306133', 'Videonistagmografía', 130384.00, 'OFTALMOLOGIA')
ON CONFLICT (codigo) DO UPDATE
   SET descripcion = EXCLUDED.descripcion,
       valor = EXCLUDED.valor,
       categoria = EXCLUDED.categoria;

REVOKE ALL PRIVILEGES ON TABLE public.oftar_nomenclador_source FROM PUBLIC;
DO $$
BEGIN
    IF to_regrole('origen_admin') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE public.oftar_nomenclador_source TO origen_admin';
    END IF;
    IF to_regrole('origen_med') IS NOT NULL THEN
        EXECUTE 'GRANT SELECT ON TABLE public.oftar_nomenclador_source TO origen_med';
    END IF;
END $$;

SELECT count(*) AS filas_oftalmologia,
       count(DISTINCT codigo) AS codigos,
       min(codigo) AS primer_codigo,
       max(codigo) AS ultimo_codigo
  FROM public.oftar_nomenclador_source;

SELECT codigo, descripcion, valor
  FROM public.oftar_nomenclador_source
 WHERE codigo = '305111';

COMMIT;