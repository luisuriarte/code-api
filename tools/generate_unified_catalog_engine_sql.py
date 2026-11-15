# -*- coding: utf-8 -*-
"""
Generador Maestro: Origen Catalog Engine 1.0 (PostgreSQL 18)
Unifica DENTAR, Nomencladores Argentinos (NN-PMO, NBU, NHPGD, ANDIS, Kinesiología, Salud Mental),
Sistemas Terminológicos (SNOMED-CT, CIE-10, LOINC, CDT-2025), Vademécum Multicapa y Aranceles.
Genera: sql/origen_catalog_engine.sql
"""
import os, sys

def load_odontologico_rows():
    sql_path = os.path.join(os.path.dirname(__file__), "..", "sql", "odontologico.sql")
    with open(sql_path, "r", encoding="utf-8") as f:
        sql = f.read()

    start_idx = sql.find("INSERT INTO `odontologico` VALUES") + len("INSERT INTO `odontologico` VALUES")
    end_idx = sql.find("/*!40000 ALTER TABLE `odontologico` ENABLE KEYS */")
    values_str = sql[start_idx:end_idx].strip()
    if values_str.endswith(";"):
        values_str = values_str[:-1]

    tuples = []
    current_tuple = []
    current_val = []
    in_quotes = False
    quote_char = None
    in_tuple = False
    escape = False

    i = 0
    n = len(values_str)
    while i < n:
        c = values_str[i]
        if not in_tuple:
            if c == "(":
                in_tuple = True
                current_tuple = []
                current_val = []
        else:
            if in_quotes:
                if escape:
                    current_val.append(c)
                    escape = False
                elif c == "\\":
                    escape = True
                elif c == quote_char:
                    if i + 1 < n and values_str[i+1] == quote_char:
                        current_val.append(quote_char)
                        i += 1
                    else:
                        in_quotes = False
                else:
                    current_val.append(c)
            else:
                if c in ("\x27", "\x22"):
                    in_quotes = True
                    quote_char = c
                elif c == ",":
                    val_str = "".join(current_val).strip()
                    current_tuple.append(None if val_str == "NULL" else val_str)
                    current_val = []
                elif c == ")":
                    val_str = "".join(current_val).strip()
                    current_tuple.append(None if val_str == "NULL" else val_str)
                    tuples.append(current_tuple)
                    in_tuple = False
                    current_tuple = []
                    current_val = []
                else:
                    current_val.append(c)
        i += 1
    return tuples

def sql_str(s):
    if s is None:
        return "NULL"
    clean = str(s).replace("'", "''").replace("\\", "\\\\")
    return f"E'{clean}'"

# Map row from odontologico.sql to chapter, CDT-2025 code and SNOMED-CT procedure concept
def map_dental_row(r):
    code = r[0].strip()
    desc = r[1].strip()
    c_num = code.split(".")[0]

    if c_num == "01":
        if "fichado" in desc.lower() or "diagn" in desc.lower():
            return ("CAT-DIAG", "D0150", 424759004)
        return ("CAT-DIAG", "D0120", 424759004)
    elif c_num == "02":
        if "amalgama" in desc.lower():
            if "simple" in desc.lower(): return ("CAT-REST", "D2140", 424759004)
            if "compuesta" in desc.lower(): return ("CAT-REST", "D2150", 424759004)
            return ("CAT-REST", "D2160", 424759004)
        elif "composite" in desc.lower() or "resina" in desc.lower():
            if "simple" in desc.lower(): return ("CAT-REST", "D2330", 424759004)
            if "compuesta" in desc.lower(): return ("CAT-REST", "D2331", 424759004)
            return ("CAT-REST", "D2332", 424759004)
        elif "incrusta" in desc.lower(): return ("CAT-REST", "D2610", 424759004)
        return ("CAT-REST", "D2999", 424759004)
    elif c_num == "03":
        if "birradicular" in desc.lower(): return ("CAT-ENDO", "D3320", 424759004)
        if "multirradicular" in desc.lower(): return ("CAT-ENDO", "D3330", 424759004)
        if "unirradicular" in desc.lower(): return ("CAT-ENDO", "D3310", 424759004)
        return ("CAT-ENDO", "D3999", 424759004)
    elif c_num == "04":
        return ("CAT-SURG", "D7140", 424759004)
    elif c_num == "05":
        return ("CAT-PROSTH-R", "D5110", 424759004)
    elif c_num == "06":
        return ("CAT-PROSTH-F", "D6240", 424759004)
    elif c_num == "07":
        return ("CAT-PERI", "D4341", 424759004)
    elif c_num == "08":
        return ("CAT-ORTHO", "D8080", 424759004)
    elif c_num == "09":
        return ("CAT-IMPL", "D6010", 424759004)
    elif c_num == "10":
        return ("CAT-SURG-MAX", "D7210", 424759004)
    else:
        return ("CAT-ADJ", "D9110", 424759004)

rows = load_odontologico_rows()
print(f"Loaded {len(rows)} dental rows from odontologico.sql")

# Seed data for Argentine Nomenclators
nn_pmo_items = [
    {"perm_code": "NN-420101", "code": "42.01.01", "clean": "420101", "term": "Consulta médica general o especializada en consultorio", "unit": "GALENO", "amount": 1.0, "expenses": 0.0, "sct": "185349003", "sct_display": "Consulta médica ambulatoria (procedimiento)"},
    {"perm_code": "NN-420102", "code": "42.01.02", "clean": "420102", "term": "Consulta médica general o especializada en domicilio", "unit": "GALENO", "amount": 1.5, "expenses": 0.0, "sct": "308439007", "sct_display": "Visita médica a domicilio (procedimiento)"},
    {"perm_code": "NN-430101", "code": "43.01.01", "clean": "430101", "term": "Consulta de guardia / urgencia médica", "unit": "GALENO", "amount": 1.2, "expenses": 0.0, "sct": "50849002", "sct_display": "Atención de urgencia médica (procedimiento)"},
    {"perm_code": "NN-340101", "code": "34.01.01", "clean": "340101", "term": "Electrocardiograma de rutina (ECG) de 12 derivaciones con informe", "unit": "GALENO", "amount": 1.0, "expenses": 0.5, "sct": "268400002", "sct_display": "Electrocardiograma de 12 derivaciones", "loinc": "11524-6", "loinc_display": "EKG study"},
    {"perm_code": "NN-340105", "code": "34.01.05", "clean": "340105", "term": "Ergometría computarizada de 12 derivaciones / prueba de esfuerzo", "unit": "GALENO", "amount": 3.5, "expenses": 2.0, "sct": "44734002", "sct_display": "Prueba de esfuerzo cardiovascular", "loinc": "73788-2", "loinc_display": "Cardiac stress test"},
    {"perm_code": "NN-170101", "code": "17.01.01", "clean": "170101", "term": "Apendicectomía por laparotomía o laparoscópica", "unit": "GALENO", "amount": 18.0, "expenses": 12.0, "sct": "80146002", "sct_display": "Apendicectomía (procedimiento)"},
    {"perm_code": "NN-170112", "code": "17.01.12", "clean": "170112", "term": "Colecistectomía laparoscópica con colangiografía intraoperatoria", "unit": "GALENO", "amount": 24.0, "expenses": 16.0, "sct": "45595009", "sct_display": "Colecistectomía laparoscópica (procedimiento)"},
    {"perm_code": "NN-180101", "code": "18.01.01", "clean": "180101", "term": "Atención del parto vaginal en quirófano o sala de partos institucional", "unit": "GALENO", "amount": 20.0, "expenses": 10.0, "sct": "236973005", "sct_display": "Parto vaginal normal (procedimiento)"},
    {"perm_code": "NN-180102", "code": "18.01.02", "clean": "180102", "term": "Operación cesárea con o sin histerectomía", "unit": "GALENO", "amount": 22.0, "expenses": 14.0, "sct": "11466000", "sct_display": "Operación cesárea (procedimiento)"},
    {"perm_code": "NN-400101", "code": "40.01.01", "clean": "400101", "term": "Día clínico de internación en sala general con atención de enfermería", "unit": "MODULO", "amount": 1.0, "expenses": 5.0, "sct": "32485007", "sct_display": "Internación hospitalaria (procedimiento)"},
    {"perm_code": "NN-400103", "code": "40.01.03", "clean": "400103", "term": "Día de internación en Unidad de Terapia Intensiva (UTI) polivalente", "unit": "MODULO", "amount": 1.0, "expenses": 18.0, "sct": "305351004", "sct_display": "Cuidados intensivos en UTI (procedimiento)"}
]

