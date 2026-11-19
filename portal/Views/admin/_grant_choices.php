<?php

declare(strict_types=1);

/**
 * Selector de grants por catálogo con casillas de verificación.
 *
 * Se incluye desde los formularios de asignación, invitación y edición de
 * memberships. El servidor vuelve a validar cada valor contra os_catalog.
 *
 * @var list<array{code: string, name: string, short_name: string}> $catalogs
 * @var list<string> $allowedSelected
 * @var list<string> $deniedSelected
 */

$allowedSelected = is_array($allowedSelected ?? null) ? $allowedSelected : [];
$deniedSelected = is_array($deniedSelected ?? null) ? $deniedSelected : [];
?>
<fieldset class="admin-grant-choices">
    <legend><?= e($t('admin.grants.title')) ?></legend>

    <?php if ($catalogs === []): ?>
        <p class="admin-help"><?= e($t('admin.grants.empty')) ?></p>
    <?php else: ?>
        <p class="admin-help"><?= e($t('admin.grants.legend')) ?></p>
        <div class="admin-grant-grid">
            <?php foreach ($catalogs as $catalog): ?>
                <div class="admin-grant-catalog">
                    <div class="admin-grant-heading">
                        <strong title="<?= e($catalog['name']) ?>">
                            <?= e($catalog['short_name'] !== '' ? $catalog['short_name'] : $catalog['name']) ?>
                        </strong>
                        <code><?= e($catalog['code']) ?></code>
                    </div>
                    <div class="admin-grant-ops">
                        <?php foreach (\OrigenSalud\Portal\Admin\Rbac::CATALOG_OPERATIONS as $operation): ?>
                            <?php $value = $catalog['code'] . '|' . $operation; ?>
                            <div class="admin-grant-op">
                                <span><?= e($t('admin.grants.ops.' . $operation)) ?></span>
                                <label title="<?= e($t('admin.grants.allow')) ?>">
                                    <input type="checkbox" name="grant_allow[]" value="<?= e($value) ?>"
                                           <?= in_array($value, $allowedSelected, true) ? 'checked' : '' ?>>
                                    <span aria-hidden="true">✓</span>
                                    <span class="sr-only"><?= e($t('admin.grants.allow')) ?></span>
                                </label>
                                <label title="<?= e($t('admin.grants.deny')) ?>">
                                    <input type="checkbox" name="grant_deny[]" value="<?= e($value) ?>"
                                           <?= in_array($value, $deniedSelected, true) ? 'checked' : '' ?>>
                                    <span aria-hidden="true">✗</span>
                                    <span class="sr-only"><?= e($t('admin.grants.deny')) ?></span>
                                </label>
                            </div>
                        <?php endforeach; ?>
                    </div>
                </div>
            <?php endforeach; ?>
        </div>
    <?php endif; ?>
</fieldset>
