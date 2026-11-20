<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $valuations */

require __DIR__ . '/_nav.php';

$uvrFormat = static fn (mixed $value): string => number_format((float) $value, 2, ',', '.');
?>
<article class="admin-box">
    <h2><?= e($t('admin.uvr.e')) ?></h2>
    <p><?= e($t('admin.uvr.compare_note')) ?></p>
    <?php if (count($valuations) < 2): ?>
        <p><?= e($t('admin.uvr.compare_empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.col_item')) ?></th>
                    <th><?= e($t('admin.uvr.col_version')) ?></th>
                    <th><?= e($t('admin.uvr.work')) ?></th>
                    <th><?= e($t('admin.uvr.practice')) ?></th>
                    <th><?= e($t('admin.uvr.liability')) ?></th>
                    <th><?= e($t('admin.uvr.col_total')) ?></th>
                    <th><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($valuations as $valuation): ?>
                    <tr>
                        <td><code><?= e((string) ($valuation['service_item_id'] ?? '')) ?></code></td>
                        <td><?= e((string) ($valuation['version_tag'] ?? '')) ?></td>
                        <td><?= $uvrFormat($valuation['work_uvr'] ?? 0) ?></td>
                        <td><?= $uvrFormat($valuation['practice_expense_uvr'] ?? 0) ?></td>
                        <td><?= $uvrFormat($valuation['professional_liability_uvr'] ?? 0) ?></td>
                        <td><?= $uvrFormat($valuation['total_uvr'] ?? 0) ?></td>
                        <td><code><?= e((string) ($valuation['review_status'] ?? '')) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
