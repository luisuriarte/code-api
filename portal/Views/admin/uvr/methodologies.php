<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $methodologies */

require __DIR__ . '/_nav.php';
?>
<article class="ui-card ui-card-pad">
    <div class="mb-5 flex flex-wrap items-start justify-between gap-4">
        <div>
            <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.uvr.f')) ?></h2>
            <p class="ui-subtitle"><?= e($t('admin.uvr.methodologies_note')) ?></p>
        </div>
        <span class="flex h-10 w-10 items-center justify-center rounded-xl bg-mint text-teal-dark">
            <i data-lucide="book-open" class="h-5 w-5"></i>
        </span>
    </div>

    <?php if ($methodologies === []): ?>
        <p class="ui-empty"><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="ui-table-wrap">
            <table class="ui-table">
                <thead>
                <tr>
                    <th class="ui-th"><?= e($t('admin.uvr.methodology')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.version_tag')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_valuations')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_source')) ?></th>
                    <th class="ui-th"><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($methodologies as $methodology): ?>
                    <tr class="transition hover:bg-paper/60">
                        <td class="ui-td font-medium text-ink"><?= e((string) $methodology['methodology']) ?></td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) $methodology['version_tag']) ?></code></td>
                        <td class="ui-td"><span class="ui-badge"><?= (int) $methodology['count'] ?></span></td>
                        <td class="ui-td"><?= e((string) $methodology['source_reference']) ?></td>
                        <td class="ui-td"><code class="ui-code"><?= e((string) $methodology['review_status']) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
