<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;

/** @var array<string, string> $entities */
/** @var string $entity */
/** @var string $query */
/** @var array<string, list<array<string, mixed>>> $rows */
/** @var array<string, mixed>|null $editing */
/** @var string $editKey */
/** @var array<string, mixed> $options */
/** @var array<string, mixed>|null $target */
/** @var array<string, string> $flashValues */
/** @var bool $canWrite */
/** @var array<string, mixed> $current */
/** @var string $catalog */
/** @var int $itemId */
/** @var array<string, mixed>|null $focus */
/** @var list<array<string, mixed>>|null $candidates */
/** @var bool $focusError */

require __DIR__ . '/../_flash.php';

$options = is_array($options ?? null) ? $options : [];
$relations = is_array($options['relation_types'] ?? null) ? $options['relation_types'] : [];
$sourceFields = is_array($options['source_fields'] ?? null) ? $options['source_fields'] : [];
$mappingTypes = is_array($options['mapping_types'] ?? null) ? $options['mapping_types'] : [];
$roles = is_array($options['relationship_roles'] ?? null) ? $options['relationship_roles'] : [];
$basis = is_array($options['match_basis'] ?? null) ? $options['match_basis'] : [];
$systems = is_array($options['systems'] ?? null) ? $options['systems'] : [];
$catalogs = is_array($options['catalogs'] ?? null) ? $options['catalogs'] : [];
$matchTargets = is_array($options['match_targets'] ?? null) ? $options['match_targets'] : [];
$flashValues = is_array($flashValues ?? null) ? $flashValues : [];
$editing = is_array($editing ?? null) ? $editing : [];
$catalog = is_string($catalog ?? null) ? $catalog : '';
$itemId = is_int($itemId ?? null) ? $itemId : 0;
$focus = is_array($focus ?? null) ? $focus : null;
$candidates = is_array($candidates ?? null) ? $candidates : null;
$focusError = (bool) ($focusError ?? false);

$value = static function (string $key, string $default = '') use ($flashValues, $editing): string {
    if (is_string($flashValues[$key] ?? null) && $flashValues[$key] !== '') {
        return (string) $flashValues[$key];
    }

    return is_string($editing[$key] ?? null) ? (string) $editing[$key] : $default;
};

$isEdit = $editKey !== '';
$activeEntity = $entity !== '' ? $entity : 'catalog_relation';
$focusParams = $itemId > 0
    ? '&catalog=' . rawurlencode($catalog) . '&item=' . $itemId
    : '';
$base = static fn (string $targetEntity): string => '/admin/relations?entity='
    . rawurlencode($targetEntity) . $focusParams;
