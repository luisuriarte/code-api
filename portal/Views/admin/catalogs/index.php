<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $catalogs */
/** @var string $catalogCode */
/** @var list<array<string, mixed>> $items */
/** @var string $query */
/** @var array<string, mixed> $current */

require __DIR__ . '/_nav.php';

$catalogHref = static fn (string $code): string => '/admin/catalogs/' . rawurlencode($code);
?>
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
                                $itemHref = $catalogHref($catalogCode) . '/items/' . $itemId;
                                $uvrHref = '/admin/uvr/proposals?service_item_id=' . $itemId;
                                ?>
                                <tr class="transition hover:bg-paper/60">
                                    <td class="ui-td">
                                        <a href="<?= e($itemHref) ?>" class="font-semibold no-underline">
                                            <code class="ui-code"><?= e((string) ($item['permanent_code'] ?? '')) ?></code>
                                        </a>
                                    </td>
                                    <td class="ui-td font-medium text-ink"><?= e((string) ($item['preferred_term'] ?? '')) ?></td>
                                    <td class="ui-td"><code class="ui-code"><?= e((string) ($item['status'] ?? '')) ?></code></td>
                                    <td class="ui-td">
                                        <a href="<?= e($uvrHref) ?>" class="ui-btn ui-btn-sm ui-btn-ghost no-underline">
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
</div>
</section>
