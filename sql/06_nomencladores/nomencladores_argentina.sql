-- =============================================================================
-- Origen Salud · Nomencladores Prestacionales de Argentina y Vademécum Comercial
-- nomencladores_argentina.sql
-- =============================================================================
-- Contenido:
--  1. nomencladores_argentina (NN/PMO, NBU, NHPGD, ANDIS, Kinesiología, Salud Mental)
--  2. vademecum_comercial (Troquel, AlfaBeta, Kairos, GTIN, Monodroga)
--  3. Índices GIN trigram y B-Tree optimizados
--  4. Datos maestros iniciales de referencia
-- =============================================================================

SET client_encoding = 'UTF8';
SET statement_timeout = 0;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 1. TABLA MAESTRA: NOMENCLADORES PRESTACIONALES DE ARGENTINA
-- =============================================================================
CREATE TABLE IF NOT EXISTS nomencladores_argentina (
    id SERIAL PRIMARY KEY,
    tipo_nomenclador VARCHAR(30) NOT NULL, -- 'NN_PMO', 'NBU', 'NHPGD', 'ANDIS', 'KINESIOLOGIA', 'SALUD_MENTAL'
    codigo VARCHAR(30) NOT NULL,           -- Ej: '42.01.01', '660475', '25.01.01', '33.01.01'
    capitulo VARCHAR(100),                 -- Ej: 'Capítulo 42 - Consultas', 'Capítulo 25 - Rehabilitación'
    descripcion TEXT NOT NULL,
    
    -- Unidades arancelarias de Argentina
    unidad_tipo VARCHAR(30),               -- 'UB' (Bioquímica), 'GALENO', 'MODULO', 'SESION', 'PESOS'
    unidad_valor NUMERIC(12, 4),           -- Ej: cantidad de UB en NBU o arancel base NHPGD/ANDIS
    gastos_valor NUMERIC(12, 4),           -- Gastos sanatoriales en NN/PMO
    
    -- Interoperabilidad clínica internacional
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    codigo_loinc VARCHAR(20),              -- Vínculo a LOINC para laboratorio e imágenes
    
    vigencia_desde DATE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE (tipo_nomenclador, codigo)
);