nbu_items = [
    {"perm_code": "NBU-660475", "code": "660475", "clean": "660475", "term": "Hemograma completo (recuento de hematíes, leucocitos, fórmula leucocitaria, Hb y Hto)", "unit": "UB", "amount": 3.8, "loinc": "58410-2", "loinc_display": "CBC panel - Blood by Automated count", "sct": "43789009", "sct_display": "Recuento sanguíneo completo (procedimiento)"},
    {"perm_code": "NBU-660370", "code": "660370", "clean": "660370", "term": "Glucemia en ayunas (determinación enzimática)", "unit": "UB", "amount": 1.8, "loinc": "1558-6", "loinc_display": "Fasting glucose [Mass/volume] in Serum or Plasma", "sct": "67079006", "sct_display": "Medición de glucosa en suero (procedimiento)"},
    {"perm_code": "NBU-660855", "code": "660855", "clean": "660855", "term": "Uremia / urea en sangre por método cinético", "unit": "UB", "amount": 1.8, "loinc": "3094-0", "loinc_display": "Urea nitrogen [Mass/volume] in Serum or Plasma", "sct": "26881000", "sct_display": "Medición de urea en suero (procedimiento)"},
    {"perm_code": "NBU-660230", "code": "660230", "clean": "660230", "term": "Creatinina en sangre (índice de filtrado glomerular)", "unit": "UB", "amount": 2.0, "loinc": "2160-0", "loinc_display": "Creatinine [Mass/volume] in Serum or Plasma", "sct": "27171005", "sct_display": "Medición de creatinina en suero (procedimiento)"},
    {"perm_code": "NBU-660180", "code": "660180", "clean": "660180", "term": "Colesterol total sérico enzimático", "unit": "UB", "amount": 2.0, "loinc": "2093-3", "loinc_display": "Cholesterol [Mass/volume] in Serum or Plasma", "sct": "271062006", "sct_display": "Medición de colesterol sérico total (procedimiento)"},
    {"perm_code": "NBU-660181", "code": "660181", "clean": "660181", "term": "Colesterol HDL (alta densidad)", "unit": "UB", "amount": 2.5, "loinc": "2085-9", "loinc_display": "Cholesterol in HDL [Mass/volume] in Serum or Plasma", "sct": "28036006", "sct_display": "Medición de colesterol HDL (procedimiento)"},
    {"perm_code": "NBU-660182", "code": "660182", "clean": "660182", "term": "Colesterol LDL calculado o dosado", "unit": "UB", "amount": 2.5, "loinc": "13457-7", "loinc_display": "Cholesterol in LDL [Mass/volume] in Serum or Plasma", "sct": "39689006", "sct_display": "Medición de colesterol LDL (procedimiento)"},
    {"perm_code": "NBU-660810", "code": "660810", "clean": "660810", "term": "Triglicéridos séricos", "unit": "UB", "amount": 2.2, "loinc": "2571-8", "loinc_display": "Triglyceride [Mass/volume] in Serum or Plasma", "sct": "14740000", "sct_display": "Medición de triglicéridos séricos (procedimiento)"},
    {"perm_code": "NBU-660490", "code": "660490", "clean": "660490", "term": "Hepatograma completo (GOT, GPT, FAL, Bilirrubina total y fraccionada)", "unit": "UB", "amount": 5.5, "loinc": "24325-3", "loinc_display": "Hepatic function panel - Serum or Plasma", "sct": "24325000", "sct_display": "Perfil hepático (procedimiento)"},
    {"perm_code": "NBU-660600", "code": "660600", "clean": "660600", "term": "Orina completa (examen físico, químico y sedimento urinario microscópico)", "unit": "UB", "amount": 2.2, "loinc": "24356-8", "loinc_display": "Urinalysis complete panel - Urine", "sct": "27171005", "sct_display": "Análisis de orina rutinario (procedimiento)"},
    {"perm_code": "NBU-660835", "code": "660835", "clean": "660835", "term": "TSH (Tirotrofina sérica por quimioluminiscencia ultrasensible)", "unit": "UB", "amount": 6.0, "loinc": "3016-3", "loinc_display": "Thyrotropin [Units/volume] in Serum or Plasma", "sct": "67174007", "sct_display": "Medición de tirotropina sérica (procedimiento)"},
    {"perm_code": "NBU-660825", "code": "660825", "clean": "660825", "term": "T4 libre (Tiroxina libre sérica)", "unit": "UB", "amount": 6.0, "loinc": "3024-7", "loinc_display": "Thyroxine (T4) free [Mass/volume] in Serum or Plasma", "sct": "69566008", "sct_display": "Medición de tiroxina libre (procedimiento)"},
    {"perm_code": "NBU-660485", "code": "660485", "clean": "660485", "term": "Hemoglobina glicosilada (HbA1c por HPLC)", "unit": "UB", "amount": 5.0, "loinc": "4548-4", "loinc_display": "Hemoglobin A1c/Hemoglobin.total in Blood", "sct": "43396009", "sct_display": "Medición de hemoglobina A1c (procedimiento)"},
    {"perm_code": "NBU-660500", "code": "660500", "clean": "660500", "term": "Serología para VIH 1/2 (Anticuerpos + Antígeno p24 de 4ta generación)", "unit": "UB", "amount": 7.5, "loinc": "56888-1", "loinc_display": "HIV 1 and 2 tests - Serum or Plasma", "sct": "104344004", "sct_display": "Prueba de detección serológica de VIH (procedimiento)"}
]

