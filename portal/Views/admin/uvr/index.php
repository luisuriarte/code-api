<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $valuations */
/** @var array<string, mixed> $current */

require __DIR__ . '/_nav.php';

$uvrPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$uvrCanPublish = \OrigenSalud\Portal\Admin\Rbac::hasPermission($uvrPermissions, 'catalog.publish');
$uvrFormat = static fn (mixed $value): string => number_format((float) $value, 2, ',', '.');
?>
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.a')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.uvr.derived_note')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="table-properties" class="h-5 w-5"></i>
        </span>
    </div>

    <?php if ($valuations === []): ?>
        <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="ui-table-wrap">
            <table class="ui-table">
                <thead>
                <tr>
                    <th class="ui-th"><?= e($t('admin.uvr.col_code')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_version')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_components')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_total')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_importe')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_published')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($valuations as $valuation): ?>
                    <?php
                    $uvrId = (int) ($valuation['valuation_id'] ?? 0);
                    $uvrImporte = is_array($valuation['importe'] ?? null) ? $valuation['importe'] : null;
                    ?>
                    <tr class="transition hover:bg-paper/60">
                        <td class="ui-td">
                            <code class="ui-code"><?= e((string) ($valuation['subject_code'] ?? $valuation['service_item_id'] ?? '')) ?></code>
                            <?php if (($valuation['valuation_kind'] ?? '') === 'prestacion'): ?>
                                <span class="mt-0.5 block text-xs text-muted">
                                    <?= e($t('admin.uvr.prestacion')) ?>:
                                    <?= e((string) ($valuation['prestacion_name'] ?? '')) ?>
                                    · <?= e($t('admin.uvr.profile')) ?>:
                                    <?= e((string) ($valuation['profile_code'] ?? '')) ?>
                                </span>
                            <?php endif; ?>
                        </td>
                        <td class="ui-td"><?= e((string) ($valuation['version_tag'] ?? '')) ?></td>
                        <td class="ui-td">
                            <span class="block text-xs text-muted">
                                <?= e($t('admin.uvr.work')) ?>: <?= $uvrFormat($valuation['work_uvr'] ?? 0) ?>
                                · <?= e($t('admin.uvr.practice')) ?>: <?= $uvrFormat($valuation['practice_expense_uvr'] ?? 0) ?>
                                · <?= e($t('admin.uvr.liability')) ?>: <?= $uvrFormat($valuation['professional_liability_uvr'] ?? 0) ?>
                            </span>
                        </td>
                        <td class="ui-td font-semibold text-ink"><?= $uvrFormat($valuation['total_uvr'] ?? 0) ?></td>
                        <td class="ui-td">
                            <?php if ($uvrImporte === null): ?>
                                <span class="text-muted"><?= e($t('admin.uvr.no_conversion')) ?></span>
                            <?php else: ?>
                                <span class="font-semibold text-ink"><?= e($uvrFormat($uvrImporte['importe_referencial'] ?? 0) . ' ' . (string) ($uvrImporte['currency'] ?? '')) ?></span>
                                <span class="mt-0.5 block text-xs text-muted"><?= e($t('admin.uvr.estimated_note')) ?></span>
                            <?php endif; ?>
                        </td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($valuation['review_status'] ?? '')) ?></code></td>
                        <td class="ui-td">
                            <span class="block"><?= e((string) ($valuation['published_at'] ?? '')) ?></span>
                            <?php if ($uvrCanPublish && ($valuation['review_status'] ?? '') === 'approved'): ?>
                            <form method="post" action="/admin/uvr/valuations/<?= $uvrId ?>/publish" class="mt-2">
                                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                <button type="submit" class="ui-btn ui-btn-sm">
                                    <i data-lucide="send" class="h-3.5 w-3.5"></i>
                                    <?= e($t('admin.uvr.publish')) ?>
                                </button>
                            </form>
                            <?php endif; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