$editHref = static function (string $targetEntity, string $key) use ($base): string {
    return $base($targetEntity) . '&edit=' . rawurlencode($key);
};
$rowKey = static function (string $targetEntity, array $row): string {
    if ($targetEntity === 'nomenclador_match') {
        return (string) ($row['source_catalog_code'] ?? '') . ':' . (string) ($row['source_code'] ?? '');
    }

    return (string) ($row['id'] ?? '');
};
?>
<section class="space-y-6">
    <article class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-teal-dark"><?= e($t('nav.management')) ?></p>
                <h1 class="ui-title"><?= e($t('admin.relations.title')) ?></h1>
                <p class="ui-subtitle"><?= e($t('admin.relations.lead')) ?></p>
            </div>
            <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
                <i data-lucide="git-fork" class="h-5 w-5"></i>
            </span>
        </div>
        <div class="ui-alert mt-5 border-amber-200 bg-amber-50 text-amber-900" role="note">
            <i data-lucide="shield-alert" class="h-4 w-4 shrink-0"></i>
            <p><?= e($t('admin.relations.draft_notice')) ?></p>
        </div>
    </article>

    <article class="ui-card ui-card-pad">
        <div class="mb-4 flex flex-wrap items-start justify-between gap-3">
            <div>
                <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.relations.lookup_title')) ?></h2>
                <p class="ui-subtitle"><?= e($t('admin.relations.lookup_hint')) ?></p>
            </div>
            <?php if ($focus !== null): ?>
                <a href="/admin/relations" class="text-sm font-medium text-teal-dark hover:underline">
                    <?= e($t('admin.relations.focus_back')) ?>
                </a>
            <?php endif; ?>
        </div>

        <form method="get" action="/admin/relations" class="ui-grid items-end">
            <input type="hidden" name="lookup" value="1">
            <div>
                <label for="relation-catalog" class="ui-label"><?= e($t('admin.uvr.col_catalog')) ?></label>
                <select id="relation-catalog" name="catalog" class="ui-input">
                    <option value=""><?= e($t('admin.select')) ?></option>
                    <?php foreach ($catalogs as $catalogRow): ?>
                        <?php $catalogCode = (string) ($catalogRow['code'] ?? ''); ?>
                        <option value="<?= e($catalogCode) ?>" <?= $catalogCode === $catalog ? 'selected' : '' ?>>
                            <?= e($catalogCode) ?>
                            <?= (string) ($catalogRow['short_name'] ?? '') !== '' ? ' · ' . e((string) $catalogRow['short_name']) : '' ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div>
                <label for="relation-code" class="ui-label"><?= e($t('admin.relations.search')) ?></label>
                <input id="relation-code" name="q" value="<?= e($query) ?>" class="ui-input" maxlength="80"
                       placeholder="<?= e($t('admin.relations.lookup_placeholder')) ?>">
            </div>
            <div>
                <button type="submit" class="ui-btn ui-btn-sm"><?= e($t('admin.relations.lookup_submit')) ?></button>
            </div>
        </form>

        <?php if ($focusError): ?>
            <p class="ui-alert mt-4" role="alert"><?= e($t('admin.relations.focus_not_found')) ?></p>
        <?php endif; ?>

        <?php if ($focus !== null): ?>
            <dl class="ui-dl mt-5 rounded-xl border border-line bg-paper/70 p-4">
                <dt class="ui-dt"><?= e($t('admin.relations.focus_code')) ?></dt>
                <dd class="ui-dd"><code class="ui-code"><?= e((string) ($focus['permanent_code'] ?? '')) ?></code></dd>
                <dt class="ui-dt"><?= e($t('admin.uvr.col_catalog')) ?></dt>
                <dd class="ui-dd"><code class="ui-code"><?= e((string) ($focus['catalog_code'] ?? '')) ?></code></dd>
                <dt class="ui-dt"><?= e($t('admin.catalogs.col_term')) ?></dt>
                <dd class="ui-dd"><?= e((string) ($focus['display'] ?? '')) ?></dd>
                <?php if ((string) ($focus['identifiers'] ?? '') !== ''): ?>
                    <dt class="ui-dt"><?= e($t('admin.relations.candidate_identifiers')) ?></dt>
                    <dd class="ui-dd"><code class="ui-code"><?= e((string) $focus['identifiers']) ?></code></dd>
                <?php endif; ?>
            </dl>
        <?php elseif ($candidates !== null): ?>
            <?php if ($candidates === []): ?>
                <p class="ui-empty mt-5"><?= e($t('admin.relations.lookup_empty')) ?></p>
            <?php else: ?>
                <div class="ui-table-wrap mt-5">
                    <table class="ui-table">
                        <thead>
                        <tr>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_code')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_catalog')) ?></th>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_term')) ?></th>
                            <th class="ui-th"><?= e($t('admin.relations.candidate_identifiers')) ?></th>
                            <th class="ui-th"><?= e($t('admin.relations.col_actions')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($candidates as $candidate): ?>
                            <?php
                            $candidateId = (int) ($candidate['id'] ?? 0);
                            $candidateCatalog = (string) ($candidate['catalog_code'] ?? '');
                            $candidateHref = '/admin/relations?catalog='
                                . rawurlencode($candidateCatalog) . '&item=' . $candidateId;
                            ?>
                            <tr>
                                <td class="ui-td font-mono text-xs"><code class="ui-code"><?= e((string) ($candidate['permanent_code'] ?? '')) ?></code></td>
                                <td class="ui-td"><code class="ui-code"><?= e($candidateCatalog) ?></code></td>
                                <td class="ui-td"><?= e((string) ($candidate['display'] ?? '')) ?></td>
                                <td class="ui-td font-mono text-xs"><?= e((string) ($candidate['identifiers'] ?? '')) ?></td>
                                <td class="ui-td">
                                    <a href="<?= e($candidateHref) ?>" class="text-sm font-medium text-teal-dark hover:underline">
                                        <?= e($t('admin.relations.candidate_view')) ?>
                                    </a>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        <?php endif; ?>
    </article>

    <article class="ui-card ui-card-pad">
        <form method="get" action="/admin/relations" class="ui-grid items-end">
            <div>
                <label for="relation-entity" class="ui-label"><?= e($t('admin.relations.col_entity')) ?></label>
                <select id="relation-entity" name="entity" class="ui-input" onchange="this.form.submit()">
                    <option value=""><?= e($t('admin.select')) ?></option>
                    <?php foreach ($entities as $code => $label): ?>
                        <option value="<?= e($code) ?>" <?= $code === $entity ? 'selected' : '' ?>>
                            <?= e($t('admin.relations.entity.' . $code)) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div>
                <label for="relation-q" class="ui-label"><?= e($t('admin.relations.search')) ?></label>
                <input id="relation-q" name="q" value="<?= e($query) ?>" class="ui-input" maxlength="80">
            </div>
            <div>
                <button type="submit" class="ui-btn ui-btn-sm"><?= e($t('admin.relations.search_submit')) ?></button>
            </div>
        </form>
    </article>

    <?php foreach ($entities as $entityCode => $entityLabel): ?>
        <?php if ($entity !== '' && $entity !== $entityCode) { continue; } ?>
        <?php $records = $rows[$entityCode] ?? []; ?>
        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <h2 class="text-lg font-semibold text-ink">
                    <?= e($t('admin.relations.entity.' . $entityCode)) ?>
                </h2>
                <span class="ui-badge"><?= count($records) ?></span>
            </div>

            <?php if ($records === []): ?>
                <p class="ui-subtitle"><?= e($t('admin.relations.empty')) ?></p>
            <?php else: ?>
                <div class="overflow-x-auto">
                    <table class="ui-table">
                        <thead>
                            <tr>
                                <?php if ($entityCode === 'catalog_relation'): ?>
                                    <?php if ($focus !== null): ?>
                                        <th><?= e($t('admin.relations.col_direction')) ?></th>
                                    <?php endif; ?>
                                    <th><?= e($t('admin.relations.col_source')) ?></th>
                                    <th><?= e($t('admin.relations.col_target')) ?></th>
                                    <th><?= e($t('admin.relations.col_type')) ?></th>
                                    <th><?= e($t('admin.relations.col_status')) ?></th>
                                <?php elseif ($entityCode === 'concept_mapping'): ?>
                                    <th><?= e($t('admin.relations.col_item')) ?></th>
                                    <th><?= e($t('admin.relations.col_system')) ?></th>
                                    <th><?= e($t('admin.relations.col_external')) ?></th>
                                    <th><?= e($t('admin.relations.col_status')) ?></th>
                                <?php else: ?>
                                    <th><?= e($t('admin.relations.col_pair')) ?></th>
                                    <th><?= e($t('admin.relations.col_resolved')) ?></th>
                                    <th><?= e($t('admin.relations.col_basis')) ?></th>
                                    <th><?= e($t('admin.relations.col_status')) ?></th>
                                <?php endif; ?>
                                <th><?= e($t('admin.relations.col_actions')) ?></th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($records as $record): ?>
                                <?php
                                $key = $rowKey($entityCode, $record);
                                $rowId = (string) ($record['id'] ?? '0');
                                $isCurrent = $isEdit && $activeEntity === $entityCode && $editKey === $key;
                                ?>
                                <tr class="<?= $isCurrent ? 'bg-mint/30' : '' ?>">
                                    <?php if ($entityCode === 'catalog_relation'): ?>
                                        <?php if ($focus !== null): ?>
                                            <?php $direction = (string) ($record['direction'] ?? ''); ?>
                                            <td><?= e($direction === 'out'
                                                ? $t('admin.relations.direction_out')
                                                : $t('admin.relations.direction_in')) ?></td>
                                        <?php endif; ?>
                                        <td class="font-mono text-xs"><?= e((string) ($record['source_code'] ?? '')) ?></td>
                                        <td class="font-mono text-xs"><?= e((string) ($record['target_code'] ?? '')) ?></td>
                                        <td><?= e((string) ($record['relation_type'] ?? '')) ?></td>
                                    <?php elseif ($entityCode === 'concept_mapping'): ?>
                                        <td class="font-mono text-xs"><?= e((string) ($record['item_code'] ?? '')) ?></td>
                                        <td><?= e((string) ($record['system_code'] ?? '')) ?></td>
                                        <td class="font-mono text-xs"><?= e((string) ($record['external_code'] ?? '')) ?></td>
                                    <?php else: ?>
                                        <td class="font-mono text-xs">
                                            <?= e((string) ($record['source_catalog_code'] ?? '')) ?>:
                                            <?= e((string) ($record['source_code'] ?? '')) ?>
                                            → <?= e((string) ($record['target_code'] ?? '')) ?>
                                        </td>
                                        <td>
                                            <?php if (($record['target_permanent_code'] ?? null) !== null): ?>
                                                <span class="ui-badge">
                                                    <?= e((string) $record['target_permanent_code']) ?>
                                                </span>
                                            <?php else: ?>
                                                <span class="text-amber-700">
                                                    <?= e($t('admin.relations.unresolved')) ?>
                                                </span>
                                            <?php endif; ?>
                                        </td>
                                        <td><?= e((string) ($record['match_basis'] ?? '')) ?></td>
                                    <?php endif; ?>
                                    <td><span class="ui-badge"><?= e((string) ($record['review_status'] ?? '')) ?></span></td>
                                    <td>
                                        <?php if ($canWrite): ?>
                                            <div class="flex flex-wrap items-center gap-3">
                                                <a href="<?= e($editHref($entityCode, $key)) ?>" class="text-sm font-medium text-teal-dark hover:underline">
                                                    <?= e($t('admin.relations.edit')) ?>
                                                </a>
                                                <form method="post" action="/admin/relations"
                                                      onsubmit="return confirm('<?= e($t('admin.relations.confirm_delete')) ?>');">
                                                    <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
                                                    <input type="hidden" name="op" value="delete">
                                                    <input type="hidden" name="entity" value="<?= e($entityCode) ?>">
                                                    <?php if ($entityCode === 'nomenclador_match'): ?>
                                                        <input type="hidden" name="source_catalog_code"
                                                               value="<?= e((string) ($record['source_catalog_code'] ?? '')) ?>">
                                                        <input type="hidden" name="source_code"
                                                               value="<?= e((string) ($record['source_code'] ?? '')) ?>">
                                                    <?php else: ?>
                                                        <input type="hidden" name="id" value="<?= e($rowId) ?>">
                                                    <?php endif; ?>
                                                    <input type="hidden" name="reason"
                                                           value="<?= e($t('admin.relations.delete_reason')) ?>">
                                                    <button type="submit" class="text-sm font-medium text-red-700 hover:underline">
                                                        <?= e($t('admin.relations.delete')) ?>
                                                    </button>
                                                </form>
                                            </div>
                                        <?php else: ?>
                                            <span class="text-xs text-slate-500"><?= e($t('admin.relations.read_only')) ?></span>
                                        <?php endif; ?>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </article>
    <?php endforeach; ?>

    <?php if ($canWrite): ?>
        <article class="ui-card ui-card-pad">
            <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
                <div>
                    <h2 class="text-lg font-semibold text-ink">
                        <?= e($isEdit ? $t('admin.relations.edit_title') : $t('admin.relations.new_title')) ?>
                    </h2>
                    <p class="ui-subtitle"><?= e($t('admin.relations.form_note')) ?></p>
                </div>
                <?php if ($isEdit): ?>
                    <a href="<?= e($base($activeEntity)) ?>" class="text-sm font-medium text-teal-dark hover:underline"><?= e($t('admin.relations.cancel')) ?></a>
                <?php endif; ?>
            </div>

            <form method="post" action="/admin/relations" class="space-y-5">
                <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
                <input type="hidden" name="op" value="<?= $isEdit ? 'update' : 'create' ?>">
                <input type="hidden" name="entity" value="<?= e($activeEntity) ?>">
                <input type="hidden" name="return_catalog" value="<?= e($catalog) ?>">
                <input type="hidden" name="return_item" value="<?= e((string) $itemId) ?>">
                <?php if ($isEdit && $activeEntity !== 'nomenclador_match'): ?>
                    <input type="hidden" name="id" value="<?= e($editKey) ?>">
                <?php endif; ?>

                <?php if ($activeEntity === 'catalog_relation'): ?>
                    <div class="ui-grid">
                        <div>
                            <label for="source_code" class="ui-label"><?= e($t('admin.relations.col_source')) ?></label>
                            <input id="source_code" name="source_code" class="ui-input" required
                                   value="<?= e($value('source_code')) ?>"
                                   placeholder="OFT-PR-000025">
                        </div>
                        <div>
                            <label for="target_code" class="ui-label"><?= e($t('admin.relations.col_target')) ?></label>
                            <input id="target_code" name="target_code" class="ui-input" required
                                   value="<?= e($value('target_code')) ?>">
                        </div>
                        <div class="ui-subtitle text-xs">
                            <?= e($t('admin.relations.code_hint')) ?>
                        </div>
                        <div>
                            <label for="relation_type" class="ui-label"><?= e($t('admin.relations.col_type')) ?></label>
                            <select id="relation_type" name="relation_type" class="ui-input" required>
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach ($relations as $type): ?>
                                    <option value="<?= e($type) ?>" <?= $type === $value('relation_type') ? 'selected' : '' ?>>
                                        <?= e($type) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="source_field" class="ui-label"><?= e($t('admin.relations.col_source_field')) ?></label>
                            <select id="source_field" name="source_field" class="ui-input" required>
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach ($sourceFields as $field): ?>
                                    <option value="<?= e($field) ?>" <?= $field === $value('source_field', 'description') ? 'selected' : '' ?>>
                                        <?= e($field) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="source_system_code" class="ui-label"><?= e($t('admin.relations.col_system_code')) ?></label>
                            <input id="source_system_code" name="source_system_code" class="ui-input" maxlength="30"
                                   value="<?= e($value('source_system_code', 'CDT-2025')) ?>">
                        </div>
                        <div>
                            <label for="source_value" class="ui-label"><?= e($t('admin.relations.col_source_value')) ?></label>
                            <input id="source_value" name="source_value" class="ui-input" maxlength="20" required
                                   value="<?= e($value('source_value')) ?>">
                        </div>
                    </div>
                    <div>
                        <label for="context_text" class="ui-label"><?= e($t('admin.relations.col_context')) ?></label>
                        <textarea id="context_text" name="context_text" class="ui-input" rows="2"><?= e($value('context_text')) ?></textarea>
                    </div>
                    <div>
                        <label for="provenance" class="ui-label"><?= e($t('admin.relations.col_provenance')) ?></label>
                        <input id="provenance" name="provenance" class="ui-input" required
                               value="<?= e($value('provenance')) ?>">
                    </div>

                <?php elseif ($activeEntity === 'concept_mapping'): ?>
                    <div class="ui-grid">
                        <div>
                            <label for="item_code" class="ui-label"><?= e($t('admin.relations.col_item')) ?></label>
                            <input id="item_code" name="item_code" class="ui-input" required
                                   value="<?= e($value('item_code')) ?>">
                        </div>
                        <div>
                            <label for="terminology_system_id" class="ui-label"><?= e($t('admin.relations.col_system')) ?></label>
                            <select id="terminology_system_id" name="terminology_system_id" class="ui-input" required>
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach ($systems as $system): ?>
                                    <?php $systemId = (string) ($system['id'] ?? ''); ?>
                                    <option value="<?= e($systemId) ?>"
                                        <?= $systemId === $value('terminology_system_id') ? 'selected' : '' ?>>
                                        <?= e((string) ($system['code'] ?? '')) ?>
                                        <?= (string) ($system['name'] ?? '') !== '' ? ' · ' . e((string) $system['name']) : '' ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="external_code" class="ui-label"><?= e($t('admin.relations.col_external')) ?></label>
                            <input id="external_code" name="external_code" class="ui-input" required
                                   value="<?= e($value('external_code')) ?>">
                        </div>
                        <div>
                            <label for="external_display" class="ui-label"><?= e($t('admin.relations.col_external_display')) ?></label>
                            <input id="external_display" name="external_display" class="ui-input" required
                                   value="<?= e($value('external_display')) ?>">
                        </div>
                        <div>
                            <label for="mapping_type" class="ui-label"><?= e($t('admin.relations.col_mapping_type')) ?></label>
                            <select id="mapping_type" name="mapping_type" class="ui-input">
                                <?php foreach ($mappingTypes as $type): ?>
                                    <option value="<?= e($type) ?>" <?= $type === $value('mapping_type', 'equivalent') ? 'selected' : '' ?>>
                                        <?= e($type) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="relationship_role" class="ui-label"><?= e($t('admin.relations.col_role')) ?></label>
                            <select id="relationship_role" name="relationship_role" class="ui-input">
                                <?php foreach ($roles as $role): ?>
                                    <option value="<?= e($role) ?>" <?= $role === $value('relationship_role', 'procedure_concept') ? 'selected' : '' ?>>
                                        <?= e($role) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <div>
                        <label for="clinical_rationale" class="ui-label"><?= e($t('admin.relations.col_rationale')) ?></label>
                        <textarea id="clinical_rationale" name="clinical_rationale" class="ui-input" rows="2"><?= e($value('clinical_rationale')) ?></textarea>
                    </div>

                <?php else: ?>
                    <div class="ui-grid">
                        <div>
                            <label for="source_catalog_code" class="ui-label"><?= e($t('admin.relations.col_source_catalog')) ?></label>
                            <select id="source_catalog_code" name="source_catalog_code" class="ui-input" required
                                <?= $isEdit ? 'disabled' : '' ?>>
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach ($catalogs as $catalog): ?>
                                    <?php $code = (string) ($catalog['code'] ?? ''); ?>
                                    <option value="<?= e($code) ?>"
                                        <?= $code === $value('source_catalog_code', 'nomenclador-oftalmologico-cao-ar') ? 'selected' : '' ?>>
                                        <?= e($code) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                            <?php if ($isEdit): ?>
                                <input type="hidden" name="source_catalog_code"
                                       value="<?= e($value('source_catalog_code')) ?>">
                            <?php endif; ?>
                        </div>
                        <div>
                            <label for="source_code" class="ui-label"><?= e($t('admin.relations.col_source_code')) ?></label>
                            <input id="source_code" name="source_code" class="ui-input" maxlength="20" required
                                   <?= $isEdit ? 'readonly' : '' ?>
                                   value="<?= e($value('source_code')) ?>">
                        </div>
                        <div>
                            <label for="target_catalog_code" class="ui-label"><?= e($t('admin.relations.col_target_catalog')) ?></label>
                            <input id="target_catalog_code" name="target_catalog_code" class="ui-input" maxlength="30"
                                   value="<?= e($value('target_catalog_code', 'oftar-pr')) ?>">
                        </div>
                        <div>
                            <label for="target_code" class="ui-label"><?= e($t('admin.relations.col_target_code')) ?></label>
                            <input id="target_code" name="target_code" class="ui-input" maxlength="30" required
                                   list="match-targets" value="<?= e($value('target_code')) ?>">
                            <datalist id="match-targets">
                                <?php foreach ($matchTargets as $candidate): ?>
                                    <option value="<?= e((string) ($candidate['value'] ?? '')) ?>">
                                        <?= e((string) ($candidate['permanent_code'] ?? '')) ?>
                                        · <?= e((string) ($candidate['display'] ?? '')) ?>
                                    </option>
                                <?php endforeach; ?>
                            </datalist>
                        </div>
                        <div>
                            <label for="match_basis" class="ui-label"><?= e($t('admin.relations.col_basis')) ?></label>
                            <select id="match_basis" name="match_basis" class="ui-input" required>
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach ($basis as $item): ?>
                                    <option value="<?= e($item) ?>" <?= $item === $value('match_basis') ? 'selected' : '' ?>>
                                        <?= e($item) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                    <?php if ($target !== null): ?>
                        <div class="ui-alert border-mint bg-mint/40 text-teal-dark" role="status">
                            <i data-lucide="link-2" class="h-4 w-4 shrink-0"></i>
                            <p>
                                <?= e($t('admin.relations.resolved_as')) ?>:
                                <span class="font-mono"><?= e((string) ($target['permanent_code'] ?? '')) ?></span>
                                · <?= e((string) ($target['display'] ?? '')) ?>
                            </p>
                        </div>
                    <?php endif; ?>
                    <div class="ui-grid">
                        <div>
                            <label for="source_term" class="ui-label"><?= e($t('admin.relations.col_source_term')) ?></label>
                            <input id="source_term" name="source_term" class="ui-input"
                                   value="<?= e($value('source_term')) ?>">
                        </div>
                        <div>
                            <label for="target_term" class="ui-label"><?= e($t('admin.relations.col_target_term')) ?></label>
                            <input id="target_term" name="target_term" class="ui-input"
                                   value="<?= e($value('target_term')) ?>">
                        </div>
                    </div>
                    <div>
                        <label for="provenance" class="ui-label"><?= e($t('admin.relations.col_provenance')) ?></label>
                        <input id="provenance" name="provenance" class="ui-input" required
                               value="<?= e($value('provenance')) ?>">
                    </div>
                    <div>
                        <label for="notes" class="ui-label"><?= e($t('admin.relations.col_notes')) ?></label>
                        <textarea id="notes" name="notes" class="ui-input" rows="2"><?= e($value('notes')) ?></textarea>
                    </div>
                <?php endif; ?>

                <div>
                    <label for="reason" class="ui-label"><?= e($t('admin.relations.col_reason')) ?></label>
                    <input id="reason" name="reason" class="ui-input" required minlength="4"
                           value="<?= e($value('reason')) ?>">
                    <p class="mt-1 text-xs text-slate-500"><?= e($t('admin.relations.reason_hint')) ?></p>
                </div>

                <div class="flex flex-wrap gap-3">
                    <button type="submit" class="ui-btn">
                        <?= e($isEdit ? $t('admin.relations.save') : $t('admin.relations.create')) ?>
                    </button>
                    <a href="<?= e($base($activeEntity)) ?>" class="ui-btn ui-btn-ghost no-underline">
                        <?= e($t('admin.cancel')) ?>
                    </a>
                </div>
            </form>
        </article>
    <?php endif; ?>
</section>
