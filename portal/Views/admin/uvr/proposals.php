<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $proposals */
/** @var list<array{code: string, name: string, short_name: string}> $catalogs */
/** @var string $catalogCode */
/** @var string $query */
/** @var list<array<string, mixed>> $items */
/** @var int $itemId */
/** @var array<string, mixed>|null $selectedItem */
/** @var list<array<string, mixed>> $selectedVersions */
/** @var list<array<string, mixed>> $selectedReleases */
/** @var list<array<string, mixed>> $selectedLanguages */
/** @var bool $itemError */
/** @var bool $transversal */
/** @var list<array<string, mixed>> $prestaciones */
/** @var list<array<string, mixed>> $profiles */
/** @var array<int, string> $profileComponents */

require __DIR__ . '/_nav.php';

$uvrPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$uvrCanPropose = \OrigenSalud\Portal\Admin\Rbac::hasPermission($uvrPermissions, 'catalog.propose');
$uvrValues = is_array($flash['values'] ?? null) ? $flash['values'] : [];
$uvrPrefill = is_array($prefill ?? null) ? $prefill : [];
$uvrValue = static fn (string $key, string $default = ''): string => e(
    is_string($uvrValues[$key] ?? null) && $uvrValues[$key] !== ''
        ? $uvrValues[$key]
        : (is_string($uvrPrefill[$key] ?? null) && $uvrPrefill[$key] !== '' ? $uvrPrefill[$key] : $default)
);
$uvrComponents = [
    'work' => 'admin.uvr.work',
    'practice_expense' => 'admin.uvr.practice',
    'professional_liability' => 'admin.uvr.liability',
];
$uvrTransversal = (bool) ($transversal ?? false);
$uvrPrestaciones = is_array($prestaciones ?? null) ? $prestaciones : [];
$uvrProfiles = is_array($profiles ?? null) ? $profiles : [];
$uvrProfileComponents = is_array($profileComponents ?? null) ? $profileComponents : [];

$uvrStepHref = static function (int $id) use ($catalogCode, $query): string {
    $params = ['catalog' => $catalogCode, 'item' => $id];

    if ($query !== '') {
        $params['q'] = $query;
    }

    return '/admin/uvr/proposals?' . http_build_query($params);
};

$uvrVersions = is_array($selectedVersions ?? null) ? $selectedVersions : [];
$uvrReleases = is_array($selectedReleases ?? null) ? $selectedReleases : [];
$uvrLanguages = is_array($selectedLanguages ?? null) ? $selectedLanguages : [];
$uvrVersion = is_array($uvrVersions[0] ?? null) ? $uvrVersions[0] : [];
$uvrVersionReleaseId = (int) ($uvrVersion['release_id'] ?? 0);
$uvrRelease = null;

foreach ($uvrReleases as $release) {
    if ((int) ($release['id'] ?? 0) === $uvrVersionReleaseId) {
        $uvrRelease = $release;
        break;
    }
}

