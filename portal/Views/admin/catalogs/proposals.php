<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $proposals */

require __DIR__ . '/_nav.php';
?>
<article class="admin-box">
    <h2><?= e($t('admin.catalogs.requests_title')) ?></h2>
    <p><?= e($t('admin.catalogs.requests_note')) ?></p>
    <?php if ($proposals === []): ?>
        <p><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.col_id')) ?></th>
                    <th><?= e($t('admin.uvr.col_subject')) ?></th>
                    <th><?= e($t('admin.uvr.col_source')) ?></th>
                    <th><?= e($t('admin.uvr.col_actor')) ?></th>
                    <th><?= e($t('admin.uvr.col_status')) ?></th>
                    <th><?= e($t('admin.uvr.col_created')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($proposals as $proposal): ?>
                    <tr>
                        <td><a href="/admin/catalogs/proposals/<?= (int) ($proposal['id'] ?? 0) ?>"><?= (int) ($proposal['id'] ?? 0) ?></a></td>
                        <td><code><?= e((string) ($proposal['subject_id'] ?? '')) ?></code></td>
                        <td><?= e((string) ($proposal['source_reference'] ?? '')) ?></td>
                        <td><?= e((string) ($proposal['requested_by'] ?? '')) ?></td>
                        <td><code><?= e((string) ($proposal['review_status'] ?? '')) ?></code></td>
                        <td><?= e((string) ($proposal['created_at'] ?? '')) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
