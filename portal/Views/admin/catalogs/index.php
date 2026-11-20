<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $catalogs */
/** @var string $catalogCode */
/** @var list<array<string, mixed>> $items */
/** @var string $query */
/** @var array<string, mixed> $current */
/** @var array<string, mixed>|null $editItem */
/** @var bool $editError */

require __DIR__ . '/_nav.php';

$catalogHref = static fn (string $code): string => '/admin/catalogs/' . rawurlencode($code);

$editDetail = is_array($editItem ?? null) ? $editItem : [];
$editRecord = is_array($editDetail['item'] ?? null) ? $editDetail['item'] : null;
$editVersions = is_array($editDetail['versions'] ?? null) ? $editDetail['versions'] : [];
$editRelations = is_array($editDetail['relations'] ?? null) ? $editDetail['relations'] : [];
$editReleases = is_array($editDetail['releases'] ?? null) ? $editDetail['releases'] : [];
$editLanguages = is_array($editDetail['languages'] ?? null) ? $editDetail['languages'] : [];
$editVersion = is_array($editVersions[0] ?? null) ? $editVersions[0] : [];
$editRelation = is_array($editRelations[0] ?? null) ? $editRelations[0] : [];
$editLanguage = is_array($editLanguages[0] ?? null) ? $editLanguages[0] : [];

$editValues = [];

if ($editRecord !== null) {
    $releaseId = (int) ($editVersion['release_id'] ?? 0);
    if ($releaseId === 0) {
        foreach ($editReleases as $release) {
            if ((string) ($release['version_tag'] ?? '') === (string) ($editVersion['version_tag'] ?? '')) {
                $releaseId = (int) ($release['id'] ?? 0);
                break;
            }
        }
    }
    $editValues = [
        'code' => $catalogCode,
        'item_id' => (string) (int) ($editRecord['id'] ?? 0),
        'permanent_code' => (string) ($editRecord['permanent_code'] ?? ''),
        'status' => (string) ($editRecord['status'] ?? ''),
        'release_id' => $releaseId > 0 ? (string) $releaseId : '',
        'version_tag' => (string) ($editVersion['version_tag'] ?? ''),
        'preferred_term' => (string) ($editVersion['preferred_term'] ?? ''),
        'definition' => (string) ($editVersion['definition'] ?? ''),
        'clinical_criteria' => (string) ($editVersion['clinical_criteria'] ?? ''),
        'language_code' => (string) ($editVersion['language_code'] ?? 'es-AR'),
    ];

    foreach ($editReleases as $release) {
        if ($releaseId > 0 && (int) ($release['id'] ?? 0) === $releaseId) {
            $editValues['valid_from'] = (string) ($release['valid_from'] ?? '');
            $editValues['valid_to'] = (string) ($release['valid_to'] ?? '');
            $editValues['release_status'] = (string) ($release['status'] ?? '');
            break;
        }
    }
}

$flashValues = is_array($flash['values'] ?? null) ? $flash['values'] : [];
$editRaw = static function (string $key, string $default = '') use ($flashValues, $editValues): string {
    if (is_string($flashValues[$key] ?? null) && $flashValues[$key] !== '') {
        return $flashValues[$key];
    }

    if (is_string($editValues[$key] ?? null) && $editValues[$key] !== '') {
        return $editValues[$key];
    }

    return $default;
};
$editValue = static fn (string $key, string $default = ''): string => e($editRaw($key, $default));
$editSelected = static fn (string $key, string $value): string => $editRaw($key) === $value ? 'selected' : '';
$editDate = static fn (string $key): string => substr($editRaw($key), 0, 10);

$editStatuses = ['active', 'retired', 'superseded'];
$editReleaseStatuses = ['draft', 'review', 'published', 'deprecated'];
$editRelationTypes = ['refer_to_details', 'used_in_combination_with', 'not_paid_separately', 'interchangeable_with'];
$editSourceFields = ['description', 'procedure', 'notes', 'req'];
$editCoverage = ['original', 'complete', 'partial', 'planned', 'undetermined'];
$editLanguageOptions = ['es-AR', 'es', 'en', 'pt-BR'];
?>
<?php if (!empty($editError)): ?>
    <div class="ui-alert border-red-200 bg-red-50 text-red-800" role="alert">
        <p class="font-medium"><?= e($t('admin.catalogs.item_not_found')) ?></p>
    </div>
<?php endif; ?>

