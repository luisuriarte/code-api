<?php

declare(strict_types=1);

/**
 * Selector de idioma compartido por las vistas del portal.
 *
 * Requiere que la vista haya llamado a I18n::boot() y defina $currentPath.
 */

use OrigenSalud\Web\I18n;

$locale = I18n::locale();
$currentPath = $currentPath ?? '/';
$alternates = I18n::alternateLinks($currentPath);
$lastIndex = count($alternates) - 1;
?>
<div class="lang-switch" role="group" aria-label="<?= e(trans('lang.label', [], $locale)) ?>">
    <?php foreach ($alternates as $index => $alternate): ?>
        <a href="<?= e($alternate['href']) ?>"
           hreflang="<?= e($alternate['hreflang']) ?>"
           lang="<?= e($alternate['hreflang']) ?>"
           title="<?= e($alternate['label']) ?>"
           <?= $alternate['active'] ? 'aria-current="true" class="is-active"' : '' ?>><?= e($alternate['short']) ?></a>
        <?php if ($index < $lastIndex): ?>
            <span aria-hidden="true">/</span>
        <?php endif; ?>
    <?php endforeach; ?>
</div>