nhpgd_items = [
    {"perm_code": "NHPGD-010101", "code": "01.01.01", "clean": "010101", "term": "Consulta médica ambulatoria en hospital público (primer nivel / guardia)", "unit": "PESOS", "fixed_price": 6500.0, "sct": "185349003", "sct_display": "Consulta médica ambulatoria (procedimiento)"},
    {"perm_code": "NHPGD-010102", "code": "01.01.02", "clean": "010102", "term": "Consulta médica de especialidad / interconsulta hospitalaria", "unit": "PESOS", "fixed_price": 8200.0, "sct": "185349003", "sct_display": "Consulta médica ambulatoria (procedimiento)"},
    {"perm_code": "NHPGD-020101", "code": "02.01.01", "clean": "020101", "term": "Consulta odontológica y atención de urgencia odontológica hospitalaria", "unit": "PESOS", "fixed_price": 7800.0, "sct": "424759004", "sct_display": "Consulta odontológica (procedimiento)"},
    {"perm_code": "NHPGD-030101", "code": "03.01.01", "clean": "030101", "term": "Día cama en sala de cuidados generales / internación clínica hospitalaria", "unit": "PESOS", "fixed_price": 38000.0, "sct": "32485007", "sct_display": "Internación hospitalaria (procedimiento)"},
    {"perm_code": "NHPGD-030102", "code": "03.01.02", "clean": "030102", "term": "Día cama en Unidad de Cuidados Intensivos Pediátricos o Adultos (UTI)", "unit": "PESOS", "fixed_price": 125000.0, "sct": "305351004", "sct_display": "Cuidados intensivos en UTI (procedimiento)"},
    {"perm_code": "NHPGD-040101", "code": "04.01.01", "clean": "040101", "term": "Atención integral del parto eutócico institucional y puerperio", "unit": "PESOS", "fixed_price": 145000.0, "sct": "236973005", "sct_display": "Parto vaginal normal (procedimiento)"},
    {"perm_code": "NHPGD-040102", "code": "04.01.02", "clean": "040102", "term": "Operación cesárea programada o de urgencia y cuidados neonatales iniciales", "unit": "PESOS", "fixed_price": 195000.0, "sct": "11466000", "sct_display": "Operación cesárea (procedimiento)"},
    {"perm_code": "NHPGD-050101", "code": "05.01.01", "clean": "050101", "term": "Intervención quirúrgica en quirófano ambulatorio con anestesia local/regional", "unit": "PESOS", "fixed_price": 62000.0, "sct": "387713003", "sct_display": "Procedimiento quirúrgico (procedimiento)"}
]

andis_items = [
    {"perm_code": "ANDIS-250101", "code": "250101", "clean": "250101", "term": "Módulo de rehabilitación ambulatoria integral (kinesiología, terapia ocupacional, fonoaudiología)", "unit": "MODULO", "fixed_price": 85000.0, "sct": "386053000", "sct_display": "Rehabilitación ambulatoria integral (procedimiento)"},
    {"perm_code": "ANDIS-250102", "code": "250102", "clean": "250102", "term": "Sesión individual de estimulación fonoaudiológica y rehabilitación de deglución/lenguaje", "unit": "SESION", "fixed_price": 9200.0, "sct": "284478002", "sct_display": "Terapia del habla y del lenguaje (procedimiento)"},
    {"perm_code": "ANDIS-250103", "code": "250103", "clean": "250103", "term": "Sesión individual de psicopedagogía y apoyo escolar especializado", "unit": "SESION", "fixed_price": 9200.0, "sct": "76168009", "sct_display": "Terapia psicopedagógica (procedimiento)"},
    {"perm_code": "ANDIS-250104", "code": "250104", "clean": "250104", "term": "Sesión de terapia ocupacional para desarrollo de autonomía y vida diaria", "unit": "SESION", "fixed_price": 9200.0, "sct": "385805005", "sct_display": "Terapia ocupacional (procedimiento)"},
    {"perm_code": "ANDIS-250201", "code": "250201", "clean": "250201", "term": "Centro de Día - Jornada Simple (con alimentación y talleres adaptados)", "unit": "MODULO", "fixed_price": 210000.0, "sct": "310168007", "sct_display": "Servicio de centro de día (régimen)"},
    {"perm_code": "ANDIS-250202", "code": "250202", "clean": "250202", "term": "Centro de Día - Jornada Doble (completa con talleres y actividades terapéuticas)", "unit": "MODULO", "fixed_price": 345000.0, "sct": "310168007", "sct_display": "Servicio de centro de día (régimen)"},
    {"perm_code": "ANDIS-250301", "code": "250301", "clean": "250301", "term": "Módulo CET - Jornada Doble con abordaje multidisciplinario pedagógico y clínico", "unit": "MODULO", "fixed_price": 380000.0, "sct": "386053000", "sct_display": "Centro educativo terapéutico (régimen)"},
    {"perm_code": "ANDIS-250401", "code": "250401", "clean": "250401", "term": "Transporte especial para personas con discapacidad (arancel por kilómetro recorrido)", "unit": "KM", "fixed_price": 520.0, "sct": "413294000", "sct_display": "Transporte especial de paciente (procedimiento)"},
    {"perm_code": "ANDIS-250501", "code": "250501", "clean": "250501", "term": "Acompañante de apoyo a la inclusión escolar (maestra/o de apoyo a la inclusión)", "unit": "MODULO", "fixed_price": 190000.0, "sct": "76168009", "sct_display": "Apoyo a la inclusión educativa (procedimiento)"}
]

kinesiologia_items = [
    {"perm_code": "KIN-250101", "code": "25.01.01", "clean": "250101", "term": "Sesión de fisioterapia y kinesiología motriz en consultorio (ejercicios, movilización)", "unit": "SESION", "fixed_price": 8500.0, "sct": "91251008", "sct_display": "Terapia física (procedimiento)"},
    {"perm_code": "KIN-250102", "code": "25.01.02", "clean": "250102", "term": "Sesión de fisioterapia y kinesiología motriz en domicilio del paciente", "unit": "SESION", "fixed_price": 12500.0, "sct": "91251008", "sct_display": "Terapia física domiciliaria (procedimiento)"},
    {"perm_code": "KIN-250103", "code": "25.01.03", "clean": "250103", "term": "Sesión de kinesiología respiratoria (drenaje postural, aspiración, ejercicios ventilatorios)", "unit": "SESION", "fixed_price": 9500.0, "sct": "304526009", "sct_display": "Terapia respiratoria (procedimiento)"},
    {"perm_code": "KIN-250104", "code": "25.01.04", "clean": "250104", "term": "Aplicación de aparatología fisioterapéutica (magnetoterapia, ultrasonido, electroestimulación TENS)", "unit": "SESION", "fixed_price": 6800.0, "sct": "91251008", "sct_display": "Fisioterapia instrumental (procedimiento)"},
    {"perm_code": "KIN-250105", "code": "25.01.05", "clean": "250105", "term": "Rehabilitación neuromuscular compleja (Bobath, Kabat, reeducación de la marcha)", "unit": "SESION", "fixed_price": 14000.0, "sct": "91251008", "sct_display": "Rehabilitación neuromuscular (procedimiento)"},
    {"perm_code": "KIN-250106", "code": "25.01.06", "clean": "250106", "term": "Drenaje linfático manual por miembro afectado (postquirúrgico / oncológico)", "unit": "SESION", "fixed_price": 11000.0, "sct": "229562008", "sct_display": "Drenaje linfático manual (procedimiento)"}
]