CREATE INDEX IF NOT EXISTS idx_nom_arg_trgm ON nomencladores_argentina USING gin (descripcion gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_nom_arg_tipo_codigo ON nomencladores_argentina(tipo_nomenclador, codigo);
CREATE INDEX IF NOT EXISTS idx_nom_arg_snomed ON nomencladores_argentina(snomed_concept_id);


-- =============================================================================
-- 2. TABLA MAESTRA: VADEMÉCUM COMERCIAL (TROQUEL / ALFABETA / KAIROS / GTIN)
-- =============================================================================
CREATE TABLE IF NOT EXISTS vademecum_comercial (
    id SERIAL PRIMARY KEY,
    numero_troquel VARCHAR(20) UNIQUE,     -- Identificador de validación en farmacias/obras sociales
    codigo_alfabeta VARCHAR(20),           -- ID interno AlfaBeta
    codigo_kairos VARCHAR(20),             -- ID interno Kairos
    codigo_barras_gtin VARCHAR(20),        -- EAN-13 / GTIN para trazabilidad GS1
    
    monodroga VARCHAR(255) NOT NULL,       -- Principio activo (DCI)
    nombre_comercial VARCHAR(255) NOT NULL,
    presentacion VARCHAR(255) NOT NULL,
    laboratorio VARCHAR(150),
    accion_farmacologica VARCHAR(150),
    tipo_venta VARCHAR(50),                -- 'Venta Libre', 'Venta Bajo Receta', 'Archivada', 'Decreto'
    
    anmat_certificado VARCHAR(50),         -- Vínculo con anmat_medicamentos(certificado_number)
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    
    activo BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vad_troquel ON vademecum_comercial(numero_troquel);
CREATE INDEX IF NOT EXISTS idx_vad_alfabeta ON vademecum_comercial(codigo_alfabeta);
CREATE INDEX IF NOT EXISTS idx_vad_kairos ON vademecum_comercial(codigo_kairos);
CREATE INDEX IF NOT EXISTS idx_vad_comercial_trgm ON vademecum_comercial USING gin (nombre_comercial gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_vad_monodroga_trgm ON vademecum_comercial USING gin (monodroga gin_trgm_ops);


-- =============================================================================
-- 3. DATOS SEMILLA: NOMENCLADOR NACIONAL MÉDICO / PMO (NN_PMO)
-- =============================================================================
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, capitulo, descripcion, unidad_tipo, unidad_valor, gastos_valor) VALUES
('NN_PMO', '42.01.01', 'Capítulo 42 - Consultas Médicas', 'Consulta médica general o especializada en consultorio', 'GALENO', 1.0000, 0.0000),
('NN_PMO', '42.01.02', 'Capítulo 42 - Consultas Médicas', 'Consulta médica general o especializada en domicilio', 'GALENO', 1.5000, 0.0000),
('NN_PMO', '43.01.01', 'Capítulo 43 - Urgencias y Guardias', 'Consulta de guardia / urgencia médica', 'GALENO', 1.2000, 0.0000),
('NN_PMO', '34.01.01', 'Capítulo 34 - Cardiología', 'Electrocardiograma de rutina (ECG) de 12 derivaciones con informe', 'GALENO', 1.0000, 0.5000),
('NN_PMO', '34.01.05', 'Capítulo 34 - Cardiología', 'Ergometría computarizada de 12 derivaciones / prueba de esfuerzo', 'GALENO', 3.5000, 2.0000),
('NN_PMO', '17.01.01', 'Capítulo 17 - Cirugía General', 'Apendicectomía por laparotomía o laparoscópica', 'GALENO', 18.0000, 12.0000),
('NN_PMO', '17.01.12', 'Capítulo 17 - Cirugía General', 'Colecistectomía laparoscópica con colangiografía intraoperatoria', 'GALENO', 24.0000, 16.0000),
('NN_PMO', '18.01.01', 'Capítulo 18 - Obstetricia', 'Atención del parto vaginal en quirófano o sala de partos institucional', 'GALENO', 20.0000, 10.0000),
('NN_PMO', '18.01.02', 'Capítulo 18 - Obstetricia', 'Operación cesárea con o sin histerectomía', 'GALENO', 22.0000, 14.0000),
('NN_PMO', '40.01.01', 'Capítulo 40 - Internación', 'Día clínico de internación en sala general con atención de enfermería', 'MODULO', 1.0000, 5.0000),
('NN_PMO', '40.01.03', 'Capítulo 40 - Internación', 'Día de internación en Unidad de Terapia Intensiva (UTI) polivalente', 'MODULO', 1.0000, 18.0000)
ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    unidad_valor = EXCLUDED.unidad_valor,
    gastos_valor = EXCLUDED.gastos_valor;


-- =============================================================================
-- 4. DATOS SEMILLA: NOMENCLADOR BIOQUÍMICO ÚNICO (NBU - CUBRA)
-- =============================================================================
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, capitulo, descripcion, unidad_tipo, unidad_valor, codigo_loinc) VALUES
('NBU', '660475', 'Hematología', 'Hemograma completo (recuento de hematíes, leucocitos, fórmula leucocitaria, Hb y Hto)', 'UB', 3.8000, '58410-2'),
('NBU', '660370', 'Química Clínica', 'Glucemia en ayunas (determinación enzimática)', 'UB', 1.8000, '1558-6'),
('NBU', '660855', 'Química Clínica', 'Uremia / urea en sangre por método cinético', 'UB', 1.8000, '3094-0'),
('NBU', '660230', 'Química Clínica', 'Creatinina en sangre (índice de filtrado glomerular)', 'UB', 2.0000, '2160-0'),
('NBU', '660180', 'Lípidos', 'Colesterol total sérico enzimático', 'UB', 2.0000, '2093-3'),
('NBU', '660181', 'Lípidos', 'Colesterol HDL (alta densidad)', 'UB', 2.5000, '2085-9'),
('NBU', '660182', 'Lípidos', 'Colesterol LDL calculado o dosado', 'UB', 2.5000, '13457-7'),
('NBU', '660810', 'Lípidos', 'Triglicéridos séricos', 'UB', 2.2000, '2571-8'),
('NBU', '660490', 'Hepatograma', 'Hepatograma completo (GOT, GPT, FAL, Bilirrubina total y fraccionada)', 'UB', 5.5000, '24325-3'),
('NBU', '660600', 'Orinas', 'Orina completa (examen físico, químico y sedimento urinario microscópico)', 'UB', 2.2000, '24356-8'),
('NBU', '660835', 'Endocrinología', 'TSH (Tirotrofina sérica por quimioluminiscencia ultrasensible)', 'UB', 6.0000, '3016-3'),
('NBU', '660825', 'Endocrinología', 'T4 libre (Tiroxina libre sérica)', 'UB', 6.0000, '3024-7'),
('NBU', '660485', 'Inmunología', 'Hemoglobina glicosilada (HbA1c por HPLC)', 'UB', 5.0000, '4548-4'),
('NBU', '660500', 'Infecciosas', 'Serología para VIH 1/2 (Anticuerpos + Antígeno p24 de 4ta generación)', 'UB', 7.5000, '56888-1')
ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    unidad_valor = EXCLUDED.unidad_valor,
    codigo_loinc = EXCLUDED.codigo_loinc;


-- =============================================================================
-- 5. DATOS SEMILLA: HOSPITALES PÚBLICOS DE GESTIÓN DESCENTRALIZADA (NHPGD)
-- =============================================================================
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, capitulo, descripcion, unidad_tipo, unidad_valor) VALUES
('NHPGD', '01.01.01', 'Consultas Médicas', 'Consulta médica ambulatoria en hospital público (primer nivel / guardia)', 'PESOS', 6500.0000),
('NHPGD', '01.01.02', 'Consultas Médicas', 'Consulta médica de especialidad / interconsulta hospitalaria', 'PESOS', 8200.0000),
('NHPGD', '02.01.01', 'Odontología Hospitalaria', 'Consulta odontológica y atención de urgencia odontológica hospitalaria', 'PESOS', 7800.0000),
('NHPGD', '03.01.01', 'Internaciones', 'Día cama en sala de cuidados generales / internación clínica hospitalaria', 'PESOS', 38000.0000),
('NHPGD', '03.01.02', 'Internaciones', 'Día cama en Unidad de Cuidados Intensivos Pediátricos o Adultos (UTI)', 'PESOS', 125000.0000),
('NHPGD', '04.01.01', 'Partos y Cesáreas', 'Atención integral del parto eutócico institucional y puerperio', 'PESOS', 145000.0000),
('NHPGD', '04.01.02', 'Partos y Cesáreas', 'Operación cesárea programada o de urgencia y cuidados neonatales iniciales', 'PESOS', 195000.0000),
('NHPGD', '05.01.01', 'Cirugía Mayor Ambulatoria', 'Intervención quirúrgica en quirófano ambulatorio con anestesia local/regional', 'PESOS', 62000.0000)
ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    unidad_valor = EXCLUDED.unidad_valor;


