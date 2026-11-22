#!/usr/bin/env python3
"""
Aplica el fix de hash editorial para OFTAR-DX.

Motivo: EditorialEvaluator comparaba el content_hash agregado de
os_catalog_item_version contra el content_hash individual de os_field_review.
Ese hash individual se calcula como valor + idioma + source_reference, igual
que en MappingReviewReader y en trg_field_review_hash().

Uso en el VPS:
    cd /var/www/html/origen.ar/code-api
    python3 tools/aplicar_fix_hash_editorial.py

Crea copias .bak.<timestamp> antes de modificar. Es idempotente: si el fix ya
está aplicado, no vuelve a tocar los archivos.
"""
from __future__ import annotations

from datetime import datetime
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

EDITS: dict[str, list[tuple[str, str]]] = {
    "api/services/CatalogEngineService.php": [
        (
            "                       ver.language_evidence AS version_language_evidence,\n"
            "                       ver.preferred_term,",
            "                       ver.language_evidence AS version_language_evidence,\n"
            "                        ver.source_reference AS version_source_reference,\n"
            "                       ver.preferred_term,",
        ),
        (
            "            'SELECT id, item_version_id, term, term_type, language_code, review_status,\n"
            "                    source_language_code, provenance, language_evidence, content_hash\n"
            "               FROM os_catalog_term",
            "            'SELECT id, item_version_id, term, term_type, language_code, review_status,\n"
            "                    source_language_code, provenance, language_evidence, content_hash,\n"
            "                    source_reference\n"
            "               FROM os_catalog_term",
        ),
        (
            "                                content_hash, scope_release_id\n"
            "                           FROM os_localized_text",
            "                                content_hash, scope_release_id, source_reference\n"
            "                           FROM os_localized_text",
        ),
        (
            "                'content_hash' => (string) $row['version_content_hash'],\n"
            "                'target_id' => (int) $row['version_id'],",
            "                'content_hash' => (string) $row['version_content_hash'],\n"
            "                'source_reference' => $row['version_source_reference'] !== null\n"
            "                    ? (string) $row['version_source_reference']\n"
            "                    : null,\n"
            "                'target_id' => (int) $row['version_id'],",
        ),
        (
            "                'content_hash' => (string) $term['content_hash'],\n"
            "                'target_id' => (int) $term['id'],",
            "                'content_hash' => (string) $term['content_hash'],\n"
            "                'source_reference' => $term['source_reference'] !== null\n"
            "                    ? (string) $term['source_reference']\n"
            "                    : null,\n"
            "                'target_id' => (int) $term['id'],",
        ),
        (
            "                'content_hash' => (string) $row['content_hash'],\n"
            "                'target_id' => (int) $row['id'],\n"
            "                'value' => (string) $row['value'],",
            "                'content_hash' => (string) $row['content_hash'],\n"
            "                'source_reference' => $row['source_reference'] !== null\n"
            "                    ? (string) $row['source_reference']\n"
            "                    : null,\n"
            "                'target_id' => (int) $row['id'],\n"
            "                'value' => (string) $row['value'],",
        ),
    ],
    "api/services/EditorialEvaluator.php": [
        (
            "            $hash = isset($variant['content_hash']) ? (string) $variant['content_hash'] : '';\n"
            "            $variantTargetId = isset($variant['target_id']) && $variant['target_id'] !== null",
            "            // D-41: en os_catalog_item_version el content_hash es agregado\n"
            "            // (row_shared), no el hash del campo. La revisión individual se\n"
            "            // valida contra valor + idioma + source_reference, igual que en\n"
            "            // MappingReviewReader y en trg_field_review_hash().\n"
            "            $sourceReference = $variant['source_reference'] ?? null;\n"
            "            $hash = array_key_exists('value', $variant) && is_scalar($variant['value'])\n"
            "                ? $this->reviews->contentHash(\n"
            "                    (string) $variant['value'],\n"
            "                    $code,\n"
            "                    $sourceReference === null ? null : (string) $sourceReference\n"
            "                )\n"
            "                : (isset($variant['content_hash']) ? (string) $variant['content_hash'] : '');\n"
            "            $variantTargetId = isset($variant['target_id']) && $variant['target_id'] !== null",
        ),
    ],
}


def main() -> int:
    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    changed = False

    for relative, replacements in EDITS.items():
        path = ROOT / relative
        if not path.is_file():
            print(f"ERROR: no existe {relative}", file=sys.stderr)
            return 1

        text = path.read_text(encoding="utf-8")
        original = text

        for old, new in replacements:
            if new in text and old not in text:
                continue  # ya aplicado
            if text.count(old) != 1:
                print(
                    f"ERROR: {relative}: se esperaba 1 coincidencia exacta, hay {text.count(old)}",
                    file=sys.stderr,
                )
                return 1
            text = text.replace(old, new, 1)

        if text == original:
            print(f"OK (sin cambios): {relative}")
            continue

        backup = path.with_suffix(path.suffix + f".bak.{stamp}")
        backup.write_text(original, encoding="utf-8")
        path.write_text(text, encoding="utf-8")
        print(f"OK (modificado): {relative} -> backup {backup.name}")
        changed = True

    if changed:
        print("Fix aplicado. Verificá con: php -l api/services/CatalogEngineService.php && php -l api/services/EditorialEvaluator.php")
    else:
        print("Fix ya estaba aplicado.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
