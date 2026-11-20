<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $catalogs */

require __DIR__ . '/_nav.php';
?>
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.b')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.uvr.catalogs_note')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="library" class="h-5 w-5"></i>
        </span>
    </div>

    <?php if ($catalogs === []): ?>
        <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="ui-table-wrap">
            <table class="ui-table">
                <thead>
                <tr>
                    <th class="ui-th"><?= e($t('admin.uvr.col_catalog')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_name')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_short')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($catalogs as $catalog): ?>
                    <tr class="transition hover:bg-paper/60">
                        <td class="ui-td"><code class="ui-code"><?= e((string) ($catalog['code'] ?? '')) ?></code></td>
                        <td class="ui-td font-medium text-ink"><?= e((string) ($catalog['name'] ?? '')) ?></td>
                        <td class="ui-td"><?= e((string) ($catalog['short_name'] ?? '')) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