-- =============================================================================
-- 6. DATOS SEMILLA: PRESTACIONES BÁSICAS PARA PERSONAS CON DISCAPACIDAD (ANDIS)
-- =============================================================================
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, capitulo, descripcion, unidad_tipo, unidad_valor) VALUES
('ANDIS', '250101', 'Rehabilitación Integral', 'Módulo de rehabilitación ambulatoria integral (kinesiología, terapia ocupacional, fonoaudiología)', 'MODULO', 85000.0000),
('ANDIS', '250102', 'Fonoaudiología', 'Sesión individual de estimulación fonoaudiológica y rehabilitación de deglución/lenguaje', 'SESION', 9200.0000),
('ANDIS', '250103', 'Psicopedagogía', 'Sesión individual de psicopedagogía y apoyo escolar especializado', 'SESION', 9200.0000),
('ANDIS', '250104', 'Terapia Ocupacional', 'Sesión de terapia ocupacional para desarrollo de autonomía y vida diaria', 'SESION', 9200.0000),
('ANDIS', '250201', 'Centros de Día', 'Centro de Día - Jornada Simple (con alimentación y talleres adaptados)', 'MODULO', 210000.0000),
('ANDIS', '250202', 'Centros de Día', 'Centro de Día - Jornada Doble (completa con talleres y actividades terapéuticas)', 'MODULO', 345000.0000),
('ANDIS', '250301', 'Centro Educativo Terapéutico', 'Módulo CET - Jornada Doble con abordaje multidisciplinario pedagógico y clínico', 'MODULO', 380000.0000),
('ANDIS', '250401', 'Transporte Especial', 'Transporte especial para personas con discapacidad (arancel por kilómetro recorrido)', 'PESOS', 520.0000),
('ANDIS', '250501', 'Apoyo a la Inclusión Escolar', 'Acompañante de apoyo a la inclusión escolar (maestra/o de apoyo a la inclusión)', 'MODULO', 190000.0000)
ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    unidad_valor = EXCLUDED.unidad_valor;


