<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $catalogs */

require __DIR__ . '/_nav.php';
?>
<article class="admin-box">
    <h2><?= e($t('admin.uvr.b')) ?></h2>
    <p><?= e($t('admin.uvr.catalogs_note')) ?></p>
    <?php if ($catalogs === []): ?>
        <p><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.col_catalog')) ?></th>
                    <th><?= e($t('admin.uvr.col_name')) ?></th>
                    <th><?= e($t('admin.uvr.col_short')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($catalogs as $catalog): ?>
                    <tr>
                        <td><code><?= e((string) ($catalog['code'] ?? '')) ?></code></td>
                        <td><?= e((string) ($catalog['name'] ?? '')) ?></td>
                        <td><?= e((string) ($catalog['short_name'] ?? '')) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
