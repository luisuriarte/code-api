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
        <div class="flex flex-wrap items-center justify-between gap-3 rounded-xl border border-line bg-white px-3 py-2.5">
            <div class="min-w-0">
                <strong class="block truncate text-sm font-semibold text-ink" title="<?= e($catalog['name']) ?>">
                    <?= e($catalog['short_name'] !== '' ? $catalog['short_name'] : $catalog['name']) ?>
                </strong>
                <code class="ui-code"><?= e($catalog['code']) ?></code>
            </div>
            <div class="flex flex-wrap gap-1.5">
                <?php foreach (\OrigenSalud\Portal\Admin\Rbac::CATALOG_OPERATIONS as $operation): ?>
                    <?php $value = $catalog['code'] . '|' . $operation; ?>
                    <label class="inline-flex cursor-pointer items-center gap-1.5 rounded-full border border-line bg-paper px-2.5 py-1 text-xs font-medium text-ink-soft transition hover:border-teal hover:text-teal-dark has-[:checked]:border-teal has-[:checked]:bg-mint has-[:checked]:text-teal-dark">
                        <input type="checkbox" name="<?= e($field) ?>[]" value="<?= e($value) ?>"
                               class="h-3.5 w-3.5 rounded border-line text-teal focus:ring-teal/30"
                               <?= in_array($value, $selected, true) ? 'checked' : '' ?>>
                        <span><?= e($t('admin.grants.ops.' . $operation)) ?></span>
                    </label>
                <?php endforeach; ?>
                <?php if ($field === 'grant_allow'): ?>
                    <button type="button"
                            class="inline-flex cursor-pointer items-center rounded-full border border-line bg-white px-2.5 py-1 text-xs font-semibold text-ink-soft transition hover:border-teal hover:text-teal-dark"
                            data-grant-toggle-catalog="<?= e($catalog['code']) ?>"
                            data-label-all="<?= e($t('admin.grants.all')) ?>"
                            data-label-none="<?= e($t('admin.grants.none')) ?>"
                            aria-pressed="false"
                            title="<?= e($t('admin.grants.catalog_toggle_title')) ?>">
                        <span data-grant-toggle-label><?= e($t('admin.grants.all')) ?></span>
                    </button>
                <?php endif; ?>
            </div>
        </div>
        <?php
    }
};
?>
<fieldset class="ui-fieldset">
    <legend class="ui-legend"><?= e($t('admin.grants.title')) ?></legend>

    <?php if ($catalogs === []): ?>
        <p class="text-sm text-muted"><?= e($t('admin.grants.empty')) ?></p>
    <?php else: ?>
        <p class="text-sm text-muted"><?= e($t('admin.grants.legend')) ?></p>
        <div class="ui-stack">
            <?php $renderChips($catalogs, $allowedSelected, 'grant_allow'); ?>
        </div>

        <div class="mt-3 flex flex-wrap gap-2 rounded-xl border border-line bg-paper/70 p-2.5"
             data-grant-bulk>
            <?php foreach (\OrigenSalud\Portal\Admin\Rbac::CATALOG_OPERATIONS as $operation): ?>
                <button type="button"
                        class="ui-btn ui-btn-sm ui-btn-ghost"
                        data-grant-toggle-op="<?= e($operation) ?>"
                        data-label-all="<?= e($t('admin.grants.all')) ?>"
                        data-label-none="<?= e($t('admin.grants.none')) ?>"
                        aria-pressed="false">
                    <span class="font-medium"><?= e($t('admin.grants.ops.' . $operation)) ?></span>:
                    <span data-grant-toggle-label><?= e($t('admin.grants.all')) ?></span>
                </button>
            <?php endforeach; ?>
        </div>

        <div class="overflow-hidden rounded-xl border border-line bg-white">
            <details class="admin-grants-deny">
                <summary class="cursor-pointer list-none rounded-xl px-4 py-3 text-sm font-semibold text-ink-soft transition hover:bg-paper">
                    <span class="inline-flex items-center gap-2">
                        <i data-lucide="shield-x" class="h-4 w-4 text-red-700"></i>
                        <?= e($t('admin.grants.deny_title')) ?>
                        <?php if ($deniedSelected !== []): ?>
                            <span class="ui-badge"><?= count($deniedSelected) ?></span>
                        <?php endif; ?>
                    </span>
                </summary>
                <div class="ui-stack border-t border-line p-4">
                    <p class="text-sm text-muted"><?= e($t('admin.grants.deny_help')) ?></p>
                    <?php $renderChips($catalogs, $deniedSelected, 'grant_deny'); ?>
                </div>
            </details>
        </div>
    <?php endif; ?>
</fieldset>