$uvrLanguage = (string) ($uvrVersion['language_code'] ?? '');
if ($uvrLanguage === '') {
    foreach ($uvrLanguages as $language) {
        if (!empty($language['is_default'])) {
            $uvrLanguage = (string) ($language['code'] ?? '');
            break;
        }
    }
}
?>
<div class="ui-grid items-start">
    <?php if ($uvrCanPropose): ?>
        <article class="ui-card ui-card-pad">
            <div class="mb-5 flex items-start justify-between gap-4">
                <div>
                    <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.select_title')) ?></h2>
                    <p class="ui-subtitle"><?= e($t('admin.uvr.catalogs_note')) ?></p>
                </div>
                <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="library" class="h-5 w-5"></i>
                </span>
            </div>

            <form method="get" action="/admin/uvr/proposals" class="space-y-4">
                <div>
                    <label for="uvr-catalog" class="ui-label"><?= e($t('admin.uvr.col_catalog')) ?></label>
                    <select id="uvr-catalog" name="catalog" required onchange="this.form.submit()" class="ui-input">
                        <?php if ($catalogs === []): ?>
                            <option value=""><?= e($t('admin.uvr.empty')) ?></option>
                        <?php else: ?>
                            <?php foreach ($catalogs as $catalog): ?>
                                <?php
                                $uvrCatalogCode = (string) ($catalog['code'] ?? '');
                                $uvrCatalogLabel = (string) ($catalog['short_name'] ?? '') !== ''
                                    ? (string) $catalog['short_name']
                                    : (string) ($catalog['name'] ?? $uvrCatalogCode);
                                ?>
                                <option value="<?= e($uvrCatalogCode) ?>"<?= $uvrCatalogCode === $catalogCode ? ' selected' : '' ?>>
                                    <?= e($uvrCatalogLabel . ' · ' . $uvrCatalogCode) ?>
                                </option>
                            <?php endforeach; ?>
                        <?php endif; ?>
                    </select>
                </div>
                <div>
                    <label for="uvr-code-search" class="ui-label"><?= e($t('admin.catalogs.search_label')) ?></label>
                    <div class="flex gap-2">
                        <input id="uvr-code-search" type="search" name="q" maxlength="100"
                               value="<?= e($query) ?>" placeholder="<?= e($t('admin.catalogs.search_placeholder')) ?>"
                               class="ui-input">
                        <button type="submit" class="ui-btn ui-btn-sm"><?= e($t('admin.catalogs.search_submit')) ?></button>
                    </div>
                </div>
            </form>

            <?php if ($catalogCode !== ''): ?>
                <div class="mt-5 border-t border-line pt-5">
                    <h3 class="mb-3 text-sm font-semibold text-ink"><?= e($t('admin.catalogs.search_title')) ?></h3>

                    <?php if ($itemError): ?>
                        <p class="ui-empty"><?= e($t('admin.catalogs.item_not_found')) ?></p>
                    <?php elseif ($query === '' && $selectedItem === null): ?>
                        <p class="ui-subtitle"><?= e($t('admin.catalogs.search_placeholder')) ?></p>
                    <?php elseif ($items === []): ?>
                        <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
                    <?php else: ?>
                        <div class="ui-table-wrap">
                            <table class="ui-table">
                                <thead>
                                <tr>
                                    <th class="ui-th"><?= e($t('admin.catalogs.col_code')) ?></th>
                                    <th class="ui-th"><?= e($t('admin.catalogs.col_term')) ?></th>
                                    <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                                </tr>
                                </thead>
                                <tbody class="divide-y divide-line">
                                <?php foreach ($items as $item): ?>
                                    <?php
                                    $uvrItemId = (int) ($item['id'] ?? 0);
                                    $uvrEditing = $uvrItemId === $itemId;
                                    ?>
                                    <tr class="transition hover:bg-paper/60 <?= $uvrEditing ? 'bg-mint/40' : '' ?>">
                                        <td class="ui-td">
                                            <a href="<?= e($uvrStepHref($uvrItemId)) ?>"
                                               class="font-semibold no-underline hover:underline"
                                               aria-current="<?= $uvrEditing ? 'true' : 'false' ?>">
                                                <code class="ui-code"><?= e((string) ($item['permanent_code'] ?? '')) ?></code>
                                            </a>
                                        </td>
                                        <td class="ui-td font-medium text-ink"><?= e((string) ($item['preferred_term'] ?? '')) ?></td>
                                        <td class="ui-td"><code class="ui-code"><?= e((string) ($item['status'] ?? '')) ?></code></td>
                                    </tr>
                                <?php endforeach; ?>
                                </tbody>
                            </table>
                        </div>
                    <?php endif; ?>
                </div>
            <?php endif; ?>
        </article>

        <article class="ui-card ui-card-pad">
            <?php if ($selectedItem === null): ?>
                <div class="mb-5 flex items-start justify-between gap-4">
                    <div>
                        <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.propose_title')) ?></h2>
                        <p class="ui-subtitle"><?= e($t('admin.uvr.select_item')) ?></p>
                    </div>
                    <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
                        <i data-lucide="file-plus-2" class="h-5 w-5"></i>
                    </span>
                </div>
            <?php else: ?>
                <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
                    <div>
                        <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.extracted_values')) ?></h2>
                        <p class="ui-subtitle"><?= e($t('admin.uvr.catalogs_note')) ?></p>
                        <div class="mt-3 flex flex-wrap items-center gap-2">
                            <code class="ui-code"><?= e((string) ($selectedItem['permanent_code'] ?? '')) ?></code>
                            <span class="ui-badge">#<?= (int) ($selectedItem['id'] ?? 0) ?></span>
                        </div>
                    </div>
                    <a href="<?= e('/admin/uvr/proposals?' . http_build_query(array_filter(['catalog' => $catalogCode, 'q' => $query]))) ?>"
                       class="text-xs font-semibold no-underline hover:underline">
                        <?= e($t('admin.catalogs.new_title')) ?>
                    </a>
                </div>

                <div class="rounded-xl border border-line bg-paper p-4">
                    <dl class="grid gap-3 sm:grid-cols-2">
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.catalogs.col_code')) ?></dt>
                            <dd class="font-medium text-ink"><code class="ui-code"><?= e((string) ($selectedItem['permanent_code'] ?? '')) ?></code></dd>
                        </div>
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.catalogs.col_term')) ?></dt>
                            <dd class="font-medium text-ink"><?= e((string) ($uvrVersion['preferred_term'] ?? '')) ?></dd>
                        </div>
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.uvr.col_status')) ?></dt>
                            <dd class="font-medium text-ink"><code class="ui-code"><?= e((string) ($selectedItem['status'] ?? '')) ?></code></dd>
                        </div>
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.uvr.col_release')) ?></dt>
                            <dd class="font-medium text-ink">
                                <?= e((string) ($uvrVersion['version_tag'] ?? ($uvrRelease['version_tag'] ?? ''))) ?>
                            </dd>
                        </div>
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.uvr.version_tag')) ?></dt>
                            <dd class="font-medium text-ink"><?= e((string) ($uvrVersion['version_tag'] ?? '')) ?></dd>
                        </div>
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.catalogs.col_language')) ?></dt>
                            <dd class="font-medium text-ink"><?= e($uvrLanguage) ?></dd>
                        </div>
                        <div class="sm:col-span-2">
                            <dt class="ui-subtitle"><?= e($t('admin.catalogs.col_definition')) ?></dt>
                            <dd class="text-sm text-ink-soft"><?= e((string) ($uvrVersion['definition'] ?? '')) ?></dd>
                        </div>
                        <div class="sm:col-span-2">
                            <dt class="ui-subtitle"><?= e($t('admin.catalogs.col_criteria')) ?></dt>
                            <dd class="text-sm text-ink-soft"><?= e((string) ($uvrVersion['clinical_criteria'] ?? '')) ?></dd>
                        </div>
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.uvr.valid_from')) ?></dt>
                            <dd class="font-medium text-ink"><?= e(substr((string) ($uvrRelease['valid_from'] ?? ''), 0, 10)) ?></dd>
                        </div>
                        <div>
                            <dt class="ui-subtitle"><?= e($t('admin.uvr.valid_to')) ?></dt>
                            <dd class="font-medium text-ink"><?= e(substr((string) ($uvrRelease['valid_to'] ?? ''), 0, 10)) ?></dd>
                        </div>
                    </dl>
                </div>

                <h3 class="mb-3 mt-6 text-sm font-semibold text-ink"><?= e($t('admin.uvr.new_values')) ?></h3>
                <form method="post" action="/admin/uvr/proposals" class="space-y-5"
                      x-data="{
                          selectedComponents() {
                              const select = this.$refs.profile;
                              if (!select || !select.value || !select.selectedOptions[0]) {
                                  return 'work,practice_expense,professional_liability';
                              }
                              return (select.selectedOptions[0].dataset.components || '').split(',');
                          },
                          allowed(type) { return this.selectedComponents().includes(type); }
                      }">
                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                    <input type="hidden" name="catalog" value="<?= e($catalogCode) ?>">
                    <input type="hidden" name="q" value="<?= e($query) ?>">
                    <input type="hidden" name="service_item_id" value="<?= (int) ($selectedItem['id'] ?? 0) ?>">

                    <?php if ($uvrTransversal): ?>
                        <p class="ui-subtitle"><?= e($t('admin.uvr.transversal_note')) ?></p>
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div>
                                <label for="uvr-prestacion" class="ui-label"><?= e($t('admin.uvr.prestacion')) ?></label>
                                <select id="uvr-prestacion" name="prestacion_id" required class="ui-input">
                                    <option value=""><?= e($t('admin.select')) ?></option>
                                    <?php foreach ($uvrPrestaciones as $prestacion): ?>
                                        <?php $prestacionId = (int) ($prestacion['id'] ?? 0); ?>
                                        <option value="<?= $prestacionId ?>"
                                            <?= $uvrValue('prestacion_id') === (string) $prestacionId ? 'selected' : '' ?>>
                                            <?= e((string) ($prestacion['display_name'] ?? '')) ?>
                                            · <?= e((string) ($prestacion['code'] ?? '')) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                                <?php if ($uvrPrestaciones === []): ?>
                                    <p class="form-note"><?= e($t('admin.uvr.prestacion_none')) ?></p>
                                <?php endif; ?>
                            </div>
                            <div>
                                <label for="uvr-profile" class="ui-label"><?= e($t('admin.uvr.profile')) ?></label>
                                <select id="uvr-profile" name="profile_id" x-ref="profile" required class="ui-input">
                                    <option value=""><?= e($t('admin.select')) ?></option>
                                    <?php foreach ($uvrProfiles as $profile): ?>
                                        <?php
                                        $profileId = (int) ($profile['id'] ?? 0);
                                        $profileComponentsValue = (string) ($uvrProfileComponents[$profileId] ?? '');
                                        ?>
                                        <option value="<?= $profileId ?>"
                                                data-components="<?= e($profileComponentsValue) ?>"
                                            <?= $uvrValue('profile_id') === (string) $profileId ? 'selected' : '' ?>>
                                            <?= e((string) ($profile['name'] ?? '')) ?>
                                            · <?= e((string) ($profile['version_tag'] ?? '')) ?>
                                        </option>
                                    <?php endforeach; ?>
                                </select>
                                <p class="form-note"><?= e($t('admin.uvr.profile_components_note')) ?></p>
                            </div>
                        </div>
                    <?php else: ?>
                        <input type="hidden" name="prestacion_id" value="">
                        <input type="hidden" name="profile_id" value="">
                    <?php endif; ?>

                    <div class="grid gap-4 sm:grid-cols-2">
                        <div>
                            <label for="uvr-release" class="ui-label"><?= e($t('admin.uvr.col_release')) ?></label>
                            <input id="uvr-release" type="number" name="release_id" min="1" class="ui-input"
                                   value="<?= $uvrValue('release_id') ?>">
                        </div>
                        <div>
                            <label for="uvr-version" class="ui-label"><?= e($t('admin.uvr.version_tag')) ?></label>
                            <input id="uvr-version" type="text" name="version_tag" required maxlength="50"
                                   value="<?= $uvrValue('version_tag') ?>" class="ui-input">
                        </div>
                        <?php if ($uvrTransversal): ?>
                            <div class="sm:col-span-2">
                                <p class="ui-subtitle"><?= e($t('admin.uvr.methodology_from_profile')) ?></p>
                                <input type="hidden" name="methodology" value="">
                            </div>
                        <?php else: ?>
                            <div>
                                <label for="uvr-methodology" class="ui-label"><?= e($t('admin.uvr.methodology')) ?></label>
                                <input id="uvr-methodology" type="text" name="methodology" required maxlength="120"
                                       value="<?= $uvrValue('methodology') ?>" class="ui-input">
                            </div>
                        <?php endif; ?>
                        <div class="sm:col-span-2">
                            <label for="uvr-source" class="ui-label"><?= e($t('admin.uvr.col_source')) ?></label>
                            <textarea id="uvr-source" name="source_reference" required rows="2" maxlength="2000"
                                      class="ui-input"><?= $uvrValue('source_reference') ?></textarea>
                        </div>
                        <div>
                            <label for="uvr-evaluated" class="ui-label"><?= e($t('admin.uvr.evaluated_at')) ?></label>
                            <input id="uvr-evaluated" type="date" name="evaluated_at" required
                                   value="<?= $uvrValue('evaluated_at') ?>" class="ui-date">
                        </div>
                        <div>
                            <label for="uvr-valid-from" class="ui-label"><?= e($t('admin.uvr.valid_from')) ?></label>
                            <input id="uvr-valid-from" type="date" name="valid_from"
                                   value="<?= $uvrValue('valid_from') ?>" class="ui-date">
                        </div>
                        <div>
                            <label for="uvr-valid-to" class="ui-label"><?= e($t('admin.uvr.valid_to')) ?></label>
                            <input id="uvr-valid-to" type="date" name="valid_to"
                                   value="<?= $uvrValue('valid_to') ?>" class="ui-date">
                        </div>
                    </div>

                    <fieldset class="ui-fieldset">
                        <legend class="ui-legend"><?= e($t('admin.uvr.col_components')) ?></legend>
                        <div class="space-y-4">
                            <?php foreach ($uvrComponents as $type => $label): ?>
                                <?php $componentKey = e($type); ?>
                                <div class="rounded-xl border border-line bg-white p-4"
                                    <?= $uvrTransversal ? "x-show=\"allowed('" . $componentKey . "')\"" : '' ?>>
                                    <p class="mb-3 text-sm font-semibold text-ink"><?= e($t($label)) ?></p>
                                    <div class="grid gap-3 sm:grid-cols-2">
                                        <div>
                                            <label class="ui-label" for="uvr-<?= $componentKey ?>-value"><?= e($t('admin.uvr.col_value')) ?></label>
                                            <input id="uvr-<?= $componentKey ?>-value" type="text" inputmode="decimal"
                                                   autocomplete="off" name="components[<?= $componentKey ?>][value]"
                                                   value="0" class="ui-input">
                                            <p class="form-note"><?= e($t('admin.uvr.decimal_hint')) ?></p>
                                        </div>
                                        <label class="flex items-center gap-2 self-end pb-2.5 text-sm text-ink-soft">
                                            <input type="checkbox" name="components[<?= $componentKey ?>][not_applicable]" value="1"
                                                   class="h-4 w-4 rounded border-line text-teal focus:ring-teal/30">
                                            <?= e($t('admin.uvr.not_applicable')) ?>
                                        </label>
                                        <div class="sm:col-span-2">
                                            <label class="ui-label" for="uvr-<?= $componentKey ?>-evidence"><?= e($t('admin.uvr.negative_evidence')) ?></label>
                                            <textarea id="uvr-<?= $componentKey ?>-evidence" rows="1" maxlength="2000"
                                                      name="components[<?= $componentKey ?>][evidence]" class="ui-input"></textarea>
                                        </div>
                                        <div class="sm:col-span-2">
                                            <label class="ui-label" for="uvr-<?= $componentKey ?>-note"><?= e($t('admin.uvr.calculation_note')) ?></label>
                                            <textarea id="uvr-<?= $componentKey ?>-note" rows="1" maxlength="2000"
                                                      name="components[<?= $componentKey ?>][note]" class="ui-input"></textarea>
                                        </div>
                                    </div>
                                </div>
                            <?php endforeach; ?>
                        </div>
                    </fieldset>

                    <button type="submit" class="ui-btn w-full">
                        <i data-lucide="plus" class="h-4 w-4"></i>
                        <?= e($t('admin.uvr.propose_submit')) ?>
                    </button>
                </form>
            <?php endif; ?>
        </article>
    <?php endif; ?>
</div>

<article class="ui-card ui-card-pad mt-6">
    <div class="mb-5 flex items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.c')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.uvr.lead')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="inbox" class="h-5 w-5"></i>
        </span>
    </div>

    <?php if ($proposals === []): ?>
        <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="ui-table-wrap">
            <table class="ui-table">
                <thead>
                <tr>
                    <th class="ui-th"><?= e($t('admin.uvr.col_id')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_subject')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_source')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_actor')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_created')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($proposals as $proposal): ?>
                    <tr class="transition hover:bg-paper/60">
                        <td class="ui-td">
                            <a href="/admin/uvr/proposals/<?= (int) $proposal['id'] ?>" class="font-semibold no-underline">
                                <?= (int) $proposal['id'] ?>
                            </a>
                        </td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($proposal['subject_id'] ?? '')) ?></code></td>
                        <td class="ui-td"><?= e((string) ($proposal['source_reference'] ?? '')) ?></td>
                        <td class="ui-td"><?= e((string) ($proposal['requested_by'] ?? '')) ?></td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($proposal['review_status'] ?? '')) ?></code></td>
                        <td class="ui-td text-xs"><?= e((string) ($proposal['created_at'] ?? '')) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
