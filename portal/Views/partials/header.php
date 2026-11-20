<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;
?>
<header class="site-header">
    <div class="container header-inner">
        <a class="brand" href="<?= e(I18n::localizedPath($locale, '/')) ?>" aria-label="Origen Salud">
            <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
            <span class="brand-name">Origen<span>Salud</span></span>
        </a>

        <nav class="site-nav" aria-label="<?= e($t('nav.label')) ?>">
            <?php require __DIR__ . '/nav-links.php'; ?>
        </nav>

        <div class="header-actions">
            <?php require __DIR__ . '/language-switcher.php'; ?>
            <a class="button button-small button-management" href="/admin/login"><?= e($t('nav.management')) ?></a>
            <a class="button button-small" href="<?= e($accessMailto ?? I18n::localizedPath($locale, '/contact')) ?>"><?= e($t('nav.access')) ?></a>
        </div>
    </div>
</header>
