<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Controllers;

use OrigenSalud\Portal\Admin\AdminGuard;
use OrigenSalud\Portal\Admin\Rbac;
use OrigenSalud\Portal\Repositories\RelationAdminRepository;
use OrigenSalud\Portal\Repositories\RepositoryException;
use OrigenSalud\Portal\View;
use OrigenSalud\Web\I18n;

/**
 * CRUD directo y auditable de relaciones, mapeos y pares CAO/Regional ↔ OFT-PR.
 *
 * Requiere `catalog.view` para consultar y `catalog.edit_draft` para escribir.
 * Los cambios quedan en estado no publicable (`draft` / `proposed`) y la baja
 * es lógica (`deprecated` / `rejected`). Ninguna acción fija `approved`.
 */
final class AdminRelationController
{
    /** @var array<string, string> */
    private const MESSAGES = [
        'create' => 'relation_created',
        'update' => 'relation_updated',
        'delete' => 'relation_deleted',
    ];

    public static function index(): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.view']);
        $entity = self::entity();
        $query = self::query();
        $edit = self::edit();
        $repo = new RelationAdminRepository();

        try {
            $options = $repo->options();
            $all = [
                'catalog_relation' => $repo->relations($query),
                'concept_mapping' => $repo->mappings($query),
                'nomenclador_match' => $repo->matches($query),
            ];
        } catch (RepositoryException) {
            $options = [];
            $all = [
                'catalog_relation' => [],
                'concept_mapping' => [],
                'nomenclador_match' => [],
            ];
        }

        $editing = null;

        if ($edit !== null) {
            foreach ($all[$edit['entity']] as $row) {
                if (self::rowKey($edit['entity'], $row) === $edit['key']) {
                    $editing = $row;
                    break;
                }
            }
        }

        $target = null;

        if ($editing !== null && $edit !== null && $edit['entity'] === 'nomenclador_match') {
            try {
                $target = $repo->matchTarget((string) ($editing['target_code'] ?? ''));
            } catch (RepositoryException) {
                $target = null;
            }
        }

        $flash = AdminForm::pull();
        $flashValues = is_array($flash['values'] ?? null) ? $flash['values'] : [];

