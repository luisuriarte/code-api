<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $tasks */

require __DIR__ . '/_nav.php';
?>
<article class="admin-box">
    <h2><?= e($t('admin.uvr.d')) ?></h2>
    <p><?= e($t('admin.uvr.tasks_note')) ?></p>
    <?php if ($tasks === []): ?>
        <p><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.col_id')) ?></th>
                    <th><?= e($t('admin.uvr.col_subject')) ?></th>
                    <th><?= e($t('admin.uvr.col_request_type')) ?></th>
                    <th><?= e($t('admin.uvr.col_pending')) ?></th>
                    <th><?= e($t('admin.uvr.col_actor')) ?></th>
                    <th><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($tasks as $task): ?>
                    <tr>
                        <td><a href="/admin/uvr/proposals/<?= (int) $task['request_id'] ?>"><?= (int) $task['request_id'] ?></a></td>
                        <td><code><?= e((string) ($task['subject_id'] ?? '')) ?></code></td>
                        <td><?= e((string) ($task['request_type'] ?? '')) ?></td>
                        <td><?= (int) $task['pending_reviews'] ?></td>
                        <td><?= e((string) ($task['requested_by'] ?? '')) ?></td>
                        <td><code><?= e((string) ($task['review_status'] ?? '')) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
