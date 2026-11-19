# -*- coding: utf-8 -*-
"""Genera el artefacto PostgreSQL del Nomenclador Odontológico Nacional.

Fuente:  tools/sources/odontologico/odontologico.sql  (dump MariaDB, UTF-8)
Salida:  sql/03_dentar/nomenclador_odontologico_nacional.sql

El artefacto es aditivo y NO se ejecuta automáticamente. Publica el catálogo
`nomenclador-odontologico-ar` con los 135 códigos originales y, al mismo tiempo,
conserva el código nacional como identificador secundario y buscable en cada
DNT-PR vinculado. DENTAR sigue siendo el código permanente visible.
"""
from __future__ import annotations

import os
import re
import unicodedata

ROOT = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(ROOT, "..", "tools", "sources", "odontologico", "odontologico.sql")
OUTPUT = os.path.join(ROOT, "..", "sql", "03_dentar", "nomenclador_odontologico_nacional.sql")

CATALOG = "nomenclador-odontologico-ar"
RELEASE = "NOM-ODON-AR-v1"
SYSTEM = "NOMENCLADOR-AR"
IDENTIFIER = "NOMENCLADOR_AR"
LANGUAGE = "es-AR"

FLAG_COLUMNS = [
    ("factura", "Facturable"),
    ("ficha_odontolog", "Ficha odontológica"),
    ("ficha_periodontal", "Ficha periodontal"),
    ("pieza", "Pieza dentaria"),
    ("caras", "Caras"),
    ("rx_pre", "Radiografía preoperatoria"),
    ("rx_post", "Radiografía postoperatoria"),
    ("material", "Material"),
    ("maxilar", "Maxilar"),
]

ROW_RE = re.compile(
    r"\('([^']*)','([^']*)','([^']*)','([^']*)','([^']*)','([^']*)','([^']*)',"
    r"'([^']*)','([^']*)','([^']*)','([^']*)','([^']*)','([^']*)'\)"
)


