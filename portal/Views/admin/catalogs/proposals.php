<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $proposals */

require __DIR__ . '/_nav.php';
?>
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.catalogs.requests_title')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.catalogs.requests_note')) ?></p>
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
                            <a href="/admin/catalogs/proposals/<?= (int) ($proposal['id'] ?? 0) ?>" class="font-semibold no-underline">
                                <?= (int) ($proposal['id'] ?? 0) ?>
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
