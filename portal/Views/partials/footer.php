<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$footerProduct = [
    ['label' => $t('nav.docs'), 'href' => I18n::localizedPath($locale, '/docs')],
    ['label' => $t('footer.product_dentar'), 'href' => I18n::localizedPath($locale, '/dentar')],
    ['label' => $t('footer.product_snomed'), 'href' => I18n::localizedPath($locale, '/browse')],
    ['label' => $t('footer.product_anmat'), 'href' => I18n::localizedPath($locale, '/browse')],
];
$footerCompany = [
    ['label' => $t('footer.company_about'), 'href' => I18n::localizedPath($locale, '/about')],
    ['label' => $t('footer.company_contact'), 'href' => I18n::localizedPath($locale, '/contact')],
    ['label' => $t('nav.services'), 'href' => I18n::localizedPath($locale, '/cart')],
];
?>
<footer class="site-footer">
    <div class="container footer-grid">
        <div class="footer-brand">
            <a class="brand" href="<?= e(I18n::localizedPath($locale, '/')) ?>" aria-label="Origen Salud">
                <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                    <rect width="40" height="40" rx="12" fill="currentColor"/>
                    <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
                </svg>
                <span class="brand-name">Origen<span>Salud</span></span>
            </a>
            <p><?= e($t('footer.tagline')) ?></p>
        </div>

        <div>
            <h3><?= e($t('footer.product')) ?></h3>
            <ul>
                <?php foreach ($footerProduct as $item): ?>
                    <li><a href="<?= e($item['href']) ?>"><?= e($item['label']) ?></a></li>
                <?php endforeach; ?>
            </ul>
        </div>

        <div>
            <h3><?= e($t('footer.company')) ?></h3>
            <ul>
                <?php foreach ($footerCompany as $item): ?>
                    <li><a href="<?= e($item['href']) ?>"><?= e($item['label']) ?></a></li>
                <?php endforeach; ?>
            </ul>
        </div>

        <div>
            <h3><?= e($t('footer.legal')) ?></h3>
            <ul>
                <li><a href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_terms')) ?></a></li>
                <li><a href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_privacy')) ?></a></li>
            </ul>
        </div>
    </div>

    <div class="container footer-bottom">
        <p><?= e($t('footer.rights', ['%year%' => $year])) ?></p>
        <p class="disclaimer"><?= e($t('footer.disclaimer')) ?></p>
    </div>
</footer>
