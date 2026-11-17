<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$alternates = I18n::alternateLinks($currentPath);
$lastIndex = count($alternates) - 1;
?>
<div class="lang-switch" role="group" aria-label="<?= e($t('lang.label')) ?>">
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
