<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $conversions */
/** @var list<array<string, mixed>> $indexes */

require __DIR__ . '/_nav.php';
?>
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.g')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.uvr.monetary_note')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="circle-dollar-sign" class="h-5 w-5"></i>
        </span>
    </div>

    <div class="space-y-8">
        <section>
            <h3 class="mb-3 text-base font-semibold text-ink"><?= e($t('admin.uvr.conversions_title')) ?></h3>
            <?php if ($conversions === []): ?>
                <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
            <?php else: ?>
                <div class="ui-table-wrap">
                    <table class="ui-table">
                        <thead>
                        <tr>
                            <th class="ui-th"><?= e($t('admin.uvr.col_value')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_currency')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_jurisdiction')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_period')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_source')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($conversions as $conversion): ?>
                            <tr class="transition hover:bg-paper/60">
                                <td class="ui-td font-semibold text-ink"><?= $formatNumber($conversion['uvr_value'] ?? 0) ?></td>
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($conversion['currency'] ?? '')) ?></code></td>
                                <td class="ui-td"><?= e((string) ($conversion['jurisdiction'] ?? '')) ?></td>
                                <td class="ui-td text-xs"><?= e((string) ($conversion['period_start'] ?? '')) ?> — <?= e((string) ($conversion['period_end'] ?? '')) ?></td>
                                <td class="ui-td"><?= e((string) ($conversion['source_reference'] ?? '')) ?></td>
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($conversion['review_status'] ?? '')) ?></code></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </section>

        <section>
            <h3 class="mb-3 text-base font-semibold text-ink"><?= e($t('admin.uvr.indexes_title')) ?></h3>
            <?php if ($indexes === []): ?>
                <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
            <?php else: ?>
                <div class="ui-table-wrap">
                    <table class="ui-table">
                        <thead>
                        <tr>
                            <th class="ui-th"><?= e($t('admin.uvr.col_component')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_jurisdiction')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_index')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_period')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_source')) ?></th>
                            <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($indexes as $index): ?>
                            <tr class="transition hover:bg-paper/60">
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($index['component_type'] ?? '')) ?></code></td>
                                <td class="ui-td"><?= e((string) ($index['jurisdiction'] ?? '')) ?></td>
                                <td class="ui-td font-mono text-xs text-ink"><?= $formatNumber($index['index_value'] ?? 0, 6) ?></td>
                                <td class="ui-td text-xs"><?= e((string) ($index['period_start'] ?? '')) ?> — <?= e((string) ($index['period_end'] ?? '')) ?></td>
                                <td class="ui-td"><?= e((string) ($index['source_reference'] ?? '')) ?></td>
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($index['review_status'] ?? '')) ?></code></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </section>
    </div>
</article>
</section>
