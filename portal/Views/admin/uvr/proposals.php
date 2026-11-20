<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $proposals */
/** @var array<string, mixed> $current */

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
?>
<div class="ui-grid items-start">
    <?php if ($uvrCanPropose): ?>
        <article class="ui-card ui-card-pad">
            <div class="mb-5 flex items-start justify-between gap-4">
                <div>
                    <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.propose_title')) ?></h2>
                    <p class="ui-subtitle"><?= e($t('admin.uvr.lead')) ?></p>
                </div>
                <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
                    <i data-lucide="file-plus-2" class="h-5 w-5"></i>
                </span>
            </div>

            <form method="post" action="/admin/uvr/proposals" class="space-y-5">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">

                <div class="grid gap-4 sm:grid-cols-2">
                    <div>
                        <label for="uvr-item" class="ui-label"><?= e($t('admin.uvr.col_item')) ?></label>
                        <input id="uvr-item" type="number" name="service_item_id" min="1" required
                               value="<?= $uvrValue('service_item_id') ?>" class="ui-input">
                    </div>
                    <div>
                        <label for="uvr-release" class="ui-label"><?= e($t('admin.uvr.col_release')) ?></label>
                        <input id="uvr-release" type="number" name="release_id" min="1" class="ui-input">
                    </div>
                    <div>
                        <label for="uvr-version" class="ui-label"><?= e($t('admin.uvr.version_tag')) ?></label>
                        <input id="uvr-version" type="text" name="version_tag" required maxlength="50"
                               value="<?= $uvrValue('version_tag') ?>" class="ui-input">
                    </div>
                    <div>
                        <label for="uvr-methodology" class="ui-label"><?= e($t('admin.uvr.methodology')) ?></label>
                        <input id="uvr-methodology" type="text" name="methodology" required maxlength="120"
                               value="<?= $uvrValue('methodology') ?>" class="ui-input">
                    </div>
                    <div class="sm:col-span-2">
                        <label for="uvr-source" class="ui-label"><?= e($t('admin.uvr.col_source')) ?></label>
                        <textarea id="uvr-source" name="source_reference" required rows="2" maxlength="2000"
                                  class="ui-input"><?= $uvrValue('source_reference') ?></textarea>
                    </div>
                    <div>
                        <label for="uvr-evaluated" class="ui-label"><?= e($t('admin.uvr.evaluated_at')) ?></label>
                        <input id="uvr-evaluated" type="date" name="evaluated_at" required
                               value="<?= $uvrValue('evaluated_at') ?>" class="ui-input">
                    </div>
                    <div>
                        <label for="uvr-valid-from" class="ui-label"><?= e($t('admin.uvr.valid_from')) ?></label>
                        <input id="uvr-valid-from" type="date" name="valid_from"
                               value="<?= $uvrValue('valid_from') ?>" class="ui-input">
                    </div>
                    <div>
                        <label for="uvr-valid-to" class="ui-label"><?= e($t('admin.uvr.valid_to')) ?></label>
                        <input id="uvr-valid-to" type="date" name="valid_to"
                               value="<?= $uvrValue('valid_to') ?>" class="ui-input">
                    </div>
                </div>

                <fieldset class="ui-fieldset">
                    <legend class="ui-legend"><?= e($t('admin.uvr.col_components')) ?></legend>
                    <div class="space-y-4">
                        <?php foreach ($uvrComponents as $type => $label): ?>
                            <?php $componentKey = e($type); ?>
                            <div class="rounded-xl border border-line bg-white p-4">
                                <p class="mb-3 text-sm font-semibold text-ink"><?= e($t($label)) ?></p>
                                <div class="grid gap-3 sm:grid-cols-2">
                                    <div>
                                        <label class="ui-label" for="uvr-<?= $componentKey ?>-value"><?= e($t('admin.uvr.col_value')) ?></label>
                                        <input id="uvr-<?= $componentKey ?>-value" type="number" step="0.0001"
                                               name="components[<?= $componentKey ?>][value]" value="0" class="ui-input">
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
        </article>
    <?php endif; ?>

    <article class="ui-card ui-card-pad">
        <div class="mb-5 flex items-start justify-between gap-4">
            <div>
                <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.c')) ?></h2>
                <p class="ui-subtitle"><?= e($t('admin.uvr.lead')) ?></p>
            </div>
            <span class="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-mint text-teal-dark">
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
</div>
</section>
