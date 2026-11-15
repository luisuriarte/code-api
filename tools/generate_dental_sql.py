# -*- coding: utf-8 -*-
"""
Generador del catálogo odontológico interoperable:
Nomenclador Odontológico Argentino + ADA CDT 2025 + SNOMED CT
Genera el archivo: sql/Argentina_dental_cdt_codes_2025.sql (PostgreSQL 18)
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

rows = load_odontologico_rows()

# 12 Categorías Oficiales CDT adaptadas a Argentina
categories = [
    ("DIAGNOSTIC", "D0100-D0999", "Diagnostic", "Diagnóstico y Exámenes Clínicos", "Evaluaciones clínicas orales, exámenes diagnósticos, imágenes radiográficas e interconsultas diagnósticas."),
    ("PREVENTIVE", "D1000-D1999", "Preventive", "Odontología Preventiva", "Higiene bucal, profilaxis dental, aplicaciones tópicas de flúor, selladores de fisuras y mantenedores de espacio."),
    ("RESTORATIVE", "D2000-D2999", "Restorative", "Operatoria Dental y Restauradora", "Restauraciones con amalgama, resinas compuestas/fotocurado, incrustaciones inlay/onlay y reconstrucción de muñón."),
    ("ENDODONTICS", "D3000-D3999", "Endodontics", "Endodoncia", "Tratamientos pulpares, biopulpectomías, terapia de conductos radiculares anteriores/premolares/molares y cirugías periapicales."),
    ("PERIODONTICS", "D4000-D4999", "Periodontics", "Periodoncia", "Tratamiento de gingivitis, raspado y alisado radicular, cirugías periodontales, gingivectomías y mantenimiento periodontal."),
    ("PROSTHODONTICS_REMOVABLE", "D5000-D5899", "Prosthodontics, removable", "Prótesis Parcial y Completa Removible", "Prótesis completas superiores e inferiores, parciales en acrílico o cromo-cobalto, prótesis inmediatas y composturas."),
    ("MAXILLOFACIAL_PROSTHETICS", "D5900-D5999", "Maxillofacial prosthetics", "Prótesis Maxilofacial", "Prótesis faciales, nasales, auriculares, obturadores palatinos y guías quirúrgicas complejas."),
    ("IMPLANT_SERVICES", "D6000-D6199", "Implant services", "Implantología Odontológica", "Colocación quirúrgica de implantes intraóseos, pilares protésicos, injertos óseos y coronas sobre implante."),
    ("PROSTHODONTICS_FIXED", "D6200-D6999", "Prosthodontics, fixed", "Prótesis Fija", "Coronas forjadas, coladas, con frente estético, de porcelana pura o sobre metal, pernos muñón y tramos de puente."),
    ("ORAL_MAXILLOFACIAL_SURGERY", "D7000-D7999", "Oral & maxillofacial surgery", "Cirugía Bucal y Maxilofacial", "Extracciones simples y quirúrgicas de dientes erupcionados o retenidos, germectomías, apicectomías, frenectomías, biopsias y drenaje de abscesos."),
    ("ORTHODONTICS", "D8000-D8999", "Orthodontics", "Ortodoncia y Ortopedia Funcional", "Estudios de ortodoncia, tratamientos de dentición primaria/mixta/permanente y aparatos de corrección de malposiciones."),
    ("ADJUNCTIVE_GENERAL_SERVICES", "D9000-D9999", "Adjunctive general services", "Servicios Complementarios de Odontología", "Consultas de urgencia, visitas domiciliarias, sedación, placas de estabilización oclusal (bruxismo/ATM), desensibilizaciones y peritajes.")
]

# Catálogo núcleo de códigos CDT 2025
cdt_catalog = [
    # DIAGNOSTIC
    ("D0120", "DIAGNOSTIC", "Periodic oral evaluation - established patient", "Evaluación oral periódica - paciente establecido", 399120002),
    ("D0140", "DIAGNOSTIC", "Limited oral evaluation - problem focused", "Evaluación oral limitada - focalizada en problema", 399120002),
    ("D0145", "DIAGNOSTIC", "Oral evaluation for a patient under three years of age", "Evaluación oral para paciente pediátrico / motivación", 399120002),
    ("D0150", "DIAGNOSTIC", "Comprehensive oral evaluation - new or established patient", "Examen diagnóstico completo, fichado y plan de tratamiento", 424759004),
    ("D0160", "DIAGNOSTIC", "Detailed and extensive oral evaluation - problem focused", "Consulta de estomatología / evaluación oral detallada para especialistas", 386053000),
    ("D0180", "DIAGNOSTIC", "Comprehensive periodontal evaluation - new or established patient", "Evaluación y examen periodontal integral con periodontograma", 424759004),
    ("D0210", "DIAGNOSTIC", "Intraoral - comprehensive series of radiographic images", "Serie radiográfica intraoral completa / seriada periapical", 399195000),
    ("D0220", "DIAGNOSTIC", "Intraoral - periapical first radiographic image", "Radiografía intraoral periapical primera exposición", 399195000),
    ("D0230", "DIAGNOSTIC", "Intraoral - periapical each additional radiographic image", "Radiografía intraoral periapical cada exposición adicional", 399195000),
    ("D0240", "DIAGNOSTIC", "Intraoral - occlusal radiographic image", "Radiografía intraoral oclusal (6x8 cm)", 399195000),
    ("D0250", "DIAGNOSTIC", "Extra-oral - 2D projection radiographic image", "Radiografía extraoral - primera exposición", 399195000),
    ("D0272", "DIAGNOSTIC", "Bitewings - two radiographic images", "Radiografía coronal / Bite-Wing (2 películas)", 399195000),
    ("D0310", "DIAGNOSTIC", "Sialography", "Sialografía de glándulas salivales", 399195000),
    ("D0320", "DIAGNOSTIC", "Temporomandibular joint arthrogram", "Radiografía comparativa de articulación temporomandibular (ATM)", 399195000),
    ("D0330", "DIAGNOSTIC", "Panoramic radiographic image", "Radiografía panorámica / pantomografía maxilofacial", 399195000),
    ("D0340", "DIAGNOSTIC", "2D cephalometric radiographic image", "Telerradiografía cefalométrica / trazado cefalométrico", 399195000),
    ("D0425", "DIAGNOSTIC", "Caries susceptibility tests", "Test de susceptibilidad de caries y placa bacteriana", None),

    # PREVENTIVE
    ("D1110", "PREVENTIVE", "Prophylaxis - adult", "Tartrectomía, raspado y cepillado mecánico en adultos", 22769002),
    ("D1120", "PREVENTIVE", "Prophylaxis - child", "Profilaxis y limpieza dental en niños", 22769002),
    ("D1206", "PREVENTIVE", "Topical application of fluoride varnish", "Aplicación tópica de barniz de flúor", 110462007),
    ("D1208", "PREVENTIVE", "Topical application of fluoride - excluding varnish", "Aplicación de flúor tópico (gel/colutorios)", 110462007),
    ("D1330", "PREVENTIVE", "Oral hygiene instructions", "Enseñanza de técnicas de higiene bucal y control de placa", 399047006),
    ("D1351", "PREVENTIVE", "Sealant - per tooth", "Sellador de puntos y fisuras por pieza dentaria", 234735005),
    ("D1354", "PREVENTIVE", "Interim caries arresting medicament application - per tooth", "Aplicación de cariostáticos / detención no invasiva de caries", 713601007),
    ("D1510", "PREVENTIVE", "Space maintainer - fixed, unilateral - per quadrant", "Mantenedor de espacio fijo unilateral", 274437007),
    ("D1520", "PREVENTIVE", "Space maintainer - removable, unilateral", "Mantenedor de espacio removible", 274437007),

    # RESTORATIVE
    ("D2140", "RESTORATIVE", "Amalgam - one surface, primary or permanent", "Obturación con amalgama: cavidad simple (1 cara)", 80891009),
    ("D2150", "RESTORATIVE", "Amalgam - two surfaces, primary or permanent", "Obturación con amalgama: cavidad compuesta (2 caras)", 80891009),
    ("D2160", "RESTORATIVE", "Amalgam - three surfaces, primary or permanent", "Obturación con amalgama: cavidad compleja (3 caras)", 80891009),
    ("D2161", "RESTORATIVE", "Amalgam - four or more surfaces, primary or permanent", "Obturación con amalgama: reconstrucción compleja con anclaje", 80891009),
    ("D2330", "RESTORATIVE", "Resin-based composite - one surface, anterior", "Obturación estética / composite simple en sector anterior (1 cara)", 111164008),
    ("D2331", "RESTORATIVE", "Resin-based composite - two surfaces, anterior", "Obturación estética / composite compuesto en sector anterior (2 caras)", 111164008),
    ("D2332", "RESTORATIVE", "Resin-based composite - three surfaces, anterior", "Obturación estética / composite complejo en sector anterior (3 caras)", 111164008),
    ("D2335", "RESTORATIVE", "Resin-based composite crown, anterior (involving incisal angle)", "Reconstrucción de ángulo incisal en dientes anteriores con composite", 111164008),
    ("D2391", "RESTORATIVE", "Resin-based composite - one surface, posterior", "Obturación con resina fotocurado en sector posterior (1 cara)", 111164008),
    ("D2392", "RESTORATIVE", "Resin-based composite - two surfaces, posterior", "Obturación con resina fotocurado en sector posterior (2 caras)", 111164008),
    ("D2393", "RESTORATIVE", "Resin-based composite - three surfaces, posterior", "Obturación con resina fotocurado en sector posterior (3 caras)", 111164008),
    ("D2394", "RESTORATIVE", "Resin-based composite - four or more surfaces, posterior", "Obturación con resina fotocurado en sector posterior (4 o más caras)", 111164008),
    ("D2610", "RESTORATIVE", "Inlay - porcelain/ceramic - one surface", "Incrustación de porcelana/cerámica: cavidad simple", 111163002),
    ("D2620", "RESTORATIVE", "Inlay - porcelain/ceramic - two surfaces", "Incrustación de porcelana/cerámica: cavidad compuesta", 111163002),
    ("D2630", "RESTORATIVE", "Inlay - porcelain/ceramic - three or more surfaces", "Incrustación de porcelana/cerámica: cavidad compleja", 111163002),
    ("D2710", "RESTORATIVE", "Crown - resin-based composite (indirect)", "Corona de acrílico o resina compuesta", 36830009),
    ("D2740", "RESTORATIVE", "Crown - porcelain/ceramic", "Corona colada revestida en porcelana pura", 36830009),
    ("D2751", "RESTORATIVE", "Crown - porcelain fused to predominantly base metal", "Corona colada con frente estético en acrílico o metal-cerámica", 36830009),
    ("D2752", "RESTORATIVE", "Crown - noble metal with porcelain/resin", "Corona colada revestida en acrílico / metal noble", 36830009),
    ("D2790", "RESTORATIVE", "Crown - full cast predominantly base metal", "Corona colada totalmente metálica", 36830009),
    ("D2799", "RESTORATIVE", "Provisional crown - further treatment or completion of diagnosis necessary prior to final impression", "Corona provisoria de acrílico", 36830009),
    ("D2930", "RESTORATIVE", "Prefabricated stainless steel crown - primary tooth", "Corona de acero inoxidable preformada en diente temporario", 36830009),
    ("D2951", "RESTORATIVE", "Pin retention - per tooth, in addition to restoration", "Reconstrucción con tornillo / perno en conducto", 111164008),
    ("D2952", "RESTORATIVE", "Post and core in addition to crown, indirectly fabricated", "Perno muñón colado simple o seccionado", 234736006),
    ("D2970", "RESTORATIVE", "Temporary crown (fractured tooth)", "Carilla provisoria / corona temporal por traumatismo", 111164008),

    # ENDODONTICS
    ("D3110", "ENDODONTICS", "Pulp cap - direct (excluding final restoration)", "Protección pulpar directa", 234737002),
    ("D3220", "ENDODONTICS", "Therapeutic pulpotomy (excluding final restoration)", "Biopulpectomía parcial / pulpotomía con formocresol", 234737002),
    ("D3221", "ENDODONTICS", "Pulpal debridement, primary and permanent teeth", "Necropulpectomía parcial / momificación / debridamiento pulpar", 234737002),
    ("D3310", "ENDODONTICS", "Endodontic therapy, anterior tooth (excluding final restoration)", "Tratamiento de conducto en diente anterior (un conducto)", 68673005),
    ("D3320", "ENDODONTICS", "Endodontic therapy, premolar tooth (excluding final restoration)", "Tratamiento de conductos en diente premolar (dos conductos)", 68673005),
    ("D3330", "ENDODONTICS", "Endodontic therapy, molar tooth (excluding final restoration)", "Tratamiento de conductos en molar (tres o cuatro conductos)", 68673005),
    ("D3410", "ENDODONTICS", "Apicoectomy - anterior", "Apicectomía con o sin obturación retrógrada", 234737002),
    ("D3920", "ENDODONTICS", "Hemisection (including any root removal), not including root canal therapy", "Radectomía / hemisección radicular", 234737002),

    # PERIODONTICS
    ("D4210", "PERIODONTICS", "Gingivectomy or gingivoplasty - four or more contiguous teeth", "Gingivectomía o gingivoplastia / cirugía periodontal", 234740008),
    ("D4249", "PERIODONTICS", "Clinical crown lengthening - hard tissue", "Alargamiento quirúrgico de la corona clínica", 234740008),
    ("D4260", "PERIODONTICS", "Osseous surgery (including elevation of a full thickness flap and scaling)", "Tratamiento quirúrgico de periodontitis destructiva severa (bolsas 6mm+)", 234740008),
    ("D4322", "PERIODONTICS", "Splint - intra-coronal; natural teeth or in conjunction with prostheses", "Ferulización intracoronal por causas periodontales", 274438002),
    ("D4323", "PERIODONTICS", "Splint - extra-coronal; natural teeth or in conjunction with prostheses", "Ferulización extracoronal por causas periodontales", 274438002),
    ("D4341", "PERIODONTICS", "Periodontal scaling and root planing - four or more teeth per quadrant", "Tratamiento de periodontitis destructiva leve/moderada (bolsas hasta 5mm)", 110463002),
    ("D4346", "PERIODONTICS", "Scaling in presence of generalized moderate or severe gingival inflammation", "Tratamiento de gingivitis marginal crónica", 110463002),
    ("D4910", "PERIODONTICS", "Periodontal maintenance", "Mantenimiento periódico post-tratamiento periodontal", 110463002),

    # PROSTHODONTICS_REMOVABLE
    ("D5110", "PROSTHODONTICS_REMOVABLE", "Complete denture - maxillary", "Prótesis completa superior en acrílico", 274440007),
    ("D5120", "PROSTHODONTICS_REMOVABLE", "Complete denture - mandibular", "Prótesis completa inferior en acrílico", 274440007),
    ("D5130", "PROSTHODONTICS_REMOVABLE", "Immediate denture - maxillary", "Prótesis completa inmediata superior (temporaria)", 274440007),
    ("D5140", "PROSTHODONTICS_REMOVABLE", "Immediate denture - mandibular", "Prótesis completa inmediata inferior (temporaria)", 274440007),
    ("D5211", "PROSTHODONTICS_REMOVABLE", "Maxillary partial denture - resin base", "Prótesis parcial removible de acrílico superior", 274440007),
    ("D5212", "PROSTHODONTICS_REMOVABLE", "Mandibular partial denture - resin base", "Prótesis parcial removible de acrílico inferior", 274440007),
    ("D5213", "PROSTHODONTICS_REMOVABLE", "Maxillary partial denture - cast metal framework with resin denture bases", "Prótesis parcial removible de cromo cobalto superior", 274440007),
    ("D5214", "PROSTHODONTICS_REMOVABLE", "Mandibular partial denture - cast metal framework with resin denture bases", "Prótesis parcial removible de cromo cobalto inferior", 274440007),
    ("D5221", "PROSTHODONTICS_REMOVABLE", "Immediate maxillary partial denture - resin base", "Prótesis parcial inmediata temporaria", 274440007),
    ("D5611", "PROSTHODONTICS_REMOVABLE", "Repair acrylic denture base, mandibular", "Compostura simple de base acrílica", 274440007),
    ("D5621", "PROSTHODONTICS_REMOVABLE", "Repair cast partial framework, mandibular", "Soldado de retención en aparatos de cromo cobalto", 274440007),
    ("D5630", "PROSTHODONTICS_REMOVABLE", "Repair or replace broken retentive clasping materials - per tooth", "Compostura con agregado o reparación de retenedor", 274440007),
    ("D5640", "PROSTHODONTICS_REMOVABLE", "Replace broken teeth - per tooth", "Compostura con agregado de diente artificial", 274440007),
    ("D5750", "PROSTHODONTICS_REMOVABLE", "Reline complete maxillary denture (laboratory)", "Rebasado de prótesis completa", 274440007),
    ("D5751", "PROSTHODONTICS_REMOVABLE", "Reline complete mandibular denture (laboratory)", "Rebasado de prótesis parcial", 274440007),
    ("D5862", "PROSTHODONTICS_REMOVABLE", "Precision attachment, each", "Ataches de precisión o barra tangencial tipo Dolder", 274439005),
    ("D5867", "PROSTHODONTICS_REMOVABLE", "Replacement of replaceable part of semi-precision or precision attachment", "Poste bola o repuesto de anclaje de precisión", 274439005),
    ("D5899", "PROSTHODONTICS_REMOVABLE", "Unspecified removable prosthodontic procedure, by report", "Cubeta individual para toma de impresiones", None),

    # PROSTHODONTICS_FIXED
    ("D6240", "PROSTHODONTICS_FIXED", "Pontic - porcelain/ceramic", "Tramo de puente colado revestido en porcelana", 274439005),
    ("D6241", "PROSTHODONTICS_FIXED", "Pontic - porcelain fused to predominantly base metal", "Tramo de puente colado metálico / acrílico", 274439005),

    # IMPLANT_SERVICES
    ("D6010", "IMPLANT_SERVICES", "Surgical placement of implant body: endosteal implant", "Colocación quirúrgica de implante dentario intraóseo", 234745003),
    ("D6053", "IMPLANT_SERVICES", "Implant/abutment supported removable denture for completely edentulous arch", "Prótesis completa o parcial removible sobre implantes", 234745003),
    ("D6056", "IMPLANT_SERVICES", "Prefabricated abutment - includes modification and placement", "Emergente o intermediario sobre implantes dentales", 234745003),
    ("D6058", "IMPLANT_SERVICES", "Abutment supported porcelain/ceramic crown", "Corona de porcelana/cerámica sobre implante", 36830009),
    ("D6085", "IMPLANT_SERVICES", "Provisional implant crown", "Corona provisoria sobre implante dentario", 36830009),
    ("D6104", "IMPLANT_SERVICES", "Bone graft at time of implant placement", "Relleno óseo / injerto óseo en sitio de implante", 234745003),

    # ORAL_MAXILLOFACIAL_SURGERY
    ("D7140", "ORAL_MAXILLOFACIAL_SURGERY", "Extraction, erupted tooth or exposed root", "Extracción dentaria simple de pieza erupcionada o raíz", 234744004),
    ("D7210", "ORAL_MAXILLOFACIAL_SURGERY", "Extraction, erupted tooth requiring removal of bone and/or sectioning of tooth", "Extracción dentaria con alveolectomía externa / remoción ósea", 234744004),
    ("D7240", "ORAL_MAXILLOFACIAL_SURGERY", "Removal of impacted tooth - completely bony", "Extracción de diente en retención ósea completa", 234744004),
    ("D7251", "ORAL_MAXILLOFACIAL_SURGERY", "Coronectomy - intentional partial tooth removal", "Germectomía / coronectomía intencional", 234744004),
    ("D7260", "ORAL_MAXILLOFACIAL_SURGERY", "Oral antral fistula closure", "Plástica de comunicación buco-sinusal", 234744004),
    ("D7270", "ORAL_MAXILLOFACIAL_SURGERY", "Tooth reimplantation and/or stabilization of accidentally evulsed or displaced tooth", "Reimplante dentario inmediato al traumatismo y fijación", 234744004),
    ("D7280", "ORAL_MAXILLOFACIAL_SURGERY", "Exposure of an unerupted tooth", "Liberación quirúrgica de diente retenido para tracción", 234744004),
    ("D7285", "ORAL_MAXILLOFACIAL_SURGERY", "Incisional biopsy of oral tissue - hard (bone, tooth)", "Biopsia de tejido duro (óseo o dentario) por punción/aspiración", 234744004),
    ("D7286", "ORAL_MAXILLOFACIAL_SURGERY", "Incisional biopsy of oral tissue - soft", "Biopsia por escisión de tejido blando bucal", 234744004),
    ("D7310", "ORAL_MAXILLOFACIAL_SURGERY", "Alveoloplasty in conjunction with extractions - four or more teeth or tooth spaces, per quadrant", "Alveolectomía estabilizadora o correctiva por zona", 234744004),
    ("D7440", "ORAL_MAXILLOFACIAL_SURGERY", "Excision of malignant tumor - lesion diameter greater than 1.25 cm", "Tratamiento quirúrgico de osteomielitis maxilar", 234744004),
    ("D7510", "ORAL_MAXILLOFACIAL_SURGERY", "Incision and drainage of abscess - intraoral soft tissue", "Incisión y drenaje de abscesos por vía intrabucal", 234744004),
    ("D7530", "ORAL_MAXILLOFACIAL_SURGERY", "Removal of foreign body from mucosa, skin, or subcutaneous alveolar tissue", "Extracción de cuerpo extraño en cavidad bucal", 234744004),
    ("D7880", "ORAL_MAXILLOFACIAL_SURGERY", "Occlusal orthotic device, by report", "Aparato de estabilización oclusal / terapia de ATM", 274441006),
    ("D7910", "ORAL_MAXILLOFACIAL_SURGERY", "Dentofacial simple suture of recent wounds up to 5 cm", "Sutura de encías como tratamiento de lesión traumática", 234744004),
    ("D7961", "ORAL_MAXILLOFACIAL_SURGERY", "Buccal / labial frenectomy (frenulectomy)", "Frenectomía labial o lingual", 234744004),

    # ORTHODONTICS
    ("D8020", "ORTHODONTICS", "Interceptive orthodontic treatment of the transitional dentition", "Tratamiento de ortodoncia interceptiva en dentición primaria o mixta", 401267008),
    ("D8050", "ORTHODONTICS", "Interceptive orthodontic treatment of the adolescent dentition", "Corrección de malposiciones simples con espacio", 401267008),
    ("D8070", "ORTHODONTICS", "Comprehensive orthodontic treatment of the transitional dentition", "Tratamiento de ortodoncia en dentición mixta / hemi-arcada", 401267008),
    ("D8080", "ORTHODONTICS", "Comprehensive orthodontic treatment of the adolescent dentition", "Tratamiento integral de ortodoncia de dentición permanente", 401267008),
    ("D8660", "ORTHODONTICS", "Pre-orthodontic treatment examination to monitor growth and development", "Consulta de estudio y diagnóstico para ortodoncia", 401267008),

    # ADJUNCTIVE_GENERAL_SERVICES
    ("D9110", "ADJUNCTIVE_GENERAL_SERVICES", "Palliative treatment of dental pain - minor procedure", "Consultas de urgencia / tratamiento paliativo del dolor", 275932009),
    ("D9410", "ADJUNCTIVE_GENERAL_SERVICES", "House/extended care facility call", "Visita odontológica a domicilio / fuera de radio urbano", 308335008),
    ("D9440", "ADJUNCTIVE_GENERAL_SERVICES", "Office visit - after regularly scheduled hours", "Consulta nocturna, domingos y feriados (urgencias)", 185347001),
    ("D9944", "ADJUNCTIVE_GENERAL_SERVICES", "Occlusal guard - hard appliance, full arch", "Placa oclusal rígida para bruxismo / levante de articulación", 274441006),
    ("D9951", "ADJUNCTIVE_GENERAL_SERVICES", "Occlusal adjustment - limited", "Desgaste selectivo o armonización oclusal", 274441006),
    ("D9999", "ADJUNCTIVE_GENERAL_SERVICES", "Unspecified adjunctive procedure, by report", "Procedimiento odontológico complementario no clasificado", 275932009),
]

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

def sql_str(s):
    if s is None:
        return "NULL"
    return "E'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "\\r") + "'"

def sql_bool(v):
    return "TRUE" if v == "1" else "FALSE"

out = []
out.append("-- =============================================================================")
out.append("-- Origen Salud · Terminología Dental Interoperable")
out.append("-- Argentina_dental_cdt_codes_2025.sql :: Nomenclador Argentino + CDT 2025 + SNOMED CT")
out.append("-- =============================================================================")
out.append("--")
out.append("-- CONTENIDO:")
out.append("--   1. odontologia_cdt_categorias: 12 Categorías Oficiales ADA CDT adaptadas a Argentina.")
out.append("--   2. odontologia_cdt_catalogo: Catálogo CDT 2025 en inglés y español.")
out.append("--   3. odontologia_nomenclador: 138 prestaciones oficiales del Nomenclador Odontológico")
out.append("--      Argentino (Capítulos I a XI) con sus reglas de auditoría clínica:")
out.append("--      requiere_pieza, face_specification (caras), requiere_rx_pre, requiere_rx_post,")
out.append("--      ficha_odontologica, ficha_periodontal, material, maxilar y normas particulares.")
out.append("--   4. odontologia_mapeo_argentina_cdt: Mapeo cruzado (cross-walk) Nomenclador <-> CDT.")
out.append("--   5. odontologia_prestaciones: Tabla unificada con índices pg_trgm para el endpoint")
out.append("--      REST /v1/search/odontologia de la API.")
out.append("--")
out.append("-- COMPATIBILIDAD: PostgreSQL 18")
out.append("-- EJECUCIÓN: psql -d origen_salud -f sql/Argentina_dental_cdt_codes_2025.sql")
out.append("-- =============================================================================\n")

out.append("SET client_encoding = 'UTF8';")
out.append("SET statement_timeout = 0;")
out.append("CREATE EXTENSION IF NOT EXISTS pg_trgm;\n")

# 1. Categories
out.append("-- =============================================================================")
out.append("-- 1. CATEGORÍAS CDT (AMERICAN DENTAL ASSOCIATION) ADAPTADAS A ARGENTINA")
out.append("-- =============================================================================")
out.append("CREATE TABLE IF NOT EXISTS odontologia_cdt_categorias (")
out.append("    codigo VARCHAR(50) PRIMARY KEY,")
out.append("    rango_cdt VARCHAR(20) NOT NULL,")
out.append("    nombre_en VARCHAR(100) NOT NULL,")
out.append("    nombre_es VARCHAR(150) NOT NULL,")
out.append("    descripcion TEXT")
out.append(");\n")

for cat in categories:
    out.append(f"INSERT INTO odontologia_cdt_categorias (codigo, rango_cdt, nombre_en, nombre_es, descripcion)")
    out.append(f"VALUES ({sql_str(cat[0])}, {sql_str(cat[1])}, {sql_str(cat[2])}, {sql_str(cat[3])}, {sql_str(cat[4])})")
    out.append(f"ON CONFLICT (codigo) DO UPDATE SET")
    out.append(f"    rango_cdt = EXCLUDED.rango_cdt,")
    out.append(f"    nombre_en = EXCLUDED.nombre_en,")
    out.append(f"    nombre_es = EXCLUDED.nombre_es,")
    out.append(f"    descripcion = EXCLUDED.descripcion;\n")

# 2. CDT Catalog
out.append("\n-- =============================================================================")
out.append("-- 2. CATÁLOGO CDT 2025 (CÓDIGOS BUCALES ESTÁNDAR INTERNACIONALES)")
out.append("-- =============================================================================")
out.append("CREATE TABLE IF NOT EXISTS odontologia_cdt_catalogo (")
out.append("    codigo_cdt VARCHAR(10) PRIMARY KEY,")
out.append("    categoria_codigo VARCHAR(50) NOT NULL REFERENCES odontologia_cdt_categorias(codigo),")
out.append("    descripcion_en TEXT NOT NULL,")
out.append("    descripcion_es TEXT NOT NULL,")
out.append("    snomed_concept_id BIGINT")
out.append(");\n")

for cdt in cdt_catalog:
    snomed_val = str(cdt[4]) if cdt[4] else "NULL"
    out.append(f"INSERT INTO odontologia_cdt_catalogo (codigo_cdt, categoria_codigo, descripcion_en, descripcion_es, snomed_concept_id)")
    out.append(f"VALUES ({sql_str(cdt[0])}, {sql_str(cdt[1])}, {sql_str(cdt[2])}, {sql_str(cdt[3])}, {snomed_val})")
    out.append(f"ON CONFLICT (codigo_cdt) DO UPDATE SET")
    out.append(f"    categoria_codigo = EXCLUDED.categoria_codigo,")
    out.append(f"    descripcion_en = EXCLUDED.descripcion_en,")
    out.append(f"    descripcion_es = EXCLUDED.descripcion_es,")
    out.append(f"    snomed_concept_id = EXCLUDED.snomed_concept_id;\n")

# 3. Nomenclador Argentino (Maestro completo)
out.append("\n-- =============================================================================")
out.append("-- 3. NOMENCLADOR ODONTOLÓGICO ARGENTINO (138 PRESTACIONES CON AUDITORÍA)")
out.append("-- =============================================================================")
out.append("CREATE TABLE IF NOT EXISTS odontologia_nomenclador (")
out.append("    codigo VARCHAR(30) PRIMARY KEY,")
out.append("    descripcion TEXT NOT NULL,")
out.append("    capitulo VARCHAR(150) NOT NULL,")
out.append("    facturable BOOLEAN DEFAULT TRUE,")
out.append("    requiere_pieza BOOLEAN DEFAULT FALSE,")
out.append("    requiere_caras BOOLEAN DEFAULT FALSE,")
out.append("    requiere_rx_pre BOOLEAN DEFAULT FALSE,")
out.append("    requiere_rx_post BOOLEAN DEFAULT FALSE,")
out.append("    ficha_odontologica BOOLEAN DEFAULT FALSE,")
out.append("    ficha_periodontal BOOLEAN DEFAULT FALSE,")
out.append("    material VARCHAR(100),")
out.append("    maxilar VARCHAR(50),")
out.append("    norma_particular TEXT,")
out.append("    cdt_code_default VARCHAR(10) REFERENCES odontologia_cdt_catalogo(codigo_cdt),")
out.append("    snomed_concept_id BIGINT")
out.append(");\n")

for r in rows:
    code = r[0].strip()
    desc = r[1].strip()
    cap = r[11].strip() if r[11] else "General"
    if cap.startswith("C\u00e1pitulo"):
        cap = cap.replace("C\u00e1pitulo", "Cap\u00edtulo")
    fact = sql_bool(r[2])
    f_odo = sql_bool(r[3])
    f_per = sql_bool(r[4])
    pieza = sql_bool(r[5])
    caras = sql_bool(r[6])
    rx_pre = sql_bool(r[7])
    rx_post = sql_bool(r[8])
    mat = sql_str(r[9]) if r[9] else "NULL"
    maxil = sql_str(r[10]) if r[10] else "NULL"
    norma = sql_str(r[12]) if r[12] else "NULL"

    cat, cat_es, cdt, sct, rel = map_row(r)
    sct_val = str(sct) if sct else "NULL"

    out.append(f"INSERT INTO odontologia_nomenclador (codigo, descripcion, capitulo, facturable, requiere_pieza, requiere_caras, requiere_rx_pre, requiere_rx_post, ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, cdt_code_default, snomed_concept_id)")
    out.append(f"VALUES ({sql_str(code)}, {sql_str(desc)}, {sql_str(cap)}, {fact}, {pieza}, {caras}, {rx_pre}, {rx_post}, {f_odo}, {f_per}, {mat}, {maxil}, {norma}, {sql_str(cdt)}, {sct_val})")
    out.append(f"ON CONFLICT (codigo) DO UPDATE SET")
    out.append(f"    descripcion = EXCLUDED.descripcion,")
    out.append(f"    capitulo = EXCLUDED.capitulo,")
    out.append(f"    facturable = EXCLUDED.facturable,")
    out.append(f"    requiere_pieza = EXCLUDED.requiere_pieza,")
    out.append(f"    requiere_caras = EXCLUDED.requiere_caras,")
    out.append(f"    requiere_rx_pre = EXCLUDED.requiere_rx_pre,")
    out.append(f"    requiere_rx_post = EXCLUDED.requiere_rx_post,")
    out.append(f"    ficha_odontologica = EXCLUDED.ficha_odontologica,")
    out.append(f"    ficha_periodontal = EXCLUDED.ficha_periodontal,")
    out.append(f"    material = EXCLUDED.material,")
    out.append(f"    maxilar = EXCLUDED.maxilar,")
    out.append(f"    norma_particular = EXCLUDED.norma_particular,")
    out.append(f"    cdt_code_default = EXCLUDED.cdt_code_default,")
    out.append(f"    snomed_concept_id = EXCLUDED.snomed_concept_id;\n")

# 4. Crosswalk mapping
out.append("\n-- =============================================================================")
out.append("-- 4. MAPEO CRUZADO (CROSSWALK) NOMENCLADOR ARGENTINO <-> CDT 2025")
out.append("-- =============================================================================")
out.append("CREATE TABLE IF NOT EXISTS odontologia_mapeo_argentina_cdt (")
out.append("    id SERIAL PRIMARY KEY,")
out.append("    codigo_nomenclador VARCHAR(30) NOT NULL REFERENCES odontologia_nomenclador(codigo) ON DELETE CASCADE,")
out.append("    codigo_cdt VARCHAR(10) NOT NULL REFERENCES odontologia_cdt_catalogo(codigo_cdt) ON DELETE CASCADE,")
out.append("    relationship VARCHAR(30) NOT NULL DEFAULT 'equivalent',")
out.append("    snomed_concept_id BIGINT,")
out.append("    notas TEXT,")
out.append("    UNIQUE (codigo_nomenclador, codigo_cdt)")
out.append(");\n")

for r in rows:
    code = r[0].strip()
    cat, cat_es, cdt, sct, rel = map_row(r)
    sct_val = str(sct) if sct else "NULL"
    out.append(f"INSERT INTO odontologia_mapeo_argentina_cdt (codigo_nomenclador, codigo_cdt, relationship, snomed_concept_id, notas)")
    out.append(f"VALUES ({sql_str(code)}, {sql_str(cdt)}, {sql_str(rel)}, {sct_val}, {sql_str(f'Mapeo oficial DENTAR / CDT {cat_es}')})")
    out.append(f"ON CONFLICT (codigo_nomenclador, codigo_cdt) DO UPDATE SET")
    out.append(f"    relationship = EXCLUDED.relationship,")
    out.append(f"    snomed_concept_id = EXCLUDED.snomed_concept_id,")
    out.append(f"    notas = EXCLUDED.notas;\n")

# 5. Populate odontologia_prestaciones for API Search
out.append("\n-- =============================================================================")
out.append("-- 5. TABLA DE CONSUMO DE LA API: odontologia_prestaciones")
out.append("-- =============================================================================")
out.append("CREATE TABLE IF NOT EXISTS odontologia_prestaciones (")
out.append("    id SERIAL PRIMARY KEY,")
out.append("    codigo_nomenclador VARCHAR(30) UNIQUE NOT NULL,")
out.append("    descripcion TEXT NOT NULL,")
out.append("    capitulo VARCHAR(150),")
out.append("    cdt_code VARCHAR(20),")
out.append("    cdt_categoria VARCHAR(50),")
out.append("    cdt_categoria_es VARCHAR(150),")
out.append("    snomed_concept_id BIGINT,")
out.append("    requiere_pieza BOOLEAN DEFAULT FALSE,")
out.append("    face_specification BOOLEAN DEFAULT FALSE,")
out.append("    requiere_rx_pre BOOLEAN DEFAULT FALSE,")
out.append("    requiere_rx_post BOOLEAN DEFAULT FALSE,")
out.append("    ficha_odontologica BOOLEAN DEFAULT FALSE,")
out.append("    ficha_periodontal BOOLEAN DEFAULT FALSE,")
out.append("    material VARCHAR(100),")
out.append("    maxilar VARCHAR(50),")
out.append("    norma_particular TEXT,")
out.append("    activo BOOLEAN DEFAULT TRUE,")
out.append("    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP")
out.append(");\n")

out.append("-- Migración idempotente si la tabla ya existía con esquema previo:")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS capitulo VARCHAR(150);")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS cdt_code VARCHAR(20);")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS cdt_categoria VARCHAR(50);")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS cdt_categoria_es VARCHAR(150);")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS requiere_pieza BOOLEAN DEFAULT FALSE;")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS requiere_rx_pre BOOLEAN DEFAULT FALSE;")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS requiere_rx_post BOOLEAN DEFAULT FALSE;")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS ficha_odontologica BOOLEAN DEFAULT FALSE;")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS ficha_periodontal BOOLEAN DEFAULT FALSE;")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS material VARCHAR(100);")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS maxilar VARCHAR(50);")
out.append("ALTER TABLE odontologia_prestaciones ADD COLUMN IF NOT EXISTS norma_particular TEXT;\n")

# Sync into odontologia_prestaciones
out.append("-- Sincronización desde odontologia_nomenclador hacia odontologia_prestaciones:")
out.append("INSERT INTO odontologia_prestaciones (")
out.append("    codigo_nomenclador, descripcion, capitulo, cdt_code, cdt_categoria, cdt_categoria_es,")
out.append("    snomed_concept_id, requiere_pieza, face_specification, requiere_rx_pre, requiere_rx_post,")
out.append("    ficha_odontologica, ficha_periodontal, material, maxilar, norma_particular, activo")
out.append(")")
out.append("SELECT")
out.append("    n.codigo,")
out.append("    n.descripcion,")
out.append("    n.capitulo,")
out.append("    n.cdt_code_default,")
out.append("    cat.codigo,")
out.append("    cat.nombre_es,")
out.append("    CASE WHEN sc.id IS NOT NULL THEN n.snomed_concept_id ELSE NULL END,")
out.append("    n.requiere_pieza,")
out.append("    n.requiere_caras,")
out.append("    n.requiere_rx_pre,")
out.append("    n.requiere_rx_post,")
out.append("    n.ficha_odontologica,")
out.append("    n.ficha_periodontal,")
out.append("    n.material,")
out.append("    n.maxilar,")
out.append("    n.norma_particular,")
out.append("    TRUE")
out.append("FROM odontologia_nomenclador n")
out.append("LEFT JOIN odontologia_cdt_catalogo cdt ON cdt.codigo_cdt = n.cdt_code_default")
out.append("LEFT JOIN odontologia_cdt_categorias cat ON cat.codigo = cdt.categoria_codigo")
out.append("LEFT JOIN snomed_concepts sc ON sc.id = n.snomed_concept_id")
out.append("ON CONFLICT (codigo_nomenclador) DO UPDATE SET")
out.append("    descripcion = EXCLUDED.descripcion,")
out.append("    capitulo = EXCLUDED.capitulo,")
out.append("    cdt_code = EXCLUDED.cdt_code,")
out.append("    cdt_categoria = EXCLUDED.cdt_categoria,")
out.append("    cdt_categoria_es = EXCLUDED.cdt_categoria_es,")
out.append("    snomed_concept_id = EXCLUDED.snomed_concept_id,")
out.append("    requiere_pieza = EXCLUDED.requiere_pieza,")
out.append("    face_specification = EXCLUDED.face_specification,")
out.append("    requiere_rx_pre = EXCLUDED.requiere_rx_pre,")
out.append("    requiere_rx_post = EXCLUDED.requiere_rx_post,")
out.append("    ficha_odontologica = EXCLUDED.ficha_odontologica,")
out.append("    ficha_periodontal = EXCLUDED.ficha_periodontal,")
out.append("    material = EXCLUDED.material,")
out.append("    maxilar = EXCLUDED.maxilar,")
out.append("    norma_particular = EXCLUDED.norma_particular,")
out.append("    activo = EXCLUDED.activo;\n")

# Indexes
out.append("-- Índices de alto rendimiento para búsquedas y autocompletado en la API:")
out.append("CREATE INDEX IF NOT EXISTS idx_odontologia_trgm ON odontologia_prestaciones USING gin (descripcion gin_trgm_ops);")
out.append("CREATE INDEX IF NOT EXISTS idx_odontologia_codigo ON odontologia_prestaciones(codigo_nomenclador);")
out.append("CREATE INDEX IF NOT EXISTS idx_odontologia_cdt ON odontologia_prestaciones(cdt_code);")
out.append("CREATE INDEX IF NOT EXISTS idx_odontologia_snomed ON odontologia_prestaciones(snomed_concept_id);\n")

out.append("ANALYZE odontologia_cdt_categorias;")
out.append("ANALYZE odontologia_cdt_catalogo;")
out.append("ANALYZE odontologia_nomenclador;")
out.append("ANALYZE odontologia_mapeo_argentina_cdt;")
out.append("ANALYZE odontologia_prestaciones;\n")

out.append("SELECT 'odontologia_cdt_categorias' AS tabla, count(*) AS filas FROM odontologia_cdt_categorias")
out.append("UNION ALL SELECT 'odontologia_cdt_catalogo', count(*) FROM odontologia_cdt_catalogo")
out.append("UNION ALL SELECT 'odontologia_nomenclador', count(*) FROM odontologia_nomenclador")
out.append("UNION ALL SELECT 'odontologia_mapeo_argentina_cdt', count(*) FROM odontologia_mapeo_argentina_cdt")
out.append("UNION ALL SELECT 'odontologia_prestaciones', count(*) FROM odontologia_prestaciones;\n")

full_sql = "\n".join(out)

with open("sql/Argentina_dental_cdt_codes_2025.sql", "w", encoding="utf-8") as f:
    f.write(full_sql)

print(f"Generated sql/Argentina_dental_cdt_codes_2025.sql successfully ({len(full_sql)} bytes).")
