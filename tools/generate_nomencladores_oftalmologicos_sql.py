# -*- coding: utf-8 -*-
"""Genera los artefactos PostgreSQL de los nomencladores oftalmológicos de origen.

Fuentes:
  tools/sources/oftar/cao.csv      Nomenclador Nacional · Consejo Argentino de Oftalmología
  tools/sources/oftar/oftal2.csv   Nomenclador Oftalmológico de Referencia Regional (NOA)

Salidas:
  sql/03_oftar/nomenclador_oftalmologico_cao.sql
  sql/03_oftar/nomenclador_oftalmologico_regional.sql

Decisiones de modelo (alineadas con el Nomenclador Odontológico de DENTAR):
  · Cada nomenclador es un catálogo de origen dentro de la familia OFTAR.
  · Publica su numeración original como código permanente. NO crea OFT-PR nuevos.
  · No se copia ninguna columna de precio: ni valor, ni honorario, gasto o total.
  · definition y external_display quedan NULL y sin revisión: no se inventa texto clínico.
  · Las coincidencias exactas de descripción se cargan como propuestas de mapeo en
    una tabla gobernada. Ningún enlace se publica hasta revisión humana.
"""
from __future__ import annotations

import csv
import hashlib
import os
import re
import unicodedata

ROOT = os.path.dirname(os.path.abspath(__file__))
SOURCES = os.path.join(ROOT, "..", "tools", "sources", "oftar")
SQL_DIR = os.path.join(ROOT, "..", "sql", "03_oftar")

NN_SQL = os.path.join(SQL_DIR, "fuente_nomenclador_oftar_pr.sql")
MATCH_TABLE = "public.os_oftar_nomenclador_match"

CONFIGS = [
    {
        "key": "cao",
        "csv": os.path.join(SOURCES, "cao.csv"),
        "output": os.path.join(SQL_DIR, "nomenclador_oftalmologico_cao.sql"),
        "catalog": "nomenclador-oftalmologico-cao-ar",
        "name": "Nomenclador Nacional de Oftalmología · Consejo Argentino de Oftalmología",
        "organization": "Consejo Argentino de Oftalmología (CAO)",
        "short_name": "NOM-CAO-AR",
        "system": "NOMENCLADOR-CAO-AR",
        "system_name": "Nomenclador Nacional de Oftalmología (CAO, Argentina)",
        "system_uri": "https://www.cao.org.ar",
        "identifier": "NOMENCLADOR_CAO_AR",
        "release": "NOM-CAO-AR-v1",
        "source_table": "os_source_oftar_cao",
        "provenance": "imported_oftar_cao",
        "source_reference": "Nomenclador Nacional de Oftalmología · CAO",
        "source_file": "tools/sources/oftar/cao.csv",
        "expected_rows": 143,
        "category_field": "categoria",
        "subcategory_field": None,
    },
    {
        "key": "regional",
        "csv": os.path.join(SOURCES, "oftal2.csv"),
        "output": os.path.join(SQL_DIR, "nomenclador_oftalmologico_regional.sql"),
        "catalog": "nomenclador-oftalmologico-regional-ar",
        "name": "Nomenclador Oftalmológico de Referencia Regional (Argentina NOA)",
        "organization": "Nomencladores oftalmológicos de referencia regional (NOA)",
        "short_name": "NOM-OFTAL-REG",
        "system": "NOMENCLADOR-OFTAL-REG-AR",
        "system_name": "Nomenclador Oftalmológico de Referencia Regional (Argentina)",
        "system_uri": "https://www.cao.org.ar",
        "identifier": "NOMENCLADOR_OFTAL_REG_AR",
        "release": "NOM-OFTAL-REG-v1",
        "source_table": "os_source_oftar_regional",
        "provenance": "imported_oftar_regional",
        "source_reference": "Nomenclador Oftalmológico de Referencia Regional",
        "source_file": "tools/sources/oftar/oftal2.csv",
        "expected_rows": 136,
        "category_field": "grupo",
        "subcategory_field": "subgrupo",
    },
]

NN_ROW_RE = re.compile(r"\('(\d{6})', '([^']*)'")


def normalize(value: str) -> str:
    """Comparación literal: sin acentos, sin mayúsculas y sin puntuación."""
    decomposed = unicodedata.normalize("NFKD", value)
    plain = "".join(ch for ch in decomposed if not unicodedata.combining(ch))
    return re.sub(r"[^a-z0-9]+", " ", plain.lower()).strip()