<div class="ui-grid items-start">
    <article class="ui-card ui-card-pad">
        <div class="mb-5 flex items-start justify-between gap-4">
            <div>
                <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.select_title')) ?></h2>
                <p class="ui-subtitle"><?= e($t('admin.catalogs.lead')) ?></p>
            </div>
            <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
                <i data-lucide="library" class="h-5 w-5"></i>
            </span>
        </div>

        <form method="get" action="/admin/catalogs" class="space-y-4">
            <div>
                <label for="catalog-select" class="ui-label"><?= e($t('admin.uvr.col_catalog')) ?></label>
                <select id="catalog-select" name="code" required onchange="this.form.submit()" class="ui-input">
                    <option value=""><?= e($t('admin.select')) ?></option>
                    <?php foreach ($catalogs as $catalog): ?>
                        <?php $code = (string) ($catalog['code'] ?? ''); ?>
                        <option value="<?= e($code) ?>" <?= $code === $catalogCode ? 'selected' : '' ?>>
                            <?= e((string) ($catalog['name'] ?? $code)) ?> (<?= e($code) ?>)
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <button type="submit" class="ui-btn ui-btn-sm"><?= e($t('admin.catalogs.select_submit')) ?></button>
        </form>

        <?php if ($catalogCode !== ''): ?>
            <div class="mt-8 border-t border-line pt-6">
                <h3 class="mb-3 text-base font-semibold text-ink"><?= e($t('admin.catalogs.search_title')) ?></h3>
                <form method="get" action="<?= e($catalogHref($catalogCode)) ?>" class="flex flex-col gap-3 sm:flex-row sm:items-end">
                    <div class="flex-1">
                        <label for="catalog-search" class="ui-label"><?= e($t('admin.catalogs.search_label')) ?></label>
                        <input id="catalog-search" type="search" name="q" maxlength="80" value="<?= e($query) ?>"
                               placeholder="<?= e($t('admin.catalogs.search_placeholder')) ?>" class="ui-input">
                    </div>
                    <button type="submit" class="ui-btn ui-btn-sm">
                        <i data-lucide="search" class="h-4 w-4"></i>
                        <?= e($t('admin.catalogs.search_submit')) ?>
                    </button>
                </form>

                <?php if ($items === []): ?>
                    <p class="ui-empty mt-5"><?= e($t('admin.uvr.empty')) ?></p>
                <?php else: ?>
                    <div class="ui-table-wrap mt-5">
                        <table class="ui-table">
                            <thead>
                            <tr>
                                <th class="ui-th"><?= e($t('admin.catalogs.col_code')) ?></th>
                                <th class="ui-th"><?= e($t('admin.catalogs.col_term')) ?></th>
                                <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                                <th class="ui-th"><?= e($t('admin.uvr.title')) ?></th>
                            </tr>
                            </thead>
                            <tbody class="divide-y divide-line">
                            <?php foreach ($items as $item): ?>
                                <?php
                                $itemId = (int) ($item['id'] ?? 0);
                                $itemHref = $catalogHref($catalogCode) . '?edit=' . $itemId;

                                if ($query !== '') {
                                    $itemHref .= '&q=' . rawurlencode($query);
                                }

                                $itemDetailHref = $catalogHref($catalogCode) . '/items/' . $itemId;
                                $isEditing = $editRecord !== null && (int) ($editRecord['id'] ?? 0) === $itemId;
                                ?>
                                <tr class="transition hover:bg-paper/60 <?= $isEditing ? 'bg-mint/40' : '' ?>">
                                    <td class="ui-td">
                                        <a href="<?= e($itemHref) ?>" class="font-semibold no-underline hover:underline"
                                           aria-current="<?= $isEditing ? 'true' : 'false' ?>">
                                            <code class="ui-code"><?= e((string) ($item['permanent_code'] ?? '')) ?></code>
                                        </a>
                                        <a href="<?= e($itemDetailHref) ?>"
                                           class="ml-2 inline-flex align-middle text-muted no-underline transition hover:text-teal-dark"
                                           aria-label="<?= e($t('admin.catalogs.item_title')) ?>">
                                            <i data-lucide="external-link" class="h-3.5 w-3.5"></i>
                                        </a>
                                    </td>
                                    <td class="ui-td font-medium text-ink"><?= e((string) ($item['preferred_term'] ?? '')) ?></td>
                                    <td class="ui-td"><code class="ui-code"><?= e((string) ($item['status'] ?? '')) ?></code></td>
                                    <td class="ui-td">
                                        <a href="<?= e($uvrHref = '/admin/uvr/proposals?service_item_id=' . $itemId) ?>"
                                           class="ui-btn ui-btn-sm ui-btn-ghost no-underline">
                                            <i data-lucide="scale" class="h-3.5 w-3.5"></i>
                                            <?= e($t('admin.catalogs.uvr_button')) ?>
                                        </a>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
        <?php endif; ?>
    </article>

    <?php if ($catalogCanPropose): ?>
        <?php if ($editRecord !== null): ?>
            <article class="ui-card ui-card-pad">
                <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
                    <div>
                        <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.edit_title')) ?></h2>
                        <p class="ui-subtitle"><?= e($t('admin.catalogs.change_note')) ?></p>
                        <div class="mt-3 flex flex-wrap items-center gap-2">
                            <code class="ui-code"><?= e((string) ($editRecord['permanent_code'] ?? '')) ?></code>
                            <span class="ui-badge">#<?= (int) ($editRecord['id'] ?? 0) ?></span>
                        </div>
                    </div>
                    <div class="flex flex-col items-end gap-2">
                        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
                            <i data-lucide="file-pen-line" class="h-5 w-5"></i>
                        </span>
                        <a href="<?= e($catalogHref($catalogCode)) ?>"
                           class="text-xs font-semibold no-underline hover:underline">
                            <?= e($t('admin.catalogs.new_title')) ?>
                        </a>
                    </div>
                </div>

                <form method="post" action="/admin/catalogs/proposals" class="ui-stack">
                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                    <input type="hidden" name="operation" value="update">
                    <input type="hidden" name="item_id" value="<?= $editValue('item_id') ?>">
                    <input type="hidden" name="code" value="<?= e($catalogCode) ?>">

                    <fieldset class="ui-fieldset">
                        <legend class="ui-legend"><?= e($t('admin.catalogs.group_item')) ?></legend>
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div>
                                <label for="edit-item-code" class="ui-label"><?= e($t('admin.catalogs.col_code')) ?></label>
                                <input id="edit-item-code" type="text" name="permanent_code" maxlength="50"
                                       value="<?= $editValue('permanent_code') ?>" class="ui-input">
                            </div>
                            <div>
                                <label for="edit-item-status" class="ui-label"><?= e($t('admin.uvr.col_status')) ?></label>
                                <select id="edit-item-status" name="status" class="ui-input">
                                    <?php foreach ($editStatuses as $status): ?>
                                        <option value="<?= e($status) ?>" <?= $editSelected('status', $status) ?>>
                                            <?= e($status) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                        </div>
                    </fieldset>

                    <fieldset class="ui-fieldset">
                        <legend class="ui-legend"><?= e($t('admin.catalogs.group_release')) ?></legend>
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div>
                                <label for="edit-release" class="ui-label"><?= e($t('admin.catalogs.col_release')) ?></label>
                                <select id="edit-release" name="release_id" class="ui-input">
                                    <option value=""><?= e($t('admin.select')) ?></option>
                                    <?php foreach ($editReleases as $release): ?>
                                        <?php $releaseId = (string) (int) ($release['id'] ?? 0); ?>
                                        <option value="<?= e($releaseId) ?>" <?= $editSelected('release_id', $releaseId) ?>>
                                            <?= e((string) ($release['version_tag'] ?? '')) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <div>
                                <label for="edit-version" class="ui-label"><?= e($t('admin.uvr.version_tag')) ?></label>
                                <input id="edit-version" type="text" name="version_tag" maxlength="50"
                                       value="<?= $editValue('version_tag') ?>" class="ui-input">
                            </div>
                            <div>
                                <label for="edit-valid-from" class="ui-label"><?= e($t('admin.uvr.valid_from')) ?></label>
                                <input id="edit-valid-from" type="date" name="valid_from"
                                       value="<?= e($editDate('valid_from')) ?>" class="ui-input">
                            </div>
                            <div>
                                <label for="edit-valid-to" class="ui-label"><?= e($t('admin.uvr.valid_to')) ?></label>
                                <input id="edit-valid-to" type="date" name="valid_to"
                                       value="<?= e($editDate('valid_to')) ?>" class="ui-input">
                            </div>
                            <div class="sm:col-span-2">
                                <label for="edit-release-status" class="ui-label"><?= e($t('admin.uvr.col_status')) ?></label>
                                <select id="edit-release-status" name="release_status" class="ui-input">
                                    <option value=""><?= e($t('admin.select')) ?></option>
                                    <?php foreach ($editReleaseStatuses as $status): ?>
                                        <option value="<?= e($status) ?>" <?= $editSelected('release_status', $status) ?>>
                                            <?= e($status) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                        </div>
                    </fieldset>

                    <fieldset class="ui-fieldset">
                        <legend class="ui-legend"><?= e($t('admin.catalogs.group_version')) ?></legend>
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div class="sm:col-span-2">
                                <label for="edit-term" class="ui-label"><?= e($t('admin.catalogs.col_term')) ?></label>
                                <input id="edit-term" type="text" name="preferred_term" maxlength="255"
                                       value="<?= $editValue('preferred_term') ?>" class="ui-input">
                            </div>
                            <div>
                                <label for="edit-definition" class="ui-label"><?= e($t('admin.catalogs.col_definition')) ?></label>
                                <textarea id="edit-definition" name="definition" rows="2" maxlength="4000"
                                          class="ui-input"><?= $editValue('definition') ?></textarea>
                            </div>
                            <div>
                                <label for="edit-criteria" class="ui-label"><?= e($t('admin.catalogs.col_criteria')) ?></label>
                                <textarea id="edit-criteria" name="clinical_criteria" rows="2" maxlength="4000"
                                          class="ui-input"><?= $editValue('clinical_criteria') ?></textarea>
                            </div>
                            <div>
                                <label for="edit-language" class="ui-label"><?= e($t('admin.catalogs.col_language')) ?></label>
                                <select id="edit-language" name="language_code" class="ui-input">
                                    <?php foreach ($editLanguageOptions as $language): ?>
                                        <option value="<?= e($language) ?>" <?= $editSelected('language_code', $language) ?>>
                                            <?= e($language) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                        </div>
                    </fieldset>

                    <fieldset class="ui-fieldset">
                        <legend class="ui-legend"><?= e($t('admin.catalogs.group_relations')) ?></legend>
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div>
                                <label for="edit-rel-target" class="ui-label"><?= e($t('admin.catalogs.col_target')) ?></label>
                                <input id="edit-rel-target" type="number" min="1"
                                       name="relations[0][target_item_id]"
                                       value="<?= e((string) ($editRelation['target_item_id'] ?? '')) ?>" class="ui-input">
                            </div>
                            <div>
                                <label for="edit-rel-type" class="ui-label"><?= e($t('admin.catalogs.col_relation')) ?></label>
                                <select id="edit-rel-type" name="relations[0][relation_type]" class="ui-input">
                                    <?php foreach ($editRelationTypes as $type): ?>
                                        <option value="<?= e($type) ?>"
                                            <?= (string) ($editRelation['relation_type'] ?? '') === $type ? 'selected' : '' ?>>
                                            <?= e($type) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <div>
                                <label for="edit-rel-field" class="ui-label"><?= e($t('admin.catalogs.col_source_field')) ?></label>
                                <select id="edit-rel-field" name="relations[0][source_field]" class="ui-input">
                                    <?php foreach ($editSourceFields as $field): ?>
                                        <option value="<?= e($field) ?>"
                                            <?= (string) ($editRelation['source_field'] ?? '') === $field ? 'selected' : '' ?>>
                                            <?= e($field) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <div>
                                <label for="edit-rel-value" class="ui-label"><?= e($t('admin.catalogs.col_source_value')) ?></label>
                                <input id="edit-rel-value" type="text" maxlength="20"
                                       name="relations[0][source_value]"
                                       value="<?= e((string) ($editRelation['source_value'] ?? '')) ?>" class="ui-input">
                            </div>
                            <div class="sm:col-span-2">
                                <label for="edit-rel-provenance" class="ui-label"><?= e($t('admin.catalogs.col_provenance')) ?></label>
                                <input id="edit-rel-provenance" type="text" maxlength="2000"
                                       name="relations[0][provenance]"
                                       value="<?= e((string) ($editRelation['provenance'] ?? '')) ?>" class="ui-input">
                            </div>
                        </div>
                    </fieldset>

                    <fieldset class="ui-fieldset">
                        <legend class="ui-legend"><?= e($t('admin.catalogs.group_languages')) ?></legend>
                        <div class="grid gap-4 sm:grid-cols-3">
                            <div>
                                <label for="edit-lang-code" class="ui-label"><?= e($t('admin.catalogs.col_language')) ?></label>
                                <select id="edit-lang-code" name="languages[0][language_code]" class="ui-input">
                                    <?php foreach ($editLanguageOptions as $language): ?>
                                        <option value="<?= e($language) ?>"
                                            <?= (string) ($editLanguage['language_code'] ?? '') === $language ? 'selected' : '' ?>>
                                            <?= e($language) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                            <label class="flex items-center gap-2 self-end pb-2.5 text-sm text-ink-soft">
                                <input type="checkbox" name="languages[0][enabled]" value="1"
                                       class="h-4 w-4 rounded border-line text-teal focus:ring-teal/30"
                                       <?= $editLanguage !== [] ? 'checked' : '' ?>>
                                <?= e($t('admin.catalogs.apply_language')) ?>
                            </label>
                            <div>
                                <label for="edit-lang-coverage" class="ui-label"><?= e($t('admin.catalogs.col_coverage')) ?></label>
                                <select id="edit-lang-coverage" name="languages[0][coverage_status]" class="ui-input">
                                    <?php foreach ($editCoverage as $coverage): ?>
                                        <option value="<?= e($coverage) ?>"
                                            <?= (string) ($editLanguage['coverage_status'] ?? '') === $coverage ? 'selected' : '' ?>>
                                            <?= e($coverage) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                            </div>
                        </div>
                    </fieldset>

                    <div>
                        <label for="edit-source" class="ui-label"><?= e($t('admin.uvr.col_source')) ?></label>
                        <textarea id="edit-source" name="source_reference" required rows="2" maxlength="2000"
                                  class="ui-input"><?= $editValue('source_reference') ?></textarea>
                    </div>

                    <button type="submit" class="ui-btn w-full"><?= e($t('admin.catalogs.propose_submit')) ?></button>
                </form>
            </article>
        <?php else: ?>
            <article class="ui-card ui-card-pad">
                <div class="mb-5 flex items-start justify-between gap-4">
                    <div>
                        <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.new_title')) ?></h2>
                        <p class="ui-subtitle"><?= e($t('admin.catalogs.new_note')) ?></p>
                    </div>
                    <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
                        <i data-lucide="file-plus-2" class="h-5 w-5"></i>
                    </span>
                </div>

                <form method="post" action="/admin/catalogs/proposals" class="space-y-4">
                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                    <input type="hidden" name="operation" value="create">
                    <div class="grid gap-4 sm:grid-cols-2">
                        <div class="sm:col-span-2">
                            <label for="catalog-new-code" class="ui-label"><?= e($t('admin.uvr.col_catalog')) ?></label>
                            <select id="catalog-new-code" name="code" required class="ui-input">
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach ($catalogs as $catalog): ?>
                                    <option value="<?= e((string) ($catalog['code'] ?? '')) ?>"
                                        <?= (string) ($catalog['code'] ?? '') === $catalogCode ? 'selected' : '' ?>>
                                        <?= e((string) ($catalog['name'] ?? '')) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="catalog-permanent-code" class="ui-label"><?= e($t('admin.catalogs.col_code')) ?></label>
                            <input id="catalog-permanent-code" type="text" name="permanent_code" required maxlength="50"
                                   value="<?= $catalogValue('permanent_code') ?>" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-status" class="ui-label"><?= e($t('admin.uvr.col_status')) ?></label>
                            <select id="catalog-status" name="status" required class="ui-input">
                                <option value="active">active</option>
                                <option value="retired">retired</option>
                                <option value="superseded">superseded</option>
                            </select>
                        </div>
                        <div class="sm:col-span-2">
                            <label for="catalog-term" class="ui-label"><?= e($t('admin.catalogs.col_term')) ?></label>
                            <input id="catalog-term" type="text" name="preferred_term" maxlength="255"
                                   value="<?= $catalogValue('preferred_term') ?>" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-release" class="ui-label"><?= e($t('admin.catalogs.col_release')) ?></label>
                            <input id="catalog-release" type="number" name="release_id" min="1"
                                   value="<?= $catalogValue('release_id') ?>" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-version" class="ui-label"><?= e($t('admin.uvr.version_tag')) ?></label>
                            <input id="catalog-version" type="text" name="version_tag" maxlength="50"
                                   value="<?= $catalogValue('version_tag') ?>" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-valid-from" class="ui-label"><?= e($t('admin.uvr.valid_from')) ?></label>
                            <input id="catalog-valid-from" type="date" name="valid_from"
                                   value="<?= $catalogValue('valid_from') ?>" class="ui-input">
                        </div>
                        <div class="sm:col-span-2">
                            <label for="catalog-source" class="ui-label"><?= e($t('admin.uvr.col_source')) ?></label>
                            <textarea id="catalog-source" name="source_reference" required rows="2" maxlength="2000"
                                      class="ui-input"><?= $catalogValue('source_reference') ?></textarea>
                        </div>
                    </div>
                    <button type="submit" class="ui-btn w-full"><?= e($t('admin.catalogs.propose_submit')) ?></button>
                </form>
            </article>
        <?php endif; ?>
    <?php endif; ?>
</div>
</section>