def slug(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    plain = normalized.encode("ascii", "ignore").decode("ascii").lower()
    plain = re.sub(r"[^a-z0-9]+", "-", plain).strip("-")
    return plain[:50]


def sql_text(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_optional(value: str) -> str:
    return "NULL" if value == "" else sql_text(value)


def sql_bool(value: str) -> str:
    return "TRUE" if value.strip() == "1" else "FALSE"


def load_rows() -> list[list[str]]:
    with open(SOURCE, "r", encoding="utf-8") as handle:
        dump = handle.read()

    start = dump.find("INSERT INTO `odontologico` VALUES")
    if start < 0:
        raise RuntimeError("No se encontró el INSERT de odontologico en la fuente.")
    end = dump.find("/*!40000 ALTER TABLE `odontologico` ENABLE KEYS */", start)
    if end < 0:
        raise RuntimeError("No se encontró el fin del INSERT de odontologico.")

    rows = [list(match.groups()) for match in ROW_RE.finditer(dump[start:end])]
    if len(rows) != 135:
        raise RuntimeError(f"Se esperaban 135 filas; se leyeron {len(rows)}.")
    if len({row[0] for row in rows}) != len(rows):
        raise RuntimeError("La fuente contiene códigos duplicados.")

    return rows


def tuples(values: list[str], indent: str = "    ") -> str:
    return ",\n".join(indent + value for value in values)


def build() -> str:
    rows = load_rows()
    categories: dict[str, str] = {}
    for row in rows:
        categories[slug(row[11].strip())] = row[11].strip()

    out: list[str] = []
    add = out.append

    add("-- =============================================================================")
    add("-- Origen Salud · Nomenclador Odontológico Nacional (PostgreSQL, artefacto aditivo)")
    add("-- =============================================================================")
    add("--")
    add("-- Generado desde tools/sources/odontologico/odontologico.sql (dump MariaDB).")
    add("-- NO EJECUTADO. Requiere autorización explícita para DDL, carga y deploy.")
    add("--")
    add("-- Decisiones de modelo:")
    add("--   1. `nomenclador-odontologico-ar` publica los 135 códigos originales.")
    add("--   2. Cada fila se vincula con su DNT-PR por `referencia_literal` en ambos")
    add("--      sentidos; no se declara equivalencia clínica asumida.")
    add("--   3. DENTAR-PR conserva el código nacional como identificador secundario")
    add("--      y buscable; el código visible sigue siendo DNT-PR-NNNNNN.")
    add("--   4. Los 10 indicadores del dump se conservan como campos literales de")
    add("--      fuente, también en la ficha DENTAR-PR correspondiente.")
    add("-- =============================================================================")
    add("")
    add("SET client_encoding = 'UTF8';")
    add("")
    add("BEGIN;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 1. Espejo de la fuente MariaDB: los 13 campos se conservan literalmente")
    add("-- -----------------------------------------------------------------------------")
    add("CREATE TABLE IF NOT EXISTS os_source_odontologico_nacional (")
    add("    codigo VARCHAR(50) PRIMARY KEY,")
    add("    descripcion TEXT NOT NULL,")
    add("    factura BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    ficha_odontolog BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    ficha_periodontal BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    pieza BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    caras BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    rx_pre BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    rx_post BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    material BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    maxilar BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    agrupamiento VARCHAR(100),")
    add("    norma_particular TEXT")
    add(");")
    add("")
    add("CREATE TABLE IF NOT EXISTS os_catalog_source_attribute (")
    add("    item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,")
    add("    source_catalog_code VARCHAR(50) NOT NULL,")
    add("    attribute_code VARCHAR(50) NOT NULL,")
    add("    attribute_label VARCHAR(150) NOT NULL,")
    add("    attribute_value TEXT NOT NULL,")
    add("    is_boolean BOOLEAN NOT NULL DEFAULT FALSE,")
    add("    display_order INT NOT NULL DEFAULT 0,")
    add("    PRIMARY KEY (item_id, source_catalog_code, attribute_code)")
    add(");")
    add("")
    add("CREATE TEMP TABLE _nomenclador_categoria (")
    add("    code VARCHAR(50) PRIMARY KEY,")
    add("    name VARCHAR(150) NOT NULL")
    add(") ON COMMIT DROP;")
    add("")
    add("CREATE TEMP TABLE _nomenclador_clasificacion (")
    add("    codigo VARCHAR(50) PRIMARY KEY,")
    add("    categoria_code VARCHAR(50) NOT NULL")
    add(") ON COMMIT DROP;")
    add("")
    add("CREATE TEMP TABLE _nomenclador_dentar_match (")
    add("    source_codigo VARCHAR(50) PRIMARY KEY,")
    add("    dentar_item_id INT NOT NULL,")
    add("    dentar_code VARCHAR(30) NOT NULL")
    add(") ON COMMIT DROP;")
    add("")
    add("CREATE TEMP TABLE _nomenclador_attribute_target (")
    add("    item_id INT PRIMARY KEY,")
    add("    source_codigo VARCHAR(50) NOT NULL")
    add(") ON COMMIT DROP;")
    add("")
    add("DELETE FROM os_source_odontologico_nacional;")
    add("")
    add("INSERT INTO os_source_odontologico_nacional (")
    add("    codigo, descripcion, factura, ficha_odontolog, ficha_periodontal,")
    add("    pieza, caras, rx_pre, rx_post, material, maxilar, agrupamiento, norma_particular")
    add(") VALUES")
    source_tuples = []
    for row in rows:
        source_tuples.append(
            "("
            + sql_text(row[0])
            + ", "
            + sql_text(row[1])
            + ", "
            + ", ".join(sql_bool(row[index]) for index in range(2, 11))
            + ", "
            + sql_optional(row[11])
            + ", "
            + sql_optional(row[12])
            + ")"
        )
    add(tuples(source_tuples) + ";")
    add("")

    add("INSERT INTO _nomenclador_categoria (code, name) VALUES")
    add(tuples([
        "(" + sql_text(code) + ", " + sql_text(name) + ")"
        for code, name in sorted(categories.items())
    ]) + ";")
    add("")

    add("INSERT INTO _nomenclador_clasificacion (codigo, categoria_code) VALUES")
    add(tuples([
        "(" + sql_text(row[0]) + ", " + sql_text(slug(row[11].strip())) + ")"
        for row in rows
    ]) + ";")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 2. Registro del catálogo dentro de la familia DENTAR")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO os_catalog")
    add("    (code, name, organization, country_code, domain_type, family_code,")
    add("     product_role, short_name, description, is_active)")
    add("VALUES (")
    add("    " + sql_text(CATALOG) + ",")
    add("    'Nomenclador Odontológico Nacional · Argentina',")
    add("    'Federación Odontológica de la República Argentina / Colegios Odontológicos',")
    add("    'AR', 'dental', 'dentar', 'catalog', 'NOM-ODON-AR',")
    add("    'Nomenclador odontológico argentino (Capítulos I a XI) cargado desde el dump MariaDB. "
        "Cada código se publica con su numeración original y se vincula literalmente con DENTAR-PR.',")
    add("    TRUE")
    add(")")
    add("ON CONFLICT (code) DO UPDATE SET")
    add("    name = EXCLUDED.name,")
    add("    family_code = EXCLUDED.family_code,")
    add("    product_role = EXCLUDED.product_role,")
    add("    short_name = EXCLUDED.short_name,")
    add("    description = EXCLUDED.description,")
    add("    is_active = EXCLUDED.is_active;")
    add("")
    add("-- La fuente no declara vigencia: CURRENT_DATE registra la fecha de carga de la")
    add("-- release, no una fecha normativa del nomenclador.")
    add("INSERT INTO os_catalog_release (catalog_id, version_tag, valid_from, official_norm_reference, status)")
    add("SELECT id, " + sql_text(RELEASE) + ", CURRENT_DATE, "
        "'Dump MariaDB: tools/sources/odontologico/odontologico.sql', 'published'")
    add("  FROM os_catalog WHERE code = " + sql_text(CATALOG))
    add("ON CONFLICT (catalog_id, version_tag)")
    add("DO UPDATE SET status = EXCLUDED.status,")
    add("              official_norm_reference = EXCLUDED.official_norm_reference;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 3. Categorías: textos de agrupamiento sin reescribirlos")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO os_catalog_category (catalog_id, code, name)")
    add("SELECT c.id, k.code, k.name FROM os_catalog c CROSS JOIN _nomenclador_categoria k")
    add(" WHERE c.code = " + sql_text(CATALOG))
    add("ON CONFLICT (catalog_id, code) DO UPDATE SET name = EXCLUDED.name;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 4. Ítems y versiones: el código original es el código permanente")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO os_catalog_item (catalog_id, permanent_code, status)")
    add("SELECT c.id, s.codigo, 'active'")
    add("  FROM os_source_odontologico_nacional s CROSS JOIN os_catalog c")
    add(" WHERE c.code = " + sql_text(CATALOG))
    add("ON CONFLICT (catalog_id, permanent_code) DO UPDATE SET status = 'active';")
    add("")
    add("INSERT INTO os_catalog_item_version")
    add("    (item_id, release_id, category_id, preferred_term, definition, clinical_criteria, language_code)")
    add("SELECT i.id, r.id, cat.id, s.descripcion, NULLIF(s.norma_particular, ''), NULL, "
        + sql_text(LANGUAGE))
    add("  FROM os_source_odontologico_nacional s")
    add("  JOIN _nomenclador_clasificacion k ON k.codigo = s.codigo")
    add("  JOIN os_catalog c ON c.code = " + sql_text(CATALOG))
    add("  JOIN os_catalog_release r ON r.catalog_id = c.id AND r.version_tag = " + sql_text(RELEASE))
    add("  JOIN os_catalog_item i ON i.catalog_id = c.id AND i.permanent_code = s.codigo")
    add("  LEFT JOIN os_catalog_category cat ON cat.catalog_id = c.id AND cat.code = k.categoria_code")
    add("ON CONFLICT (item_id, release_id, language_code) DO UPDATE SET")
    add("    category_id = EXCLUDED.category_id,")
    add("    preferred_term = EXCLUDED.preferred_term,")
    add("    definition = EXCLUDED.definition;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 5. Correspondencia DENTAR-PR ↔ Nomenclador desde los mapeos reales")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO _nomenclador_dentar_match (source_codigo, dentar_item_id, dentar_code)")
    add("SELECT DISTINCT ON (m.external_code) m.external_code, dnt.id, dnt.permanent_code")
    add("  FROM dentar_concept_mapping m")
    add("  JOIN dentar_concept_version cv ON cv.id = m.concept_version_id")
    add("  JOIN dentar_concept dc ON dc.id = cv.concept_id")
    add("  JOIN os_catalog_item dnt")
    add("    ON dnt.permanent_code = dc.code")
    add("   AND dnt.catalog_id = (SELECT id FROM os_catalog WHERE code = 'dentar-pr')")
    add(" WHERE m.system_code = " + sql_text(SYSTEM))
    add(" ORDER BY m.external_code, cv.version_number DESC, m.id DESC;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 6. Atributos literales de la fuente (indicadores 1/0 y agrupamiento)")
    add("-- -----------------------------------------------------------------------------")
    add("INSERT INTO _nomenclador_attribute_target (item_id, source_codigo)")
    add("SELECT i.id, s.codigo")
    add("  FROM os_catalog_item i")
    add("  JOIN os_catalog c ON c.id = i.catalog_id AND c.code = " + sql_text(CATALOG))
    add("  JOIN os_source_odontologico_nacional s ON s.codigo = i.permanent_code;")
    add("")
    add("INSERT INTO _nomenclador_attribute_target (item_id, source_codigo)")
    add("SELECT dentar_item_id, source_codigo FROM _nomenclador_dentar_match")
    add("ON CONFLICT (item_id) DO NOTHING;")
    add("")
    add("DELETE FROM os_catalog_source_attribute")
    add(" WHERE source_catalog_code = " + sql_text(CATALOG)
        + " AND item_id IN (SELECT item_id FROM _nomenclador_attribute_target);")
    add("")
    add("INSERT INTO os_catalog_source_attribute")
    add("    (item_id, source_catalog_code, attribute_code, attribute_label, attribute_value, is_boolean, display_order)")
    add("SELECT t.item_id, " + sql_text(CATALOG) + ", x.codigo, x.etiqueta, x.valor, x.es_booleano, x.orden")
    add("  FROM _nomenclador_attribute_target t")
    add("  JOIN os_source_odontologico_nacional s ON s.codigo = t.source_codigo")
    add("  CROSS JOIN LATERAL (")
    attribute_rows = []
    for order, (column, label) in enumerate(FLAG_COLUMNS, start=1):
        attribute_rows.append(
            "    SELECT " + sql_text(column) + "::text AS codigo, "
            + sql_text(label) + "::text AS etiqueta, "
            + f"CASE WHEN s.{column} THEN '1' ELSE '0' END::text AS valor, "
            + f"TRUE::boolean AS es_booleano, {order}::int AS orden"
        )
    attribute_rows.append(
        "    SELECT 'agrupamiento'::text, 'Agrupamiento'::text, "
        "COALESCE(s.agrupamiento, ''), FALSE::boolean, 11::int"
    )
    add("\n  UNION ALL\n".join(attribute_rows))
    add("  ) x;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 7. Sistema terminológico e identificadores en ambos sentidos")
    add("-- -----------------------------------------------------------------------------")
    add("SELECT setval(")
    add("    pg_get_serial_sequence('os_terminology_system', 'id'),")
    add("    (SELECT COALESCE(max(id), 1) FROM os_terminology_system),")
    add("    true")
    add(");")
    add("")
    add("INSERT INTO os_terminology_system (code, name, uri, default_version)")
    add("VALUES (")
    add("    " + sql_text(SYSTEM) + ",")
    add("    'Nomenclador Odontológico Nacional (Argentina)',")
    add("    'https://fopba.org.ar',")
    add("    '2026-v1'")
    add(")")
    add("ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, uri = EXCLUDED.uri;")
    add("")
    add("-- 7.1 DENTAR-PR → identificador NOMENCLADOR_AR, buscable pero no principal.")
    add("INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)")
    add("SELECT dentar_item_id, " + sql_text(IDENTIFIER) + ", source_codigo, FALSE")
    add("  FROM _nomenclador_dentar_match")
    add("ON CONFLICT (item_id, system_name, value) DO UPDATE SET is_primary = FALSE;")
    add("")
    add("-- 7.2 Catálogo de origen → identificador DENTAR-PR (destino de migración).")
    add("DELETE FROM os_catalog_identifier i")
    add(" USING os_catalog_item src, os_catalog c")
    add(" WHERE i.item_id = src.id AND src.catalog_id = c.id")
    add("   AND c.code = " + sql_text(CATALOG) + " AND i.system_name = 'DENTAR-PR';")
    add("")
    add("INSERT INTO os_catalog_identifier (item_id, system_name, value, is_primary)")
    add("SELECT src.id, 'DENTAR-PR', m.dentar_code, FALSE")
    add("  FROM os_catalog_item src")
    add("  JOIN os_catalog c ON c.id = src.catalog_id AND c.code = " + sql_text(CATALOG))
    add("  JOIN _nomenclador_dentar_match m ON m.source_codigo = src.permanent_code")
    add("ON CONFLICT (item_id, system_name, value) DO NOTHING;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 8. Relación literal navegable en la pestaña Relaciones")
    add("-- -----------------------------------------------------------------------------")
    add("CREATE TABLE IF NOT EXISTS os_catalog_relation (")
    add("    id BIGSERIAL PRIMARY KEY,")
    add("    source_item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,")
    add("    target_item_id INT NOT NULL REFERENCES os_catalog_item(id) ON DELETE CASCADE,")
    add("    relation_type VARCHAR(60) NOT NULL CHECK (relation_type IN (")
    add("        'alternate_benefit', 'billed_in_conjunction_with', 'concurrent_to',")
    add("        'denied_as_integral', 'frequency_limitations', 'integral_to',")
    add("        'interchangeable_with', 'not_paid_separately', 'not_to_be_used_with',")
    add("        'paid_as_code', 'procedure_code_not_used_for', 'refer_to_details',")
    add("        'referencia_literal', 'shares_frequency_limitation_with',")
    add("        'used_in_combination_with'")
    add("    )),")
    add("    source_system_code VARCHAR(30) NOT NULL DEFAULT 'CDT-2025',")
    add("    source_field VARCHAR(30) NOT NULL CHECK (source_field IN ('description', 'procedure', 'notes', 'req')),")
    add("    source_value VARCHAR(20) NOT NULL,")
    add("    context_text TEXT,")
    add("    source_cdt_id INT,")
    add("    review_status VARCHAR(20) NOT NULL DEFAULT 'reviewed'")
    add("        CHECK (review_status IN ('draft', 'reviewed', 'approved', 'deprecated')),")
    add("    provenance TEXT NOT NULL,")
    add("    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,")
    add("    CONSTRAINT ck_os_catalog_relation_not_self CHECK (source_item_id <> target_item_id),")
    add("    CONSTRAINT uq_os_catalog_relation UNIQUE")
    add("        (source_item_id, target_item_id, relation_type, source_system_code,")
    add("         source_field, source_value, context_text)")
    add(");")
    add("")
    add("CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_source")
    add("    ON os_catalog_relation (source_item_id);")
    add("CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_target")
    add("    ON os_catalog_relation (target_item_id);")
    add("CREATE INDEX IF NOT EXISTS idx_os_catalog_relation_type")
    add("    ON os_catalog_relation (relation_type);")
    add("")
    add("DELETE FROM os_catalog_relation r")
    add(" USING os_catalog_item src, os_catalog c, _nomenclador_dentar_match m")
    add(" WHERE (r.source_item_id = src.id AND r.target_item_id = m.dentar_item_id")
    add("        OR r.source_item_id = m.dentar_item_id AND r.target_item_id = src.id)")
    add("   AND src.catalog_id = c.id AND c.code = " + sql_text(CATALOG))
    add("   AND src.permanent_code = m.source_codigo")
    add("   AND r.relation_type = 'referencia_literal'")
    add("   AND r.source_system_code = " + sql_text(SYSTEM) + ";")
    add("")
    add("INSERT INTO os_catalog_relation")
    add("    (source_item_id, target_item_id, relation_type, source_system_code,")
    add("     source_field, source_value, context_text, review_status, provenance)")
    add("SELECT src.id, m.dentar_item_id, 'referencia_literal', " + sql_text(SYSTEM) + ",")
    add("       'description', m.source_codigo,")
    add("       'Código de origen ' || m.source_codigo || '; código permanente destino ' || m.dentar_code || "
        "'. Referencia literal sin juicio de equivalencia clínica.',")
    add("       'reviewed',")
    add("       'tools/sources/odontologico/odontologico.sql · vínculo por " + SYSTEM + "'")
    add("  FROM os_catalog_item src")
    add("  JOIN os_catalog c ON c.id = src.catalog_id AND c.code = " + sql_text(CATALOG))
    add("  JOIN _nomenclador_dentar_match m ON m.source_codigo = src.permanent_code")
    add("UNION ALL")
    add("SELECT m.dentar_item_id, src.id, 'referencia_literal', " + sql_text(SYSTEM) + ",")
    add("       'description', m.dentar_code,")
    add("       'Código permanente DENTAR ' || m.dentar_code || '; código de origen ' || m.source_codigo || "
        "'. Referencia literal sin juicio de equivalencia clínica.',")
    add("       'reviewed',")
    add("       'tools/sources/odontologico/odontologico.sql · vínculo por " + SYSTEM + "'")
    add("  FROM os_catalog_item src")
    add("  JOIN os_catalog c ON c.id = src.catalog_id AND c.code = " + sql_text(CATALOG))
    add("  JOIN _nomenclador_dentar_match m ON m.source_codigo = src.permanent_code")
    add("ON CONFLICT DO NOTHING;")
    add("")

    add("-- -----------------------------------------------------------------------------")
    add("-- 9. Verificación mínima (consultas de control, no aserciones)")
    add("-- -----------------------------------------------------------------------------")
    add("-- SELECT count(*) FROM os_catalog_item i JOIN os_catalog c ON c.id = i.catalog_id")
    add("--  WHERE c.code = " + sql_text(CATALOG) + ";  -- esperado: 135")
    add("-- SELECT count(*) FROM os_catalog_source_attribute")
    add("--  WHERE source_catalog_code = " + sql_text(CATALOG) + ";  -- esperado: 1485 + mapeos DENTAR")
    add("-- SELECT count(*) FROM os_catalog_relation WHERE source_system_code = " + sql_text(SYSTEM) + ";")
    add("")
    add("COMMIT;")

    return "\n".join(out) + "\n"


if __name__ == "__main__":
    content = build()
    with open(OUTPUT, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)
    print("Generado " + os.path.relpath(OUTPUT, ROOT))