salud_mental_items = [
    {"perm_code": "SM-330101", "code": "33.01.01", "clean": "330101", "term": "Sesión individual de psicoterapia en consultorio o teleconsulta (45-50 min)", "unit": "SESION", "fixed_price": 11500.0, "sct": "84114007", "sct_display": "Psicoterapia individual (procedimiento)"},
    {"perm_code": "SM-330102", "code": "33.01.02", "clean": "330102", "term": "Sesión de psicoterapia de pareja o grupo familiar", "unit": "SESION", "fixed_price": 16000.0, "sct": "108313002", "sct_display": "Psicoterapia familiar (procedimiento)"},
    {"perm_code": "SM-330103", "code": "33.01.03", "clean": "330103", "term": "Sesión de psicoterapia grupal (hasta 8 pacientes)", "unit": "SESION", "fixed_price": 6500.0, "sct": "39716008", "sct_display": "Psicoterapia de grupo (procedimiento)"},
    {"perm_code": "SM-330104", "code": "33.01.04", "clean": "330104", "term": "Evaluación psicodiagnóstica completa con batería de tests y emisión de informe pericial", "unit": "MODULO", "fixed_price": 52000.0, "sct": "85247002", "sct_display": "Evaluación psicodiagnóstica (procedimiento)"},
    {"perm_code": "SM-330105", "code": "33.01.05", "clean": "330105", "term": "Consulta psiquiátrica clínica, evaluación psicofarmacológica y ajuste de dosis", "unit": "SESION", "fixed_price": 14500.0, "sct": "185349003", "sct_display": "Consulta psiquiátrica (procedimiento)"},
    {"perm_code": "SM-330106", "code": "33.01.06", "clean": "330106", "term": "Interconsulta institucional psicológica / psiquiátrica en sala de internación sanatorial", "unit": "SESION", "fixed_price": 13000.0, "sct": "185349003", "sct_display": "Interconsulta psiquiátrica hospitalaria (procedimiento)"}
]

# Medicines seed data (10 items)
medicines_items = [
    {
        "substance": "Amoxicilina", "atc": "J01CA04", "brand": "AMOXIDAL 500", "lab": "Roemmers", "action": "Antibiótico betalactámico bactericida",
        "presentation": "Envase con 16 comprimidos recubiertos", "form": "Comprimidos recubiertos", "sale": "Venta Bajo Receta",
        "troquel": "458921", "alfabeta": "12045", "kairos": "30491", "gtin": "7791234567890", "cert": "38901"
    },
    {
        "substance": "Amoxicilina + Ácido Clavulánico", "atc": "J01CR02", "brand": "AMOXIDAL DUO", "lab": "Roemmers", "action": "Antibiótico bactericida de amplio espectro",
        "presentation": "Envase con 14 comprimidos recubiertos", "form": "Comprimidos recubiertos", "sale": "Venta Bajo Receta",
        "troquel": "458930", "alfabeta": "12046", "kairos": "30492", "gtin": "7791234567891", "cert": "42105"
    },
    {
        "substance": "Ibuprofeno", "atc": "M01AE01", "brand": "ACTRON 600", "lab": "Bayer", "action": "Analgésico, antiinflamatorio y antipirético no esteroide (AINE)",
        "presentation": "Envase con 20 cápsulas blandas de rápida acción", "form": "Cápsulas blandas", "sale": "Venta Bajo Receta",
        "troquel": "324510", "alfabeta": "11024", "kairos": "21904", "gtin": "7798765432101", "cert": "40512"
    },
    {
        "substance": "Ibuprofeno", "atc": "M01AE01", "brand": "IBUPIRAC 400", "lab": "Pfizer", "action": "Analgésico y antiinflamatorio no esteroide (AINE)",
        "presentation": "Envase con 20 comprimidos", "form": "Comprimidos", "sale": "Venta Libre",
        "troquel": "324515", "alfabeta": "11025", "kairos": "21905", "gtin": "7798765432102", "cert": "36204"
    },
    {
        "substance": "Paracetamol", "atc": "N02BE01", "brand": "TERMOLGIN 1000", "lab": "Montpellier", "action": "Analgésico y antipirético de acción central",
        "presentation": "Envase con 20 comprimidos", "form": "Comprimidos", "sale": "Venta Libre",
        "troquel": "512390", "alfabeta": "14589", "kairos": "33412", "gtin": "7795432109876", "cert": "45802"
    },
    {
        "substance": "Losartán Potásico", "atc": "C09CA01", "brand": "LOTRIAL 50", "lab": "Roemmers", "action": "Antihipertensivo antagonista receptor AT1 de angiotensina II",
        "presentation": "Envase con 30 comprimidos recubiertos", "form": "Comprimidos recubiertos", "sale": "Venta Bajo Receta",
        "troquel": "298412", "alfabeta": "10340", "kairos": "20115", "gtin": "7796543210987", "cert": "44102"
    },
    {
        "substance": "Metformina Clorhidrato", "atc": "A10BA02", "brand": "GLUCOPHAGE 850", "lab": "Merck", "action": "Hipoglucemiante oral biguanida",
        "presentation": "Envase con 60 comprimidos", "form": "Comprimidos", "sale": "Venta Bajo Receta",
        "troquel": "489012", "alfabeta": "13401", "kairos": "31502", "gtin": "7797654321098", "cert": "41209"
    },
    {
        "substance": "Omeprazol", "atc": "A02BC01", "brand": "GASTROMAX 20", "lab": "Baliarda", "action": "Antiulceroso inhibidor de la bomba de protones (IBP)",
        "presentation": "Envase con 28 cápsulas gastrorresistentes", "form": "Cápsulas", "sale": "Venta Bajo Receta",
        "troquel": "550123", "alfabeta": "16021", "kairos": "38104", "gtin": "7798901234567", "cert": "43051"
    },
    {
        "substance": "Clonazepam", "atc": "N03AE01", "brand": "RIVOTRIL 0.5", "lab": "Roche", "action": "Ansiolítico y anticonvulsivo benzodiazepínico",
        "presentation": "Envase con 30 comprimidos ranurados", "form": "Comprimidos", "sale": "Archivada",
        "troquel": "589124", "alfabeta": "17452", "kairos": "40192", "gtin": "7799012345678", "cert": "31204"
    },
    {
        "substance": "Levotiroxina Sódica", "atc": "H03AA01", "brand": "T4 MONTPELLIER 100", "lab": "Montpellier", "action": "Hormonoterapia tiroidea de reemplazo",
        "presentation": "Envase con 50 comprimidos", "form": "Comprimidos", "sale": "Venta Bajo Receta",
        "troquel": "601245", "alfabeta": "18204", "kairos": "42015", "gtin": "7790123456789", "cert": "39401"
    }
]

