<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $valuations */
/** @var array<string, mixed> $current */

require __DIR__ . '/_nav.php';

$uvrPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$uvrCanPublish = \OrigenSalud\Portal\Admin\Rbac::hasPermission($uvrPermissions, 'catalog.publish');
$uvrFormat = static fn (mixed $value): string => number_format((float) $value, 2, ',', '.');
?>
<article class="admin-box">
    <h2><?= e($t('admin.uvr.a')) ?></h2>
    <p><?= e($t('admin.uvr.derived_note')) ?></p>
    <?php if ($valuations === []): ?>
        <p><?= e($t('admin.uvr.empty')) ?></p>
    <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.uvr.col_item')) ?></th>
                    <th><?= e($t('admin.uvr.col_version')) ?></th>
                    <th><?= e($t('admin.uvr.col_components')) ?></th>
                    <th><?= e($t('admin.uvr.col_total')) ?></th>
                    <th><?= e($t('admin.uvr.col_importe')) ?></th>
                    <th><?= e($t('admin.uvr.col_status')) ?></th>
                    <th><?= e($t('admin.uvr.col_published')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($valuations as $valuation): ?>
                    <?php
                    $uvrId = (int) ($valuation['valuation_id'] ?? 0);
                    $uvrImporte = is_array($valuation['importe'] ?? null) ? $valuation['importe'] : null;
                    ?>
                    <tr>
                        <td><code><?= e((string) ($valuation['service_item_id'] ?? '')) ?></code></td>
                        <td><?= e((string) ($valuation['version_tag'] ?? '')) ?></td>
                        <td>
                            <?= e($t('admin.uvr.work')) ?>: <?= $uvrFormat($valuation['work_uvr'] ?? 0) ?>
                            · <?= e($t('admin.uvr.practice')) ?>: <?= $uvrFormat($valuation['practice_expense_uvr'] ?? 0) ?>
                            · <?= e($t('admin.uvr.liability')) ?>: <?= $uvrFormat($valuation['professional_liability_uvr'] ?? 0) ?>
                        </td>
                        <td><?= $uvrFormat($valuation['total_uvr'] ?? 0) ?></td>
                        <td>
                            <?php if ($uvrImporte === null): ?>
                                <?= e($t('admin.uvr.no_conversion')) ?>
                            <?php else: ?>
                                <?= e($uvrFormat($uvrImporte['importe_referencial'] ?? 0)
                                    . ' ' . (string) ($uvrImporte['currency'] ?? '')) ?>
                                <small><?= e($t('admin.uvr.estimated_note')) ?></small>
                            <?php endif; ?>
                        </td>
                        <td><code><?= e((string) ($valuation['review_status'] ?? '')) ?></code></td>
                        <td>
                            <?= e((string) ($valuation['published_at'] ?? '')) ?>
                            <?php if ($uvrCanPublish && ($valuation['review_status'] ?? '') === 'approved'): ?>
                                <form method="post" action="/admin/uvr/valuations/<?= $uvrId ?>/publish"
                                      class="admin-inline">
                                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                    <button type="submit" class="button button-small">
                                        <?= e($t('admin.uvr.publish')) ?>
                                    </button>
                                </form>
                            <?php endif; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</article>
</section>
