<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $catalogs */
/** @var string $catalogCode */
/** @var list<array<string, mixed>> $items */
/** @var string $query */
/** @var array<string, mixed> $current */

require __DIR__ . '/_nav.php';

$catalogHref = static fn (string $code): string => '/admin/catalogs/' . rawurlencode($code);
?>
<div class="admin-grid">
    <article class="admin-box">
        <h2><?= e($t('admin.catalogs.select_title')) ?></h2>
        <form method="get" action="/admin/catalogs" class="admin-form">
            <label><?= e($t('admin.uvr.col_catalog')) ?>
                <select name="code" required onchange="this.form.submit()">
                    <option value=""><?= e($t('admin.select')) ?></option>
                    <?php foreach ($catalogs as $catalog): ?>
                        <?php $code = (string) ($catalog['code'] ?? ''); ?>
                        <option value="<?= e($code) ?>" <?= $code === $catalogCode ? 'selected' : '' ?>>
                            <?= e((string) ($catalog['name'] ?? $code)) ?> (<?= e($code) ?>)
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>
            <button type="submit" class="button button-small"><?= e($t('admin.catalogs.select_submit')) ?></button>
        </form>

        <?php if ($catalogCode !== ''): ?>
            <h3><?= e($t('admin.catalogs.search_title')) ?></h3>
            <form method="get" action="<?= e($catalogHref($catalogCode)) ?>" class="admin-form">
                <label><?= e($t('admin.catalogs.search_label')) ?>
                    <input type="search" name="q" maxlength="80" value="<?= e($query) ?>"
                           placeholder="<?= e($t('admin.catalogs.search_placeholder')) ?>">
                </label>
                <button type="submit" class="button button-small"><?= e($t('admin.catalogs.search_submit')) ?></button>
            </form>

            <?php if ($items === []): ?>
                <p><?= e($t('admin.uvr.empty')) ?></p>
            <?php else: ?>
                <div class="admin-table-wrap">
                    <table class="admin-table">
                        <thead>
                        <tr>
                            <th><?= e($t('admin.catalogs.col_code')) ?></th>
                            <th><?= e($t('admin.catalogs.col_term')) ?></th>
                            <th><?= e($t('admin.uvr.col_status')) ?></th>
                            <th><?= e($t('admin.catalogs.col_uvr')) ?></th>
                        </tr>
                        </thead>
                        <tbody>
                        <?php foreach ($items as $item): ?>
                            <?php
                            $itemId = (int) ($item['id'] ?? 0);
                            $itemHref = $catalogHref($catalogCode) . '/items/' . $itemId;
                            $uvrHref = '/admin/uvr/proposals?service_item_id=' . $itemId;
                            ?>
                            <tr>
                                <td><a href="<?= e($itemHref) ?>"><code><?= e((string) ($item['permanent_code'] ?? '')) ?></code></a></td>
                                <td><?= e((string) ($item['preferred_term'] ?? '')) ?></td>
                                <td><code><?= e((string) ($item['status'] ?? '')) ?></code></td>
                                <td><a href="<?= e($uvrHref) ?>"><?= e($t('admin.catalogs.uvr_button')) ?></a></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        <?php endif; ?>
    </article>

    <?php if ($catalogCanPropose): ?>
        <article class="admin-box">
            <h2><?= e($t('admin.catalogs.new_title')) ?></h2>
            <p><?= e($t('admin.catalogs.new_note')) ?></p>
            <form method="post" action="/admin/catalogs/proposals" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <input type="hidden" name="operation" value="create">
                <label><?= e($t('admin.uvr.col_catalog')) ?>
                    <select name="code" required>
                        <option value=""><?= e($t('admin.select')) ?></option>
                        <?php foreach ($catalogs as $catalog): ?>
                            <option value="<?= e((string) ($catalog['code'] ?? '')) ?>"
                                <?= (string) ($catalog['code'] ?? '') === $catalogCode ? 'selected' : '' ?>>
                                <?= e((string) ($catalog['name'] ?? '')) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label><?= e($t('admin.catalogs.col_code')) ?>
                    <input type="text" name="permanent_code" required maxlength="50"
                           value="<?= $catalogValue('permanent_code') ?>">
                </label>
                <label><?= e($t('admin.uvr.col_status')) ?>
                    <select name="status" required>
                        <option value="active">active</option>
                        <option value="retired">retired</option>
                        <option value="superseded">superseded</option>
                    </select>
                </label>
                <label><?= e($t('admin.catalogs.col_term')) ?>
                    <input type="text" name="preferred_term" maxlength="255"
                           value="<?= $catalogValue('preferred_term') ?>">
                </label>
                <label><?= e($t('admin.catalogs.col_release')) ?>
                    <input type="number" name="release_id" min="1" value="<?= $catalogValue('release_id') ?>">
                </label>
                <label><?= e($t('admin.uvr.version_tag')) ?>
                    <input type="text" name="version_tag" maxlength="50" value="<?= $catalogValue('version_tag') ?>">
                </label>
                <label><?= e($t('admin.uvr.valid_from')) ?>
                    <input type="date" name="valid_from" value="<?= $catalogValue('valid_from') ?>">
                </label>
                <label><?= e($t('admin.uvr.col_source')) ?>
                    <textarea name="source_reference" required rows="2" maxlength="2000"><?= $catalogValue('source_reference') ?></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.catalogs.propose_submit')) ?></button>
            </form>
        </article>
    <?php endif; ?>
</div>
</section>
