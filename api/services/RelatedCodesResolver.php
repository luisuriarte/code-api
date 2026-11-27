<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

use PDO;

/**
 * Resuelve códigos relacionados (mapeos transversales entre catálogos y terminologías)
 * y valoración UVR publicada para un concepto/ítem sanitario.
 */
final class RelatedCodesResolver
{
    /** @var array<string, bool> */
    private array $tableCache = [];

    public function __construct(private readonly PDO $db)
    {
    }

    /**
     * @return array{codes: list<array<string, mixed>>, uvr: list<array<string, mixed>>}
     */
    public function resolve(
        ?int $snomedConceptId = null,
        ?string $catalogCode = null,
        ?int $itemId = null,
        ?string $officialCode = null,
        string $language = 'es'
    ): array {
        $codes = [];
        $seen = [];

        $add = static function (
            string $system,
            string $code,
            ?string $display,
            string $relation = 'related',
            ?string $extra = null
        ) use (&$codes, &$seen, $catalogCode, $officialCode): void {
            $code = trim($code);
            if ($code === '') {
                return;
            }
            if ($catalogCode !== null && $officialCode !== null
                && strtolower($system) === strtolower($catalogCode)
                && $code === $officialCode
            ) {
                return;
            }

            $key = strtolower($system) . '|' . $code;
            if (isset($seen[$key])) {
                return;
            }
            $seen[$key] = true;

            $entry = [
                'system' => $system,
                'code' => $code,
                'display' => $display !== null ? trim($display) : null,
                'relationship' => $relation,
            ];
            if ($extra !== null && $extra !== '') {
                $entry['detail'] = $extra;
            }
            $codes[] = $entry;
        };

        $this->collectPrestacionCodes($add, $catalogCode, $itemId, $officialCode);

        if ($snomedConceptId !== null && $snomedConceptId > 0) {
            $this->collectBySnomed($add, $snomedConceptId, $language);
        }

        $uvr = $this->collectUvr($catalogCode, $itemId, $officialCode);

        return [
            'codes' => $codes,
            'uvr' => $uvr,
        ];
    }

    private function collectPrestacionCodes(
        callable $add,
        ?string $catalogCode,
        ?int $itemId,
        ?string $officialCode
    ): void {
        if (!$this->hasTable('public.os_prestacion_codigo')) {
            return;
        }
        if ($itemId === null && ($catalogCode === null || $officialCode === null)) {
            return;
        }

        $sql = 'SELECT pc2.catalog_code,
                       COALESCE(pc2.external_code, i2.permanent_code) AS code,
                       p.display_name,
                       pc2.correspondence_type
                  FROM os_prestacion_codigo pc1
                  JOIN os_prestacion_codigo pc2 ON pc2.prestacion_id = pc1.prestacion_id
                  JOIN os_prestacion p ON p.id = pc2.prestacion_id
                  LEFT JOIN os_catalog_item i2 ON i2.id = pc2.item_id
                 WHERE pc2.review_status IN (\'approved\', \'draft\')';

        $params = [];
        if ($itemId !== null) {
            $sql .= ' AND pc1.item_id = :item_id';
            $params[':item_id'] = $itemId;
        } else {
            $sql .= ' AND pc1.catalog_code = :cat_code AND pc1.external_code = :ext_code';
            $params[':cat_code'] = $catalogCode;
            $params[':ext_code'] = $officialCode;
        }
        $sql .= ' LIMIT 25';

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);
        foreach ($stmt->fetchAll() as $row) {
            $add(
                (string) $row['catalog_code'],
                (string) $row['code'],
                $row['display_name'] !== null ? (string) $row['display_name'] : null,
                (string) $row['correspondence_type']
            );
        }
    }

