/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-11.7.2-MariaDB, for Win64 (AMD64)
--
-- Host: localhost    Database: demo
-- ------------------------------------------------------
-- Server version	11.8.6-MariaDB-5ubuntu0.1 from Ubuntu

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Table structure for table `odontologico`
--

DROP TABLE IF EXISTS `odontologico`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `odontologico` (
  `codigo` varchar(50) DEFAULT NULL,
  `descripcion` text DEFAULT NULL,
  `factura` varchar(50) DEFAULT NULL,
  `ficha_odontolog` varchar(50) DEFAULT NULL,
  `ficha_periodontal` varchar(50) DEFAULT NULL,
  `pieza` varchar(20) DEFAULT NULL,
  `caras` varchar(50) DEFAULT NULL,
  `rx_pre` varchar(10) DEFAULT NULL,
  `rx_post` varchar(10) DEFAULT NULL,
  `material` varchar(100) DEFAULT NULL,
  `maxilar` varchar(50) DEFAULT NULL,
  `agrupamiento` varchar(100) DEFAULT NULL,
  `norma_particular` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `odontologico`
--

LOCK TABLES `odontologico` WRITE;
/*!40000 ALTER TABLE `odontologico` DISABLE KEYS */;
INSERT INTO `odontologico` VALUES
('01.01','Examen-Diagnóstico-Fichado y plan de tratamiento','1','1','','','','','','','','Capítulo I - Consultas','Se considera primera consulta al examen, diagnóstico, el fichado y plan de tratamiento. Como consecuencia del examen, el fichado deberá reflejar el estado actual de la boca, previo al tratamiento a efectuarse. El código 01.01 podrá facturarse hasta una vez por año, salvo para menores de dieciocho años cuyo tope serán dos consultas por año, cualquiera fuese el número de veces que en dicho período el beneficiario demande servicios con el mismo prestador, no pudiendo facturarlo los especialistas que efectúen determinada práctica derivada de otro prestador y/o profesional. Sólo se reconocerá cuando no se realice la práctica indicada '),
('01.02','Consulta nocturna-Domingo y feriado (urgencias)','1','1','','','','','','','','Capítulo I - Consultas',''),
('01.03','Visitas a domicilio','1','1','','','','','','','','Capítulo I - Consultas','Se considera consulta domiciliaria a la atención de pacientes impedidos de trasladarse al consultorio del prestador, fuera del radio urbano. '),
('01.04','Consultas de urgencia, prestación que no constituya paso intermedio de tratamiento.','1','1','','','','','','','','Capítulo I - Consultas','Se considera consulta de urgencia a toda prestación que no constituye paso intermedio o final de tratamiento. Se debe establecer en todos los casos el motivo de la misma, Ej.: Pericoronaritis, estomatitis, cementado de coronas y puentes, punción y drenaje de abscesos, flemones, hemorragias y alveolitis, etc. '),
('01.05','Consulta de estomatología (sólo para especialistas) ','1','1','','','','','','','','Capítulo I - Consultas','Se reconoce para lesiones propias de la mucosa bucal. Se permite facturar en forma independiente del código 01.01 (Ej.: patologías: Papilomas épulis, lesiones precancerosas y cancerosas, micosis, etc.). Incluye diagnóstico e indicación de tratamiento '),
('01.06','Consulta preventiva periódica','1','1','','','','','','','','Capítulo I - Consultas',''),
('01.07','Bonos otras Obras Sociales','1','1','','','','','','','','Capítulo I - Consultas',''),
('02.01','Obturación con amalgama: cavidad simple','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental','Se reconocerá para cavidad simple habiéndose practicado correcto diagnóstico y adecuado tallado de la cavidad. '),
('02.02','Obturación con amalgama: cavidad compuesta','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental','Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad. '),
('02.03','Obturación con amalgama: cavidad compleja','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental','Se reconocerá para cavidad compuesta o compleja previo diagnóstico pulpar y adecuado tallado de la cavidad.'),
('02.04','Obturación con amalgama: reconstrucción con tornillo en conducto','1','1','','1','1','','1','','','Cápitulo II - Operatoria Dental','Se reconocerá en piezas posteriores y con Rx post-operatoria que se incluye.'),
('02.05','Obturación Estética - Cavidad simple ','1','1','','1','1','','1','','','Cápitulo II - Operatoria Dental','Se reconocerá para cavidad simple y previo diagnóstico pulpar, y se aplica a piezas TEMPORARIAS. '),
('02.06','Obturación Estética- Cavidad compuesta o Compuesta ','1','1','','1','1','','1','','','Cápitulo II - Operatoria Dental','Se reconocerá para cavidades compuestas o complejas previo diagnóstico pulpar. y se aplica a piezas TEMPORARIAS. '),
('02.08','Obturación resina fotocurado sector Anterior y Posterior ','1','1','','1','1','','1','','','Cápitulo II - Operatoria Dental','Se reconocerá en piezas permanentes anteriores y posteriores previo diagnóstico pulpar '),
('02.09','Reconstrucción de ángulo en dientes anteriores','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental','Se reconocerá en piezas anteriores, previo diagnóstico pulpar e incluye técnicas de grabado ácido.'),
('02.10','Obturación resina fotocurado sector Posterior','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental','Se reconocerá en piezas permanentes posteriores previo diagnóstico pulpar.'),
('02.15','Composite simple ( incluye fotocurado )','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental',''),
('02.16','Composite compuesto ( incluye fotocurado )','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental',''),
('02.17','Composite compuesto con tornillo en conducto','1','1','','1','1','','1','','','Cápitulo II - Operatoria Dental',''),
('02.15 F','Ferulización por causas periodontales','1','1','','1','1','','','','','Cápitulo II - Operatoria Dental','Se reconocerá con autorización previa, análisis de los factores traumatizantes, remitiéndose los elementos de juicio necesarios para su evaluación. Periodo de cobertura mínima de tres (3) años.'),
('03.01','Tratamiento de un conducto','1','1','','1','','1','1','','','Capítulo III - Endodoncia',''),
('03.02','Tratamiento de dos conductos','1','1','','1','','1','1','','','Capítulo III - Endodoncia',''),
('03.03','Tratamiento de tres conductos','1','1','','1','','1','1','','','Capítulo III - Endodoncia',''),
('03.04','Tratamiento de cuatro conductos','1','1','','1','','1','1','','','Capítulo III - Endodoncia',''),
('03.05','Biopulpectomía parcial','1','1','','1','','1','1','','','Capítulo III - Endodoncia','Cuando se realice esta práctica no se reconocerá otro tratamiento de endodoncia y su  correspondiente restauración coronaria hasta un año después de efectuada la misma, si  es realizado por el mismo profesional. Solamente para piezas con foramen apical abierto o en formación.'),
('03.06','Necropulpectomía parcial ( momificación )','1','1','','1','','1','1','','','Capítulo III - Endodoncia','Se reconocerá solamente en dientes posteriores.'),
('04.01.01','Incrustaciones:  cavidad simple','1','1','','1','1','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.02','Incrustaciones: cavidad compuesta o compleja','1','1','','1','1','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.03','Corona forjada','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','No incluye corona provisoria. Para su reconocimiento deberá fundamentarse el motivo de su confección.'),
('04.01.04','Corona colada','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','No incluye corona provisoria.'),
('04.01.05','Corona colada con frente estético','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','No incluye corona provisoria. Incluye la carilla de acrílico. '),
('04.01.06','Corona espiga','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','Incluye pieza metálica y acrílico.'),
('04.01.07','Corona colada revestida en acrílico','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','No incluye corona provisoria. Incluye pieza metálica y acrílica y metálica.'),
('04.01.07 bis','Corona colada revestida en porcelana','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.07 bis i','Corona colada revestida en porcelana sobre implante','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.08','Perno muñón simple','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias. '),
('04.01.08 i','Emergente o intermediario sobre implantes','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.09','Perno muñon seccionado','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','Para su reconocimiento podrá requerirse las radiografías pre y post-operatorias.'),
('04.01.10','Tramo de puente colado','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','Incluye pieza metálica y acrílico.'),
('04.01.10 bis','Tramo puente colado ( porcelana )','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.11','Corona de acrílico','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija','No incluye corona provisoria.'),
('04.01.12','Corona provisoria','1','1','','1','','','','','','Capítulo IV – Prótesis Fija','Para su reconocimiento podrá requerirse su presentación.'),
('04.01.12 i','Corona provisoria sobre implantes','1','1','','1','','','','','','Capítulo IV – Prótesis Fija',''),
('04.01.15','Ataches','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.16','Poste bola','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.01.17','Barra tangencial tipo Dolder','1','1','','1','','1','1','','','Capítulo IV – Prótesis Fija',''),
('04.02.01','De acrílico: hasta cuatro dientes','1','1','','1','','','','1','','Prótesis parcial removible',' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
('04.02.02','De acrílico: de cinco o más dientes','1','1','','1','','','','1','','Prótesis parcial removible',' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
('04.02.03','Cromo cobalto: hasta cuatro dientes','1','1','','1','','','','1','','Prótesis parcial removible',' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
('04.02.04','Cromo cobalto: de cinco o más dientes','1','1','','1','','','','1','','Prótesis parcial removible',' Incluye cubeta individual, armazón colado, montaje de dientes artificiales y controles posteriores.'),
('04.02.04 i','Cromo cobalto sobre implantes ','1','1','','1','','','','1','','Prótesis parcial removible',''),
('04.02.05','Prótesis parcial inmediata ( temporaria )','1','1','','1','','','','','','Prótesis parcial removible','Incluye cubeta individual, retenedores, cualquier número dientes, eventual rebasado y controles posteriores. No podrá reconocerse la facturación de la prótesis definitiva, hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.'),
('04.02.05 i','Prótesis parcial inmediata ( temporaria ) sobre implantes','1','1','','1','','','','','','Prótesis parcial removible',''),
('04.03.01','Superior','1','1','','1','','','','','','Prótesis completa - 04.03','Incluye las consultas posteriores a su instalación para los retoques necesarios.'),
('04.03.01 i','Superior sobre implantes','1','1','','1','','','','','','Prótesis completa - 04.04',''),
('04.03.02','Inferior','1','1','','1','','','','','','Prótesis completa - 04.05','Incluye las consultas posteriores a su instalación para los retoques necesarios.'),
('04.03.02 i','Inferior sobre implantes','1','1','','1','','','','','','Prótesis completa - 04.06',''),
('04.03.03','Prótesis completa inmediata ( temporaria )','1','1','','1','','','','','','Prótesis completa - 04.07','Incluye cubeta individual, eventual rebasado y controles posteriores a su instalación. No podrá reconocerse la facturación de la prótesis definitiva hasta transcurridos seis meses de su instalación; con autorización previa de la Obra Social.'),
('04.03.03 i','Prótesis completa inmediata sobre implantes ( temporaria )','1','1','','1','','','','','','Prótesis completa - 04.08',''),
('04.04.01','Compostura simple','1','1','','','','','','','1','Varios',''),
('04.04.02','Compostura con agregado de un diente','1','1','','1','','','','','','Varios',''),
('04.04.03','Compostura con agregado de un retenedor','1','1','','1','','','','','','Varios',''),
('04.04.04','Compostura simple con agregado de un diente y un retenedor','1','1','','1','','','','','','Varios',''),
('04.04.05','Diente subsiguiente, c/u','1','1','','1','','','','','','Varios',''),
('04.04.06','Retenedor subsiguiente, c/u','1','1','','1','','','','','','Varios',''),
('04.04.07','Soldado de retención en aparatos de cromo','1','1','','1','','','','','','Varios','Incluye el montaje del diente artificial.'),
('04.04.08','Retención subsiguiente','1','1','','1','','','','','','Varios',''),
('04.04.09','Carilla de acrílico','1','1','','1','','','','','','Varios',''),
('04.04.10','Rebasado de prótesis, c/u','1','1','','','','','','','1','Varios',''),
('04.04.11','Cubeta individual','1','1','','','','','','','1','Varios','Se reconocerá cuando se efectúe con acrílico termocurable, pudiendo requerirse su presentación para su reconocimiento.'),
('04.04.12','Levante de articulación, en acrílico traslucido y retenedores forjados en acero. ','1','1','','','','','','','','Varios','Incluye cubeta individual y controles posteriores. Gramos estimados de los metales utilizados en las siguientes prácticas según código '),
('05.00','Ficha de prevención. ','','','','','','','','','','Capítulo V - Odontología Preventiva',''),
('05.01','Tartrectomía y cepillado mecánico','1','1','','','','','','','','Capítulo V - Odontología Preventiva','No incluye blanqueamiento de piezas dentarias.  Se cubre una vez por año a pacientes mayores de 18 años.'),
('05.02','Aplicación de fluor, incluye cepillado previo y tartrectomía','1','1','','','','','','','','Capítulo V - Odontología Preventiva','Incluye Tartrectomía y cepillado mecánico, detección y control de placa bacteriana,  enseñanza de técnicas de higiene. Comprende aplicación de flúor tópico, barniz y  colutorios. O sea, incluye código 05.04.  Se cubrirá hasta los 18 años y semestralmente.'),
('05.03','Detección de placa bacteriana y test de susceptibilidad de caries','1','1','','','','','','','','Capítulo V - Odontología Preventiva',''),
('05.04','Enseñanzas de técnicas de higiene bucal.Incluye control de placa y test de suscep.','1','1','','','','','','','','Capítulo V - Odontología Preventiva','Incluye detección de placa bacteriana y enseñanza de técnica de higiene bucal.  Comprende uso de elementos como interdentarios, asesoramiento dietético y revelado  de placa, se aplica en mayores de 18 años.'),
('05.05','Sellantes de puntos y fisuras','1','1','','1','','','','','','Capítulo V - Odontología Preventiva','Se reconoce hasta los 15 años en premolares y molares permanentes enteros con un  período de responsabilidad de dos años, no pudiendo facturar el mismo profesional prestador obturaciones ni extracciones de las piezas tratadas en dicho período de  tiempo. No se acepta en caras libres. '),
('05.06','Aplicación de cariostáticos en piezas dentarias permanentes','1','1','','1','','','','','','Capítulo V - Odontología Preventiva','Se cubrirá para aquellos casos que sea necesario curar infección de ulceras,  estabilización de procesos de destrucción, mineralización, etc. Se contempla en piezas  permanentes, hasta una vez por año por pieza (incluye las aplicaciones necesarias),  aclarando diagnóstico.'),
('06.01','Consulta de estudio','1','1','','','','','','','','Capítulo VI - Ortodoncia y ortopedia funcional',''),
('06.02','Tratamiento de la dentición primaria o mixta *','1','1','','','','','','','','Capítulo VI - Ortodoncia y ortopedia funcional',''),
('06.03','Tratamiento de la dentición permanente *','1','1','','','','','','','','Capítulo VI - Ortodoncia y ortopedia funcional',''),
('06.04','Corrección de malposiciones simples con espacio','1','1','','','','','','','','Capítulo VI - Ortodoncia y ortopedia funcional',''),
('06.05','Tratamiento de la dentición permanente: hemi - arcada. ','','','','','','','','','','Capítulo VI - Ortodoncia y ortopedia funcional',''),
('07.01','Motivación ( hasta 3 consultas ) Incluye 1ra y ficha hasta 13 años','1','1','','','','','','','','Capítulo VII - Odontopediatría','Se reconocerán hasta los 13 años de edad. Incluye 01.01 y comprende hasta tres visitas  al consultorio'),
('07.02','Mantenedor de espacio fijo','1','1','','1','','','1','','','Capítulo VII - Odontopediatría','Incluye corona en pieza dentaria y ansa de alambre de apoyo. Deberá acompañar  radiografía post-operatoria. Se cubre por única vez y en pacientes hasta 8 años de  edad. Requiere autorización previa.'),
('07.03','Mantenedor de espacio removible','1','1','','1','','','','','','Capítulo VII - Odontopediatría','Se reconocerá cuando falten dos o más dientes primarios contiguos o más de dos  dientes alternados en la misma arcada dental. Se cubre por única vez y en pacientes  hasta 8 años de edad. Requiere autorización previa.'),
('07.04','Tratamiento de dientes primarios con formocresol','1','1','','1','','','1','','','Capítulo VII - Odontopediatría','Se reconoce con radiografía post-operatoria, y cuando el diente tratado no se encuentre  en período de exfoliación normal. '),
('07.05','Corona de acero y similares','1','1','','1','','','1','','','Capítulo VII - Odontopediatría','Se reconocerá en dientes primarios con gran destrucción coronaria y que no se  encuentre en período de exfoliación normal. Incluye toda obturación realizada por el  mismo profesional y deberá acompañar radiografía post-operatoria. En primeros  molares permanentes hasta los 15 años de edad. Requiere autorización previa. '),
('07.06.01','Reducción de luxación con inmovilización dentaria','1','1','','1','','','1','','','Odontopediatría (Traumatismos dentarios)',''),
('07.06.02','Luxación total ( reimplante ) o inmovilización dentaria','1','1','','1','','','1','','','Odontopediatría (Traumatismos dentarios)','No incluye el tratamiento endodónticos.'),
('07.06.04','Fractura amelodentinaria, protección pulpar con coronas provisorias','1','1','','1','','1','1','','','Odontopediatría (Traumatismos dentarios)','Incluye corona provisoria y se reconocerá con Rx pre y post operatoria.'),
('07.07','Protección pulpar directa','1','1','','1','','','1','','','Odontopediatría (Traumatismos dentarios)','Se reconoce en piezas molares permanentes con Rx post-operatoria incluida en valor de  la prestación. Por el término de seis (6) meses no se reconocerá otro tratamiento pulpar.  Se aplica hasta los 18 años.'),
('07.08','Aplicación de cariostáticos','1','1','','1','','','1','','','Odontopediatría (Traumatismos dentarios)','Se aplicará ante la presencia de caries rampantes en dientes temporarios, por única  vez y hasta los seis (6) años.'),
('08.01','Consulta de estudio-Diagnóstico-Pronóstico','1','1','','','','','','','','Capítulo VIII - Periodoncia','Incluye la confección de la ficha periodontal respectiva (de acuerdo al modelo que se  adopte), la cual deberá acompañar a los códigos 08.03. y 08.04. Se reconocerá una vez  cada dos años e incluye código 0101.'),
('08.02','Tratamiento de gingivitis, marginal crónica','1','1','','','','','','','','Capítulo VIII - Periodoncia','Comprende todos los cuadros gingivales cualquiera fuese su etiología. Incluye Tartrectomía, raspado, control de placas, enseñanza de cepillado y FLUOR ambas  arcadas. Como única patología se reconocerá una vez por año. Cuando en la ficha  periodontal correspondiente a los códigos 08.03. y 08.04.; se señale esta patología en  otros sectores de la boca, se podrá sumar este código para el resto de las piezas. '),
('08.03','Trat. periodontitis destructiva leve o mod. Bolsas hasta  5mm por sector (6 sec)','1','','1','','','1',NULL,'','','Capítulo VIII - Periodoncia','En bolsas de hasta 5 mm., pérdida ósea alveolar de hasta 2/3 de la raíz, por sector.  Incluye 05.01; 05.04; 08.02 y 08.05 alisado radicular eventual gingivectomía o colgajo.  Periodo de cobertura: 2 años, excepto casos especiales a considerar por auditoria.  Mínimo de cuatro (4) piezas por sector. Se reconocerá con Radiografías preoperatorias y ficha periodontal debidamente  confeccionada'),
('08.04','Trat. periodontitis destructiva severa. Bolsas de 6mm o más. Por sector (6 sec)','1','','1','','','1',NULL,'','','Capítulo VIII - Periodoncia','En bolsas de 6 mm. o más, pérdida ósea alveolar de más de 2/3 y/o lesión de  furcación en grados 3 y 4 , por sector. Incluye 05.01; 05.04 ; 08.02, 08.03 y 08.05 más eventual cirugía mucogingival e  injerto.  Periodo de cobertura: 2 años., excepto casos especiales a considerar por auditoria.  Mínimo cuatro (4) piezas por sector. Se reconocerá con Radiografías preoperatorias y ficha periodontal debidamente  confeccionada'),
('08.04 C','Cirugía Periodontal','1','1','','','','1','1','','','Capítulo VIII - Periodoncia',''),
('08.05','Desgaste selectivo o armonización oclusal','1','1','','','','','','','','Capítulo VIII - Periodoncia','Se reconocerá cuando se detalle el estudio de la oclusión y el análisis de los factores  traumatizantes, remitiendo los elementos de juicio necesarios para su evaluación. '),
('08.05.01','ATM. y bruxismo, terapia farmacológica y fisioterapia. ','','','','','','','','','','Capítulo VIII - Periodoncia',''),
('08.05.02','Aparato de estabilización oclusal y en relación céntrica. ','','','','','','','','','','Capítulo VIII - Periodoncia',''),
('08.05.03','Aparato oclusal pivotante. ','','','','','','','','','','Capítulo VIII - Periodoncia',''),
('08.06','Placas oclusales ( temporarias ) removibles de acrílico, cualquier tipo','1','1','','','','','','','','Capítulo VIII - Periodoncia',NULL),
('08.07','Mantenimiento de tratamiento periodontal','1','1','','','','','','','','Capítulo VIII - Periodoncia','Se reconocerá cada seis (6) meses siempre que exista tratamiento previo de 08.03 u  08.04, y con el mismo profesional. Incluye 05.01; 05.04 y 08.02 '),
('09.01.01','Periapical, técnicas de cono corto o cono largo','1','','','','','','','','','Capítulo IX – Radiología (Intraorales – 09.01)','Se admite como máximo cuatro veces la suma. De cinco a siete películas se facturará como  código 09.01.04., de ocho a nueve películas se facturará como código 09.01.04., más una o dos  veces el código 09.01.01. según corresponda. De diez a catorce películas se facturará como código 09.01. 05.'),
('09.01.02','Bite-Wing','1','','','','','','','','','Capítulo IX – Radiología (Intraorales – 09.01)',''),
('09.01.03','Oclusal de 6 x 8 cm.','1','','','','','','','','','Capítulo IX – Radiología (Intraorales – 09.01)',''),
('09.01.04','Media seriada: 7 películas- Técnicas de cono corto o largo','1','','','','','','','','','Capítulo IX – Radiología (Intraorales – 09.01)','Se reconocerá cuando la integren siete películas.'),
('09.01.05','Seriada de 14 péliculas- técnicas de cono corto o largo','1','','','','','','','','','Capítulo IX – Radiología (Intraorales – 09.01)','Se reconocerá cuando la integren 14 películas.'),
('09.02.01','Extraorales: primera exposición','1','','','','','','','','','Capítulo IX – Radiología (Extraorales – 09.02)','Comprende todas las radiografías extraorales de la especialidad, exceptuadas las  señaladas con los códigos 09.02.03., 09.02.04., 09.02.05 y 09.02.06. '),
('09.02.02','Extraorales: por exposición subsiguiente','1','','','','','','','','','Capítulo IX – Radiología (Extraorales – 09.02)','Comprende todas las radiografías extraorales de la especialidad, 09.02.05 y 09.02.06.'),
('09.02.03','Articulación Temporo-maxilar ( 6 tomas )','1','','','','','','','','','Capítulo IX – Radiología (Extraorales – 09.02)','Técnica de Schuller Modificada. Incluye seis tomas comparativas, tres por lado.'),
('09.02.04','Pantomografía ( radiografícas panorámicas )','1','','','','','','','','','Capítulo IX – Radiología (Extraorales – 09.02)','Radiografía panorámica. Es el estudio panorámico de la cavidad bucal y zonas vecinas.'),
('09.02.05','Telerradiografía cefalométrica','1','','','','','','','','','Capítulo IX – Radiología (Extraorales – 09.02)',''),
('09.02.05 bis','Estudio o trazado cefalométrico','1','','','','','','','','','Capítulo IX – Radiología (Extraorales – 09.02)',''),
('09.02.06','Sialografía','1','','','','','','','','','Capítulo IX – Radiología (Extraorales – 09.02)','No incluye la sustancia de contraste. Comprende el estudio con un mínimo de tres placas,  por glándula y por lado.'),
('10.01','Extracción dentaria','1','1','','1','','','','','','Capítulo X - Cirugía Bucal','No se contempla su cobertura en piezas temporarias en su periodo de exfoliación.'),
('10.02','Plástica de comunicación buco-sinusal como riesgo previsto simultáneo a la extracción','1','1','','','','1','','','','Capítulo X - Cirugía Bucal','Para su reconocimiento deberá acompañarse la radiografía preoperatoria que justifique  la realización de la práctica.'),
('10.03','Biopsia por punción o aspiración','1','1','','','','','','','','Capítulo X - Cirugía Bucal','No incluye el estudio Anatomopatológico.'),
('10.04','Alveolectomia estabilizadora ( 6 zonas ): por zona','1','1','','','','','','','','Capítulo X - Cirugía Bucal','Podrá requerir autorización previa.'),
('10.05','Reimplante dentario inmediato al traumatismo','1','1','','1','','','1','','','Capítulo X - Cirugía Bucal','Se reconoce con radiografía post-operatoria.'),
('10.06','Incisión y drenaje de abscesos por via intrabucal','1','1','','','','','','','','Capítulo X - Cirugía Bucal',''),
('10.07','Biopsia por escisión','1','1','','','','','','','','Capítulo X - Cirugía Bucal','No incluye el estudio Anatomopatológico.'),
('10.08','Alargamiento quirúrgico de la corona clínica','1','1','','1','','','','','','Capítulo X - Cirugía Bucal','Se reconoce solo asociado a práctica de la misma facturación.'),
('10.09','Extracción de dientes retenidos o restos radiculares retenidos','1','1','','1','','1','1','','','Capítulo X - Cirugía Bucal','Se reconocerá con radiografía pre y post-operatoria.'),
('10.10','Germectomía','1','1','','','','1','1','','','Capítulo X - Cirugía Bucal','Se reconocerá con radiografía pre y post-operatoria. Podrá requerirse autorización previa.'),
('10.11','Libreración de dientes retenidos','1','1','','1','','1','1','','','Capítulo X - Cirugía Bucal','Se reconocerá con radiografía pre-operatoria y post-operatoria.'),
('10.12','Apicectomía','1','1','','','','1','1','','','Capítulo X - Cirugía Bucal','Se reconocerá con radiografía pre y post-operatoria.'),
('10.13','Tratamiento de osteomielitis','1','1','','','','1','1','','','Capítulo X - Cirugía Bucal',''),
('10.14','Extracción de cuerpo extraño','1','1','','','','1','1','','','Capítulo X - Cirugía Bucal','Se reconocerá con radiografía pre y post-operatoria.'),
('10.15','Alveolectomía correctiva( 6 zonas ): por zona','1','1','','','','1','1','','','Capítulo X - Cirugía Bucal','Se reconocerá con radiografía pre y post-operatoria.'),
('10.16','Frenectomía','1','1','','','','','','','1','Capítulo X - Cirugía Bucal',''),
('10.17','Radectomía','1','1','','1','','1','1','','','Capítulo X - Cirugía Bucal',''),
('10.18','Extracción por alveolectomía externa (complicación de extracción). ','','','','','','','','','','Capítulo X - Cirugía Bucal',''),
('10.19','Extracción de dientes en retención ósea. ','','','','','','','','','','Capítulo X - Cirugía Bucal',''),
('10.20','Sutura de encías como tratamiento de lesión traumática. ','','','','','','','','','','Capítulo X - Cirugía Bucal',''),
('11.01.01','Implante dentario','1','1','','','','1','1','','','Capítulo XI – Implantes',''),
('11.02','Relleno óseo ','1','1','','','','','1','','','Capítulo XI – Implantes','');
/*!40000 ALTER TABLE `odontologico` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2026-11-15 10:25:56
