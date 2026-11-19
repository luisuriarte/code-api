<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $events */
?>
<section class="admin-panel">
    <h1><?= e($t('admin.audit.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.audit.lead')) ?></p>

    <?php if ($events === []): ?>
    <p><?= e($t('admin.audit.empty')) ?></p>
    <?php else: ?>
    <div class="admin-table-wrap">
        <table class="admin-table">
            <thead>
            <tr>
                <th><?= e($t('admin.audit.when')) ?></th>
                <th><?= e($t('admin.audit.actor')) ?></th>
                <th><?= e($t('admin.audit.action')) ?></th>
                <th><?= e($t('admin.audit.detail')) ?></th>
            </tr>
            </thead>
            <tbody>
            <?php foreach ($events as $event): ?>
                <tr>
                    <td><?= e((string) ($event['occurred_at'] ?? '')) ?></td>
                    <td><?= e((string) ($event['actor_email'] ?? '')) ?></td>
                    <td><code><?= e((string) ($event['action'] ?? '')) ?></code></td>
                    <td><?= e((string) ($event['reason'] ?? ($event['catalog_code'] ?? ''))) ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    <?php endif; ?>
</section>