out = []
out.append("""-- =============================================================================
-- Origen Salud · Origen Catalog Engine 1.0 (PostgreSQL 18 Architecture)
-- Archivo unificado de esquemas, catálogos, aranceles, mapeos y vademécum
-- =============================================================================
SET client_encoding = 'UTF8';
SET statement_timeout = 0;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- =============================================================================
-- 1. TABLAS NUCLEARES DE CATÁLOGOS (os_catalog_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_catalog (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    organization VARCHAR(150) NOT NULL,
    country_code VARCHAR(2) NOT NULL DEFAULT 'AR',
    domain_type VARCHAR(30) NOT NULL CHECK (domain_type IN ('dental', 'medical', 'biochemical', 'rehabilitation', 'mental_health', 'pharma', 'terminology')),
    description TEXT,
    website_url VARCHAR(255),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS os_catalog_release (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    version_tag VARCHAR(50) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    official_norm_reference TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'review', 'published', 'deprecated')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (catalog_id, version_tag)
);

CREATE TABLE IF NOT EXISTS os_catalog_category (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    code VARCHAR(50) NOT NULL,
    name VARCHAR(150) NOT NULL,
    parent_category_id INT REFERENCES os_catalog_category(id) ON DELETE SET NULL,
    UNIQUE (catalog_id, code)
);

CREATE TABLE IF NOT EXISTS os_catalog_item (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    permanent_code VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'retired', 'superseded')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (catalog_id, permanent_code)
);

CREATE TABLE IF NOT EXISTS os_catalog_item_version (
    id SERIAL PRIMARY KEY,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    release_id INT NOT NULL REFERENCES os_catalog_release(id) ON DELETE CASCADE,
    category_id INT REFERENCES os_catalog_category(id) ON DELETE SET NULL,
    preferred_term VARCHAR(255) NOT NULL,
    definition TEXT,
    clinical_criteria TEXT,
    language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    UNIQUE (item_id, release_id, language_code)
);

CREATE TABLE IF NOT EXISTS os_catalog_term (
    id SERIAL PRIMARY KEY,
    item_version_id INT NOT NULL REFERENCES os_catalog_item_version(id) ON DELETE CASCADE,
    term VARCHAR(255) NOT NULL,
    term_type VARCHAR(20) NOT NULL DEFAULT 'synonym' CHECK (term_type IN ('preferred', 'synonym', 'acronym', 'search_variant')),
    language_code VARCHAR(10) NOT NULL DEFAULT 'es-AR'
);

CREATE TABLE IF NOT EXISTS os_catalog_identifier (
    id SERIAL PRIMARY KEY,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    system_name VARCHAR(50) NOT NULL,
    value VARCHAR(50) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (item_id, system_name, value)
);

CREATE INDEX IF NOT EXISTS idx_os_catalog_code ON os_catalog(code);
CREATE INDEX IF NOT EXISTS idx_os_item_perm ON os_catalog_item(catalog_id, permanent_code);
CREATE INDEX IF NOT EXISTS idx_os_item_ver_trgm ON os_catalog_item_version USING gin (preferred_term gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_term_trgm ON os_catalog_term USING gin (term gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_identifier_val ON os_catalog_identifier(value);


-- =============================================================================
-- 2. TABLAS DE INTEROPERABILIDAD Y MAPEOS (os_terminology_*, os_mapping_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_terminology_system (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    uri VARCHAR(255) NOT NULL,
    default_version VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS os_concept_mapping (
    id SERIAL PRIMARY KEY,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    terminology_system_id INT NOT NULL REFERENCES os_terminology_system(id) ON DELETE CASCADE,
    external_code VARCHAR(50) NOT NULL,
    external_display VARCHAR(255) NOT NULL,
    mapping_type VARCHAR(30) NOT NULL DEFAULT 'equivalent'
        CHECK (mapping_type IN ('equivalent', 'narrower', 'broader', 'related', 'unmatched')),
    relationship_role VARCHAR(30) NOT NULL DEFAULT 'procedure_concept'
        CHECK (relationship_role IN ('procedure_concept', 'justifying_diagnosis', 'observation_concept', 'substance_concept')),
    clinical_rationale TEXT,
    review_status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (review_status IN ('draft', 'reviewed', 'approved', 'deprecated')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (item_id, terminology_system_id, external_code, relationship_role)
);

CREATE INDEX IF NOT EXISTS idx_os_mapping_ext ON os_concept_mapping(external_code);
CREATE INDEX IF NOT EXISTS idx_os_mapping_item ON os_concept_mapping(item_id, relationship_role);


-- =============================================================================
-- 3. TABLAS DE ARANCELES Y VALORIZACIÓN (os_pricing_*, os_fee_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_pricing_unit (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    organization VARCHAR(100),
    description TEXT
);

CREATE TABLE IF NOT EXISTS os_fee_schedule (
    id SERIAL PRIMARY KEY,
    catalog_id INT NOT NULL REFERENCES os_catalog(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE,
    currency VARCHAR(5) NOT NULL DEFAULT 'ARS',
    unit_monetary_value NUMERIC(12, 4),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (catalog_id, name)
);

CREATE TABLE IF NOT EXISTS os_fee_item (
    id SERIAL PRIMARY KEY,
    fee_schedule_id INT NOT NULL REFERENCES os_fee_schedule(id) ON DELETE CASCADE,
    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,
    pricing_unit_id INT NOT NULL REFERENCES os_pricing_unit(id),
    units_amount NUMERIC(12, 4) NOT NULL DEFAULT 1.0,
    fixed_price NUMERIC(12, 4),
    expenses_amount NUMERIC(12, 4) DEFAULT 0.0,
    UNIQUE (fee_schedule_id, item_id)
);


-- =============================================================================
-- 4. TABLAS DE FARMACIA Y VADEMÉCUM (os_pharma_*)
-- =============================================================================
CREATE TABLE IF NOT EXISTS os_substance (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    atc_code VARCHAR(10),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS os_medicinal_product (
    id SERIAL PRIMARY KEY,
    substance_id INT NOT NULL REFERENCES os_substance(id) ON DELETE CASCADE,
    brand_name VARCHAR(255) NOT NULL,
    laboratory VARCHAR(150) NOT NULL,
    pharmacological_action VARCHAR(200),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (brand_name, laboratory)
);

CREATE TABLE IF NOT EXISTS os_product_package (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL REFERENCES os_medicinal_product(id) ON DELETE CASCADE,
    presentation_text VARCHAR(255) NOT NULL,
    dosage_form VARCHAR(100),
    sale_type VARCHAR(50) NOT NULL DEFAULT 'Venta Bajo Receta'
        CHECK (sale_type IN ('Venta Libre', 'Venta Bajo Receta', 'Archivada', 'Decreto')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (product_id, presentation_text)
);

CREATE TABLE IF NOT EXISTS os_product_identifier (
    id SERIAL PRIMARY KEY,
    package_id INT NOT NULL REFERENCES os_product_package(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL,
    identifier_value VARCHAR(50) NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (system_code, identifier_value)
);

CREATE INDEX IF NOT EXISTS idx_os_substance_trgm ON os_substance USING gin (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_product_brand ON os_medicinal_product USING gin (brand_name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_os_prod_ident ON os_product_identifier(system_code, identifier_value);


-- =============================================================================
-- 5. POBLADO: SISTEMAS TERMINOLÓGICOS Y UNIDADES
-- =============================================================================
INSERT INTO os_terminology_system (id, code, name, uri) VALUES
(1, 'SNOMED-CT', 'SNOMED Clinical Terms (Edición Argentina)', 'http://snomed.info/sct'),
(2, 'CIE-10', 'Clasificación Internacional de Enfermedades 10ª Rev.', 'http://hl7.org/fhir/sid/icd-10'),
(3, 'LOINC', 'Logical Observation Identifiers Names and Codes', 'http://loinc.org'),
(4, 'CDT-2025', 'Code on Dental Procedures and Nomenclature 2025', 'http://www.ada.org/cdt')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, uri = EXCLUDED.uri;

INSERT INTO os_pricing_unit (code, name, organization, description) VALUES
('UB', 'Unidad Bioquímica', 'CUBRA', 'Unidad de valorización arancelaria de análisis clínicos'),
('GALENO', 'Galeno Médico / Quirúrgico', 'MSAL', 'Unidad arancelaria histórica del Nomenclador Nacional'),
('MODULO', 'Módulo Prestacional', 'MSAL / ANDIS', 'Paquete cerrado de cobertura integral'),
('SESION', 'Sesión Terapéutica', 'Colegios Profesionales', 'Arancel por sesión de kinesiología o psicología'),
('PESOS', 'Pesos Argentinos', 'MSAL / NHPGD', 'Arancel fijado directamente en moneda de curso legal'),
('KM', 'Kilómetro Recorrido', 'ANDIS', 'Valor por kilómetro de transporte especial')
ON CONFLICT (code) DO NOTHING;


-- =============================================================================
-- 6. POBLADO: REGISTRO DE LOS 7 CATÁLOGOS CENTRALES
-- =============================================================================
INSERT INTO os_catalog (code, name, organization, country_code, domain_type, description) VALUES
('dentar', 'Sistema DENTAR - Ontología Odontológica Argentina y Latinoamericana', 'Origen Salud / Comité Odontológico', 'AR', 'dental', 'Catálogo odontológico central armonizado con ADA CDT 2025, Nomenclador Argentino y CIE-10.'),
('nn-pmo', 'Nomenclador Nacional de Prestaciones Médicas y Sanatoriales', 'Ministerio de Salud de la Nación', 'AR', 'medical', 'Estándar histórico para consultas médicas, cirugías, internaciones y base del PMO.'),
('nbu', 'Nomenclador Bioquímico Único', 'Confederación Unificada Bioquímica de la República Argentina (CUBRA)', 'AR', 'biochemical', 'Catálogo nacional de análisis clínicos con cálculo de Unidades Bioquímicas (UB).'),
('nhpgd', 'Nomenclador de Hospitales Públicos de Gestión Descentralizada', 'Ministerio de Salud de la Nación', 'AR', 'medical', 'Nomenclador para recupero de costos hospitalarios a obras sociales y prepagas.'),
('andis', 'Nomenclador de Prestaciones Básicas para Personas con Discapacidad', 'Agencia Nacional de Discapacidad', 'AR', 'rehabilitation', 'Aranceles regulados para rehabilitación, centros de día, transporte y apoyo escolar.'),
('kinesiologia', 'Nomenclador de Kinesiología y Fisiatría', 'Colegios y Asociaciones de Kinesiólogos', 'AR', 'rehabilitation', 'Codificación arancelaria para fisioterapia, kinesiología motriz y respiratoria.'),
('salud-mental', 'Nomenclador de Psicología y Salud Mental', 'Colegios de Psicólogos y Asociaciones de Psiquiatría', 'AR', 'mental_health', 'Prestaciones de psicoterapia individual, familiar, evaluaciones y peritajes.')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

-- Releases 2026 oficiales para todos los catálogos
INSERT INTO os_catalog_release (catalog_id, version_tag, valid_from, official_norm_reference)
SELECT id, '2026-v1', '2026-01-01', 'Vigencia oficial 2026' FROM os_catalog
ON CONFLICT (catalog_id, version_tag) DO NOTHING;

-- Cuadros Arancelarios 2026 para todos los catálogos
INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel Ético DENTAR 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Nomenclador Nacional Base 2026', '2026-01-01', 'ARS', 12000.0 FROM os_catalog WHERE code = 'nn-pmo'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel CUBRA NBU 2026', '2026-01-01', 'ARS', 3500.0 FROM os_catalog WHERE code = 'nbu'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel NHPGD Resolución MSAL 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'nhpgd'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Nomenclador Arancelario ANDIS 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'andis'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel Colegiado Kinesiología 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'kinesiologia'
ON CONFLICT (catalog_id, name) DO NOTHING;

INSERT INTO os_fee_schedule (catalog_id, name, valid_from, currency, unit_monetary_value)
SELECT id, 'Arancel Referencial Psicología 2026', '2026-01-01', 'ARS', 1.0 FROM os_catalog WHERE code = 'salud-mental'
ON CONFLICT (catalog_id, name) DO NOTHING;
""")

