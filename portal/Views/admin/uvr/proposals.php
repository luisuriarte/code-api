<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $proposals */
/** @var array<string, mixed> $current */

require __DIR__ . '/_nav.php';

$uvrPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$uvrCanPropose = \OrigenSalud\Portal\Admin\Rbac::hasPermission($uvrPermissions, 'catalog.propose');
$uvrValues = is_array($flash['values'] ?? null) ? $flash['values'] : [];
$uvrPrefill = is_array($prefill ?? null) ? $prefill : [];
$uvrValue = static fn (string $key, string $default = ''): string => e(
    is_string($uvrValues[$key] ?? null) && $uvrValues[$key] !== ''
        ? $uvrValues[$key]
        : (is_string($uvrPrefill[$key] ?? null) && $uvrPrefill[$key] !== '' ? $uvrPrefill[$key] : $default)
);
$uvrComponents = [
    'work' => 'admin.uvr.work',
    'practice_expense' => 'admin.uvr.practice',
    'professional_liability' => 'admin.uvr.liability',
];
?>
<div class="admin-grid">
    <?php if ($uvrCanPropose): ?>
        <article class="admin-box">
            <h2><?= e($t('admin.uvr.propose_title')) ?></h2>
            <form method="post" action="/admin/uvr/proposals" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.uvr.col_item')) ?>
                    <input type="number" name="service_item_id" min="1" required
                           value="<?= $uvrValue('service_item_id') ?>">
                </label>
                <label><?= e($t('admin.uvr.col_release')) ?>
                    <input type="number" name="release_id" min="1">
                </label>
                <label><?= e($t('admin.uvr.version_tag')) ?>
                    <input type="text" name="version_tag" required maxlength="50"
                           value="<?= $uvrValue('version_tag') ?>">
                </label>
                <label><?= e($t('admin.uvr.methodology')) ?>
                    <input type="text" name="methodology" required maxlength="120"
                           value="<?= $uvrValue('methodology') ?>">
                </label>
                <label><?= e($t('admin.uvr.col_source')) ?>
                    <textarea name="source_reference" required rows="2" maxlength="2000"><?= $uvrValue('source_reference') ?></textarea>
                </label>
                <label><?= e($t('admin.uvr.evaluated_at')) ?>
                    <input type="date" name="evaluated_at" required value="<?= $uvrValue('evaluated_at') ?>">
                </label>
                <label><?= e($t('admin.uvr.valid_from')) ?>
                    <input type="date" name="valid_from" value="<?= $uvrValue('valid_from') ?>">
                </label>
                <label><?= e($t('admin.uvr.valid_to')) ?>
                    <input type="date" name="valid_to" value="<?= $uvrValue('valid_to') ?>">
                </label>
                <fieldset>
                    <legend><?= e($t('admin.uvr.col_components')) ?></legend>
                    <?php foreach ($uvrComponents as $type => $label): ?>
                        <div class="admin-component">
                            <strong><?= e($t($label)) ?></strong>
                            <label><?= e($t('admin.uvr.col_value')) ?>
                                <input type="number" name="components[<?= e($type) ?>][value]"
                                       step="0.0001" value="0">
                            </label>
                            <label><?= e($t('admin.uvr.not_applicable')) ?>
                                <input type="checkbox" name="components[<?= e($type) ?>][not_applicable]" value="1">
                            </label>
                            <label><?= e($t('admin.uvr.negative_evidence')) ?>
                                <textarea name="components[<?= e($type) ?>][evidence]" rows="1" maxlength="2000"></textarea>
                            </label>
                            <label><?= e($t('admin.uvr.calculation_note')) ?>
                                <textarea name="components[<?= e($type) ?>][note]" rows="1" maxlength="2000"></textarea>
                            </label>
                        </div>
                    <?php endforeach; ?>
                </fieldset>
                <button type="submit" class="button"><?= e($t('admin.uvr.propose_submit')) ?></button>
            </form>
        </article>
    <?php endif; ?>

    <article class="admin-box">
        <h2><?= e($t('admin.uvr.c')) ?></h2>
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
                            <td><a href="/admin/uvr/proposals/<?= (int) $proposal['id'] ?>"><?= (int) $proposal['id'] ?></a></td>
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
</div>
</section>
