<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$alternates = I18n::alternateLinks($currentPath);
?>
<div class="inline-flex shrink-0 items-center gap-0.5 rounded-full border border-line bg-paper/80 p-0.5"
     role="group" aria-label="<?= e($t('lang.label')) ?>">
    <?php foreach ($alternates as $alternate): ?>
        <a class="inline-flex items-center rounded-full px-2 py-1 text-[10px] font-bold tracking-wide transition focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 <?= $alternate['active'] ? 'bg-ink text-white' : 'text-muted hover:bg-white hover:text-teal-dark' ?>"
           href="<?= e($alternate['href']) ?>"
           hreflang="<?= e($alternate['hreflang']) ?>"
           lang="<?= e($alternate['hreflang']) ?>"
           title="<?= e($alternate['label']) ?>"
           <?= $alternate['active'] ? 'aria-current="true"' : '' ?>><?= e($alternate['short']) ?></a>
    <?php endforeach; ?>
</div>