# Categorías DENTAR
dental_categories = [
    ("CAT-DIAG", "Capítulo I - Consultas y Diagnóstico"),
    ("CAT-REST", "Capítulo II - Operatoria Dental y Restauradora"),
    ("CAT-ENDO", "Capítulo III - Endodoncia"),
    ("CAT-SURG", "Capítulo IV - Cirugía Bucomaxilofacial Menor"),
    ("CAT-PROSTH-R", "Capítulo V - Prótesis Removible"),
    ("CAT-PROSTH-F", "Capítulo VI - Prótesis Fija"),
    ("CAT-PERI", "Capítulo VII - Periodoncia"),
    ("CAT-ORTHO", "Capítulo VIII - Ortodoncia y Ortopedia Funcional"),
    ("CAT-IMPL", "Capítulo IX - Implantología Oral"),
    ("CAT-SURG-MAX", "Capítulo X - Cirugía Bucomaxilofacial Mayor"),
    ("CAT-ADJ", "Capítulo XI - Prestaciones Generales y Urgencias"),
]

out.append("\n-- Categorías DENTAR")
for code, name in dental_categories:
    out.append(f"""INSERT INTO os_catalog_category (catalog_id, code, name)
SELECT id, '{code}', {sql_str(name)} FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, code) DO NOTHING;""")

# Ingesta 138 Prestaciones DENTAR
out.append("\n-- Ingesta de las 138 Prestaciones DENTAR")
for idx, r in enumerate(rows, 1):
    dnt_code = f"DNT-{idx:06d}"
    ar_code = r[0].strip()
    desc = r[1].strip()
    cap_code, cdt_code, sct_concept = map_dental_row(r)

    out.append(f"""-- {dnt_code} :: {ar_code}
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, '{dnt_code}', 'active' FROM os_catalog WHERE code = 'dentar'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, category_id, preferred_term, language_code)
SELECT i.id, r.id, c.id, {sql_str(desc)}, 'es-AR'
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
LEFT JOIN os_catalog_category c ON c.catalog_id = cat.id AND c.code = '{cap_code}'
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'NOMENCLADOR_AR', '{ar_code}', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, system_name, value) DO NOTHING;

-- Mapeo CDT 2025
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 4, '{cdt_code}', 'ADA CDT 2025', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Mapeo SNOMED CT
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '{sct_concept}', 'SNOMED CT Procedure Concept', 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code = '{dnt_code}'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
""")

