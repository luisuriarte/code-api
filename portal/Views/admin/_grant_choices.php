<?php

declare(strict_types=1);

/**
 * Selector compacto de grants por catálogo.
 *
 * Cada operación es un "chip" de un solo clic para permitir. Las denegaciones
 * explícitas viven en una sección plegable para no recargar la pantalla.
 * El servidor vuelve a validar cada valor contra os_catalog.
 *
 * @var list<array{code: string, name: string, short_name: string}> $catalogs
 * @var list<string> $allowedSelected
 * @var list<string> $deniedSelected
 */

$allowedSelected = is_array($allowedSelected ?? null) ? $allowedSelected : [];
$deniedSelected = is_array($deniedSelected ?? null) ? $deniedSelected : [];

/**
 * @param list<array{code: string, name: string, short_name: string}> $catalogs
 * @param list<string> $selected
 * @param string $field
 */
$renderChips = static function (array $catalogs, array $selected, string $field) use ($t): void {
    foreach ($catalogs as $catalog) {
        ?>
        <div class="admin-grants-row">
            <div class="admin-grants-label">
                <strong title="<?= e($catalog['name']) ?>">
                    <?= e($catalog['short_name'] !== '' ? $catalog['short_name'] : $catalog['name']) ?>
                </strong>
                <code><?= e($catalog['code']) ?></code>
            </div>
            <div class="admin-grants-chips">
                <?php foreach (\OrigenSalud\Portal\Admin\Rbac::CATALOG_OPERATIONS as $operation): ?>
                    <?php $value = $catalog['code'] . '|' . $operation; ?>
                    <label class="admin-grant-chip">
                        <input type="checkbox" name="<?= e($field) ?>[]" value="<?= e($value) ?>"
                               <?= in_array($value, $selected, true) ? 'checked' : '' ?>>
                        <span><?= e($t('admin.grants.ops.' . $operation)) ?></span>
                    </label>
                <?php endforeach; ?>
            </div>
        </div>
        <?php
    }
};
?>
<fieldset class="admin-grants">
    <legend><?= e($t('admin.grants.title')) ?></legend>

    <?php if ($catalogs === []): ?>
        <p class="admin-help"><?= e($t('admin.grants.empty')) ?></p>
    <?php else: ?>
        <p class="admin-help"><?= e($t('admin.grants.legend')) ?></p>
        <div class="admin-grants-list">
            <?php $renderChips($catalogs, $allowedSelected, 'grant_allow'); ?>
        </div>

        <details class="admin-grants-deny">
            <summary>
                <?= e($t('admin.grants.deny_title')) ?>
                <?php if ($deniedSelected !== []): ?>
                    <span class="admin-grants-count"><?= count($deniedSelected) ?></span>
                <?php endif; ?>
            </summary>
            <p class="admin-help"><?= e($t('admin.grants.deny_help')) ?></p>
            <div class="admin-grants-list">
                <?php $renderChips($catalogs, $deniedSelected, 'grant_deny'); ?>
            </div>
        </details>
    <?php endif; ?>
</fieldset>