def slug(value: str, limit: int = 50) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    plain = normalized.encode("ascii", "ignore").decode("ascii").lower()
    plain = re.sub(r"[^a-z0-9]+", "-", plain).strip("-")
    return plain[:limit]


def sql_text(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_optional(value: str) -> str:
    return "NULL" if not value.strip() else sql_text(value.strip())


def tuples(values: list[str], indent: str = "    ") -> str:
    return ",\n".join(indent + value for value in values)


def load_rows(config: dict) -> list[dict[str, str]]:
    with open(config["csv"], "r", encoding="utf-8", newline="") as handle:
        rows = [row for row in csv.DictReader(handle, delimiter=";")
                if re.fullmatch(r"\d{6}", (row.get("codigo") or "").strip())]

    if len(rows) != config["expected_rows"]:
        raise RuntimeError(
            f"{config['key']}: se esperaban {config['expected_rows']} filas, se leyeron {len(rows)}."
        )
    if len({row["codigo"].strip() for row in rows}) != len(rows):
        raise RuntimeError(f"{config['key']}: la fuente contiene códigos duplicados.")
    return rows


def load_nn_index() -> dict[str, tuple[str, str]]:
    """texto normalizado del Nomenclador Nacional 2025 -> (código OFT-PR, descripción)."""
    with open(NN_SQL, "r", encoding="utf-8") as handle:
        content = handle.read()

    index: dict[str, str] = {}
    for match in NN_ROW_RE.finditer(content):
        code, description = match.group(1), match.group(2)
        key = normalize(description)
        if key:
            index.setdefault(key, (code, description))
    if len(index) < 150:
        raise RuntimeError(f"La fuente del Nomenclador Nacional parece incompleta: {len(index)} textos.")
    return index


def category_code(config: dict, primary: str, secondary: str) -> str:
    """Código estable y único: slug legible + hash del texto completo.

    El hash evita que dos categorías largas con el mismo prefijo colisionen al
    truncar el slug a 50 caracteres (caso real en las categorías láser de CAO).
    """
    suffix = hashlib.md5((primary + "\x1f" + secondary).encode("utf-8")).hexdigest()[:8]
    if not secondary:
        return slug(primary, 41) + "-" + suffix
    return slug(primary, 22) + "-" + slug(secondary, 11) + "-" + suffix


def source_category(config: dict, row: dict[str, str]) -> tuple[str, str, str]:
    primary = row[config["category_field"]].strip()
    secondary_field = config["subcategory_field"]
    secondary = row[secondary_field].strip() if secondary_field else ""
    return category_code(config, primary, secondary), primary, secondary


def build_artifact(config: dict, rows: list[dict[str, str]], nn_index: dict[str, str]) -> str:
    catalog = config["catalog"]
    source_table = "public." + config["source_table"]
    classifications = [source_category(config, row) for row in rows]
    pairs = sorted({(primary, secondary) for _, primary, secondary in classifications})
    matches: list[tuple[str, str, str, str]] = []
    for row in rows:
        code = row["codigo"].strip()
        description = row["descripcion"].strip()
        hit = nn_index.get(normalize(description))
        if hit:
            matches.append((code, hit[0], description, hit[1]))

    out: list[str] = []
    add = out.append

    add("-- =============================================================================")
    add("-- NO EJECUTAR SIN AUTORIZACIÓN · Origen Salud · Familia OFTAR")
    add(f"-- sql/03_oftar/{os.path.basename(config['output'])}")
    add("-- =============================================================================")
    add("--")
    add("-- Generado por tools/generate_nomencladores_oftalmologicos_sql.py desde")
    add(f"-- {config['source_file']}. NO EDITAR A MANO; volver a generar.")
    add("--")
    add("-- ORDEN DE CARGA EN `origen_codes`")
    add("--   1) sql/03_oftar/nomencladores_oftar_mapping.sql")
    add(f"--   2) sql/03_oftar/{os.path.basename(config['output'])}")
    add("--   3) el otro nomenclador (cao / regional)")
    add("--   4) sql/03_oftar/aprobar_mapeo_nomencladores_oftar.sql")
    add("--      (tras revisar la tabla de mapeo y aprobar preferred_term)")
    add("--")
    add("-- QUÉ HACE")
    add("--   · Publica el nomenclador como catálogo de origen de la familia OFTAR con")
    add("--     su numeración original como código permanente. No crea códigos OFT-PR.")
    add("--   · Conserva espejo de la fuente SIN ninguna columna de precio.")
    add("--   · Carga categorías literales y versiones es-AR con preferred_term literal.")
    add("--   · Siembra propuestas de mapeo contra oftar-pr; NO publica enlaces.")
    add("--")
    add("-- QUÉ NO HACE")
    add("--   · No guarda valor, honorario_medico, gasto ni valor_total.")
    add("--   · No publica definition ni external_display: quedan NULL.")
    add("--   · No declara equivalencia clínica: los pares son solo propuestas.")
    add("--   · No crea UVR, dominios ni rutas. No usa DROP ... CASCADE ni")
    add("--     ALTER DEFAULT PRIVILEGES. Idempotente: se puede repetir sin duplicar.")
    add("-- =============================================================================")
    add("BEGIN;")
    add("")
    add("SET client_encoding = 'UTF8';")
    add("SET standard_conforming_strings = on;")
    add("")
    add("DO $$")
    add("BEGIN")
    add(f"    IF to_regclass('{MATCH_TABLE}') IS NULL THEN")
    add("        RAISE EXCEPTION 'Falta la tabla de mapeo gobernado.'")
    add("            USING HINT = 'Aplicar primero sql/03_oftar/nomencladores_oftar_mapping.sql.';")
    add("    END IF;")
    add("END $$;")
    add("")

    # 1. Espejo de la fuente, sin precios
    add("-- -----------------------------------------------------------------------------")
    add("-- 1. Espejo de la fuente: solo identificación y agrupamiento, SIN PRECIOS")
    add("-- -----------------------------------------------------------------------------")
    add(f"CREATE TABLE IF NOT EXISTS {source_table} (")
    add("    codigo VARCHAR(20) PRIMARY KEY,")
    add("    descripcion TEXT NOT NULL,")
    add("    categoria VARCHAR(150),")
    add("    subcategoria VARCHAR(150),")
    add("    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP")
    add(");")
    add("")
    add(f"COMMENT ON TABLE {source_table} IS")
    add("    'Espejo literal de la fuente oftalmológica. No contiene columnas de precio.';")
    add("")
    add(f"REVOKE ALL PRIVILEGES ON TABLE {source_table} FROM PUBLIC;")
    add("")
    add("DO $$")
    add("BEGIN")
    for role in ("origen_admin", "origen_med", "origen_api"):
        add(f"    IF to_regrole('{role}') IS NOT NULL THEN")
        add(f"        EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE {source_table} FROM {role}';")
        add(f"        EXECUTE 'GRANT SELECT ON TABLE {source_table} TO {role}';")
        add("    END IF;")
    add("END $$;")
    add("")
    add(f"DELETE FROM {source_table};")
    add("")
    add(f"INSERT INTO {source_table} (codigo, descripcion, categoria, subcategoria) VALUES")
    literals = []
    for row in rows:
        secondary_field = config["subcategory_field"]
        secondary = row[secondary_field] if secondary_field else ""
        literals.append(
            "(" + ", ".join([
                sql_text(row["codigo"].strip()),
                sql_text(row["descripcion"].strip()),
                sql_optional(row[config["category_field"]]),
                sql_optional(secondary),
            ]) + ")"
        )
    add(tuples(literals) + ";")
    add("")

    # 2. Catálogo y release
    add("-- -----------------------------------------------------------------------------")
    add("-- 2. Catálogo de origen dentro de la familia OFTAR")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO public.os_catalog")
    add("    (code, name, organization, country_code, domain_type, family_code,")
    add("     product_role, short_name, description, is_active)")
    add("VALUES (")
    add("    " + sql_text(catalog) + ",")
    add("    " + sql_text(config["name"]) + ",")
    add("    " + sql_text(config["organization"]) + ",")
    add("    'AR', 'medical', 'oftar', 'catalog', " + sql_text(config["short_name"]) + ",")
    add("    " + sql_text(
        "Nomenclador oftalmológico de origen. Publica su numeración histórica y se vincula "
        "a OFT-PR solo por mapeo gobernado; sin precios, sin UVR y sin equivalencia clínica asumida."
    ) + ",")
    add("    TRUE")
    add(")")
    add("ON CONFLICT (code) DO UPDATE SET")
    add("    name = EXCLUDED.name,")
    add("    organization = EXCLUDED.organization,")
    add("    family_code = EXCLUDED.family_code,")
    add("    product_role = EXCLUDED.product_role,")
    add("    short_name = EXCLUDED.short_name,")
    add("    description = EXCLUDED.description,")
    add("    is_active = EXCLUDED.is_active;")
    add("")
    add("-- La fecha registra la carga, no una fecha normativa declarada por la fuente.")
    add("INSERT INTO public.os_catalog_release")
    add("    (catalog_id, version_tag, valid_from, official_norm_reference, status)")
    add("SELECT id, " + sql_text(config["release"]) + ", CURRENT_DATE, "
        + sql_text("Fuente: " + config["source_file"]) + ", 'published'")
    add("  FROM public.os_catalog WHERE code = " + sql_text(catalog))
    add("ON CONFLICT (catalog_id, version_tag) DO UPDATE SET")
    add("    status = EXCLUDED.status,")
    add("    official_norm_reference = EXCLUDED.official_norm_reference;")
    add("")

    # 3. Categorías y clasificación temp
    add("-- -----------------------------------------------------------------------------")
    add("-- 3. Categorías: agrupamientos literales de la fuente (no categorías internas)")
    add("-- -----------------------------------------------------------------------------")
    add("CREATE TEMP TABLE _oftar_source_categoria (")
    add("    code VARCHAR(50) PRIMARY KEY,")
    add("    parent_code VARCHAR(50),")
    add("    name VARCHAR(150) NOT NULL")
    add(") ON COMMIT DROP;")
    add("")
    add("CREATE TEMP TABLE _oftar_source_clasificacion (")
    add("    codigo VARCHAR(20) PRIMARY KEY,")
    add("    categoria_code VARCHAR(50) NOT NULL")
    add(") ON COMMIT DROP;")
    add("")

    category_literals = []
    for primary, secondary in pairs:
        if secondary:
            category_literals.append(
                "(" + sql_text(category_code(config, primary, secondary)) + ", "
                + sql_text(category_code(config, primary, "")) + ", " + sql_text(secondary) + ")"
            )
        else:
            category_literals.append(
                "(" + sql_text(category_code(config, primary, "")) + ", NULL, " + sql_text(primary) + ")"
            )
    for primary, secondary in pairs:
        category_literals.append(
            "(" + sql_text(category_code(config, primary, "")) + ", NULL, " + sql_text(primary) + ")"
        )
    add("INSERT INTO _oftar_source_categoria (code, parent_code, name) VALUES")
    add(tuples(sorted(set(category_literals))) + ";")
    add("")

    add("INSERT INTO _oftar_source_clasificacion (codigo, categoria_code) VALUES")
    add(tuples([f"({sql_text(row['codigo'].strip())}, {sql_text(code)})"
                for row, (code, _, _) in zip(rows, classifications)]) + ";")
    add("")

    add("INSERT INTO public.os_catalog_category (catalog_id, code, name, parent_category_id)")
    add("SELECT c.id, k.code, k.name,")
    add("       (SELECT p.id FROM public.os_catalog_category p")
    add("          WHERE p.catalog_id = c.id AND p.code = k.parent_code)")
    add("  FROM public.os_catalog c CROSS JOIN _oftar_source_categoria k")
    add(" WHERE c.code = " + sql_text(catalog))
    add("ON CONFLICT (catalog_id, code) DO UPDATE SET")
    add("    name = EXCLUDED.name,")
    add("    parent_category_id = EXCLUDED.parent_category_id;")
    add("")

    # 4. Ítems y versiones
    add("-- -----------------------------------------------------------------------------")
    add("-- 4. Ítems y versiones: el código original es el código permanente")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO public.os_catalog_item (catalog_id, permanent_code, status)")
    add("SELECT c.id, s.codigo, 'active'")
    add(f"  FROM {source_table} s CROSS JOIN public.os_catalog c")
    add(" WHERE c.code = " + sql_text(catalog))
    add("ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = 'active';")
    add("")
    add("INSERT INTO public.os_catalog_item_version")
    add("    (item_id, release_id, category_id, preferred_term, definition, clinical_criteria,")
    add("     language_code, source_language_code, language_evidence, provenance,")
    add("     review_status, source_reference, valid_from)")
    add("SELECT i.id, r.id, cat.id, left(s.descripcion, 255), NULL, NULL,")
    add("       'es-AR', 'es-AR', 'explicit', " + sql_text(config["provenance"]) + ",")
    add("       'unknown', " + sql_text(config["source_reference"]) + ", CURRENT_DATE")
    add(f"  FROM {source_table} s")
    add("  JOIN public.os_catalog c ON c.code = " + sql_text(catalog))
    add("  JOIN public.os_catalog_release r ON r.catalog_id = c.id AND r.version_tag = "
        + sql_text(config["release"]))
    add("  JOIN public.os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.codigo")
    add("  LEFT JOIN _oftar_source_clasificacion k ON k.codigo = s.codigo")
    add("  LEFT JOIN public.os_catalog_category cat")
    add("         ON cat.catalog_id = c.id AND cat.code = k.categoria_code")
    add("ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET")
    add("    category_id = EXCLUDED.category_id,")
    add("    preferred_term = EXCLUDED.preferred_term,")
    add("    source_language_code = EXCLUDED.source_language_code,")
    add("    language_evidence = EXCLUDED.language_evidence,")
    add("    provenance = EXCLUDED.provenance,")
    add("    source_reference = EXCLUDED.source_reference,")
    add("    valid_from = EXCLUDED.valid_from;")
    add("")

    # 5. Revisión de campo: solo preferred_term
    add("-- -----------------------------------------------------------------------------")
    add("-- 5. Revisión de campo: SOLO preferred_term (definition queda pendiente)")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO public.os_field_review")
    add("    (target_table, target_id, field_name, language_code, scope_release_id,")
    add("     source_language_code, language_evidence, provenance, review_status,")
    add("     source_reference, reviewed_by, reviewed_at)")
    add("SELECT 'os_catalog_item_version', iv.id, 'preferred_term', iv.language_code,")
    add("       iv.release_id, iv.source_language_code, iv.language_evidence, iv.provenance,")
    add("       'unknown', iv.source_reference, NULL, NULL")
    add("  FROM public.os_catalog_item_version iv")
    add("  JOIN public.os_catalog_item i ON i.id = iv.item_id")
    add("  JOIN public.os_catalog c ON c.id = i.catalog_id AND c.code = " + sql_text(catalog))
    add(" WHERE iv.provenance = " + sql_text(config["provenance"]))
    add("   AND NULLIF(btrim(iv.preferred_term), '') IS NOT NULL")
    add("ON CONFLICT DO NOTHING;")
    add("")

    # 6. Propuestas de mapeo (nunca enlaces publicados)
    add("-- -----------------------------------------------------------------------------")
    add("-- 6. Propuestas de mapeo en tabla gobernada (sin publicar enlaces)")
    add("-- -----------------------------------------------------------------------------")
    if matches:
        add("INSERT INTO " + MATCH_TABLE)
        add("    (source_catalog_code, source_code, target_catalog_code, target_code,")
        add("     match_basis, review_status, source_term, target_term, provenance, notes)")
        add("VALUES")
        seed_literals = []
        for source_code, target_code, source_term, target_term in matches:
            seed_literals.append(
                "(" + ", ".join([
                    sql_text(catalog),
                    sql_text(source_code),
                    "'oftar-pr'",
                    sql_text(target_code),
                    "'texto_identico_normalizado'",
                    "'proposed'",
                    sql_text(source_term),
                    sql_text(target_term),
                    sql_text("Coincidencia literal de descripción normalizada entre "
                             + config["source_file"]
                             + " y sql/03_oftar/fuente_nomenclador_oftar_pr.sql"),
                    "NULL",
                ]) + ")"
            )
        add(tuples(seed_literals) + " ON CONFLICT (source_catalog_code, source_code) DO NOTHING;")
    else:
        add("-- Sin coincidencias exactas de descripción: 0 propuestas generadas.")
        add("-- Completar la tabla de mapeo a mano antes de ejecutar la aprobación.")
    add("")

    # 7. Verificación
    add("-- -----------------------------------------------------------------------------")
    add("-- 7. Verificación (solo lectura; ejecutar por separado)")
    add("-- -----------------------------------------------------------------------------")
    add(f"-- SELECT count(*) FROM {source_table};  -- esperado: {len(rows)}")
    add("-- SELECT count(*) FROM public.os_catalog_item i JOIN public.os_catalog c")
    add("--   ON c.id = i.catalog_id WHERE c.code = " + sql_text(catalog) + f";  -- esperado: {len(rows)}")
    add("-- SELECT count(*) FROM public.os_field_review WHERE provenance = "
        + sql_text(config["provenance"]) + f";  -- esperado: {len(rows)}")
    add("-- SELECT count(*) FROM " + MATCH_TABLE + " WHERE source_catalog_code = "
        + sql_text(catalog) + f";  -- esperado: {len(matches)} propuestas")
    add("")
    add("COMMIT;")
    add("")

    return "\n".join(out) + "\n"


def main() -> None:
    nn_index = load_nn_index()
    print(f"Nomenclador Nacional: {len(nn_index)} textos indexados.")
    for config in CONFIGS:
        rows = load_rows(config)
        artifact = build_artifact(config, rows, nn_index)
        with open(config["output"], "w", encoding="utf-8", newline="\n") as handle:
            handle.write(artifact)
        print(f"Generado {os.path.relpath(config['output'], ROOT)}: {len(rows)} filas.")


if __name__ == "__main__":
    main()