-- =============================================================================
-- 7. DATOS SEMILLA: KINESIOLOGÍA Y FISIATRÍA (COKIBA / CAP. 25 NN)
-- =============================================================================
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, capitulo, descripcion, unidad_tipo, unidad_valor) VALUES
('KINESIOLOGIA', '25.01.01', 'Kinesiología Motriz', 'Sesión de fisioterapia y kinesiología motriz en consultorio (ejercicios, movilización)', 'SESION', 8500.0000),
('KINESIOLOGIA', '25.01.02', 'Kinesiología a Domicilio', 'Sesión de fisioterapia y kinesiología motriz en domicilio del paciente', 'SESION', 12500.0000),
('KINESIOLOGIA', '25.01.03', 'Kinesiología Respiratoria', 'Sesión de kinesiología respiratoria (drenaje postural, aspiración, ejercicios ventilatorios)', 'SESION', 9500.0000),
('KINESIOLOGIA', '25.01.04', 'Fisioterapia Instrumental', 'Aplicación de aparatología fisioterapéutica (magnetoterapia, ultrasonido, electroestimulación TENS)', 'SESION', 6800.0000),
('KINESIOLOGIA', '25.01.05', 'Rehabilitación Neurológica', 'Rehabilitación neuromuscular compleja (Bobath, Kabat, reeducación de la marcha)', 'SESION', 14000.0000),
('KINESIOLOGIA', '25.01.06', 'Drenaje Linfático Manual', 'Drenaje linfático manual por miembro afectado (postquirúrgico / oncológico)', 'SESION', 11000.0000)
ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    unidad_valor = EXCLUDED.unidad_valor;


-- =============================================================================
-- 8. DATOS SEMILLA: PSICOLOGÍA Y SALUD MENTAL (CAP. 33 NN)
-- =============================================================================
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, capitulo, descripcion, unidad_tipo, unidad_valor) VALUES
('SALUD_MENTAL', '33.01.01', 'Psicoterapia', 'Sesión individual de psicoterapia en consultorio o teleconsulta (45-50 min)', 'SESION', 11500.0000),
('SALUD_MENTAL', '33.01.02', 'Psicoterapia de Familia', 'Sesión de psicoterapia de pareja o grupo familiar', 'SESION', 16000.0000),
('SALUD_MENTAL', '33.01.03', 'Psicoterapia Grupal', 'Sesión de psicoterapia grupal (hasta 8 pacientes)', 'SESION', 6500.0000),
('SALUD_MENTAL', '33.01.04', 'Psicodiagnóstico', 'Evaluación psicodiagnóstica completa con batería de tests y emisión de informe pericial', 'MODULO', 52000.0000),
('SALUD_MENTAL', '33.01.05', 'Psiquiatría', 'Consulta psiquiátrica clínica, evaluación psicofarmacológica y ajuste de dosis', 'SESION', 14500.0000),
('SALUD_MENTAL', '33.01.06', 'Interconsulta Institucional', 'Interconsulta psicológica / psiquiátrica en sala de internación sanatorial', 'SESION', 13000.0000)
ON CONFLICT (tipo_nomenclador, codigo) DO UPDATE SET
    descripcion = EXCLUDED.descripcion,
    unidad_valor = EXCLUDED.unidad_valor;


