<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $valuations */

require __DIR__ . '/_nav.php';

$uvrFormat = static fn (mixed $value): string => number_format((float) $value, 2, ',', '.');
?>
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.e')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.uvr.compare_note')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="git-compare-arrows" class="h-5 w-5"></i>
        </span>
    </div>

    <?php if (count($valuations) < 2): ?>
        <p class="ui-empty"><?= e($t('admin.uvr.compare_empty')) ?></p>
    <?php else: ?>
        <div class="ui-table-wrap">
            <table class="ui-table">
                <thead>
                <tr>
                    <th class="ui-th"><?= e($t('admin.uvr.col_item')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_version')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.work')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.practice')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.liability')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_total')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($valuations as $valuation): ?>
                    <tr class="transition hover:bg-paper/60">
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($valuation['service_item_id'] ?? '')) ?></code></td>
                        <td class="ui-td"><?= e((string) ($valuation['version_tag'] ?? '')) ?></td>
                        <td class="ui-td"><?= $uvrFormat($valuation['work_uvr'] ?? 0) ?></td>
                        <td class="ui-td"><?= $uvrFormat($valuation['practice_expense_uvr'] ?? 0) ?></td>
                        <td class="ui-td"><?= $uvrFormat($valuation['professional_liability_uvr'] ?? 0) ?></td>
                        <td class="ui-td font-semibold text-ink"><?= $uvrFormat($valuation['total_uvr'] ?? 0) ?></td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($valuation['review_status'] ?? '')) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
