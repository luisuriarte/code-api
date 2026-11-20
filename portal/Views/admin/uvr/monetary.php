<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $conversions */
/** @var list<array<string, mixed>> $indexes */

require __DIR__ . '/_nav.php';

$uvrFormat = static fn (mixed $value): string => number_format((float) $value, 2, ',', '.');
$uvrIndexFormat = static fn (mixed $value): string => number_format((float) $value, 6, ',', '.');
?>
<article class="admin-box">
    <h2><?= e($t('admin.uvr.g')) ?></h2>
    <p><?= e($t('admin.uvr.monetary_note')) ?></p>

    <h3><?= e($t('admin.uvr.conversions_title')) ?></h3>
    <?php if ($conversions === []): ?>
        <p><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.col_value')) ?></th>
                    <th><?= e($t('admin.uvr.col_currency')) ?></th>
                    <th><?= e($t('admin.uvr.col_jurisdiction')) ?></th>
                    <th><?= e($t('admin.uvr.col_period')) ?></th>
                    <th><?= e($t('admin.uvr.col_source')) ?></th>
                    <th><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($conversions as $conversion): ?>
                    <tr>
                        <td><?= $uvrFormat($conversion['uvr_value'] ?? 0) ?></td>
                        <td><?= e((string) ($conversion['currency'] ?? '')) ?></td>
                        <td><?= e((string) ($conversion['jurisdiction'] ?? '')) ?></td>
                        <td><?= e((string) ($conversion['period_start'] ?? '')) ?> — <?= e((string) ($conversion['period_end'] ?? '')) ?></td>
                        <td><?= e((string) ($conversion['source_reference'] ?? '')) ?></td>
                        <td><code><?= e((string) ($conversion['review_status'] ?? '')) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>

    <h3><?= e($t('admin.uvr.indexes_title')) ?></h3>
    <?php if ($indexes === []): ?>
        <p><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.col_component')) ?></th>
                    <th><?= e($t('admin.uvr.col_jurisdiction')) ?></th>
                    <th><?= e($t('admin.uvr.col_index')) ?></th>
                    <th><?= e($t('admin.uvr.col_period')) ?></th>
                    <th><?= e($t('admin.uvr.col_source')) ?></th>
                    <th><?= e($t('admin.uvr.col_status')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($indexes as $index): ?>
                    <tr>
                        <td><?= e((string) ($index['component_type'] ?? '')) ?></td>
                        <td><?= e((string) ($index['jurisdiction'] ?? '')) ?></td>
                        <td><?= $uvrIndexFormat($index['index_value'] ?? 0) ?></td>
                        <td><?= e((string) ($index['period_start'] ?? '')) ?> — <?= e((string) ($index['period_end'] ?? '')) ?></td>
                        <td><?= e((string) ($index['source_reference'] ?? '')) ?></td>
                        <td><code><?= e((string) ($index['review_status'] ?? '')) ?></code></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