-- =============================================================================
-- 9. DATOS SEMILLA: VADEMÉCUM COMERCIAL (TROQUEL / ALFABETA / KAIROS)
-- =============================================================================
INSERT INTO vademecum_comercial (
    numero_troquel, codigo_alfabeta, codigo_kairos, codigo_barras_gtin,
    monodroga, nombre_comercial, presentacion, laboratorio, accion_farmacologica, tipo_venta, anmat_certificado
) VALUES
('458921', '12045', '30491', '7791234567890', 'Amoxicilina', 'AMOXIDAL 500', 'Envase con 16 comprimidos recubiertos', 'Roemmers', 'Antibiótico betalactámico bactericida', 'Venta Bajo Receta', '38901'),
('458930', '12046', '30492', '7791234567891', 'Amoxicilina + Ácido Clavulánico', 'AMOXIDAL DUO', 'Envase con 14 comprimidos recubiertos', 'Roemmers', 'Antibiótico bactericida de amplio espectro', 'Venta Bajo Receta', '42105'),
('324510', '11024', '21904', '7798765432101', 'Ibuprofeno', 'ACTRON 600', 'Envase con 20 cápsulas blandas de rápida acción', 'Bayer', 'Analgésico, antiinflamatorio y antipirético no esteroide (AINE)', 'Venta Bajo Receta', '40512'),
('324515', '11025', '21905', '7798765432102', 'Ibuprofeno', 'IBUPIRAC 400', 'Envase con 20 comprimidos', 'Pfizer', 'Analgésico y antiinflamatorio no esteroide (AINE)', 'Venta Libre', '36204'),
('512390', '14589', '33412', '7795432109876', 'Paracetamol', 'TERMOLGIN 1000', 'Envase con 20 comprimidos', 'Montpellier', 'Analgésico y antipirético de acción central', 'Venta Libre', '45802'),
('298412', '10340', '20115', '7796543210987', 'Losartán Potásico', 'LOTRIAL 50', 'Envase con 30 comprimidos recubiertos', 'Roemmers', 'Antihipertensivo antagonista receptor AT1 de angiotensina II', 'Venta Bajo Receta', '44102'),
('489012', '13401', '31502', '7797654321098', 'Metformina Clorhidrato', 'GLUCOPHAGE 850', 'Envase con 60 comprimidos', 'Merck', 'Hipoglucemiante oral biguanida', 'Venta Bajo Receta', '41209'),
('550123', '16021', '38104', '7798901234567', 'Omeprazol', 'GASTROMAX 20', 'Envase con 28 cápsulas gastrorresistentes', 'Baliarda', 'Antiulceroso inhibidor de la bomba de protones (IBP)', 'Venta Bajo Receta', '43051'),
('589124', '17452', '40192', '7799012345678', 'Clonazepam', 'RIVOTRIL 0.5', 'Envase con 30 comprimidos ranurados', 'Roche', 'Ansiolítico y anticonvulsivo benzodiazepínico', 'Archivada', '31204'),
('601245', '18204', '42015', '7790123456789', 'Levotiroxina Sódica', 'T4 MONTPELLIER 100', 'Envase con 50 comprimidos', 'Montpellier', 'Hormonoterapia tiroidea de reemplazo', 'Venta Bajo Receta', '39401')
ON CONFLICT (numero_troquel) DO UPDATE SET
    nombre_comercial = EXCLUDED.nombre_comercial,
    presentacion = EXCLUDED.presentacion,
    laboratorio = EXCLUDED.laboratorio,
    codigo_alfabeta = EXCLUDED.codigo_alfabeta,
    codigo_kairos = EXCLUDED.codigo_kairos,
    codigo_barras_gtin = EXCLUDED.codigo_barras_gtin;

ANALYZE nomencladores_argentina;
ANALYZE vademecum_comercial;

SELECT tipo_nomenclador, count(*) AS total_practicas
  FROM nomencladores_argentina
 GROUP BY tipo_nomenclador
 UNION ALL
SELECT 'VADEMECUM_COMERCIAL', count(*)
  FROM vademecum_comercial;