    private function collectBySnomed(callable $add, int $snomedId, string $language): void
    {
        if ($this->hasTable('public.map_snomed_cie10') && $this->hasTable('public.cie10_codes')) {
            $langCode = str_starts_with(strtolower($language), 'en') ? 'en' : 'es';
            $stmt = $this->db->prepare(
                'SELECT c.codigo,
                        COALESCE(d_pref.descripcion, d_any.descripcion) AS descripcion
                   FROM map_snomed_cie10 m
                   JOIN cie10_codes c ON c.id = m.cie10_id
                   LEFT JOIN LATERAL (
                       SELECT descripcion FROM cie10_descriptions
                        WHERE cie10_id = c.id AND language_code = :lang
                        LIMIT 1
                   ) d_pref ON TRUE
                   LEFT JOIN LATERAL (
                       SELECT descripcion FROM cie10_descriptions
                        WHERE cie10_id = c.id
                        LIMIT 1
                   ) d_any ON TRUE
                  WHERE m.snomed_concept_id = :sctid
                  ORDER BY m.map_group, m.map_priority
                  LIMIT 15'
            );
            $stmt->execute([':sctid' => $snomedId, ':lang' => $langCode]);
            foreach ($stmt->fetchAll() as $row) {
                $add('CIE-10', (string) $row['codigo'], $row['descripcion'] !== null ? (string) $row['descripcion'] : null, 'mapped');
            }
        }

        if ($this->hasTable('public.map_snomed_nbu')) {
            $stmt = $this->db->prepare(
                'SELECT codigo_nbu, determinacion
                   FROM map_snomed_nbu
                  WHERE snomed_concept_id = :sctid AND activo = TRUE
                  LIMIT 15'
            );
            $stmt->execute([':sctid' => $snomedId]);
            foreach ($stmt->fetchAll() as $row) {
                $add('NBU', (string) $row['codigo_nbu'], (string) $row['determinacion'], 'mapped');
            }
        }

        if ($this->hasTable('public.nomencladores_argentina')) {
            $stmt = $this->db->prepare(
                'SELECT tipo_nomenclador, codigo, descripcion
                   FROM nomencladores_argentina
                  WHERE snomed_concept_id = :sctid AND activo = TRUE
                  LIMIT 15'
            );
            $stmt->execute([':sctid' => $snomedId]);
            foreach ($stmt->fetchAll() as $row) {
                $add((string) $row['tipo_nomenclador'], (string) $row['codigo'], (string) $row['descripcion'], 'equivalent');
            }
        }

        if ($this->hasTable('public.imagenes_practicas')) {
            $stmt = $this->db->prepare(
                'SELECT codigo_estudio, nombre_estudio, modalidad_dicom
                   FROM imagenes_practicas
                  WHERE snomed_concept_id = :sctid AND activo = TRUE
                  LIMIT 10'
            );
            $stmt->execute([':sctid' => $snomedId]);
            foreach ($stmt->fetchAll() as $row) {
                $add(
                    'IMAGENES',
                    (string) $row['codigo_estudio'],
                    (string) $row['nombre_estudio'],
                    'equivalent',
                    'DICOM: ' . (string) $row['modalidad_dicom']
                );
            }
        }

        if ($this->hasTable('public.laboratorio_practicas')) {
            $stmt = $this->db->prepare(
                'SELECT codigo_loinc, nombre_prueba
                   FROM laboratorio_practicas
                  WHERE snomed_concept_id = :sctid AND activo = TRUE AND codigo_loinc IS NOT NULL
                  LIMIT 10'
            );
            $stmt->execute([':sctid' => $snomedId]);
            foreach ($stmt->fetchAll() as $row) {
                $add('LOINC', (string) $row['codigo_loinc'], (string) $row['nombre_prueba'], 'equivalent');
            }
        }

        if ($this->hasTable('public.programas_sociales_items') && $this->hasTable('public.programas_sociales')) {
            $stmt = $this->db->prepare(
                'SELECT ps.codigo AS programa, psi.tipo_item, psi.termino
                   FROM programas_sociales_items psi
                   JOIN programas_sociales ps ON ps.id = psi.programa_id
                  WHERE psi.snomed_concept_id = :sctid AND psi.active = TRUE
                  LIMIT 10'
            );
            $stmt->execute([':sctid' => $snomedId]);
            foreach ($stmt->fetchAll() as $row) {
                $add((string) $row['programa'], (string) $snomedId, (string) $row['termino'], 'program', (string) $row['tipo_item']);
            }
        }

        if ($this->hasTable('public.map_gtin')) {
            $stmt = $this->db->prepare(
                'SELECT gtin, rpcd_fsn, condicion
                   FROM map_gtin
                  WHERE snomed_concept_id = :sctid AND activo = TRUE
                  LIMIT 10'
            );
            $stmt->execute([':sctid' => $snomedId]);
            foreach ($stmt->fetchAll() as $row) {
                $add('GTIN', (string) $row['gtin'], $row['rpcd_fsn'] !== null ? (string) $row['rpcd_fsn'] : null, 'gtin', (string) $row['condicion']);
            }
        }
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function collectUvr(?string $catalogCode, ?int $itemId, ?string $officialCode): array
    {
        if (!$this->hasTable('public.v_os_uvr_prestacion_public')) {
            return [];
        }
        if ($itemId === null && ($catalogCode === null || $officialCode === null)) {
            return [];
        }

        $sql = 'SELECT profile_code,
                       methodology,
                       scope,
                       version_tag,
                       work_uvr,
                       practice_expense_uvr,
                       professional_liability_uvr,
                       total_uvr,
                       currency,
                       importe_referencial
                  FROM public.v_os_uvr_prestacion_public
                 WHERE 1=1';
        $params = [];
        if ($itemId !== null) {
            $sql .= ' AND item_id = :item_id';
            $params[':item_id'] = $itemId;
        } else {
            $sql .= ' AND catalog_code = :cat_code AND external_code = :ext_code';
            $params[':cat_code'] = $catalogCode;
            $params[':ext_code'] = $officialCode;
        }
        $sql .= ' LIMIT 10';

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);

        $out = [];
        foreach ($stmt->fetchAll() as $row) {
            $out[] = [
                'profile_code' => (string) $row['profile_code'],
                'methodology' => (string) $row['methodology'],
                'scope' => (string) $row['scope'],
                'version' => (string) $row['version_tag'],
                'work_uvr' => $row['work_uvr'] !== null ? (float) $row['work_uvr'] : null,
                'practice_expense_uvr' => $row['practice_expense_uvr'] !== null ? (float) $row['practice_expense_uvr'] : null,
                'professional_liability_uvr' => $row['professional_liability_uvr'] !== null ? (float) $row['professional_liability_uvr'] : null,
                'total_uvr' => $row['total_uvr'] !== null ? (float) $row['total_uvr'] : null,
                'currency' => $row['currency'] !== null ? (string) $row['currency'] : null,
                'reference_amount' => $row['importe_referencial'] !== null ? (float) $row['importe_referencial'] : null,
            ];
        }

        return $out;
    }

    private function hasTable(string $regname): bool
    {
        if (isset($this->tableCache[$regname])) {
            return $this->tableCache[$regname];
        }

        $stmt = $this->db->prepare('SELECT to_regclass(:name) IS NOT NULL');
        $stmt->execute([':name' => $regname]);
        $exists = (bool) $stmt->fetchColumn();
        $this->tableCache[$regname] = $exists;

        return $exists;
    }
}
