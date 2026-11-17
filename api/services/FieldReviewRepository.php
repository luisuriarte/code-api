<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Services;

use PDO;

/**
 * Lectura de os_field_review para el evaluador editorial (D-28, D-31).
 *
 * No selecciona idioma: solo entrega las revisiones vigentes de un campo.
 * La precedencia release > global se aplica aquí, sin heredar revisiones de
 * otros releases.
 */
final class FieldReviewRepository
{
    /**
     * @var array<string, array<string, list<array<string, mixed>>>>
     */
    private array $byFieldLanguage = [];

    /**
     * @param list<array<string, mixed>> $rows
     */
    private function __construct(array $rows)
    {
        foreach ($rows as $row) {
            $field = (string) ($row['field_name'] ?? '');
            $language = strtolower(trim((string) ($row['language_code'] ?? '')));

            if ($field === '' || $language === '') {
                continue;
            }

            $this->byFieldLanguage[$field][$language][] = [
                'target_table' => (string) ($row['target_table'] ?? ''),
                'target_id' => (int) ($row['target_id'] ?? 0),
                'field_name' => $field,
                'language_code' => (string) ($row['language_code'] ?? ''),
                'scope_release_id' => isset($row['scope_release_id']) && $row['scope_release_id'] !== null
                    ? (int) $row['scope_release_id']
                    : null,
                'source_language_code' => isset($row['source_language_code'])
                    ? ($row['source_language_code'] === null ? null : (string) $row['source_language_code'])
                    : null,
                'language_evidence' => (string) ($row['language_evidence'] ?? 'undetermined'),
                'provenance' => (string) ($row['provenance'] ?? 'unknown'),
                'review_status' => (string) ($row['review_status'] ?? 'unknown'),
                'source_reference' => isset($row['source_reference'])
                    ? ($row['source_reference'] === null ? null : (string) $row['source_reference'])
                    : null,
                'reviewed_by' => isset($row['reviewed_by'])
                    ? ($row['reviewed_by'] === null ? null : (string) $row['reviewed_by'])
                    : null,
                'reviewed_at' => isset($row['reviewed_at'])
                    ? ($row['reviewed_at'] === null ? null : (string) $row['reviewed_at'])
                    : null,
                'content_hash' => (string) ($row['content_hash'] ?? ''),
            ];
        }
    }

    /**
     * @param list<array<string, mixed>> $rows
     */
    public static function fromArrays(array $rows): self
    {
        return new self($rows);
    }

    /**
     * @param list<string> $fieldNames
     */
    public static function fromPdo(
        PDO $pdo,
        string $targetTable,
        int $targetId,
        array $fieldNames
    ): self {
        return self::fromPdoForTargets($pdo, [$targetTable], [$targetId], $fieldNames);
    }

    /**
     * Carga revisiones de varias tablas/filas destino sin mezclar ids entre sí.
     * Cada variante pasa su target_id al evaluador para que nunca herede una
     * aprobación de otra fila (D-28).
     *
     * @param list<string> $targetTables
     * @param list<int> $targetIds
     * @param list<string> $fieldNames
     */
    public static function fromPdoForTargets(
        PDO $pdo,
        array $targetTables,
        array $targetIds,
        array $fieldNames
    ): self {
        $targetTables = array_values(array_unique(array_filter($targetTables, 'is_string')));
        $targetIds = array_values(array_unique(array_map('intval', $targetIds)));
        $fieldNames = array_values(array_unique(array_filter($fieldNames, 'is_string')));

        if ($targetTables === [] || $targetIds === [] || $fieldNames === []) {
            return new self([]);
        }

        $tablePlaceholders = implode(', ', array_fill(0, count($targetTables), '?'));
        $idPlaceholders = implode(', ', array_fill(0, count($targetIds), '?'));
        $fieldPlaceholders = implode(', ', array_fill(0, count($fieldNames), '?'));

        $statement = $pdo->prepare(
            'SELECT target_table, target_id, field_name, language_code, scope_release_id,
                    source_language_code, language_evidence, provenance, review_status,
                    source_reference, reviewed_by, reviewed_at, content_hash
               FROM os_field_review
              WHERE target_table IN (' . $tablePlaceholders . ')
                AND target_id IN (' . $idPlaceholders . ')
                AND field_name IN (' . $fieldPlaceholders . ')'
        );

        $statement->execute(array_merge($targetTables, $targetIds, $fieldNames));

        return new self($statement->fetchAll());
    }

    public function hasAny(string $fieldName, string $languageCode): bool
    {
        return isset($this->byFieldLanguage[$fieldName][strtolower(trim($languageCode))]);
    }

    /**
     * Indica si existe una revisión aplicable que impide usar la aprobación
     * compartida de la fila (D-07/D-28) o cuyo hash fue invalidado (D-31).
     */
    public function hasBlockingReview(
        string $fieldName,
        string $languageCode,
        ?int $releaseId,
        string $contentHash,
        ?int $targetId = null
    ): bool {
        $rows = $this->byFieldLanguage[$fieldName][strtolower(trim($languageCode))] ?? [];

        foreach ($rows as $row) {
            if ($targetId !== null && $row['target_id'] !== $targetId) {
                continue;
            }

            $scope = $row['scope_release_id'];

            if ($scope === null) {
                //global
            } elseif ($releaseId !== null && $scope === $releaseId) {
                //release solicitado
            } else {
                continue;
            }

            if ($row['review_status'] !== 'approved') {
                return true;
            }

            if ($contentHash !== '' && $row['content_hash'] !== '' && $row['content_hash'] !== $contentHash) {
                return true;
            }
        }

        return false;
    }

    /**
     * Devuelve la revisión aprobada con mayor precedencia para el release pedido.
     *
     * @return array<string, mixed>|null
     */
    public function bestApproved(
        string $fieldName,
        string $languageCode,
        ?int $releaseId,
        string $contentHash,
        ?int $targetId = null
    ): ?array {
        $rows = $this->byFieldLanguage[$fieldName][strtolower(trim($languageCode))] ?? [];
        $best = null;
        $bestScore = -1;

        foreach ($rows as $row) {
            if ($targetId !== null && $row['target_id'] !== $targetId) {
                continue;
            }

            if ($row['review_status'] !== 'approved') {
                continue;
            }

            $scope = $row['scope_release_id'];

            if ($scope === null) {
                $score = 2;
            } elseif ($releaseId !== null && $scope === $releaseId) {
                $score = 3;
            } else {
                // Una revisión específica de otro release no se hereda (D-28).
                continue;
            }

            if ($contentHash !== '' && $row['content_hash'] !== '' && $row['content_hash'] !== $contentHash) {
                // El texto cambió: la aprobación quedó invalidada (D-31).
                continue;
            }

            if ($score > $bestScore) {
                $best = $row;
                $bestScore = $score;
            }
        }

        return $best;
    }
}