# Mapeos de justificación diagnóstica DENTAR <-> CIE-10
out.append("""
-- Justificaciones Diagnósticas CIE-10 para Operatoria DENTAR
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role, clinical_rationale)
SELECT i.id, 2, 'K02.1', 'Caries de la dentina', 'equivalent', 'justifying_diagnosis', 'Caries activa con cavitación dentinaria que justifica restauración'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code IN ('DNT-000007', 'DNT-000008', 'DNT-000009', 'DNT-000010', 'DNT-000011', 'DNT-000012')
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Justificaciones Diagnósticas CIE-10 para Endodoncia DENTAR
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role, clinical_rationale)
SELECT i.id, 2, 'K04.0', 'Pulpitis irreversible', 'equivalent', 'justifying_diagnosis', 'Inflamación pulpar irreversible que requiere tratamiento endodóntico'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code IN ('DNT-000017', 'DNT-000018', 'DNT-000019', 'DNT-000020')
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;

-- Justificaciones Diagnósticas CIE-10 para Periodoncia DENTAR
INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role, clinical_rationale)
SELECT i.id, 2, 'K05.3', 'Periodontitis crónica', 'equivalent', 'justifying_diagnosis', 'Pérdida ósea y bolsas periodontales que requieren raspado y alisado radicular'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = 'dentar' AND i.permanent_code IN ('DNT-000049', 'DNT-000050', 'DNT-000051')
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
""")

# Función genérica para insertar items de catálogos
def generate_catalog_items_sql(cat_code, sched_name, items):
    sql_chunks = []
    for it in items:
        p_code = it["perm_code"]
        code = it["code"]
        clean = it["clean"]
        term = it["term"]
        unit = it.get("unit")
        amount = it.get("amount", 1.0)
        fixed_price = it.get("fixed_price")
        expenses = it.get("expenses", 0.0)
        sct = it.get("sct")
        sct_display = it.get("sct_display", "Procedimiento SNOMED CT")
        loinc = it.get("loinc")
        loinc_display = it.get("loinc_display", "LOINC Concept")

        chunk = f"""-- Item {p_code} ({code})
INSERT INTO os_catalog_item (catalog_id, permanent_code, status)
SELECT id, '{p_code}', 'active' FROM os_catalog WHERE code = '{cat_code}'
ON CONFLICT (catalog_id, permanent_code) DO NOTHING;

INSERT INTO os_catalog_item_version (item_id, release_id, preferred_term, language_code)
SELECT i.id, r.id, {sql_str(term)}, 'es-AR'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
JOIN os_catalog_release r ON r.catalog_id = cat.id AND r.version_tag = '2026-v1'
WHERE cat.code = '{cat_code}' AND i.permanent_code = '{p_code}'
ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET preferred_term = EXCLUDED.preferred_term;

INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'CÓDIGO_OFICIAL', '{code}', TRUE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = '{cat_code}' AND i.permanent_code = '{p_code}'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
"""
        if clean != code:
            chunk += f"""INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)
SELECT i.id, 'SIN_PUNTOS', '{clean}', FALSE
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = '{cat_code}' AND i.permanent_code = '{p_code}'
ON CONFLICT (item_id, system_name, value) DO NOTHING;
"""
        if sct:
            chunk += f"""INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 1, '{sct}', {sql_str(sct_display)}, 'equivalent', 'procedure_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = '{cat_code}' AND i.permanent_code = '{p_code}'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
"""
        if loinc:
            chunk += f"""INSERT INTO os_concept_mapping (item_id, terminology_system_id, external_code, external_display, mapping_type, relationship_role)
SELECT i.id, 3, '{loinc}', {sql_str(loinc_display)}, 'equivalent', 'observation_concept'
FROM os_catalog_item i JOIN os_catalog cat ON cat.id = i.catalog_id
WHERE cat.code = '{cat_code}' AND i.permanent_code = '{p_code}'
ON CONFLICT (item_id, terminology_system_id, external_code, relationship_role) DO NOTHING;
"""
        if unit:
            fprice_val = f"{fixed_price:.4f}" if fixed_price is not None else "NULL"
            chunk += f"""INSERT INTO os_fee_item (fee_schedule_id, item_id, pricing_unit_id, units_amount, fixed_price, expenses_amount)
SELECT f.id, i.id, u.id, {amount:.4f}, {fprice_val}, {expenses:.4f}
FROM os_catalog_item i
JOIN os_catalog cat ON cat.id = i.catalog_id
CROSS JOIN os_fee_schedule f
CROSS JOIN os_pricing_unit u
WHERE cat.code = '{cat_code}' AND i.permanent_code = '{p_code}' AND f.name = '{sched_name}' AND u.code = '{unit}'
ON CONFLICT (fee_schedule_id, item_id) DO UPDATE SET
    units_amount = EXCLUDED.units_amount,
    fixed_price = EXCLUDED.fixed_price,
    expenses_amount = EXCLUDED.expenses_amount;
"""
        sql_chunks.append(chunk)
    return "\n".join(sql_chunks)

# 7. NN-PMO
out.append("""-- =============================================================================
-- 7. INGESTA: NOMENCLADOR NACIONAL MÉDICO / PMO (nn-pmo) (11 ITEMS)
-- =============================================================================
""")
out.append(generate_catalog_items_sql("nn-pmo", "Nomenclador Nacional Base 2026", nn_pmo_items))

# 8. NBU
out.append("""-- =============================================================================
-- 8. INGESTA: NOMENCLADOR BIOQUÍMICO ÚNICO (nbu) (14 ITEMS)
-- =============================================================================
""")
out.append(generate_catalog_items_sql("nbu", "Arancel CUBRA NBU 2026", nbu_items))

# 9. NHPGD
out.append("""-- =============================================================================
-- 9. INGESTA: HOSPITALES PÚBLICOS DE GESTIÓN DESCENTRALIZADA (nhpgd) (8 ITEMS)
-- =============================================================================
""")
out.append(generate_catalog_items_sql("nhpgd", "Arancel NHPGD Resolución MSAL 2026", nhpgd_items))

# 10. ANDIS
out.append("""-- =============================================================================
-- 10. INGESTA: PRESTACIONES PARA PERSONAS CON DISCAPACIDAD (andis) (9 ITEMS)
-- =============================================================================
""")
out.append(generate_catalog_items_sql("andis", "Nomenclador Arancelario ANDIS 2026", andis_items))

# 11. KINESIOLOGIA
out.append("""-- =============================================================================
-- 11. INGESTA: KINESIOLOGÍA Y FISIATRÍA (kinesiologia) (6 ITEMS)
-- =============================================================================
""")
out.append(generate_catalog_items_sql("kinesiologia", "Arancel Colegiado Kinesiología 2026", kinesiologia_items))

# 12. SALUD MENTAL
out.append("""-- =============================================================================
-- 12. INGESTA: PSICOLOGÍA Y SALUD MENTAL (salud-mental) (6 ITEMS)
-- =============================================================================
""")
out.append(generate_catalog_items_sql("salud-mental", "Arancel Referencial Psicología 2026", salud_mental_items))

# 13. DOMINIO FARMACÉUTICO MULTICAPA
out.append("""-- =============================================================================
-- 13. INGESTA: DOMINIO FARMACÉUTICO MULTICAPA (10 MEDICAMENTOS)
-- =============================================================================
""")

