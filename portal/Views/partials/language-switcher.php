<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$alternates = I18n::alternateLinks($currentPath);

// Banderas inline: no dependen de emoji (Windows no los renderiza) ni de CDN.
$flags = [
    'es-AR' => '<svg viewBox="0 0 24 24" aria-hidden="true"><rect width="24" height="24" fill="#74acdf"/><rect y="8" width="24" height="8" fill="#fff"/><circle cx="12" cy="12" r="2" fill="#f6b40e"/></svg>',
    'en' => '<svg viewBox="0 0 24 24" aria-hidden="true"><rect width="24" height="24" fill="#012169"/><path d="M0 0 24 24M24 0 0 24" stroke="#fff" stroke-width="4"/><path d="M0 0 24 24M24 0 0 24" stroke="#c8102e" stroke-width="2"/><path d="M12 0v24M0 12h24" stroke="#fff" stroke-width="6"/><path d="M12 0v24M0 12h24" stroke="#c8102e" stroke-width="3.5"/></svg>',
    'pt-BR' => '<svg viewBox="0 0 24 24" aria-hidden="true"><rect width="24" height="24" fill="#009c3b"/><path d="M12 3 21 12 12 21 3 12Z" fill="#ffdf00"/><circle cx="12" cy="12" r="4.2" fill="#002776"/></svg>',
];
?>
<div class="inline-flex shrink-0 items-center gap-0.5 rounded-full border border-line bg-paper/80 p-0.5"
     role="group" aria-label="<?= e($t('lang.label')) ?>">
    <?php foreach ($alternates as $alternate): ?>
        <?php $flag = $flags[$alternate['hreflang']] ?? ''; ?>
        <a class="inline-flex items-center gap-1.5 rounded-full px-2 py-1 text-[10px] font-bold tracking-wide transition focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 <?= $alternate['active'] ? 'bg-ink text-white' : 'text-muted hover:bg-white hover:text-teal-dark' ?>"
           href="<?= e($alternate['href']) ?>"
           hreflang="<?= e($alternate['hreflang']) ?>"
           lang="<?= e($alternate['hreflang']) ?>"
           title="<?= e($alternate['label']) ?>"
           <?= $alternate['active'] ? 'aria-current="true"' : '' ?>>
            <?php if ($flag !== ''): ?>
                <span class="size-4 shrink-0 overflow-hidden rounded-full ring-1 ring-black/10 [&>svg]:size-4 [&>svg]:block"><?= $flag ?></span>
            <?php endif; ?>
            <?= e($alternate['short']) ?>
        </a>
    <?php endforeach; ?>
</div>
