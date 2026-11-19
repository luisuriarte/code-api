-- =============================================================================
-- Origen Salud · Nomenclador Odontológico Nacional (PostgreSQL, artefacto aditivo)
-- =============================================================================
--
-- Generado desde tools/sources/odontologico/odontologico.sql (dump MariaDB).
-- NO EJECUTADO. Requiere autorización explícita para DDL, carga y deploy.
--
-- Decisiones de modelo:
--   1. `nomenclador-odontologico-ar` publica los 135 códigos originales.
--   2. Cada fila se vincula con su DNT-PR por `referencia_literal` en ambos
--      sentidos; no se declara equivalencia clínica asumida.
--   3. DENTAR-PR conserva el código nacional como identificador secundario
--      y buscable; el código visible sigue siendo DNT-PR-NNNNNN.
--   4. Los 10 indicadores del dump se conservan como campos literales de
--      fuente, también en la ficha DENTAR-PR correspondiente.
-- =============================================================================

SET client_encoding = 'UTF8';

BEGIN;

-- -----------------------------------------------------------------------------
-- 1. Espejo de la fuente MariaDB: los 13 campos se conservan literalmente
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_source_odontologico_nacional (
    codigo VARCHAR(50) PRIMARY KEY,
    descripcion TEXT NOT NULL,
    factura BOOLEAN NOT NULL DEFAULT FALSE,
    ficha_odontolog BOOLEAN NOT NULL DEFAULT FALSE,
    ficha_periodontal BOOLEAN NOT NULL DEFAULT FALSE,
    pieza BOOLEAN NOT NULL DEFAULT FALSE,
    caras BOOLEAN NOT NULL DEFAULT FALSE,
    rx_pre BOOLEAN NOT NULL DEFAULT FALSE,
    rx_post BOOLEAN NOT NULL DEFAULT FALSE,
    material BOOLEAN NOT NULL DEFAULT FALSE,
    maxilar BOOLEAN NOT NULL DEFAULT FALSE,
    agrupamiento VARCHAR(100),
    norma_particular TEXT
);

CREATE TABLE IF NOT EXISTS os_catalog_source_attribute (
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    source_catalog_code VARCHAR(50) NOT NULL,
    attribute_code VARCHAR(50) NOT NULL,
    attribute_label VARCHAR(150) NOT NULL,
    attribute_value TEXT NOT NULL,
    is_boolean BOOLEAN NOT NULL DEFAULT FALSE,
    display_order INT NOT NULL DEFAULT 0,
    PRIMARY KEY (item_id, source_catalog_code, attribute_code)
);