for med in medicines_items:
    sub = med["substance"]
    atc = med["atc"]
    brand = med["brand"]
    lab = med["lab"]
    action = med["action"]
    pres = med["presentation"]
    form = med["form"]
    sale = med["sale"]
    troquel = med["troquel"]
    alfabeta = med["alfabeta"]
    kairos = med["kairos"]
    gtin = med["gtin"]

    out.append(f"""-- Fármaco: {brand} ({sub})
INSERT INTO os_substance (name, atc_code) VALUES ({sql_str(sub)}, {sql_str(atc)})
ON CONFLICT (name) DO NOTHING;

INSERT INTO os_medicinal_product (substance_id, brand_name, laboratory, pharmacological_action)
SELECT id, {sql_str(brand)}, {sql_str(lab)}, {sql_str(action)} FROM os_substance WHERE name = {sql_str(sub)}
ON CONFLICT (brand_name, laboratory) DO NOTHING;

INSERT INTO os_product_package (product_id, presentation_text, dosage_form, sale_type)
SELECT id, {sql_str(pres)}, {sql_str(form)}, {sql_str(sale)}
FROM os_medicinal_product WHERE brand_name = {sql_str(brand)} AND laboratory = {sql_str(lab)}
ON CONFLICT (product_id, presentation_text) DO NOTHING;

-- Identificadores Comerciales (Troquel, AlfaBeta, Kairos, GTIN)
INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'TROQUEL', '{troquel}', TRUE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = {sql_str(brand)} AND p.presentation_text = {sql_str(pres)}
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'ALFABETA', '{alfabeta}', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = {sql_str(brand)} AND p.presentation_text = {sql_str(pres)}
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'KAIROS', '{kairos}', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = {sql_str(brand)} AND p.presentation_text = {sql_str(pres)}
ON CONFLICT (system_code, identifier_value) DO NOTHING;

INSERT INTO os_product_identifier (package_id, system_code, identifier_value, is_primary)
SELECT p.id, 'GTIN', '{gtin}', FALSE FROM os_product_package p
JOIN os_medicinal_product mp ON mp.id = p.product_id
WHERE mp.brand_name = {sql_str(brand)} AND p.presentation_text = {sql_str(pres)}
ON CONFLICT (system_code, identifier_value) DO NOTHING;
""")

out.append("""-- =============================================================================
-- 14. TABLAS PLANAS AUXILIARES Y ANALYZE
-- =============================================================================
CREATE TABLE IF NOT EXISTS nomencladores_argentina (
    id SERIAL PRIMARY KEY,
    tipo_nomenclador VARCHAR(30) NOT NULL,
    codigo VARCHAR(30) NOT NULL,
    capitulo VARCHAR(100),
    descripcion TEXT NOT NULL,
    unidad_tipo VARCHAR(30),
    unidad_valor NUMERIC(12, 4),
    gastos_valor NUMERIC(12, 4),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    codigo_loinc VARCHAR(20),
    vigencia_desde DATE,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tipo_nomenclador, codigo)
);

CREATE INDEX IF NOT EXISTS idx_nom_arg_trgm ON nomencladores_argentina USING gin (descripcion gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_nom_arg_tipo_codigo ON nomencladores_argentina(tipo_nomenclador, codigo);

CREATE TABLE IF NOT EXISTS vademecum_comercial (
    id SERIAL PRIMARY KEY,
    numero_troquel VARCHAR(20) UNIQUE,
    codigo_alfabeta VARCHAR(20),
    codigo_kairos VARCHAR(20),
    codigo_barras_gtin VARCHAR(20),
    monodroga VARCHAR(255) NOT NULL,
    nombre_comercial VARCHAR(255) NOT NULL,
    presentacion VARCHAR(255) NOT NULL,
    laboratorio VARCHAR(150),
    accion_farmacologica VARCHAR(150),
    tipo_venta VARCHAR(50),
    anmat_certificado VARCHAR(50),
    snomed_concept_id BIGINT REFERENCES snomed_concepts(id) ON DELETE SET NULL,
    activo BOOLEAN DEFAULT TRUE,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_vad_troquel ON vademecum_comercial(numero_troquel);
CREATE INDEX IF NOT EXISTS idx_vad_alfabeta ON vademecum_comercial(codigo_alfabeta);
CREATE INDEX IF NOT EXISTS idx_vad_kairos ON vademecum_comercial(codigo_kairos);
CREATE INDEX IF NOT EXISTS idx_vad_comercial_trgm ON vademecum_comercial USING gin (nombre_comercial gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_vad_monodroga_trgm ON vademecum_comercial USING gin (monodroga gin_trgm_ops);

-- Sincronización a tablas planas
INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor, gastos_valor)
SELECT 'NN_PMO', ident.value, ver.preferred_term, u.code, f.units_amount, f.expenses_amount
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'nn-pmo'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'NBU', ident.value, ver.preferred_term, u.code, f.units_amount
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'nbu'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'NHPGD', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'nhpgd'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'ANDIS', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'andis'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'KINESIOLOGIA', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'kinesiologia'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

INSERT INTO nomencladores_argentina (tipo_nomenclador, codigo, descripcion, unidad_tipo, unidad_valor)
SELECT 'SALUD_MENTAL', ident.value, ver.preferred_term, u.code, f.fixed_price
FROM os_catalog_item i
JOIN os_catalog c ON c.id = i.catalog_id AND c.code = 'salud-mental'
JOIN os_catalog_item_version ver ON ver.item_id = i.id
JOIN os_catalog_identifier ident ON ident.item_id = i.id AND ident.system_name = 'CÓDIGO_OFICIAL'
LEFT JOIN os_fee_item f ON f.item_id = i.id
LEFT JOIN os_pricing_unit u ON u.id = f.pricing_unit_id
ON CONFLICT (tipo_nomenclador, codigo) DO NOTHING;

-- ANALYZE FINAL
ANALYZE os_catalog;
ANALYZE os_catalog_release;
ANALYZE os_catalog_category;
ANALYZE os_catalog_item;
ANALYZE os_catalog_item_version;
ANALYZE os_catalog_identifier;
ANALYZE os_terminology_system;
ANALYZE os_concept_mapping;
ANALYZE os_pricing_unit;
ANALYZE os_fee_schedule;
ANALYZE os_fee_item;
ANALYZE os_substance;
ANALYZE os_medicinal_product;
ANALYZE os_product_package;
ANALYZE os_product_identifier;
ANALYZE nomencladores_argentina;
ANALYZE vademecum_comercial;

-- Resumen de Catálogos
SELECT cat.code AS catalogo, count(i.id) AS total_items
  FROM os_catalog cat
  LEFT JOIN os_catalog_item i ON i.catalog_id = cat.id
 GROUP BY cat.code
 ORDER BY total_items DESC;
""")

output_sql = "\n".join(out)
dest_path = os.path.join(os.path.dirname(__file__), "..", "sql", "origen_catalog_engine.sql")
with open(dest_path, "w", encoding="utf-8") as f:
    f.write(output_sql)

print(f"Archivo generado con éxito: {dest_path} ({len(output_sql)} bytes)")