        self::render($current, [
            'entities' => RelationAdminRepository::ENTITIES,
            'entity' => $entity,
            'query' => $query,
            'rows' => $entity === '' ? $all : [$entity => $all[$entity] ?? []],
            'editing' => $editing,
            'editKey' => $edit['key'] ?? '',
            'options' => $options,
            'target' => $target,
            'flashValues' => $flashValues,
            'canWrite' => Rbac::hasPermission(
                $current['permissions'] ?? [],
                'catalog.edit_draft'
            ),
            'flash' => $flash,
        ]);
    }

    public static function create(): void
    {
        self::save('create');
    }

    public static function update(): void
    {
        self::save('update');
    }

    public static function delete(): void
    {
        self::save('delete');
    }

    private static function save(string $action): void
    {
        $current = AdminGuard::require(['permission' => 'catalog.edit_draft']);
        AdminForm::requirePost();

        $entity = self::posted('entity');
        $back = '/admin/relations';

        if ($entity !== '') {
            $back .= '?entity=' . rawurlencode($entity);
        }

        if (!AdminForm::validCsrf()) {
            AdminForm::fail($back, 'csrf');
        }

        if (!array_key_exists($entity, RelationAdminRepository::ENTITIES)) {
            AdminForm::fail($back, 'relation_entity_invalid');
        }

        $reason = self::posted('reason');

        if (mb_strlen($reason) < 4) {
            AdminForm::fail($back, 'relation_reason_required', self::values());
        }

        $repo = new RelationAdminRepository();

        try {
            [$id, $payload] = self::payload($repo, $entity, $action);
            $repo->write($entity, $action, $id, $payload, $reason, $current);
        } catch (RepositoryException $exception) {
            AdminForm::exception($back, $exception, self::values());
        } catch (\RuntimeException $exception) {
            AdminForm::fail($back, $exception->getMessage(), self::values());
        }

        AdminForm::success($back, self::MESSAGES[$action]);
    }

    /**
     * @return array{int, array<string, mixed>}
     */
    private static function payload(RelationAdminRepository $repo, string $entity, string $action): array
    {
        $id = self::postedInt('id');

        if ($entity === 'catalog_relation') {
            $source = $repo->itemByCode(self::posted('source_code'));
            $target = $repo->itemByCode(self::posted('target_code'));

            if ($action === 'create' && ($source === null || $target === null)) {
                throw new \RuntimeException('relation_item_not_found');
            }

            $payload = [
                'source_item_id' => (string) ($source['id'] ?? ''),
                'target_item_id' => (string) ($target['id'] ?? ''),
                'relation_type' => self::posted('relation_type'),
                'source_system_code' => self::posted('source_system_code'),
                'source_field' => self::posted('source_field'),
                'source_value' => self::posted('source_value'),
                'context_text' => self::posted('context_text'),
                'provenance' => self::posted('provenance'),
            ];

            return [$id, $payload];
        }

        if ($entity === 'concept_mapping') {
            $item = $repo->itemByCode(self::posted('item_code'));

            if ($action === 'create' && $item === null) {
                throw new \RuntimeException('relation_item_not_found');
            }

            $payload = [
                'item_id' => (string) ($item['id'] ?? ''),
                'terminology_system_id' => self::posted('terminology_system_id'),
                'external_code' => self::posted('external_code'),
                'external_display' => self::posted('external_display'),
                'mapping_type' => self::posted('mapping_type'),
                'relationship_role' => self::posted('relationship_role'),
                'clinical_rationale' => self::posted('clinical_rationale'),
            ];

            return [$id, $payload];
        }

        $payload = [
            'source_catalog_code' => self::posted('source_catalog_code'),
            'source_code' => self::posted('source_code'),
            'target_catalog_code' => self::posted('target_catalog_code') ?: 'oftar-pr',
            'target_code' => self::posted('target_code'),
            'match_basis' => self::posted('match_basis'),
            'source_term' => self::posted('source_term'),
            'target_term' => self::posted('target_term'),
            'provenance' => self::posted('provenance'),
            'notes' => self::posted('notes'),
        ];

        return [$id, $payload];
    }

    /**
     * @param array<string, mixed> $current
     * @param array<string, mixed> $extra
     */
    private static function render(array $current, array $extra): void
    {
        View::render('admin/relations/index', $extra + [
            'pageTitle' => 'Relaciones | Origen Salud',
            'pageDescription' => 'Gestión auditable de relaciones y mapeos.',
            'locale' => I18n::locale(),
            'currentPath' => '/admin/relations',
            'adminUser' => $current['user'],
            'current' => $current,
        ], 'admin');
    }

    private static function posted(string $key): string
    {
        $value = $_POST[$key] ?? '';

        return is_string($value) ? trim(mb_substr($value, 0, 1000)) : '';
    }

    private static function postedInt(string $key): int
    {
        $value = self::posted($key);

        return ctype_digit($value) ? (int) $value : 0;
    }

    /** @return array<string, string> */
    private static function values(): array
    {
        $values = [];

        foreach ([
            'entity', 'id', 'source_code', 'target_code', 'relation_type',
            'source_system_code', 'source_field', 'source_value', 'context_text',
            'item_code', 'terminology_system_id', 'external_code', 'external_display',
            'mapping_type', 'relationship_role', 'clinical_rationale',
            'source_catalog_code', 'source_code', 'target_catalog_code', 'target_code',
            'match_basis', 'source_term', 'target_term', 'provenance', 'notes', 'reason',
        ] as $key) {
            $value = self::posted($key);

            if ($value !== '') {
                $values[$key] = $value;
            }
        }

        return $values;
    }

    private static function entity(): string
    {
        $entity = $_GET['entity'] ?? '';

        return is_string($entity) && array_key_exists($entity, RelationAdminRepository::ENTITIES)
            ? $entity
            : '';
    }

    private static function query(): string
    {
        $query = $_GET['q'] ?? '';

        return is_string($query) ? trim(mb_substr($query, 0, 80)) : '';
    }

    /** @return array{entity: string, key: string}|null */
    private static function edit(): ?array
    {
        $entity = self::entity();
        $key = $_GET['edit'] ?? '';

        if ($entity === '' || !is_string($key) || $key === '') {
            return null;
        }

        return ['entity' => $entity, 'key' => trim(mb_substr($key, 0, 160))];
    }

    /** @param array<string, mixed> $row */
    private static function rowKey(string $entity, array $row): string
    {
        if ($entity === 'nomenclador_match') {
            return (string) ($row['source_catalog_code'] ?? '') . ':' . (string) ($row['source_code'] ?? '');
        }

        return (string) ($row['id'] ?? '');
    }
}
