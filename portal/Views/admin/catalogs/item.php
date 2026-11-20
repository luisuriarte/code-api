<?php

declare(strict_types=1);

/** @var array<string, mixed>|null $item */
/** @var list<array<string, mixed>> $versions */
/** @var list<array<string, mixed>> $relations */
/** @var list<array<string, mixed>> $releases */
/** @var list<array<string, mixed>> $languages */
/** @var string $catalogCode */

require __DIR__ . '/_nav.php';

$catalogItem = is_array($item) ? $item : null;
$catalogItemId = $catalogItem === null ? 0 : (int) ($catalogItem['id'] ?? 0);
$catalogBack = '/admin/catalogs/' . rawurlencode($catalogCode);
$catalogUvrHref = '/admin/uvr/proposals?service_item_id=' . $catalogItemId;
$catalogLanguageOptions = ['es-AR', 'es', 'en', 'pt-BR'];
$catalogCoverage = ['original', 'complete', 'partial', 'planned', 'undetermined'];
?>
<?php if ($catalogItem === null): ?>
    <p class="ui-empty"><?= e($t('admin.catalogs.item_not_found')) ?></p>
<?php else: ?>
    <article class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.item_title')) ?></h2>
                <p class="ui-subtitle"><?= e($t('admin.catalogs.lead')) ?></p>
            </div>
            <div class="flex flex-wrap gap-2">
                <a href="<?= e($catalogUvrHref) ?>" class="ui-btn ui-btn-sm no-underline">
                    <i data-lucide="scale" class="h-4 w-4"></i>
                    <?= e($t('admin.catalogs.uvr_button')) ?>
                </a>
                <a href="<?= e($catalogBack) ?>" class="ui-btn ui-btn-sm ui-btn-ghost no-underline">
                    <i data-lucide="arrow-left" class="h-4 w-4"></i>
                    <?= e($t('admin.catalogs.back_codes')) ?>
                </a>
            </div>
        </div>

        <dl class="ui-dl mt-5 rounded-xl border border-line bg-paper/70 p-4">
            <dt class="ui-dt"><?= e($t('admin.catalogs.col_code')) ?></dt>
            <dd class="ui-dd"><code class="ui-code"><?= e((string) ($catalogItem['permanent_code'] ?? '')) ?></code></dd>
            <dt class="ui-dt"><?= e($t('admin.uvr.col_catalog')) ?></dt>
            <dd class="ui-dd"><code class="ui-code"><?= e((string) ($catalogItem['catalog_code'] ?? $catalogCode)) ?></code></dd>
            <dt class="ui-dt"><?= e($t('admin.uvr.col_status')) ?></dt>
            <dd class="ui-dd"><code class="ui-code"><?= e((string) ($catalogItem['status'] ?? '')) ?></code></dd>
        </dl>
    </article>

    <div class="ui-grid items-start">
        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="history" class="h-4 w-4"></i>
                </span>
                <h3 class="text-base font-semibold text-ink"><?= e($t('admin.catalogs.versions_title')) ?></h3>
            </div>
            <?php if ($versions === []): ?>
                <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
            <?php else: ?>
                <div class="ui-table-wrap">
                    <table class="ui-table">
                        <thead>
                        <tr>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_release')) ?></th>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_term')) ?></th>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_language')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($versions as $version): ?>
                            <tr class="transition hover:bg-paper/60">
                                <td class="ui-td"><?= e((string) ($version['version_tag'] ?? '')) ?></td>
                                <td class="ui-td font-medium text-ink"><?= e((string) ($version['preferred_term'] ?? '')) ?></td>
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($version['language_code'] ?? '')) ?></code></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </article>

        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="git-fork" class="h-4 w-4"></i>
                </span>
                <h3 class="text-base font-semibold text-ink"><?= e($t('admin.catalogs.relations_title')) ?></h3>
            </div>
            <?php if ($relations === []): ?>
                <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
            <?php else: ?>
                <div class="ui-table-wrap">
                    <table class="ui-table">
                        <thead>
                        <tr>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_target')) ?></th>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_relation')) ?></th>
                            <th class="ui-th"><?= e($t('admin.catalogs.col_source_value')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($relations as $relation): ?>
                            <tr class="transition hover:bg-paper/60">
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($relation['target_code'] ?? $relation['target_item_id'] ?? '')) ?></code></td>
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($relation['relation_type'] ?? '')) ?></code></td>
                                <td class="ui-td"><?= e((string) ($relation['source_value'] ?? '')) ?></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </article>
    </div>

    <article class="ui-card ui-card-pad">
        <div class="mb-4 flex items-center gap-3">
            <span class="flex h-9 w-9 items-center justify-center rounded-xl bg-mint text-teal-dark">
                <i data-lucide="languages" class="h-4 w-4"></i>
            </span>
            <h3 class="text-base font-semibold text-ink"><?= e($t('admin.catalogs.languages_title')) ?></h3>
        </div>
        <?php if ($languages === []): ?>
            <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
        <?php else: ?>
            <div class="flex flex-wrap gap-2">
                <?php foreach ($languages as $language): ?>
                    <span class="inline-flex items-center gap-2 rounded-full border border-line bg-paper px-3 py-1.5 text-sm text-ink-soft">
                        <code class="ui-code"><?= e((string) ($language['language_code'] ?? '')) ?></code>
                        <span><?= e((string) ($language['coverage_status'] ?? '')) ?></span>
                        <?php if (!empty($language['is_default'])): ?>
                            <span class="ui-badge"><?= e($t('admin.catalogs.default')) ?></span>
                        <?php endif; ?>
                    </span>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </article>

    <?php if ($catalogCanPropose): ?>
        <article class="ui-card ui-card-pad">
            <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
                <div>
                    <h3 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.change_title')) ?></h3>
                    <p class="ui-subtitle"><?= e($t('admin.catalogs.change_note')) ?></p>
                </div>
                <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="file-pen-line" class="h-5 w-5"></i>
                </span>
            </div>

            <form method="post" action="/admin/catalogs/proposals" class="space-y-5">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <input type="hidden" name="operation" value="update">
                <input type="hidden" name="code" value="<?= e($catalogCode) ?>">
                <input type="hidden" name="item_id" value="<?= $catalogItemId ?>">

                <fieldset class="ui-fieldset">
                    <legend class="ui-legend"><?= e($t('admin.catalogs.group_item')) ?></legend>
                    <div class="grid gap-4 sm:grid-cols-2">
                        <div>
                            <label for="catalog-item-code" class="ui-label"><?= e($t('admin.catalogs.col_code')) ?></label>
                            <input id="catalog-item-code" type="text" name="permanent_code" maxlength="50"
                                   value="<?= e((string) ($catalogItem['permanent_code'] ?? '')) ?>" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-item-status" class="ui-label"><?= e($t('admin.uvr.col_status')) ?></label>
                            <select id="catalog-item-status" name="status" class="ui-input">
                                <?php foreach (['active', 'retired', 'superseded'] as $status): ?>
                                    <option value="<?= e($status) ?>"
                                        <?= $status === (string) ($catalogItem['status'] ?? '') ? 'selected' : '' ?>><?= e($status) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                </fieldset>

                <fieldset class="ui-fieldset">
                    <legend class="ui-legend"><?= e($t('admin.catalogs.group_release')) ?></legend>
                    <div class="grid gap-4 sm:grid-cols-2">
                        <div>
                            <label for="catalog-item-release" class="ui-label"><?= e($t('admin.catalogs.col_release')) ?></label>
                            <select id="catalog-item-release" name="release_id" class="ui-input">
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach ($releases as $release): ?>
                                    <option value="<?= (int) ($release['id'] ?? 0) ?>">
                                        <?= e((string) ($release['version_tag'] ?? '')) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="catalog-item-version" class="ui-label"><?= e($t('admin.uvr.version_tag')) ?></label>
                            <input id="catalog-item-version" type="text" name="version_tag" maxlength="50" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-item-valid-from" class="ui-label"><?= e($t('admin.uvr.valid_from')) ?></label>
                            <input id="catalog-item-valid-from" type="date" name="valid_from" class="ui-date">
                        </div>
                        <div>
                            <label for="catalog-item-valid-to" class="ui-label"><?= e($t('admin.uvr.valid_to')) ?></label>
                            <input id="catalog-item-valid-to" type="date" name="valid_to" class="ui-date">
                        </div>
                        <div class="sm:col-span-2">
                            <label for="catalog-item-release-status" class="ui-label"><?= e($t('admin.uvr.col_status')) ?></label>
                            <select id="catalog-item-release-status" name="release_status" class="ui-input">
                                <option value=""><?= e($t('admin.select')) ?></option>
                                <?php foreach (['draft', 'review', 'published', 'deprecated'] as $status): ?>
                                    <option value="<?= e($status) ?>"><?= e($status) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                </fieldset>

                <fieldset class="ui-fieldset">
                    <legend class="ui-legend"><?= e($t('admin.catalogs.group_version')) ?></legend>
                    <div class="grid gap-4 sm:grid-cols-2">
                        <div class="sm:col-span-2">
                            <label for="catalog-item-term" class="ui-label"><?= e($t('admin.catalogs.col_term')) ?></label>
                            <input id="catalog-item-term" type="text" name="preferred_term" maxlength="255" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-item-definition" class="ui-label"><?= e($t('admin.catalogs.col_definition')) ?></label>
                            <textarea id="catalog-item-definition" name="definition" rows="2" maxlength="4000" class="ui-input"></textarea>
                        </div>
                        <div>
                            <label for="catalog-item-criteria" class="ui-label"><?= e($t('admin.catalogs.col_criteria')) ?></label>
                            <textarea id="catalog-item-criteria" name="clinical_criteria" rows="2" maxlength="4000" class="ui-input"></textarea>
                        </div>
                        <div>
                            <label for="catalog-item-language" class="ui-label"><?= e($t('admin.catalogs.col_language')) ?></label>
                            <select id="catalog-item-language" name="language_code" class="ui-input">
                                <?php foreach ($catalogLanguageOptions as $language): ?>
                                    <option value="<?= e($language) ?>"><?= e($language) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                </fieldset>

                <fieldset class="ui-fieldset">
                    <legend class="ui-legend"><?= e($t('admin.catalogs.group_relations')) ?></legend>
                    <div class="grid gap-4 sm:grid-cols-2">
                        <div>
                            <label for="catalog-rel-target" class="ui-label"><?= e($t('admin.catalogs.col_target')) ?></label>
                            <input id="catalog-rel-target" type="number" name="relations[0][target_item_id]" min="1" class="ui-input">
                        </div>
                        <div>
                            <label for="catalog-rel-type" class="ui-label"><?= e($t('admin.catalogs.col_relation')) ?></label>
                            <select id="catalog-rel-type" name="relations[0][relation_type]" class="ui-input">
                                <?php foreach (['refer_to_details', 'used_in_combination_with', 'not_paid_separately', 'interchangeable_with'] as $type): ?>
                                    <option value="<?= e($type) ?>"><?= e($type) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="catalog-rel-field" class="ui-label"><?= e($t('admin.catalogs.col_source_field')) ?></label>
                            <select id="catalog-rel-field" name="relations[0][source_field]" class="ui-input">
                                <?php foreach (['description', 'procedure', 'notes', 'req'] as $field): ?>
                                    <option value="<?= e($field) ?>"><?= e($field) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div>
                            <label for="catalog-rel-value" class="ui-label"><?= e($t('admin.catalogs.col_source_value')) ?></label>
                            <input id="catalog-rel-value" type="text" name="relations[0][source_value]" maxlength="20" class="ui-input">
                        </div>
                        <div class="sm:col-span-2">
                            <label for="catalog-rel-provenance" class="ui-label"><?= e($t('admin.catalogs.col_provenance')) ?></label>
                            <input id="catalog-rel-provenance" type="text" name="relations[0][provenance]" maxlength="2000" class="ui-input">
                        </div>
                    </div>
                </fieldset>

                <fieldset class="ui-fieldset">
                    <legend class="ui-legend"><?= e($t('admin.catalogs.group_languages')) ?></legend>
                    <div class="grid gap-4 sm:grid-cols-3">
                        <div>
                            <label for="catalog-lang-code" class="ui-label"><?= e($t('admin.catalogs.col_language')) ?></label>
                            <select id="catalog-lang-code" name="languages[0][language_code]" class="ui-input">
                                <?php foreach ($catalogLanguageOptions as $language): ?>
                                    <option value="<?= e($language) ?>"><?= e($language) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <label class="flex items-center gap-2 self-end pb-2.5 text-sm text-ink-soft">
                            <input type="checkbox" name="languages[0][enabled]" value="1"
                                   class="h-4 w-4 rounded border-line text-teal focus:ring-teal/30">
                            <?= e($t('admin.catalogs.apply_language')) ?>
                        </label>
                        <div>
                            <label for="catalog-lang-coverage" class="ui-label"><?= e($t('admin.catalogs.col_coverage')) ?></label>
                            <select id="catalog-lang-coverage" name="languages[0][coverage_status]" class="ui-input">
                                <?php foreach ($catalogCoverage as $coverage): ?>
                                    <option value="<?= e($coverage) ?>"><?= e($coverage) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                    </div>
                </fieldset>

                <div>
                    <label for="catalog-item-source" class="ui-label"><?= e($t('admin.uvr.col_source')) ?></label>
                    <textarea id="catalog-item-source" name="source_reference" required rows="2" maxlength="2000"
                              class="ui-input"><?= $catalogValue('source_reference') ?></textarea>
                </div>

                <button type="submit" class="ui-btn w-full"><?= e($t('admin.catalogs.propose_submit')) ?></button>
            </form>
        </article>
    <?php endif; ?>
<?php endif; ?>
</section>
