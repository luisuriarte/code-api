# -*- coding: utf-8 -*-
"""
Generador de la Arquitectura DENTAR Core + Módulo de Diagnósticos y Justificación Clínica (CIE-10 / SNOMED CT).
Genera: sql/dentar_core_and_diagnosis.sql (PostgreSQL 18)
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
    return "E'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r") + "'"

def map_row(r):
    code = r[0].strip()
    desc = r[1].strip()
    group = r[11].strip() if r[11] else ""
    d = desc.lower()

    if code.startswith("01."):
        if code in ("01.01", "01.06"):
            return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0150" if code=="01.01" else "D0120", 424759004, "equivalent")
        elif code == "01.05":
            return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0160", 386053000, "equivalent")
        elif code in ("01.02", "01.04"):
            return ("ADJUNCTIVE_GENERAL_SERVICES", "Servicios Complementarios de Odontología", "D9440" if code=="01.02" else "D9110", 275932009, "equivalent")
        elif code == "01.03":
            return ("ADJUNCTIVE_GENERAL_SERVICES", "Servicios Complementarios de Odontología", "D9410", 308335008, "equivalent")
        else:
            return ("ADJUNCTIVE_GENERAL_SERVICES", "Servicios Complementarios de Odontología", "D9999", 275932009, "related")

    if code.startswith("02."):
        if "ferulizaci" in d:
            return ("PERIODONTICS", "Periodoncia", "D4322", 274438002, "equivalent")
        if "amalgama" in d:
            if "simple" in d: cdt = "D2140"
            elif "compuesta" in d: cdt = "D2150"
            elif "compleja" in d: cdt = "D2160"
            elif "tornillo" in d: cdt = "D2161"
            else: cdt = "D2140"
            return ("RESTORATIVE", "Operatoria Dental y Restauradora", cdt, 80891009, "equivalent")
        if "ángulo" in d:
            return ("RESTORATIVE", "Operatoria Dental y Restauradora", "D2335", 111164008, "equivalent")
        if "simple" in d:
            cdt = "D2330" if "anterior" in d or "estética" in d else "D2391"
        elif "compuesta" in d:
            cdt = "D2331" if "anterior" in d or "estética" in d else "D2392"
        elif "tornillo" in d:
            cdt = "D2951"
        else:
            cdt = "D2391"
        return ("RESTORATIVE", "Operatoria Dental y Restauradora", cdt, 111164008, "equivalent")

    if code.startswith("03."):
        if code == "03.01": return ("ENDODONTICS", "Endodoncia", "D3310", 68673005, "equivalent")
        if code == "03.02": return ("ENDODONTICS", "Endodoncia", "D3320", 68673005, "equivalent")
        if code in ("03.03", "03.04"): return ("ENDODONTICS", "Endodoncia", "D3330", 68673005, "equivalent")
        if code == "03.05": return ("ENDODONTICS", "Endodoncia", "D3220", 234737002, "equivalent")
        if code == "03.06": return ("ENDODONTICS", "Endodoncia", "D3221", 234737002, "equivalent")
        return ("ENDODONTICS", "Endodoncia", "D3310", 68673005, "related")

    if code.startswith("04.01"):
        if "incrustaci" in d:
            cdt = "D2610" if "simple" in d else "D2620"
            return ("RESTORATIVE", "Operatoria Dental y Restauradora", cdt, 111163002, "equivalent")
        if "perno" in d or "emergente" in d:
            cdt = "D6056" if "implante" in d else "D2952"
            return ("PROSTHODONTICS_FIXED", "Prótesis Fija", cdt, 234736006, "equivalent")
        if "tramo" in d or "puente" in d:
            cdt = "D6240" if "porcelana" in d else "D6241"
            return ("PROSTHODONTICS_FIXED", "Prótesis Fija", cdt, 274439005, "equivalent")
        if "provisoria" in d:
            cdt = "D6085" if "implante" in d else "D2799"
            return ("PROSTHODONTICS_FIXED", "Prótesis Fija", cdt, 36830009, "equivalent")
        if "ataches" in d or "poste bola" in d or "dolder" in d:
            return ("PROSTHODONTICS_FIXED", "Prótesis Fija", "D5862", 274439005, "equivalent")
        if "porcelana" in d:
            cdt = "D6058" if "implante" in d else "D2740"
        elif "frente estético" in d or "acrílico" in d:
            cdt = "D2751"
        else:
            cdt = "D2790"
        return ("PROSTHODONTICS_FIXED", "Prótesis Fija", cdt, 36830009, "equivalent")

    if code.startswith("04.02") or code.startswith("04.03") or code.startswith("04.04"):
        if "compostura" in d or "soldado" in d or "rebasado" in d or "agregado" in d or "carilla" in d:
            if "rebasado" in d: cdt = "D5750"
            elif "diente" in d: cdt = "D5640"
            elif "retenedor" in d: cdt = "D5630"
            elif "soldado" in d: cdt = "D5621"
            else: cdt = "D5611"
            return ("PROSTHODONTICS_REMOVABLE", "Prótesis Parcial y Completa Removible", cdt, 274440007, "equivalent")
        if "cubeta" in d:
            return ("PROSTHODONTICS_REMOVABLE", "Prótesis Parcial y Completa Removible", "D5899", None, "related")
        if "levante" in d:
            return ("ADJUNCTIVE_GENERAL_SERVICES", "Servicios Complementarios de Odontología", "D9944", 274441006, "equivalent")
        if "completa" in d or code.startswith("04.03"):
            if "superior" in d: cdt = "D5110"
            elif "inferior" in d: cdt = "D5120"
            elif "inmediata" in d: cdt = "D5130"
            else: cdt = "D5110"
            return ("PROSTHODONTICS_REMOVABLE", "Prótesis Parcial y Completa Removible", cdt, 274440007, "equivalent")
        if "cromo" in d:
            cdt = "D5213"
        elif "inmediata" in d:
            cdt = "D5221"
        else:
            cdt = "D5211"
        return ("PROSTHODONTICS_REMOVABLE", "Prótesis Parcial y Completa Removible", cdt, 274440007, "equivalent")

    if code.startswith("05."):
        if code in ("05.00", "05.03"): return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0425" if code=="05.03" else "D0150", None, "related")
        if code == "05.01": return ("PREVENTIVE", "Odontología Preventiva", "D1110", 22769002, "equivalent")
        if code == "05.02": return ("PREVENTIVE", "Odontología Preventiva", "D1206", 110462007, "equivalent")
        if code == "05.04": return ("PREVENTIVE", "Odontología Preventiva", "D1330", 399047006, "equivalent")
        if code == "05.05": return ("PREVENTIVE", "Odontología Preventiva", "D1351", 234735005, "equivalent")
        if code == "05.06": return ("PREVENTIVE", "Odontología Preventiva", "D1354", 713601007, "equivalent")
        return ("PREVENTIVE", "Odontología Preventiva", "D1110", 22769002, "equivalent")

    if code.startswith("06."):
        if code == "06.01": return ("ORTHODONTICS", "Ortodoncia y Ortopedia Funcional", "D8660", 401267008, "equivalent")
        if code == "06.02": return ("ORTHODONTICS", "Ortodoncia y Ortopedia Funcional", "D8020", 401267008, "equivalent")
        if code in ("06.03", "06.05"): return ("ORTHODONTICS", "Ortodoncia y Ortopedia Funcional", "D8080", 401267008, "equivalent")
        if code == "06.04": return ("ORTHODONTICS", "Ortodoncia y Ortopedia Funcional", "D8050", 401267008, "equivalent")
        return ("ORTHODONTICS", "Ortodoncia y Ortopedia Funcional", "D8080", 401267008, "equivalent")

    if code.startswith("07."):
        if code == "07.01": return ("PREVENTIVE", "Odontología Preventiva", "D0145", 399120002, "equivalent")
        if code == "07.02": return ("PREVENTIVE", "Odontología Preventiva", "D1510", 274437007, "equivalent")
        if code == "07.03": return ("PREVENTIVE", "Odontología Preventiva", "D1520", 274437007, "equivalent")
        if code == "07.04": return ("ENDODONTICS", "Endodoncia", "D3220", 234737002, "equivalent")
        if code == "07.05": return ("RESTORATIVE", "Operatoria Dental y Restauradora", "D2930", 36830009, "equivalent")
        if code in ("07.06.01", "07.06.02"): return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7270", 234744004, "equivalent")
        if code == "07.06.04": return ("RESTORATIVE", "Operatoria Dental y Restauradora", "D2970", 111164008, "equivalent")
        if code == "07.07": return ("ENDODONTICS", "Endodoncia", "D3110", 234737002, "equivalent")
        if code == "07.08": return ("PREVENTIVE", "Odontología Preventiva", "D1354", 713601007, "equivalent")
        return ("PREVENTIVE", "Odontología Preventiva", "D0145", None, "related")

    if code.startswith("08."):
        if code == "08.01": return ("PERIODONTICS", "Periodoncia", "D0180", 424759004, "equivalent")
        if code == "08.02": return ("PERIODONTICS", "Periodoncia", "D4346", 110463002, "equivalent")
        if code == "08.03": return ("PERIODONTICS", "Periodoncia", "D4341", 110463002, "equivalent")
        if code in ("08.04", "08.04 C"): return ("PERIODONTICS", "Periodoncia", "D4260" if code=="08.04" else "D4210", 234740008, "equivalent")
        if code == "08.05": return ("PERIODONTICS", "Periodoncia", "D9951", 274441006, "equivalent")
        if code.startswith("08.05."): return ("ADJUNCTIVE_GENERAL_SERVICES", "Servicios Complementarios de Odontología", "D7880", 274441006, "equivalent")
        if code == "08.06": return ("ADJUNCTIVE_GENERAL_SERVICES", "Servicios Complementarios de Odontología", "D9944", 274441006, "equivalent")
        if code == "08.07": return ("PERIODONTICS", "Periodoncia", "D4910", 110463002, "equivalent")
        return ("PERIODONTICS", "Periodoncia", "D4341", 110463002, "equivalent")

    if code.startswith("09."):
        if code == "09.01.01": return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0220", 399195000, "equivalent")
        if code == "09.01.02": return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0272", 399195000, "equivalent")
        if code == "09.01.03": return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0240", 399195000, "equivalent")
        if code in ("09.01.04", "09.01.05"): return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0210", 399195000, "equivalent")
        if code == "09.02.03": return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0320", 399195000, "equivalent")
        if code == "09.02.04": return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0330", 399195000, "equivalent")
        if code in ("09.02.05", "09.02.05 bis"): return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0340", 399195000, "equivalent")
        if code == "09.02.06": return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0310", 399195000, "equivalent")
        return ("DIAGNOSTIC", "Diagnóstico y Exámenes Clínicos", "D0250", 399195000, "equivalent")

    if code.startswith("10."):
        if code == "10.01": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7140", 234744004, "equivalent")
        if code == "10.02": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7260", 234744004, "equivalent")
        if code in ("10.03", "10.07"): return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7285" if code=="10.03" else "D7286", 234744004, "equivalent")
        if code in ("10.04", "10.15"): return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7310", 234744004, "equivalent")
        if code == "10.05": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7270", 234744004, "equivalent")
        if code == "10.06": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7510", 234744004, "equivalent")
        if code == "10.08": return ("PERIODONTICS", "Periodoncia", "D4249", 234740008, "equivalent")
        if code in ("10.09", "10.18", "10.19"): return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7240" if code=="10.19" else "D7210", 234744004, "equivalent")
        if code == "10.10": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7251", 234744004, "equivalent")
        if code == "10.11": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7280", 234744004, "equivalent")
        if code == "10.12": return ("ENDODONTICS", "Endodoncia", "D3410", 234737002, "equivalent")
        if code == "10.13": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7440", 234744004, "equivalent")
        if code == "10.14": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7530", 234744004, "equivalent")
        if code == "10.16": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7961", 234744004, "equivalent")
        if code == "10.17": return ("ENDODONTICS", "Endodoncia", "D3920", 234737002, "equivalent")
        if code == "10.20": return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7910", 234744004, "equivalent")
        return ("ORAL_MAXILLOFACIAL_SURGERY", "Cirugía Bucal y Maxilofacial", "D7140", 234744004, "equivalent")

    if code.startswith("11."):
        if code.startswith("11.01"): return ("IMPLANT_SERVICES", "Implantología Odontológica", "D6010", 234745003, "equivalent")
        if code == "11.02": return ("IMPLANT_SERVICES", "Implantología Odontológica", "D6104", 234745003, "equivalent")
        return ("IMPLANT_SERVICES", "Implantología Odontológica", "D6010", 234745003, "equivalent")

    return ("ADJUNCTIVE_GENERAL_SERVICES", "Servicios Complementarios de Odontología", "D9999", 275932009, "related")

rows = load_odontologico_rows()
print(f"Loaded {len(rows)} procedures for DENTAR Core.")

out = []
out.append("-- =============================================================================")
out.append("-- Origen Salud · Sistema DENTAR (Ontología Odontológica + Diagnósticos CIE-10)")
out.append("-- dentar_core_and_diagnosis.sql :: DENTAR Core + Justificación Clínica")
out.append("-- =============================================================================")
out.append("--")
out.append("-- CONTENIDO:")
out.append("--   1. dentar_release: Versiones y ciclo de vida de la ontología.")
out.append("--   2. dentar_category / dentar_category_version: Jerarquía y capítulos.")
out.append("--   3. dentar_concept / dentar_concept_version: Identidad permanente (DNT-XXXXXX).")
out.append("--   4. dentar_term: Términos preferidos, sinónimos y siglas (es-AR / en).")
out.append("--   5. dentar_unit / dentar_concept_unit: Unidades clínicas (pieza, cara, arcada).")
out.append("--   6. dentar_attribute_definition / dentar_concept_attribute_rule: Reglas de auditoría.")
out.append("--   7. dentar_terminology_system / dentar_concept_mapping: Mapeos externos CDT/SNOMED/AR.")
out.append("--   8. dentar_diagnosis / dentar_diagnosis_mapping: Catálogo de diagnósticos CIE-10 (K00-K14).")
out.append("--   9. dentar_concept_diagnosis: Matriz de justificación clínica (prestación <-> diagnóstico).")
out.append("--  10. Vistas de consulta clínica e interoperabilidad.")
out.append("--")
out.append("-- COMPATIBILIDAD: PostgreSQL 18")
out.append("-- =============================================================================\n")

out.append("SET client_encoding = 'UTF8';")
out.append("SET statement_timeout = 0;")
out.append("CREATE EXTENSION IF NOT EXISTS pg_trgm;\n")

# 1. dentar_release
out.append("-- =============================================================================")
out.append("-- 1. DENTAR RELEASE (GOBERNANZA Y VERSIONES)")
out.append("-- =============================================================================")
out.append("""CREATE TABLE IF NOT EXISTS dentar_release (
    id SERIAL PRIMARY KEY,
    version VARCHAR(20) NOT NULL UNIQUE,
    release_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'published' CHECK (status IN ('draft', 'published', 'deprecated')),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dentar_release (version, release_date, status, description)
VALUES ('1.0.0', CURRENT_DATE, 'published', 'Primera publicación oficial del estándar DENTAR Argentina')
ON CONFLICT (version) DO UPDATE SET description = EXCLUDED.description;
""")

# 2. dentar_category
out.append("\n-- =============================================================================")
out.append("-- 2. CATEGORÍAS Y CAPÍTULOS")
out.append("-- =============================================================================")
out.append("""CREATE TABLE IF NOT EXISTS dentar_category (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    parent_id INT REFERENCES dentar_category(id),
    sort_order INT NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive'))
);

CREATE TABLE IF NOT EXISTS dentar_category_version (
    id SERIAL PRIMARY KEY,
    category_id INT NOT NULL REFERENCES dentar_category(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    name VARCHAR(150) NOT NULL,
    description TEXT,
    UNIQUE (category_id, version_number, language)
);
""")

categories_core = [
    ("CAT-DIAG", 10, "Diagnóstico y Exámenes Clínicos", "Evaluaciones orales, exámenes estomatológicos e imágenes radiográficas."),
    ("CAT-PREV", 20, "Odontología Preventiva", "Profilaxis, aplicaciones de flúor, selladores y mantenedores de espacio."),
    ("CAT-REST", 30, "Operatoria Dental y Restauradora", "Restauraciones con amalgama, resinas fotocurables, incrustaciones y estética."),
    ("CAT-ENDO", 40, "Endodoncia", "Biopulpectomías, tratamientos de conductos unirradiculares y multirradiculares."),
    ("CAT-PERI", 50, "Periodoncia", "Tratamiento de gingivitis, raspado y alisado radicular y cirugías periodontales."),
    ("CAT-PROSTH-R", 60, "Prótesis Parcial y Completa Removible", "Prótesis completas, parciales acrílicas y de cromo-cobalto, composturas y rebasados."),
    ("CAT-PROSTH-F", 70, "Prótesis Fija", "Coronas unitarias coladas, porcelana pura o sobre metal, pernos muñón y puentes."),
    ("CAT-IMPL", 80, "Implantología Odontológica", "Colocación quirúrgica de implantes, emergentes protésicos y relleno óseo."),
    ("CAT-SURG", 90, "Cirugía Bucal y Maxilofacial", "Extracciones simples, dientes retenidos, germectomías, apicectomías y biopsias."),
    ("CAT-ORTHO", 100, "Ortodoncia y Ortopedia Funcional", "Estudios diagnósticos, ortodoncia interceptiva y tratamientos integrales."),
    ("CAT-ADJ", 110, "Servicios Complementarios de Odontología", "Consultas de urgencia, visitas a domicilio, placas de relajación y ATM."),
]

for code, sort, name, desc in categories_core:
    out.append(f"""INSERT INTO dentar_category (code, sort_order) VALUES ({sql_str(code)}, {sort})
ON CONFLICT (code) DO UPDATE SET sort_order = EXCLUDED.sort_order;

INSERT INTO dentar_category_version (category_id, version_number, language, name, description)
SELECT id, 1, 'es-AR', {sql_str(name)}, {sql_str(desc)} FROM dentar_category WHERE code = {sql_str(code)}
ON CONFLICT (category_id, version_number, language) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;
""")

# 3. dentar_unit
out.append("\n-- =============================================================================")
out.append("-- 3. UNIDADES CLÍNICAS DE PRESTACIÓN")
out.append("-- =============================================================================")
out.append("""CREATE TABLE IF NOT EXISTS dentar_unit (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

INSERT INTO dentar_unit (code, name, description) VALUES
('UNIT-TOOTH', 'Por pieza dentaria (FDI)', 'Requiere indicar número de pieza dentaria según nomenclatura FDI de 2 dígitos'),
('UNIT-SURFACE', 'Por cara dentaria', 'Requiere indicar caras involucradas (Oclusal, Mesial, Distal, Vestibular, Lingual/Palatina)'),
('UNIT-QUADRANT', 'Por cuadrante o sector', 'Requiere especificar cuadrante (1 a 4) o sector bucal (1 a 6)'),
('UNIT-ARCH', 'Por arcada / maxilar', 'Requiere especificar maxilar superior o inferior'),
('UNIT-SESSION', 'Por consulta / sesión', 'Prestación de carácter clínico global que no se acota a una pieza individual')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;
""")

# 4. dentar_attribute_definition
out.append("\n-- =============================================================================")
out.append("-- 4. REGLAS Y DEFINICIÓN DE ATRIBUTOS CLÍNICOS DE AUDITORÍA")
out.append("-- =============================================================================")
out.append("""CREATE TABLE IF NOT EXISTS dentar_attribute_definition (
    id SERIAL PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    data_type VARCHAR(20) NOT NULL CHECK (data_type IN ('string','integer','decimal','boolean','date','coded')),
    description TEXT
);

INSERT INTO dentar_attribute_definition (code, name, data_type, description) VALUES
('ATTR-TOOTH', 'Especificación de Pieza Dentaria', 'coded', 'Indica si es obligatorio enviar la pieza dentaria bajo norma FDI'),
('ATTR-SURFACE', 'Especificación de Caras', 'coded', 'Indica si es obligatorio detallar las caras cavitarias tratadas'),
('ATTR-PRE-XRAY', 'Radiografía Pre-Operatoria', 'boolean', 'Exigencia de radiografía previa para auditoría médica'),
('ATTR-POST-XRAY', 'Radiografía Post-Operatoria', 'boolean', 'Exigencia de radiografía de control final'),
('ATTR-DENTAL-CHART', 'Odontograma / Fichado Inicial', 'boolean', 'Requisito de registrar estado inicial de la cavidad bucal'),
('ATTR-PERIODONTAL-CHART', 'Ficha Periodontal / Periodontograma', 'boolean', 'Requisito de registro de profundidad de sondaje de bolsas'),
('ATTR-MATERIAL', 'Material Protésico / Dental', 'string', 'Especificación del material biocompatible o metal empleado')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;
""")

# 5. dentar_terminology_system
out.append("\n-- =============================================================================")
out.append("-- 5. SISTEMAS DE TERMINOLOGÍA EXTERNA VINCULADOS")
out.append("-- =============================================================================")
out.append("""CREATE TABLE IF NOT EXISTS dentar_terminology_system (
    id SERIAL PRIMARY KEY,
    code VARCHAR(30) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    uri VARCHAR(500),
    description TEXT
);

INSERT INTO dentar_terminology_system (code, name, uri, description) VALUES
('CDT-2025', 'Code on Dental Procedures and Nomenclature (ADA)', 'https://www.ada.org/cdt', 'Estándar internacional de codificación de procedimientos odontológicos de la ADA'),
('NOMENCLADOR-AR', 'Nomenclador Odontológico Único de Argentina', 'https://fopba.org.ar', 'Nomenclador nacional y de colegios odontológicos argentinos (Capítulos I a XI)'),
('SNOMED-CT', 'SNOMED Clinical Terms (Edición Argentina)', 'http://snomed.info/sct', 'Terminología clínica ontológica universal adoptada por el Ministerio de Salud'),
('CIE-10', 'Clasificación Internacional de Enfermedades 10ª Rev.', 'https://icd.who.int/browse10', 'Clasificación estadística de afecciones y diagnósticos bucomaxilofaciales (K00-K14)')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;
""")

# 6. dentar_concept, concept_version, terms, rules, mappings
out.append("\n-- =============================================================================")
out.append("-- 6. CONCEPTOS PERMANENTES DENTAR, VERSIONES, TÉRMINOS Y MAPEOS")
out.append("-- =============================================================================")
out.append("""CREATE TABLE IF NOT EXISTS dentar_concept (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,            -- Ej: 'DNT-000001'
    concept_type VARCHAR(30) NOT NULL DEFAULT 'procedure' CHECK (concept_type IN ('procedure','service','evaluation','diagnostic_service','rehabilitation')),
    lifecycle_status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (lifecycle_status IN ('draft','active','retired')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dentar_concept_version (
    id SERIAL PRIMARY KEY,
    concept_id INT NOT NULL REFERENCES dentar_concept(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    definition TEXT NOT NULL,
    clinical_scope TEXT,
    approval_status VARCHAR(20) NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('draft','review','approved','rejected')),
    effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (concept_id, version_number)
);

CREATE TABLE IF NOT EXISTS dentar_term (
    id SERIAL PRIMARY KEY,
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    language VARCHAR(10) NOT NULL DEFAULT 'es-AR',
    term VARCHAR(500) NOT NULL,
    term_type VARCHAR(20) NOT NULL DEFAULT 'preferred' CHECK (term_type IN ('preferred','synonym','abbreviation')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_dentar_term_trgm ON dentar_term USING gin (term gin_trgm_ops);

CREATE TABLE IF NOT EXISTS dentar_concept_category (
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    category_id INT NOT NULL REFERENCES dentar_category(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (concept_version_id, category_id)
);

CREATE TABLE IF NOT EXISTS dentar_concept_attribute_rule (
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    attribute_id INT NOT NULL REFERENCES dentar_attribute_definition(id) ON DELETE CASCADE,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (concept_version_id, attribute_id)
);

CREATE TABLE IF NOT EXISTS dentar_concept_mapping (
    id SERIAL PRIMARY KEY,
    concept_version_id INT NOT NULL REFERENCES dentar_concept_version(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES dentar_terminology_system(code),
    external_code VARCHAR(100) NOT NULL,
    external_display VARCHAR(500),
    relationship VARCHAR(30) NOT NULL DEFAULT 'equivalent' CHECK (relationship IN ('equivalent','broader','narrower','related','not_mappable')),
    UNIQUE (concept_version_id, system_code, external_code)
);
""")

# Map each procedure to DNT code
category_map = {
    "DIAGNOSTIC": "CAT-DIAG",
    "PREVENTIVE": "CAT-PREV",
    "RESTORATIVE": "CAT-REST",
    "ENDODONTICS": "CAT-ENDO",
    "PERIODONTICS": "CAT-PERI",
    "PROSTHODONTICS_REMOVABLE": "CAT-PROSTH-R",
    "PROSTHODONTICS_FIXED": "CAT-PROSTH-F",
    "IMPLANT_SERVICES": "CAT-IMPL",
    "ORAL_MAXILLOFACIAL_SURGERY": "CAT-SURG",
    "ORTHODONTICS": "CAT-ORTHO",
    "ADJUNCTIVE_GENERAL_SERVICES": "CAT-ADJ"
}

for idx, r in enumerate(rows, 1):
    dnt_code = f"DNT-{idx:06d}"
    ar_code = r[0].strip()
    desc = r[1].strip()
    cap = r[11].strip() if r[11] else "General"
    norma = r[12].strip() if r[12] else None

    pieza = r[5] == "1"
    caras = r[6] == "1"
    rx_pre = r[7] == "1"
    rx_post = r[8] == "1"
    f_odo = r[3] == "1"
    f_per = r[4] == "1"

    cat, cat_es, cdt, sct, rel = map_row(r)
    cat_code = category_map.get(cat, "CAT-ADJ")

    definition_text = desc
    if norma:
        definition_text += f" Normas de auditoría: {norma}"

    out.append(f"""-- {dnt_code} :: {ar_code} - {desc[:60]}
INSERT INTO dentar_concept (code, concept_type, lifecycle_status)
VALUES ({sql_str(dnt_code)}, 'procedure', 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO dentar_concept_version (concept_id, version_number, definition, clinical_scope, approval_status)
SELECT id, 1, {sql_str(definition_text)}, {sql_str(cap)}, 'approved'
FROM dentar_concept WHERE code = {sql_str(dnt_code)}
ON CONFLICT (concept_id, version_number) DO UPDATE SET definition = EXCLUDED.definition;

-- Término preferido en español
INSERT INTO dentar_term (concept_version_id, language, term, term_type)
SELECT cv.id, 'es-AR', {sql_str(desc)}, 'preferred'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = {sql_str(dnt_code)}
ON CONFLICT DO NOTHING;

-- Categoría primaria
INSERT INTO dentar_concept_category (concept_version_id, category_id, is_primary)
SELECT cv.id, cat.id, TRUE
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
CROSS JOIN dentar_category cat
WHERE c.code = {sql_str(dnt_code)} AND cat.code = {sql_str(cat_code)}
ON CONFLICT DO NOTHING;

-- Mapeo Nomenclador Argentino
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'NOMENCLADOR-AR', {sql_str(ar_code)}, {sql_str(desc)}, 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = {sql_str(dnt_code)}
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;

-- Mapeo CDT ADA 2025
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'CDT-2025', {sql_str(cdt)}, {sql_str(cat_es)}, {sql_str(rel)}
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = {sql_str(dnt_code)}
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;
""")

    if sct:
        out.append(f"""-- Mapeo SNOMED CT
INSERT INTO dentar_concept_mapping (concept_version_id, system_code, external_code, external_display, relationship)
SELECT cv.id, 'SNOMED-CT', '{sct}', 'SNOMED CT Procedure Concept', 'equivalent'
FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id
WHERE c.code = {sql_str(dnt_code)}
ON CONFLICT (concept_version_id, system_code, external_code) DO NOTHING;
""")

    # Attribute rules
    if pieza:
        out.append(f"""INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = {sql_str(dnt_code)} AND ad.code = 'ATTR-TOOTH' ON CONFLICT DO NOTHING;""")
    if caras:
        out.append(f"""INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = {sql_str(dnt_code)} AND ad.code = 'ATTR-SURFACE' ON CONFLICT DO NOTHING;""")
    if rx_pre:
        out.append(f"""INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = {sql_str(dnt_code)} AND ad.code = 'ATTR-PRE-XRAY' ON CONFLICT DO NOTHING;""")
    if rx_post:
        out.append(f"""INSERT INTO dentar_concept_attribute_rule (concept_version_id, attribute_id, is_required)
SELECT cv.id, ad.id, TRUE FROM dentar_concept c JOIN dentar_concept_version cv ON cv.concept_id = c.id CROSS JOIN dentar_attribute_definition ad
WHERE c.code = {sql_str(dnt_code)} AND ad.code = 'ATTR-POST-XRAY' ON CONFLICT DO NOTHING;""")

# 7. DIAGNOSIS MODULE (CIE-10 & SNOMED CT)
out.append("\n-- =============================================================================")
out.append("-- 7. MÓDULO DE DIAGNÓSTICOS ODONTOLÓGICOS (CIE-10 BLOQUE K00–K14)")
out.append("-- =============================================================================")
out.append("""CREATE TABLE IF NOT EXISTS dentar_diagnosis (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,              -- Ej: 'DNT-DX-0001'
    clinical_name VARCHAR(255) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'retired')),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS dentar_diagnosis_version (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES dentar_diagnosis(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    definition TEXT,
    clinical_criteria TEXT,
    UNIQUE (diagnosis_id, version_number)
);

CREATE TABLE IF NOT EXISTS dentar_diagnosis_mapping (
    id SERIAL PRIMARY KEY,
    diagnosis_id INT NOT NULL REFERENCES dentar_diagnosis(id) ON DELETE CASCADE,
    system_code VARCHAR(30) NOT NULL REFERENCES dentar_terminology_system(code),
    external_code VARCHAR(20) NOT NULL,            -- Ej: 'K02.1'
    external_display VARCHAR(255) NOT NULL,
    mapping_type VARCHAR(30) NOT NULL DEFAULT 'equivalent' CHECK (mapping_type IN ('equivalent','narrower','broader','related')),
    UNIQUE (diagnosis_id, system_code, external_code)
);

CREATE TABLE IF NOT EXISTS dentar_concept_diagnosis (
    id SERIAL PRIMARY KEY,
    concept_id INT NOT NULL REFERENCES dentar_concept(id) ON DELETE CASCADE,
    diagnosis_id INT NOT NULL REFERENCES dentar_diagnosis(id) ON DELETE CASCADE,
    relationship_type VARCHAR(30) NOT NULL DEFAULT 'indicacion_habitual'
        CHECK (relationship_type IN ('indicacion_habitual', 'indicacion_posible', 'contraindicacion', 'contextual')),
    clinical_rationale TEXT,
    UNIQUE (concept_id, diagnosis_id, relationship_type)
);

CREATE INDEX IF NOT EXISTS idx_dentar_diag_concept ON dentar_concept_diagnosis(concept_id);
CREATE INDEX IF NOT EXISTS idx_dentar_diag_diagnosis ON dentar_concept_diagnosis(diagnosis_id);
CREATE INDEX IF NOT EXISTS idx_dentar_diag_rel ON dentar_concept_diagnosis(relationship_type);
""")

# Master diagnoses list
diagnoses_master = [
    # K00
    ("DNT-DX-0001", "Dientes supernumerarios", "K00.1", "Dientes supernumerarios", 205600004, "Presencia de piezas dentarias que exceden el número habitual de la serie dentaria."),
    ("DNT-DX-0002", "Alteraciones en la erupción dentaria (dentición retenida o retrasada)", "K00.6", "Alteraciones en la erupción dentaria", 278667004, "Retraso patológico en la emergencia de piezas temporarias o permanentes."),

    # K01
    ("DNT-DX-0003", "Dientes incluidos (retención ósea o mucosa)", "K01.0", "Dientes incluidos", 371077008, "Pieza dentaria que permanece completamente rodeada de hueso o mucosa tras su tiempo de erupción."),
    ("DNT-DX-0004", "Dientes impactados (terceros molares, caninos)", "K01.1", "Dientes impactados", 371077008, "Pieza dentaria cuya trayectoria eruptiva está bloqueada por otra pieza, hueso o tejido blando."),

    # K02
    ("DNT-DX-0005", "Caries limitada al esmalte (manchas blancas / cavitación incipiente)", "K02.0", "Caries limitada al esmalte", 80967001, "Lesión de desmineralización activa localizada en la superficie adamantina."),
    ("DNT-DX-0006", "Caries de la dentina (cavitación simple, compuesta o compleja)", "K02.1", "Caries de la dentina", 80967001, "Destrucción bacteriana activa con pérdida de estructura dentinaria."),
    ("DNT-DX-0007", "Caries del cemento / radicular", "K02.2", "Caries del cemento", 80967001, "Caries que se desarrolla en superficies radiculares expuestas a la cavidad bucal."),
    ("DNT-DX-0008", "Caries dental no especificada / destrucción coronaria severa", "K02.9", "Caries dental, no especificada", 80967001, "Pérdida estructural severa por caries que compromete la viabilidad coronaria."),

    # K03
    ("DNT-DX-0009", "Abrasión y atrición dentaria patológica", "K03.1", "Abrasión de los dientes", 47444005, "Pérdida de sustancia dental por factores mecánicos o desgaste oclusal."),
    ("DNT-DX-0010", "Erosión dental ácida", "K03.2", "Erosión de los dientes", 73678001, "Disolución química del esmalte por exposición a ácidos intrínsecos o extrínsecos."),
    ("DNT-DX-0011", "Depósitos y cálculo [sarro] en los dientes", "K03.6", "Depósitos [adherencias] en los dientes", 22769002, "Acumulación de placa bacteriana calcificada supra y subgingival."),
    ("DNT-DX-0012", "Hipersensibilidad dentinaria / hiperestesia", "K03.8", "Otras enfermedades especificadas de los tejidos duros de los dientes", 88874008, "Respuesta dolorosa breve y aguda de la dentina expuesta a estímulos térmicos o táctiles."),

    # K04
    ("DNT-DX-0013", "Pulpitis reversible", "K04.0", "Pulpitis reversible", 71738007, "Inflamación pulpar con capacidad biológica de recuperación tras eliminar el irritante."),
    ("DNT-DX-0014", "Pulpitis irreversible (aguda / purulenta / crónica)", "K04.0", "Pulpitis irreversible", 71738007, "Inflamación pulpar severa que progresa hacia la necrosis y requiere endodoncia."),
    ("DNT-DX-0015", "Necrosis pulpar", "K04.1", "Necrosis de la pulpa", 34509003, "Muerte del tejido pulpar con cese de vascularización e inervación."),
    ("DNT-DX-0016", "Periodontitis apical aguda de origen pulpar", "K04.4", "Periodontitis apical aguda originada en la pulpa", 44960002, "Inflamación dolorosa del ligamento periodontal apical secundaria a patología endodóntica."),
    ("DNT-DX-0017", "Periodontitis apical crónica (granuloma apical)", "K04.5", "Periodontitis apical crónica", 44960002, "Respuesta inflamatoria periapical prolongada con reabsorción ósea asintomática."),
    ("DNT-DX-0018", "Absceso periapical con fístula", "K04.6", "Absceso periapical con fístula", 44960002, "Colección purulenta periapical con drenaje espontáneo a mucosa o piel."),
    ("DNT-DX-0019", "Absceso periapical sin fístula (flemón odontógeno agudo)", "K04.7", "Absceso periapical sin fístula", 44960002, "Colección purulenta aguda con tumefacción facial, dolor severo y riesgo de celulitis."),
    ("DNT-DX-0020", "Quiste radicular / periapical", "K04.8", "Quiste radicular", 61159002, "Lesión quística epitelizada desarrollada a partir de restos de Malassez por estímulo pulpar."),

    # K05
    ("DNT-DX-0021", "Gingivitis aguda / papilar / pericoronaritis aguda", "K05.0", "Gingivitis aguda", 66383009, "Inflamación gingival de inicio rápido con eritema, edema y hemorragia activa."),
    ("DNT-DX-0022", "Gingivitis marginal crónica inducida por placa", "K05.1", "Gingivitis crónica", 66383009, "Afección gingival crónica reversible sin pérdida de inserción periodontal clínica."),
    ("DNT-DX-0023", "Periodontitis crónica leve a moderada (bolsas hasta 5 mm)", "K05.3", "Periodontitis crónica", 110463002, "Destrucción periodontal inflamatoria con pérdida ósea alveolar de hasta 2/3 radicular."),
    ("DNT-DX-0024", "Periodontitis crónica severa destructiva (bolsas 6 mm o más)", "K05.3", "Periodontitis crónica severa", 110463002, "Pérdida ósea alveolar severa (> 2/3), compromiso de furcaciones y movilidad dentaria."),

    # K06
    ("DNT-DX-0025", "Retracción gingival localizada o generalizada", "K06.0", "Retracción gingival", 110463002, "Migración apical del margen gingival con exposición radicular y pérdida estética/funcional."),
    ("DNT-DX-0026", "Hiperplasia gingival inflamatoria o medicamentosa", "K06.1", "Hiperplasia gingival", 66383009, "Aumento de volumen tisular de la encía que cubre coronas clínicas o dificulta la higiene."),

    # K07
    ("DNT-DX-0027", "Anomalías en la posición dentaria (apiñamiento, rotación, diastemas)", "K07.3", "Anomalías de la posición del diente", 401267008, "Discrepancia dentomaxilar con malposición funcional o estética."),
    ("DNT-DX-0028", "Maloclusión funcional (Clase II, Clase III, mordida abierta / cruzada)", "K07.4", "Maloclusión, tipo no especificado", 401267008, "Relación desarmónica entre los arcos dentarios con interferencia masticatoria."),
    ("DNT-DX-0029", "Trastornos de la articulación temporomandibular (disfunción ATM / dolor miofascial)", "K07.6", "Trastornos de la articulación temporomandibular", 274441006, "Disfunción articular con ruidos, chasquidos, limitación de apertura o dolor masticatorio."),

    # K08
    ("DNT-DX-0030", "Pérdida de dientes / desdentamiento parcial o total", "K08.1", "Pérdida de dientes debida a accidente, extracción o afección periodontal", 274440007, "Ausencia de unidades dentarias con reducción de la eficacia masticatoria y soporte oclusal."),
    ("DNT-DX-0031", "Atrofia severa del reborde alveolar desdentado", "K08.2", "Atrofia del reborde alveolar desdentado", 274440007, "Reabsorción ósea de los maxilares que dificulta la retención de prótesis convencionales."),
    ("DNT-DX-0032", "Resto radicular retenido", "K08.3", "Raíz dental retenida", 371077008, "Persistencia de raíz dentaria intraósea con o sin infección activa asociada."),

    # K10, K12
    ("DNT-DX-0033", "Osteomielitis maxilar / alveolitis seca o supurada", "K10.2", "Afecciones inflamatorias de los maxilares", 234744004, "Infección bacteriana ósea de los maxilares tras extracción o trauma."),
    ("DNT-DX-0034", "Estomatitis aftosa recurrente y lesiones de mucosa oral", "K12.0", "Estomatitis aftosa recurrente", 386053000, "Ulceraciones de la mucosa bucal que requieren diagnóstico diferencial e interconsulta."),

    # Traumatismos y Contextuales
    ("DNT-DX-0035", "Fractura de corona o raíz dental (traumatismo dentario)", "S02.5", "Fractura de los dientes", 111164008, "Solución de continuidad del esmalte, dentina o raíz por impacto traumático."),
    ("DNT-DX-0036", "Luxación o avulsión total de diente por traumatismo", "S03.2", "Luxación de diente", 234744004, "Desplazamiento o expulsión completa de la pieza dentaria fuera de su alvéolo."),
    ("DNT-DX-0037", "Bruxismo (rechinar / apretamiento diurno o nocturno)", "F45.8", "Bruxismo", 274441006, "Actividad parafuncional masticatoria que genera desgaste dentario, cefaleas o dolor de ATM."),
    ("DNT-DX-0038", "Examen odontológico general de rutina / control preventivo", "Z01.2", "Examen odontológico", 424759004, "Evaluación odontológica periódica programada en paciente asintomático.")
]

for dx_code, name, cie_cod, cie_desc, sct_id, criteria in diagnoses_master:
    out.append(f"""INSERT INTO dentar_diagnosis (code, clinical_name, status)
VALUES ({sql_str(dx_code)}, {sql_str(name)}, 'active')
ON CONFLICT (code) DO UPDATE SET clinical_name = EXCLUDED.clinical_name;

INSERT INTO dentar_diagnosis_version (diagnosis_id, version_number, definition, clinical_criteria)
SELECT id, 1, {sql_str(name)}, {sql_str(criteria)}
FROM dentar_diagnosis WHERE code = {sql_str(dx_code)}
ON CONFLICT (diagnosis_id, version_number) DO UPDATE SET definition = EXCLUDED.definition, clinical_criteria = EXCLUDED.clinical_criteria;

INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'CIE-10', {sql_str(cie_cod)}, {sql_str(cie_desc)}, 'equivalent'
FROM dentar_diagnosis WHERE code = {sql_str(dx_code)}
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;
""")
    if sct_id:
        out.append(f"""INSERT INTO dentar_diagnosis_mapping (diagnosis_id, system_code, external_code, external_display, mapping_type)
SELECT id, 'SNOMED-CT', '{sct_id}', {sql_str(name)}, 'equivalent'
FROM dentar_diagnosis WHERE code = {sql_str(dx_code)}
ON CONFLICT (diagnosis_id, system_code, external_code) DO NOTHING;
""")

# 8. CLINICAL INDICATION MATRIX (Concept <-> Diagnosis)
out.append("\n-- =============================================================================")
out.append("-- 8. MATRIZ DE JUSTIFICACIÓN CLÍNICA DENTAR <-> DIAGNÓSTICOS CIE-10")
out.append("-- =============================================================================")

def link_concept_diag(dnt_code, dx_code, rel_type, rationale):
    return f"""INSERT INTO dentar_concept_diagnosis (concept_id, diagnosis_id, relationship_type, clinical_rationale)
SELECT c.id, d.id, {sql_str(rel_type)}, {sql_str(rationale)}
FROM dentar_concept c CROSS JOIN dentar_diagnosis d
WHERE c.code = {sql_str(dnt_code)} AND d.code = {sql_str(dx_code)}
ON CONFLICT (concept_id, diagnosis_id, relationship_type) DO UPDATE SET clinical_rationale = EXCLUDED.clinical_rationale;
"""

# Link groups of procedures to diagnoses
for idx, r in enumerate(rows, 1):
    dnt_code = f"DNT-{idx:06d}"
    ar_code = r[0].strip()

    # Consultas
    if ar_code == "01.01" or ar_code == "01.06":
        out.append(link_concept_diag(dnt_code, "DNT-DX-0038", "indicacion_habitual", "Examen estomatológico inicial y control periódico"))
    elif ar_code == "01.02" or ar_code == "01.04":
        out.append(link_concept_diag(dnt_code, "DNT-DX-0014", "indicacion_habitual", "Urgencia por dolor pulpar agudo"))
        out.append(link_concept_diag(dnt_code, "DNT-DX-0019", "indicacion_habitual", "Urgencia por flemón / absceso periapical"))
        out.append(link_concept_diag(dnt_code, "DNT-DX-0021", "indicacion_posible", "Urgencia por pericoronaritis aguda"))
    elif ar_code == "01.05":
        out.append(link_concept_diag(dnt_code, "DNT-DX-0034", "indicacion_habitual", "Interconsulta por lesiones mucosas o estomatitis"))

    # Operatoria (02.*)
    elif ar_code.startswith("02."):
        if ar_code == "02.15 F": # ferulización
            out.append(link_concept_diag(dnt_code, "DNT-DX-0024", "indicacion_habitual", "Movilidad dentaria por periodontitis severa"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0036", "indicacion_habitual", "Inmovilización post-traumatismo dental"))
        else:
            out.append(link_concept_diag(dnt_code, "DNT-DX-0006", "indicacion_habitual", "Caries dentinaria con cavitación activa"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0005", "indicacion_posible", "Caries incipiente cavitada"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0009", "indicacion_posible", "Atrición o abrasión cervical severa"))
            if ar_code == "02.09": # ángulo
                out.append(link_concept_diag(dnt_code, "DNT-DX-0035", "indicacion_habitual", "Fractura coronaria de ángulo por traumatismo"))

    # Endodoncia (03.*)
    elif ar_code.startswith("03."):
        if ar_code in ("03.01", "03.02", "03.03", "03.04"):
            out.append(link_concept_diag(dnt_code, "DNT-DX-0014", "indicacion_habitual", "Pulpitis irreversible sintomática o asintomática"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0015", "indicacion_habitual", "Necrosis pulpar con o sin lesión apical"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0016", "indicacion_habitual", "Periodontitis apical aguda de origen pulpar"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0017", "indicacion_posible", "Periodontitis apical crónica / granuloma"))
        elif ar_code == "03.05": # biopulpectomía parcial
            out.append(link_concept_diag(dnt_code, "DNT-DX-0013", "indicacion_habitual", "Exposición pulpar en pieza temporaria o foramen abierto"))
        elif ar_code == "03.06": # necropulpectomía parcial
            out.append(link_concept_diag(dnt_code, "DNT-DX-0015", "indicacion_habitual", "Necrosis parcial en diente posterior temporario"))

    # Prótesis Fija (04.01.*)
    elif ar_code.startswith("04.01"):
        out.append(link_concept_diag(dnt_code, "DNT-DX-0008", "indicacion_habitual", "Destrucción coronaria severa que no admite obturación simple"))
        out.append(link_concept_diag(dnt_code, "DNT-DX-0035", "indicacion_posible", "Fractura dental con compromiso de cúspides"))
        if "tramo" in r[1].lower():
            out.append(link_concept_diag(dnt_code, "DNT-DX-0030", "indicacion_habitual", "Desdentamiento parcial / brecha edéntula"))

    # Prótesis Removible (04.02 / 04.03 / 04.04)
    elif ar_code.startswith("04.02") or ar_code.startswith("04.03") or ar_code.startswith("04.04"):
        if "levante" in r[1].lower():
            out.append(link_concept_diag(dnt_code, "DNT-DX-0037", "indicacion_habitual", "Bruxismo severo con colapso de dimensión vertical"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0029", "indicacion_posible", "Disfunción de articulación temporomandibular"))
        else:
            out.append(link_concept_diag(dnt_code, "DNT-DX-0030", "indicacion_habitual", "Pérdida de piezas dentarias / edentulismo"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0031", "indicacion_posible", "Reborde alveolar atrófico que requiere prótesis"))

    # Preventiva (05.*)
    elif ar_code.startswith("05."):
        if ar_code == "05.01":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0011", "indicacion_habitual", "Presencia de sarro / cálculo dental y manchas extrínsecas"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0022", "indicacion_habitual", "Gingivitis marginal por placa bacteriana"))
        elif ar_code in ("05.02", "05.04", "05.05", "05.06"):
            out.append(link_concept_diag(dnt_code, "DNT-DX-0038", "contextual", "Prevención y control en pacientes con riesgo cariogénico"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0005", "indicacion_habitual", "Manchas blancas / caries incipiente"))

    # Ortodoncia (06.*)
    elif ar_code.startswith("06."):
        out.append(link_concept_diag(dnt_code, "DNT-DX-0027", "indicacion_habitual", "Apiñamiento dentario o alteraciones de posición"))
        out.append(link_concept_diag(dnt_code, "DNT-DX-0028", "indicacion_habitual", "Maloclusión Clase I/II/III o mordida abierta"))

    # Odontopediatría (07.*)
    elif ar_code.startswith("07."):
        if "mantenedor" in r[1].lower():
            out.append(link_concept_diag(dnt_code, "DNT-DX-0030", "indicacion_habitual", "Pérdida prematura de diente temporario"))
        elif "formocresol" in r[1].lower():
            out.append(link_concept_diag(dnt_code, "DNT-DX-0013", "indicacion_habitual", "Pulpitis en diente primario"))
        elif "luxaci" in r[1].lower() or "reimplante" in r[1].lower():
            out.append(link_concept_diag(dnt_code, "DNT-DX-0036", "indicacion_habitual", "Avulsión o luxación traumática en niño"))
        else:
            out.append(link_concept_diag(dnt_code, "DNT-DX-0006", "indicacion_habitual", "Caries rampante o temprana de la infancia"))

    # Periodoncia (08.*)
    elif ar_code.startswith("08."):
        if ar_code == "08.02":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0022", "indicacion_habitual", "Gingivitis marginal crónica"))
        elif ar_code == "08.03":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0023", "indicacion_habitual", "Periodontitis destructiva leve/moderada (bolsas <= 5mm)"))
        elif ar_code in ("08.04", "08.04 C"):
            out.append(link_concept_diag(dnt_code, "DNT-DX-0024", "indicacion_habitual", "Periodontitis destructiva severa (bolsas >= 6mm)"))
        elif ar_code == "08.06":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0037", "indicacion_habitual", "Bruxismo primario o secundario"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0029", "indicacion_habitual", "Trastornos de la ATM"))
        elif ar_code.startswith("08.05"):
            out.append(link_concept_diag(dnt_code, "DNT-DX-0029", "indicacion_habitual", "Desarmonía oclusal y disfunción temporomandibular"))

    # Radiología (09.*)
    elif ar_code.startswith("09."):
        if "atm" in r[1].lower():
            out.append(link_concept_diag(dnt_code, "DNT-DX-0029", "indicacion_habitual", "Estudio radiológico comparativo de articulación temporomandibular"))
        elif "cefalom" in r[1].lower():
            out.append(link_concept_diag(dnt_code, "DNT-DX-0028", "indicacion_habitual", "Estudio cefalométrico para ortodoncia"))
        else:
            out.append(link_concept_diag(dnt_code, "DNT-DX-0038", "contextual", "Examen radiográfico para diagnóstico y plan de tratamiento"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0006", "indicacion_habitual", "Detección de caries interproximal o lesión apical"))

    # Cirugía Bucal (10.*)
    elif ar_code.startswith("10."):
        if ar_code in ("10.09", "10.10", "10.11", "10.18", "10.19"):
            out.append(link_concept_diag(dnt_code, "DNT-DX-0003", "indicacion_habitual", "Diente incluido con retención ósea"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0004", "indicacion_habitual", "Diente impactado (terceros molares / caninos)"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0021", "indicacion_posible", "Pericoronaritis recurrente en molar impactado"))
        elif ar_code == "10.06":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0019", "indicacion_habitual", "Absceso odontógeno agudo intraoral"))
        elif ar_code in ("10.03", "10.07"):
            out.append(link_concept_diag(dnt_code, "DNT-DX-0034", "indicacion_habitual", "Lesión de mucosa bucal que requiere confirmación histopatológica"))
        elif ar_code == "10.05":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0036", "indicacion_habitual", "Avulsión traumática de diente"))
        elif ar_code == "10.12":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0017", "indicacion_habitual", "Fracaso endodóntico / granuloma o quiste apical"))
        elif ar_code == "10.13":
            out.append(link_concept_diag(dnt_code, "DNT-DX-0033", "indicacion_habitual", "Osteomielitis maxilar"))
        else:
            out.append(link_concept_diag(dnt_code, "DNT-DX-0008", "indicacion_habitual", "Destrucción coronaria no restaurable"))
            out.append(link_concept_diag(dnt_code, "DNT-DX-0032", "indicacion_habitual", "Resto radicular retenido sintomático"))

    # Implantes (11.*)
    elif ar_code.startswith("11."):
        out.append(link_concept_diag(dnt_code, "DNT-DX-0030", "indicacion_habitual", "Edentulismo parcial o total que requiere rehabilitación fija"))
        out.append(link_concept_diag(dnt_code, "DNT-DX-0031", "indicacion_posible", "Reborde alveolar con defecto que requiere regeneración ósea"))

# 9. VISTAS DE INTEROPERABILIDAD
out.append("\n-- =============================================================================")
out.append("-- 9. VISTA DE CONSULTA E INTEROPERABILIDAD CLÍNICA")
out.append("-- =============================================================================")
out.append("""CREATE OR REPLACE VIEW v_dentar_procedimiento_diagnostico AS
SELECT
    c.code                       AS dentar_code,
    t.term                       AS prestacion_nombre,
    m_ar.external_code           AS codigo_nomenclador_ar,
    m_cdt.external_code          AS codigo_cdt,
    m_sct_proc.external_code     AS snomed_ct_practica,
    cat.name                     AS categoria,
    d.code                       AS codigo_diagnostico_dentar,
    d.clinical_name              AS diagnostico_nombre,
    m_cie.external_code          AS cie10_codigo,
    m_cie.external_display       AS cie10_descripcion,
    m_sct.external_code          AS snomed_ct_codigo,
    cd.relationship_type         AS tipo_relacion,
    cd.clinical_rationale        AS justificacion_clinica
FROM dentar_concept c
JOIN dentar_concept_version cv ON cv.concept_id = c.id
JOIN dentar_term t ON t.concept_version_id = cv.id AND t.term_type = 'preferred' AND t.language = 'es-AR'
LEFT JOIN dentar_concept_category cc ON cc.concept_version_id = cv.id AND cc.is_primary = TRUE
LEFT JOIN dentar_category_version cat ON cat.category_id = cc.category_id AND cat.language = 'es-AR'
LEFT JOIN dentar_concept_mapping m_ar ON m_ar.concept_version_id = cv.id AND m_ar.system_code = 'NOMENCLADOR-AR'
LEFT JOIN dentar_concept_mapping m_cdt ON m_cdt.concept_version_id = cv.id AND m_cdt.system_code = 'CDT-2025'
LEFT JOIN dentar_concept_mapping m_sct_proc ON m_sct_proc.concept_version_id = cv.id AND m_sct_proc.system_code = 'SNOMED-CT'
LEFT JOIN dentar_concept_diagnosis cd ON cd.concept_id = c.id
LEFT JOIN dentar_diagnosis d ON d.id = cd.diagnosis_id
LEFT JOIN dentar_diagnosis_mapping m_cie ON m_cie.diagnosis_id = d.id AND m_cie.system_code = 'CIE-10'
LEFT JOIN dentar_diagnosis_mapping m_sct ON m_sct.diagnosis_id = d.id AND m_sct.system_code = 'SNOMED-CT'
ORDER BY c.code, cd.relationship_type;

COMMENT ON VIEW v_dentar_procedimiento_diagnostico IS
'Matriz clínica completa de interoperabilidad: DENTAR + Nomenclador Argentino + ADA CDT 2025 + CIE-10 + SNOMED CT.';
""")

# Final analyze
out.append("""
ANALYZE dentar_release;
ANALYZE dentar_category;
ANALYZE dentar_category_version;
ANALYZE dentar_concept;
ANALYZE dentar_concept_version;
ANALYZE dentar_term;
ANALYZE dentar_concept_category;
ANALYZE dentar_unit;
ANALYZE dentar_attribute_definition;
ANALYZE dentar_concept_attribute_rule;
ANALYZE dentar_terminology_system;
ANALYZE dentar_concept_mapping;
ANALYZE dentar_diagnosis;
ANALYZE dentar_diagnosis_version;
ANALYZE dentar_diagnosis_mapping;
ANALYZE dentar_concept_diagnosis;

SELECT 'dentar_release' AS tabla, count(*) AS filas FROM dentar_release
UNION ALL SELECT 'dentar_category', count(*) FROM dentar_category
UNION ALL SELECT 'dentar_concept', count(*) FROM dentar_concept
UNION ALL SELECT 'dentar_term', count(*) FROM dentar_term
UNION ALL SELECT 'dentar_concept_mapping', count(*) FROM dentar_concept_mapping
UNION ALL SELECT 'dentar_concept_attribute_rule', count(*) FROM dentar_concept_attribute_rule
UNION ALL SELECT 'dentar_diagnosis', count(*) FROM dentar_diagnosis
UNION ALL SELECT 'dentar_diagnosis_mapping', count(*) FROM dentar_diagnosis_mapping
UNION ALL SELECT 'dentar_concept_diagnosis', count(*) FROM dentar_concept_diagnosis;
""")

full_sql = "\n".join(out)
output_path = os.path.join(os.path.dirname(__file__), "..", "sql", "dentar_core_and_diagnosis.sql")
with open(output_path, "w", encoding="utf-8") as f:
    f.write(full_sql)

print(f"Generated {output_path} successfully ({len(full_sql)} bytes).")