CREATE TEMP TABLE _nomenclador_categoria (
    code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(150) NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE _nomenclador_clasificacion (
    codigo VARCHAR(50) PRIMARY KEY,
    categoria_code VARCHAR(50) NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE _nomenclador_dentar_match (
    source_codigo VARCHAR(50) PRIMARY KEY,
    dentar_item_id INT NOT NULL,
    dentar_code VARCHAR(30) NOT NULL
) ON COMMIT DROP;

CREATE TEMP TABLE _nomenclador_attribute_target (
    item_id INT PRIMARY KEY,
    source_codigo VARCHAR(50) NOT NULL
) ON COMMIT DROP;

DELETE FROM os_source_odontologico_nacional;

INSERT INTO os_source_odontologico_nacional (
    codigo, descripcion, factura, ficha_odontolog, ficha_periodontal,
    pieza, caras, rx_pre, rx_post, material, maxilar, agrupamiento, norma_particular
) VALUES
    ('01.01', 'Examen-Diagnóstico-Fichado y plan de tratamiento', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo I - Consultas', 'Se considera primera consulta al examen, diagnóstico, el fichado y plan de tratamiento. Como consecuencia del examen, el fichado deberá reflejar el estado actual de la boca, previo al tratamiento a efectuarse. El código 01.01 podrá facturarse hasta una vez por año, salvo para menores de dieciocho años cuyo tope serán dos consultas por año, cualquiera fuese el número de veces que en dicho período el beneficiario demande servicios con el mismo prestador, no pudiendo facturarlo los especialistas que efectúen determinada práctica derivada de otro prestador y/o profesional. Sólo se reconocerá cuando no se realice la práctica indicada '),
    ('01.02', 'Consulta nocturna-Domingo y feriado (urgencias)', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo I - Consultas', NULL),
    ('01.03', 'Visitas a domicilio', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo I - Consultas', 'Se considera consulta domiciliaria a la atención de pacientes impedidos de trasladarse al consultorio del prestador, fuera del radio urbano. '),
    ('01.04', 'Consultas de urgencia, prestación que no constituya paso intermedio de tratamiento.', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo I - Consultas', 'Se considera consulta de urgencia a toda prestación que no constituye paso intermedio o final de tratamiento. Se debe establecer en todos los casos el motivo de la misma, Ej.: Pericoronaritis, estomatitis, cementado de coronas y puentes, punción y drenaje de abscesos, flemones, hemorragias y alveolitis, etc. '),
    ('01.05', 'Consulta de estomatología (sólo para especialistas) ', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo I - Consultas', 'Se reconoce para lesiones propias de la mucosa bucal. Se permite facturar en forma independiente del código 01.01 (Ej.: patologías: Papilomas épulis, lesiones precancerosas y cancerosas, micosis, etc.). Incluye diagnóstico e indicación de tratamiento '),
    ('01.06', 'Consulta preventiva periódica', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo I - Consultas', NULL),
    ('01.07', 'Bonos otras Obras Sociales', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo I - Consultas', NULL),
    ('02.01', 'Obturación con amalgama: cavidad simple', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá para cavidad simple habiéndose practicado correcto diagnóstico y adecuado tallado de la cavidad. '),
    ('02.02', 'Obturación con amalgama: cavidad compuesta', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad. '),
    ('02.03', 'Obturación con amalgama: cavidad compleja', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad.'),
    ('02.04', 'Obturación con amalgama: reconstrucción con tornillo en conducto', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá en piezas posteriores y con Rx post-operatoria que se incluye.'),
    ('02.05', 'Obturación Estética - Cavidad simple ', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá para cavidad simple y previo diagnóstico pulpar, y se aplica a piezas TEMPORARIAS. '),
    ('02.06', 'Obturación Estética- Cavidad compuesta o Compuesta ', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá para cavidades compuestas o complejas previo diagnóstico pulpar. y se aplica a piezas TEMPORARIAS. '),
    ('02.08', 'Obturación resina fotocurado sector Anterior y Posterior ', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá en piezas permanentes anteriores y posteriores previo diagnóstico pulpar '),
    ('02.09', 'Reconstrucción de ángulo en dientes anteriores', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá en piezas anteriores, previo diagnóstico pulpar e incluye técnicas de grabado ácido.'),
    ('02.10', 'Obturación resina fotocurado sector Posterior', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá en piezas permanentes posteriores previo diagnóstico pulpar.'),
    ('02.15', 'Composite simple ( incluye fotocurado )', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', NULL),
    ('02.16', 'Composite compuesto ( incluye fotocurado )', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', NULL),
    ('02.17', 'Composite compuesto con tornillo en conducto', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', NULL),
    ('02.15 F', 'Ferulización por causas periodontales', TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, 'Cápitulo II - Operatoria Dental', 'Se reconocerá con autorización previa, análisis de los factores traumatizantes, remitiéndose los elementos de juicio necesarios para su evaluación. Periodo de cobertura mínima de tres (3) años.'),
    ('03.01', 'Tratamiento de un conducto', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo III - Endodoncia', NULL),
    ('03.02', 'Tratamiento de dos conductos', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo III - Endodoncia', NULL),
    ('03.03', 'Tratamiento de tres conductos', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo III - Endodoncia', NULL),
    ('03.04', 'Tratamiento de cuatro conductos', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo III - Endodoncia', NULL),
    ('03.05', 'Biopulpectomía parcial', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo III - Endodoncia', 'Cuando se realice esta práctica no se reconocerá otro tratamiento de endodoncia y su  correspondiente restauración coronaria hasta un año después de efectuada la misma, si  es realizado por el mismo profesional. Solamente para piezas con foramen apical abierto o en formación.'),
    ('03.06', 'Necropulpectomía parcial ( momificación )', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo III - Endodoncia', 'Se reconocerá solamente en dientes posteriores.'),
    ('04.01.01', 'Incrustaciones:  cavidad simple', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.02', 'Incrustaciones: cavidad compuesta o compleja', TRUE, TRUE, FALSE, TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.03', 'Corona forjada', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'No incluye corona provisoria. Para su reconocimiento deberá fundamentarse el motivo de su confección.'),
    ('04.01.04', 'Corona colada', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'No incluye corona provisoria.'),
    ('04.01.05', 'Corona colada con frente estético', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'No incluye corona provisoria. Incluye la carilla de acrílico. '),
    ('04.01.06', 'Corona espiga', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'Incluye pieza metálica y acrílico.'),
    ('04.01.07', 'Corona colada revestida en acrílico', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'No incluye corona provisoria. Incluye pieza metálica y acrílica y metálica.'),
    ('04.01.07 bis', 'Corona colada revestida en porcelana', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.07 bis i', 'Corona colada revestida en porcelana sobre implante', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.08', 'Perno muñón simple', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias. '),
    ('04.01.08 i', 'Emergente o intermediario sobre implantes', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.09', 'Perno muñon seccionado', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias.'),
    ('04.01.10', 'Tramo de puente colado', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'Incluye pieza metálica y acrílico.'),
    ('04.01.10 bis', 'Tramo puente colado ( porcelana )', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.11', 'Corona de acrílico', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'No incluye corona provisoria.'),
    ('04.01.12', 'Corona provisoria', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', 'Para su reconocimiento podrá requerirse su presentación.'),
    ('04.01.12 i', 'Corona provisoria sobre implantes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.15', 'Ataches', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.16', 'Poste bola', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.01.17', 'Barra tangencial tipo Dolder', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo IV – Prótesis Fija', NULL),
    ('04.02.01', 'De acrílico: hasta cuatro dientes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, 'Prótesis parcial removible', ' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
    ('04.02.02', 'De acrílico: de cinco o más dientes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, 'Prótesis parcial removible', ' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
    ('04.02.03', 'Cromo cobalto: hasta cuatro dientes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, 'Prótesis parcial removible', ' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
    ('04.02.04', 'Cromo cobalto: de cinco o más dientes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, 'Prótesis parcial removible', ' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
    ('04.02.04 i', 'Cromo cobalto sobre implantes ', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, 'Prótesis parcial removible', NULL),
    ('04.02.05', 'Prótesis parcial inmediata ( temporaria )', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis parcial removible', 'Incluye cubeta individual, retenedores, cualquier número dientes, eventual rebasado y controles posteriores. No podrá reconocerse la facturación de la prótesis definitiva, hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.'),
    ('04.02.05 i', 'Prótesis parcial inmediata ( temporaria ) sobre implantes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis parcial removible', NULL),
    ('04.03.01', 'Superior', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis completa - 04.03', 'Incluye las consultas posteriores a su instalación para los retoques necesarios.'),
    ('04.03.01 i', 'Superior sobre implantes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis completa - 04.04', NULL),
    ('04.03.02', 'Inferior', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis completa - 04.05', 'Incluye las consultas posteriores a su instalación para los retoques necesarios.'),
    ('04.03.02 i', 'Inferior sobre implantes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis completa - 04.06', NULL),
    ('04.03.03', 'Prótesis completa inmediata ( temporaria )', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis completa - 04.07', 'Incluye cubeta individual, eventual rebasado y controles posteriores a su instalación. No podrá reconocerse la facturación de la prótesis definitiva hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.'),
    ('04.03.03 i', 'Prótesis completa inmediata sobre implantes ( temporaria )', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Prótesis completa - 04.08', NULL),
    ('04.04.01', 'Compostura simple', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Varios', NULL),
    ('04.04.02', 'Compostura con agregado de un diente', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', NULL),
    ('04.04.03', 'Compostura con agregado de un retenedor', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', NULL),
    ('04.04.04', 'Compostura simple con agregado de un diente y un retenedor', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', NULL),
    ('04.04.05', 'Diente subsiguiente, c/u', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', NULL),
    ('04.04.06', 'Retenedor subsiguiente, c/u', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', NULL),
    ('04.04.07', 'Soldado de retención en aparatos de cromo', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', 'Incluye el montaje del diente artificial.'),
    ('04.04.08', 'Retención subsiguiente', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', NULL),
    ('04.04.09', 'Carilla de acrílico', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', NULL),
    ('04.04.10', 'Rebasado de prótesis, c/u', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Varios', NULL),
    ('04.04.11', 'Cubeta individual', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Varios', 'Se reconocerá cuando se efectúe con acrílico termocurable, pudiendo requerirse su presentación para su reconocimiento.'),
    ('04.04.12', 'Levante de articulación, en acrílico traslucido y retenedores forjados en acero. ', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Varios', 'Incluye cubeta individual y controles posteriores. Gramos estimados de los metales utilizados en las siguientes prácticas según código '),
    ('05.00', 'Ficha de prevención. ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo V - Odontología Preventiva', NULL),
    ('05.01', 'Tartrectomía y cepillado mecánico', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo V - Odontología Preventiva', 'No incluye blanqueamiento de piezas dentarias.  Se cubre una vez por año a pacientes mayores de 18 años.'),
    ('05.02', 'Aplicación de fluor, incluye cepillado previo y tartrectomía', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo V - Odontología Preventiva', 'Incluye Tartrectomía y cepillado mecánico, detección y control de placa bacteriana,  enseñanza de técnicas de higiene. Comprende aplicación de flúor tópico, barniz y  colutorios. O sea, incluye código 05.04.  Se cubrirá hasta los 18 años y semestralmente.'),
    ('05.03', 'Detección de placa bacteriana y test de susceptibilidad de caries', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo V - Odontología Preventiva', NULL),
    ('05.04', 'Enseñanzas de técnicas de higiene bucal.Incluye control de placa y test de suscep.', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo V - Odontología Preventiva', 'Incluye detección de placa bacteriana y enseñanza de técnica de higiene bucal.  Comprende uso de elementos como interdentarios, asesoramiento dietético y revelado  de placa, se aplica en mayores de 18 años.'),
    ('05.05', 'Sellantes de puntos y fisuras', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo V - Odontología Preventiva', 'Se reconoce hasta los 15 años en premolares y molares permanentes enteros con un  período de responsabilidad de dos años, no pudiendo facturar el mismo profesional prestador obturaciones ni extracciones de las piezas tratadas en dicho período de  tiempo. No se acepta en caras libres. '),
    ('05.06', 'Aplicación de cariostáticos en piezas dentarias permanentes', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo V - Odontología Preventiva', 'Se cubrirá para aquellos casos que sea necesario curar infección de ulceras,  estabilización de procesos de destrucción, mineralización, etc. Se contempla en piezas  permanentes, hasta una vez por año por pieza (incluye las aplicaciones necesarias),  aclarando diagnóstico.'),
    ('06.01', 'Consulta de estudio', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VI - Ortodoncia y ortopedia funcional', NULL),
    ('06.02', 'Tratamiento de la dentición primaria o mixta *', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VI - Ortodoncia y ortopedia funcional', NULL),
    ('06.03', 'Tratamiento de la dentición permanente *', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VI - Ortodoncia y ortopedia funcional', NULL),
    ('06.04', 'Corrección de malposiciones simples con espacio', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VI - Ortodoncia y ortopedia funcional', NULL),
    ('06.05', 'Tratamiento de la dentición permanente: hemi - arcada. ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VI - Ortodoncia y ortopedia funcional', NULL),
    ('07.01', 'Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 13 años', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VII - Odontopediatría', 'Se reconocerán hasta los 13 años de edad. Incluye 01.01 y comprende hasta tres visitas  al consultorio'),
    ('07.02', 'Mantenedor de espacio fijo', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Capítulo VII - Odontopediatría', 'Incluye corona en pieza dentaria y ansa de alambre de apoyo. Deberá acompañar  radiografía post-operatoria. Se cubre por única vez y en pacientes hasta 8 años de  edad. Requiere autorización previa.'),
    ('07.03', 'Mantenedor de espacio removible', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VII - Odontopediatría', 'Se reconocerá cuando falten dos o más dientes primarios contiguos o más de dos  dientes alternados en la misma arcada dental. Se cubre por única vez y en pacientes  hasta 8 años de edad. Requiere autorización previa.'),
    ('07.04', 'Tratamiento de dientes primarios con formocresol', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Capítulo VII - Odontopediatría', 'Se reconoce con radiografía post-operatoria, y cuando el diente tratado no se encuentre  en período de exfoliación normal. '),
    ('07.05', 'Corona de acero y similares', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Capítulo VII - Odontopediatría', 'Se reconocerá en dientes primarios con gran destrucción coronaria y que no se  encuentre en período de exfoliación normal. Incluye toda obturación realizada por el  mismo profesional y deberá acompañar radiografía post-operatoria. En primeros  molares permanentes hasta los 15 años de edad. Requiere autorización previa. '),
    ('07.06.01', 'Reducción de luxación con inmovilización dentaria', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Odontopediatría (Traumatismos dentarios)', NULL),
    ('07.06.02', 'Luxación total ( reimplante ) o inmovilización dentaria', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Odontopediatría (Traumatismos dentarios)', 'No incluye el tratamiento endodónticos.'),
    ('07.06.04', 'Fractura amelodentinaria, protección pulpar con coronas provisorias', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Odontopediatría (Traumatismos dentarios)', 'Incluye corona provisoria y se reconocerá con Rx pre y post operatoria.'),
    ('07.07', 'Protección pulpar directa', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Odontopediatría (Traumatismos dentarios)', 'Se reconoce en piezas molares permanentes con Rx post-operatoria incluida en valor de  la prestación. Por el término de seis (6) meses no se reconocerá otro tratamiento pulpar.  Se aplica hasta los 18 años.'),
    ('07.08', 'Aplicación de cariostáticos', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Odontopediatría (Traumatismos dentarios)', 'Se aplicará ante la presencia de caries rampantes en dientes temporarios, por única  vez y hasta los seis (6) años.'),
    ('08.01', 'Consulta de estudio-Diagnóstico-Pronóstico', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', 'Incluye la confección de la ficha periodontal respectiva (de acuerdo al modelo que se  adopte), la cual deberá acompañar a los códigos 08.03. y 08.04. Se reconocerá una vez  cada dos años e incluye código 0101.'),
    ('08.02', 'Tratamiento de gingivitis, marginal crónica', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', 'Comprende todos los cuadros gingivales cualquiera fuese su etiología. Incluye Tartrectomía, raspado, control de placas, enseñanza de cepillado y FLUOR ambas  arcadas. Como única patología se reconocerá una vez por año. Cuando en la ficha  periodontal correspondiente a los códigos 08.03. y 08.04.; se señale esta patología en  otros sectores de la boca, se podrá sumar este código para el resto de las piezas. '),
    ('08.04 C', 'Cirugía Periodontal', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', NULL),
    ('08.05', 'Desgaste selectivo o armonización oclusal', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', 'Se reconocerá cuando se detalle el estudio de la oclusión y el análisis de los factores  traumatizantes, remitiendo los elementos de juicio necesarios para su evaluación. '),
    ('08.05.01', 'ATM. y bruxismo, terapia farmacológica y fisioterapia. ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', NULL),
    ('08.05.02', 'Aparato de estabilización oclusal y en relación céntrica. ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', NULL),
    ('08.05.03', 'Aparato oclusal pivotante. ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', NULL),
    ('08.07', 'Mantenimiento de tratamiento periodontal', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo VIII - Periodoncia', 'Se reconocerá cada seis (6) meses siempre que exista tratamiento previo de 08.03 u  08.04, y con el mismo profesional. Incluye 05.01; 05.04 y 08.02 '),
    ('09.01.01', 'Periapical, técnicas de cono corto o cono largo', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Intraorales – 09.01)', 'Se admite como máximo cuatro veces la suma. De cinco a siete películas se facturará como  código 09.01.04., de ocho a nueve películas se facturará como código 09.01.04., más una o dos  veces el código 09.01.01. según corresponda. De diez a catorce películas se facturará como código 09.01. 05.'),
    ('09.01.02', 'Bite-Wing', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Intraorales – 09.01)', NULL),
    ('09.01.03', 'Oclusal de 6 x 8 cm.', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Intraorales – 09.01)', NULL),
    ('09.01.04', 'Media seriada: 7 películas- Técnicas de cono corto o largo', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Intraorales – 09.01)', 'Se reconocerá cuando la integren siete películas.'),
    ('09.01.05', 'Seriada de 14 péliculas- técnicas de cono corto o largo', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Intraorales – 09.01)', 'Se reconocerá cuando la integren 14 películas.'),
    ('09.02.01', 'Extraorales: primera exposición', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Extraorales – 09.02)', 'Comprende todas las radiografías extraorales de la especialidad, exceptuadas las  señaladas con los códigos 09.02.03., 09.02.04., 09.02.05 y 09.02.06. '),
    ('09.02.02', 'Extraorales: por exposición subsiguiente', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Extraorales – 09.02)', 'Comprende todas las radiografías extraorales de la especialidad, 09.02.05 y 09.02.06.'),
    ('09.02.03', 'Articulación Temporo-maxilar ( 6 tomas )', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Extraorales – 09.02)', 'Técnica de Schuller Modificada. Incluye seis tomas comparativas, tres por lado.'),
    ('09.02.04', 'Pantomografía ( radiografícas panorámicas )', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Extraorales – 09.02)', 'Radiografía panorámica. Es el estudio panorámico de la cavidad bucal y zonas vecinas.'),
    ('09.02.05', 'Telerradiografía cefalométrica', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Extraorales – 09.02)', NULL),
    ('09.02.05 bis', 'Estudio o trazado cefalométrico', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Extraorales – 09.02)', NULL),
    ('09.02.06', 'Sialografía', TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo IX – Radiología (Extraorales – 09.02)', 'No incluye la sustancia de contraste. Comprende el estudio con un mínimo de tres placas,  por glándula y por lado.'),
    ('10.01', 'Extracción dentaria', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'No se contempla su cobertura en piezas temporarias en su periodo de exfoliación.'),
    ('10.02', 'Plástica de comunicación buco-sinusal como riesgo previsto simultáneo a la extracción', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Para su reconocimiento deberá acompañarse la radiografía preoperatoria que justifique  la realización de la práctica.'),
    ('10.03', 'Biopsia por punción o aspiración', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'No incluye el estudio Anatomopatológico.'),
    ('10.04', 'Alveolectomia estabilizadora ( 6 zonas ): por zona', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Podrá requerir autorización previa.'),
    ('10.05', 'Reimplante dentario inmediato al traumatismo', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconoce con radiografía post-operatoria.'),
    ('10.06', 'Incisión y drenaje de abscesos por via intrabucal', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', NULL),
    ('10.07', 'Biopsia por escisión', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'No incluye el estudio Anatomopatológico.'),
    ('10.08', 'Alargamiento quirúrgico de la corona clínica', TRUE, TRUE, FALSE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconoce solo asociado a práctica de la misma facturación.'),
    ('10.09', 'Extracción de dientes retenidos o restos radiculares retenidos', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconocerá con radiografía pre y post-operatoria.'),
    ('10.10', 'Germectomía', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconocerá con radiografía pre y post-operatoria. Podrá requerirse autorización previa.'),
    ('10.11', 'Libreración de dientes retenidos', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconocerá con radiografía pre-operatoria y post-operatoria.'),
    ('10.12', 'Apicectomía', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconocerá con radiografía pre y post-operatoria.'),
    ('10.13', 'Tratamiento de osteomielitis', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', NULL),
    ('10.14', 'Extracción de cuerpo extraño', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconocerá con radiografía pre y post-operatoria.'),
    ('10.15', 'Alveolectomía correctiva( 6 zonas ): por zona', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', 'Se reconocerá con radiografía pre y post-operatoria.'),
    ('10.16', 'Frenectomía', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Capítulo X - Cirugía Bucal', NULL),
    ('10.17', 'Radectomía', TRUE, TRUE, FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', NULL),
    ('10.18', 'Extracción por alveolectomía externa (complicación de extracción). ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', NULL),
    ('10.19', 'Extracción de dientes en retención ósea. ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', NULL),
    ('10.20', 'Sutura de encías como tratamiento de lesión traumática. ', FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, 'Capítulo X - Cirugía Bucal', NULL),
    ('11.01.01', 'Implante dentario', TRUE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, FALSE, FALSE, 'Capítulo XI – Implantes', NULL),
    ('11.02', 'Relleno óseo ', TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE, 'Capítulo XI – Implantes', NULL);

INSERT INTO _nomenclador_categoria (code, name) VALUES
    ('capitulo-i-consultas', 'Capítulo I - Consultas'),
    ('capitulo-ii-operatoria-dental', 'Cápitulo II - Operatoria Dental'),
    ('capitulo-iii-endodoncia', 'Capítulo III - Endodoncia'),
    ('capitulo-iv-protesis-fija', 'Capítulo IV – Prótesis Fija'),
    ('capitulo-ix-radiologia-extraorales-09-02', 'Capítulo IX – Radiología (Extraorales – 09.02)'),
    ('capitulo-ix-radiologia-intraorales-09-01', 'Capítulo IX – Radiología (Intraorales – 09.01)'),
    ('capitulo-v-odontologia-preventiva', 'Capítulo V - Odontología Preventiva'),
    ('capitulo-vi-ortodoncia-y-ortopedia-funcional', 'Capítulo VI - Ortodoncia y ortopedia funcional'),
    ('capitulo-vii-odontopediatria', 'Capítulo VII - Odontopediatría'),
    ('capitulo-viii-periodoncia', 'Capítulo VIII - Periodoncia'),
    ('capitulo-x-cirugia-bucal', 'Capítulo X - Cirugía Bucal'),
    ('capitulo-xi-implantes', 'Capítulo XI – Implantes'),
    ('odontopediatria-traumatismos-dentarios', 'Odontopediatría (Traumatismos dentarios)'),
    ('protesis-completa-04-03', 'Prótesis completa - 04.03'),
    ('protesis-completa-04-04', 'Prótesis completa - 04.04'),
    ('protesis-completa-04-05', 'Prótesis completa - 04.05'),
    ('protesis-completa-04-06', 'Prótesis completa - 04.06'),
    ('protesis-completa-04-07', 'Prótesis completa - 04.07'),
    ('protesis-completa-04-08', 'Prótesis completa - 04.08'),
    ('protesis-parcial-removible', 'Prótesis parcial removible'),
    ('varios', 'Varios');

INSERT INTO _nomenclador_clasificacion (codigo, categoria_code) VALUES
    ('01.01', 'capitulo-i-consultas'),
    ('01.02', 'capitulo-i-consultas'),
    ('01.03', 'capitulo-i-consultas'),
    ('01.04', 'capitulo-i-consultas'),
    ('01.05', 'capitulo-i-consultas'),
    ('01.06', 'capitulo-i-consultas'),
    ('01.07', 'capitulo-i-consultas'),
    ('02.01', 'capitulo-ii-operatoria-dental'),
    ('02.02', 'capitulo-ii-operatoria-dental'),
    ('02.03', 'capitulo-ii-operatoria-dental'),
    ('02.04', 'capitulo-ii-operatoria-dental'),
    ('02.05', 'capitulo-ii-operatoria-dental'),
    ('02.06', 'capitulo-ii-operatoria-dental'),
    ('02.08', 'capitulo-ii-operatoria-dental'),
    ('02.09', 'capitulo-ii-operatoria-dental'),
    ('02.10', 'capitulo-ii-operatoria-dental'),
    ('02.15', 'capitulo-ii-operatoria-dental'),
    ('02.16', 'capitulo-ii-operatoria-dental'),
    ('02.17', 'capitulo-ii-operatoria-dental'),
    ('02.15 F', 'capitulo-ii-operatoria-dental'),
    ('03.01', 'capitulo-iii-endodoncia'),
    ('03.02', 'capitulo-iii-endodoncia'),
    ('03.03', 'capitulo-iii-endodoncia'),
    ('03.04', 'capitulo-iii-endodoncia'),
    ('03.05', 'capitulo-iii-endodoncia'),
    ('03.06', 'capitulo-iii-endodoncia'),
    ('04.01.01', 'capitulo-iv-protesis-fija'),
    ('04.01.02', 'capitulo-iv-protesis-fija'),
    ('04.01.03', 'capitulo-iv-protesis-fija'),
    ('04.01.04', 'capitulo-iv-protesis-fija'),
    ('04.01.05', 'capitulo-iv-protesis-fija'),
    ('04.01.06', 'capitulo-iv-protesis-fija'),
    ('04.01.07', 'capitulo-iv-protesis-fija'),
    ('04.01.07 bis', 'capitulo-iv-protesis-fija'),
    ('04.01.07 bis i', 'capitulo-iv-protesis-fija'),
    ('04.01.08', 'capitulo-iv-protesis-fija'),
    ('04.01.08 i', 'capitulo-iv-protesis-fija'),
    ('04.01.09', 'capitulo-iv-protesis-fija'),
    ('04.01.10', 'capitulo-iv-protesis-fija'),
    ('04.01.10 bis', 'capitulo-iv-protesis-fija'),
    ('04.01.11', 'capitulo-iv-protesis-fija'),
    ('04.01.12', 'capitulo-iv-protesis-fija'),
    ('04.01.12 i', 'capitulo-iv-protesis-fija'),
    ('04.01.15', 'capitulo-iv-protesis-fija'),
    ('04.01.16', 'capitulo-iv-protesis-fija'),
    ('04.01.17', 'capitulo-iv-protesis-fija'),
    ('04.02.01', 'protesis-parcial-removible'),
    ('04.02.02', 'protesis-parcial-removible'),
    ('04.02.03', 'protesis-parcial-removible'),
    ('04.02.04', 'protesis-parcial-removible'),
    ('04.02.04 i', 'protesis-parcial-removible'),
    ('04.02.05', 'protesis-parcial-removible'),
    ('04.02.05 i', 'protesis-parcial-removible'),
    ('04.03.01', 'protesis-completa-04-03'),
    ('04.03.01 i', 'protesis-completa-04-04'),
    ('04.03.02', 'protesis-completa-04-05'),
    ('04.03.02 i', 'protesis-completa-04-06'),
    ('04.03.03', 'protesis-completa-04-07'),
    ('04.03.03 i', 'protesis-completa-04-08'),
    ('04.04.01', 'varios'),
    ('04.04.02', 'varios'),
    ('04.04.03', 'varios'),
    ('04.04.04', 'varios'),
    ('04.04.05', 'varios'),
    ('04.04.06', 'varios'),
    ('04.04.07', 'varios'),
    ('04.04.08', 'varios'),
    ('04.04.09', 'varios'),
    ('04.04.10', 'varios'),
    ('04.04.11', 'varios'),
    ('04.04.12', 'varios'),
    ('05.00', 'capitulo-v-odontologia-preventiva'),
    ('05.01', 'capitulo-v-odontologia-preventiva'),
    ('05.02', 'capitulo-v-odontologia-preventiva'),
    ('05.03', 'capitulo-v-odontologia-preventiva'),
    ('05.04', 'capitulo-v-odontologia-preventiva'),
    ('05.05', 'capitulo-v-odontologia-preventiva'),
    ('05.06', 'capitulo-v-odontologia-preventiva'),
    ('06.01', 'capitulo-vi-ortodoncia-y-ortopedia-funcional'),
    ('06.02', 'capitulo-vi-ortodoncia-y-ortopedia-funcional'),
    ('06.03', 'capitulo-vi-ortodoncia-y-ortopedia-funcional'),
    ('06.04', 'capitulo-vi-ortodoncia-y-ortopedia-funcional'),
    ('06.05', 'capitulo-vi-ortodoncia-y-ortopedia-funcional'),
    ('07.01', 'capitulo-vii-odontopediatria'),
    ('07.02', 'capitulo-vii-odontopediatria'),
    ('07.03', 'capitulo-vii-odontopediatria'),
    ('07.04', 'capitulo-vii-odontopediatria'),
    ('07.05', 'capitulo-vii-odontopediatria'),
    ('07.06.01', 'odontopediatria-traumatismos-dentarios'),
    ('07.06.02', 'odontopediatria-traumatismos-dentarios'),
    ('07.06.04', 'odontopediatria-traumatismos-dentarios'),
    ('07.07', 'odontopediatria-traumatismos-dentarios'),
    ('07.08', 'odontopediatria-traumatismos-dentarios'),
    ('08.01', 'capitulo-viii-periodoncia'),
    ('08.02', 'capitulo-viii-periodoncia'),
    ('08.04 C', 'capitulo-viii-periodoncia'),
    ('08.05', 'capitulo-viii-periodoncia'),
    ('08.05.01', 'capitulo-viii-periodoncia'),
    ('08.05.02', 'capitulo-viii-periodoncia'),
    ('08.05.03', 'capitulo-viii-periodoncia'),
    ('08.07', 'capitulo-viii-periodoncia'),
    ('09.01.01', 'capitulo-ix-radiologia-intraorales-09-01'),
    ('09.01.02', 'capitulo-ix-radiologia-intraorales-09-01'),
    ('09.01.03', 'capitulo-ix-radiologia-intraorales-09-01'),
    ('09.01.04', 'capitulo-ix-radiologia-intraorales-09-01'),
    ('09.01.05', 'capitulo-ix-radiologia-intraorales-09-01'),
    ('09.02.01', 'capitulo-ix-radiologia-extraorales-09-02'),
    ('09.02.02', 'capitulo-ix-radiologia-extraorales-09-02'),
    ('09.02.03', 'capitulo-ix-radiologia-extraorales-09-02'),
    ('09.02.04', 'capitulo-ix-radiologia-extraorales-09-02'),
    ('09.02.05', 'capitulo-ix-radiologia-extraorales-09-02'),
    ('09.02.05 bis', 'capitulo-ix-radiologia-extraorales-09-02'),
    ('09.02.06', 'capitulo-ix-radiologia-extraorales-09-02'),
    ('10.01', 'capitulo-x-cirugia-bucal'),
    ('10.02', 'capitulo-x-cirugia-bucal'),
    ('10.03', 'capitulo-x-cirugia-bucal'),
    ('10.04', 'capitulo-x-cirugia-bucal'),
    ('10.05', 'capitulo-x-cirugia-bucal'),
    ('10.06', 'capitulo-x-cirugia-bucal'),
    ('10.07', 'capitulo-x-cirugia-bucal'),
    ('10.08', 'capitulo-x-cirugia-bucal'),
    ('10.09', 'capitulo-x-cirugia-bucal'),
    ('10.10', 'capitulo-x-cirugia-bucal'),
    ('10.11', 'capitulo-x-cirugia-bucal'),
    ('10.12', 'capitulo-x-cirugia-bucal'),
    ('10.13', 'capitulo-x-cirugia-bucal'),
    ('10.14', 'capitulo-x-cirugia-bucal'),
    ('10.15', 'capitulo-x-cirugia-bucal'),
    ('10.16', 'capitulo-x-cirugia-bucal'),
    ('10.17', 'capitulo-x-cirugia-bucal'),
    ('10.18', 'capitulo-x-cirugia-bucal'),
    ('10.19', 'capitulo-x-cirugia-bucal'),
    ('10.20', 'capitulo-x-cirugia-bucal'),
    ('11.01.01', 'capitulo-xi-implantes'),
    ('11.02', 'capitulo-xi-implantes');

-- -----------------------------------------------------------------------------
-- 2. Registro del catálogo dentro de la familia DENTAR
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog
    (code, name, organization, country_code, domain_type, family_code,
     product_role, short_name, description, is_active)
VALUES (
    'nomenclador-odontologico-ar',
    'Nomenclador Odontológico Nacional · Argentina',
    'Federación Odontológica de la República Argentina / Colegios Odontológicos',
    'AR', 'dental', 'dentar', 'catalog', 'NOM-ODON-AR',
    'Nomenclador odontológico argentino (Capítulos I a XI) cargado desde el dump MariaDB. Cada código se publica con su numeración original y se vincula literalmente con DENTAR-PR.',
    TRUE
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    family_code = EXCLUDED.family_code,
    product_role = EXCLUDED.product_role,
    short_name = EXCLUDED.short_name,
    description = EXCLUDED.description,
    is_active = EXCLUDED.is_active;

-- La fuente no declara vigencia: CURRENT_DATE registra la fecha de carga de la
-- release, no una fecha normativa del nomenclador.
INSERT INTO os_catalog_release (catalog_id, version_tag, valid_from, official_norm_reference, status)
SELECT id, 'NOM-ODON-AR-v1', CURRENT_DATE, 'Dump MariaDB: tools/sources/odontologico/odontologico.sql', 'published'
  FROM os_catalog WHERE code = 'nomenclador-odontologico-ar'
ON CONFLICT (catalog_id, version_tag)
DO UPDATE SET status = EXCLUDED.status,
              official_norm_reference = EXCLUDED.official_norm_reference;

-- -----------------------------------------------------------------------------
-- 3. Categorías: textos de agrupamiento sin reescribirlos
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT c.id, k.code, k.name FROM os_catalog c CROSS JOIN _nomenclador_categoria k
 WHERE c.code = 'nomenclador-odontologico-ar'
ON CONFLICT (catalog_id, code) DO UPDATE SET name = EXCLUDED.name;

-- -----------------------------------------------------------------------------
-- 4. Ítems y versiones: el código original es el código permanente
-- -----------------------------------------------------------------------------
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT c.id, s.codigo, 'active'
  FROM os_source_odontologico_nacional s CROSS JOIN os_catalog c
 WHERE c.code = 'nomenclador-odontologico-ar'
ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = 'active';

INSERT INTO os_catalog_item_version
    (item_id, release_id, category_id, preferred_term, definition, clinical_criteria, language_code)
SELECT i.id, r.id, cat.id, s.descripcion, NULLIF(s.norma_particular, ''), NULL, 'es-AR'
  FROM os_source_odontologico_nacional s
  JOIN _nomenclador_clasificacion k ON k.codigo = s.codigo
  JOIN os_catalog c ON c.code = 'nomenclador-odontologico-ar'
  JOIN os_catalog_release r ON r.catalog_id = c.id AND r.version_tag = 'NOM-ODON-AR-v1'
  JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.codigo
  LEFT JOIN os_catalog_category cat ON cat.catalog_id = c.id AND cat.code = k.categoria_code
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    preferred_term = EXCLUDED.preferred_term,
    definition = EXCLUDED.definition;

-- -----------------------------------------------------------------------------
-- 5. Correspondencia DENTAR-PR ↔ Nomenclador desde los mapeos reales
-- -----------------------------------------------------------------------------
INSERT INTO _nomenclador_dentar_match (source_codigo, dentar_item_id, dentar_code)
SELECT DISTINCT ON (m.external_code) m.external_code, dnt.id, dnt.permanent_code
  FROM dentar_concept_mapping m
  JOIN dentar_concept_version cv ON cv.id = m.concept_version_id
  JOIN dentar_concept dc ON dc.id = cv.concept_id
  JOIN os_catalog_item dnt
    ON dnt.permanent_code = dc.code
   AND dnt.catalog_id = (SELECT id FROM os_catalog WHERE code = 'dentar-pr')
 WHERE m.system_code = 'NOMENCLADOR-AR'
 ORDER BY m.external_code, cv.version_number DESC, m.id DESC;

-- -----------------------------------------------------------------------------
-- 6. Atributos literales de la fuente (indicadores 1/0 y agrupamiento)
-- -----------------------------------------------------------------------------
INSERT INTO _nomenclador_attribute_target (item_id, source_codigo)
SELECT i.id, s.codigo
  FROM os_catalog_item i
  JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'nomenclador-odontologico-ar'
  JOIN os_source_odontologico_nacional s ON s.codigo = i.permanent_code;

INSERT INTO _nomenclador_attribute_target (item_id, source_codigo)
SELECT dentar_item_id, source_codigo FROM _nomenclador_dentar_match
ON CONFLICT (item_id) DO NOTHING;

DELETE FROM os_catalog_source_attribute
 WHERE source_catalog_code = 'nomenclador-odontologico-ar' AND item_id IN (SELECT item_id FROM _nomenclador_attribute_target);

INSERT INTO os_catalog_source_attribute
    (item_id, source_catalog_code, attribute_code, attribute_label, attribute_value, is_boolean, display_order)
SELECT t.item_id, 'nomenclador-odontologico-ar', x.codigo, x.etiqueta, x.valor, x.es_booleano, x.orden
  FROM _nomenclador_attribute_target t
  JOIN os_source_odontologico_nacional s ON s.codigo = t.source_codigo
  CROSS JOIN LATERAL (
    SELECT 'factura'::text AS codigo, 'Facturable'::text AS etiqueta, CASE WHEN s.factura THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 1::int AS orden
  UNION ALL
    SELECT 'ficha_odontolog'::text AS codigo, 'Ficha odontológica'::text AS etiqueta, CASE WHEN s.ficha_odontolog THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 2::int AS orden
  UNION ALL
    SELECT 'ficha_periodontal'::text AS codigo, 'Ficha periodontal'::text AS etiqueta, CASE WHEN s.ficha_periodontal THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 3::int AS orden
  UNION ALL
    SELECT 'pieza'::text AS codigo, 'Pieza dentaria'::text AS etiqueta, CASE WHEN s.pieza THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 4::int AS orden
  UNION ALL
    SELECT 'caras'::text AS codigo, 'Caras'::text AS etiqueta, CASE WHEN s.caras THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 5::int AS orden
  UNION ALL
    SELECT 'rx_pre'::text AS codigo, 'Radiografía preoperatoria'::text AS etiqueta, CASE WHEN s.rx_pre THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 6::int AS orden
  UNION ALL
    SELECT 'rx_post'::text AS codigo, 'Radiografía postoperatoria'::text AS etiqueta, CASE WHEN s.rx_post THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 7::int AS orden
  UNION ALL
    SELECT 'material'::text AS codigo, 'Material'::text AS etiqueta, CASE WHEN s.material THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 8::int AS orden
  UNION ALL
    SELECT 'maxilar'::text AS codigo, 'Maxilar'::text AS etiqueta, CASE WHEN s.maxilar THEN '1' ELSE '0' END::text AS valor, TRUE::boolean AS es_booleano, 9::int AS orden
  UNION ALL
    SELECT 'agrupamiento'::text, 'Agrupamiento'::text, COALESCE(s.agrupamiento, ''), FALSE::boolean, 11::int
  ) x;

-- -----------------------------------------------------------------------------
-- 7. Sistema terminológico e identificadores en ambos sentidos
-- -----------------------------------------------------------------------------
SELECT setval(
    pg_get_serial_sequence('os_terminology_system', 'id'),
    (SELECT COALESCE(max(id), 1) FROM os_terminology_system),
    true
);

INSERT INTO os_terminology_system (code, name, uri, default_version)
VALUES (
    'NOMENCLADOR-AR',
    'Nomenclador Odontológico Nacional (Argentina)',
    'https://fopba.org.ar',
    '2026-v1'
)
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, uri = EXCLUDED.uri;

-- 7.1 DENTAR-PR → identificador NOMENCLADOR_AR, buscable pero no principal.
INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT dentar_item_id, 'NOMENCLADOR_AR', source_codigo, FALSE
  FROM _nomenclador_dentar_match
ON CONFLICT (item_id, system_name, value) DO UPDATE SET is_primary = FALSE;

-- 7.2 Catálogo de origen → identificador DENTAR-PR (destino de migración).
DELETE FROM os_catalog_identifier i
 USING os_catalog_item src, os_catalog c
 WHERE i.item_id = src.id AND src.catalog_id = c.id
   AND c.code = 'nomenclador-odontologico-ar' AND i.system_name = 'DENTAR-PR';

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT src.id, 'DENTAR-PR', m.dentar_code, FALSE
  FROM os_catalog_item src
  JOIN os_catalog c ON c.id = src.catalog_id AND c.code = 'nomenclador-odontologico-ar'
  JOIN _nomenclador_dentar_match m ON m.source_codigo = src.permanent_code
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 8. Relación literal navegable en la pestaña Relaciones
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS os_catalog_relation (
    id BIGSERIAL PRIMARY KEY,
    source_item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    target_item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    relation_type VARCHAR(60) NOT NULL CHECK (relation_type IN (
        'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',
        'denied_as_integral', 'frequency_limitations', 'integral_to',
        'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',
        'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',
        'referencia_literal', 'shares_frequency_limitation_with',
        'used_in_combination_with'
    )),
    source_system_code VARCHAR(30) NOT NULL DEFAULT 'CDT-2025',
    source_field VARCHAR(30) NOT NULL CHECK (source_field IN ('description', 'procedure', 'notes', 'req')),
    source_value VARCHAR(20) NOT NULL,
    context_text TEXT,
    source_cdt_id INT,
    review_status VARCHAR(20) NOT NULL DEFAULT 'reviewed'
        CHECK (review_status IN ('draft', 'reviewed', 'approved', 'deprecated')),
    provenance TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_os_catalog_relation_not_self CHECK (source_item_id <> target_item_id),
    CONSTRAINT uq_os_catalog_relation UNIQUE
        (source_item_id, target_item_id, relation_type, source_system_code,
         source_field, source_value, context_text)
);

CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_source
    ON os_catalog_relation (source_item_id);
CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_target
    ON os_catalog_relation (target_item_id);
CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_type
    ON os_catalog_relation (relation_type);

DELETE FROM os_catalog_relation r
 USING os_catalog_item src, os_catalog c, _nomenclador_dentar_match m
 WHERE (r.source_item_id = src.id AND r.target_item_id = m.dentar_item_id
        OR r.source_item_id = m.dentar_item_id AND r.target_item_id = src.id)
   AND src.catalog_id = c.id AND c.code = 'nomenclador-odontologico-ar'
   AND src.permanent_code = m.source_codigo
   AND r.relation_type = 'referencia_literal'
   AND r.source_system_code = 'NOMENCLADOR-AR';

INSERT INTO os_catalog_relation
    (source_item_id, target_item_id, relation_type, source_system_code,
     source_field, source_value, context_text, review_status, provenance)
SELECT src.id, m.dentar_item_id, 'referencia_literal', 'NOMENCLADOR-AR',
       'description', m.source_codigo,
       'Código de origen ' || m.source_codigo || '; código permanente destino ' || m.dentar_code || '. Referencia literal sin juicio de equivalencia clínica.',
       'reviewed',
       'tools/sources/odontologico/odontologico.sql · vínculo por NOMENCLADOR-AR'
  FROM os_catalog_item src
  JOIN os_catalog c ON c.id = src.catalog_id AND c.code = 'nomenclador-odontologico-ar'
  JOIN _nomenclador_dentar_match m ON m.source_codigo = src.permanent_code
UNION ALL
SELECT m.dentar_item_id, src.id, 'referencia_literal', 'NOMENCLADOR-AR',
       'description', m.dentar_code,
       'Código permanente DENTAR ' || m.dentar_code || '; código de origen ' || m.source_codigo || '. Referencia literal sin juicio de equivalencia clínica.',
       'reviewed',
       'tools/sources/odontologico/odontologico.sql · vínculo por NOMENCLADOR-AR'
  FROM os_catalog_item src
  JOIN os_catalog c ON c.id = src.catalog_id AND c.code = 'nomenclador-odontologico-ar'
  JOIN _nomenclador_dentar_match m ON m.source_codigo = src.permanent_code
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- 9. Verificación mínima (consultas de control, no aserciones)
-- -----------------------------------------------------------------------------
-- SELECT count(*) FROM os_catalog_item i JOIN os_catalog c ON c.id = i.catalog_id
--  WHERE c.code = 'nomenclador-odontologico-ar';  -- esperado: 135
-- SELECT count(*) FROM os_catalog_source_attribute
--  WHERE source_catalog_code = 'nomenclador-odontologico-ar';  -- esperado: 1485 + mapeos DENTAR
-- SELECT count(*) FROM os_catalog_relation WHERE source_system_code = 'NOMENCLADOR-AR';

COMMIT;
