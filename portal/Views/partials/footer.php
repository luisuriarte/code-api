<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$footerProduct = [
    ['label' => $t('nav.docs'), 'href' => I18n::localizedPath($locale, '/docs')],
    ['label' => $t('nav.uvr'), 'href' => '/uvr?lang=' . rawurlencode($locale)],
    ['label' => $t('footer.product_dentar'), 'href' => I18n::localizedPath($locale, '/dentar')],
    ['label' => $t('footer.product_oftar'), 'href' => I18n::localizedPath($locale, '/oftar')],
    ['label' => $t('footer.product_snomed'), 'href' => I18n::localizedPath($locale, '/browse')],
    ['label' => $t('footer.product_anmat'), 'href' => I18n::localizedPath($locale, '/browse')],
];
$footerCompany = [
    ['label' => $t('footer.company_about'), 'href' => I18n::localizedPath($locale, '/about')],
    ['label' => $t('footer.company_contact'), 'href' => I18n::localizedPath($locale, '/contact')],
    ['label' => $t('nav.services'), 'href' => I18n::localizedPath($locale, '/') . '#plataforma'],
];
$footerLink = 'inline-flex text-sm text-muted transition hover:text-teal-dark hover:underline underline-offset-4 focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15';
?>
<footer class="border-t border-line bg-paper">
    <div class="mx-auto w-full max-w-[1500px] px-4 py-14 sm:px-6">
        <div class="grid gap-10 lg:grid-cols-[1.4fr_repeat(3,1fr)] lg:gap-8">
            <div>
                <a class="group inline-flex items-center gap-2.5 focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
                   href="<?= e(I18n::localizedPath($locale, '/')) ?>" aria-label="Origen Salud">
                    <span class="flex size-9 items-center justify-center rounded-xl bg-teal text-white shadow-card transition group-hover:bg-teal-dark">
                        <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" aria-hidden="true" focusable="false">
                            <path d="M12 5v14M5 12h14"/>
                        </svg>
                    </span>
                    <span class="text-[15px] font-semibold tracking-tight text-ink">Origen<span class="text-teal">Salud</span></span>
                </a>
                <p class="mt-4 max-w-sm text-sm leading-relaxed text-muted"><?= e($t('footer.tagline')) ?></p>
            </div>

            <div>
                <h3 class="text-xs font-semibold uppercase tracking-[0.18em] text-ink"><?= e($t('footer.product')) ?></h3>
                <ul class="mt-4 flex flex-col gap-2.5">
                    <?php foreach ($footerProduct as $item): ?>
                        <li><a class="<?= $footerLink ?>" href="<?= e($item['href']) ?>"><?= e($item['label']) ?></a></li>
                    <?php endforeach; ?>
                </ul>
            </div>

            <div>
                <h3 class="text-xs font-semibold uppercase tracking-[0.18em] text-ink"><?= e($t('footer.company')) ?></h3>
                <ul class="mt-4 flex flex-col gap-2.5">
                    <?php foreach ($footerCompany as $item): ?>
                        <li><a class="<?= $footerLink ?>" href="<?= e($item['href']) ?>"><?= e($item['label']) ?></a></li>
                    <?php endforeach; ?>
                </ul>
            </div>

            <div>
                <h3 class="text-xs font-semibold uppercase tracking-[0.18em] text-ink"><?= e($t('footer.legal')) ?></h3>
                <ul class="mt-4 flex flex-col gap-2.5">
                    <li><a class="<?= $footerLink ?>" href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_terms')) ?></a></li>
                    <li><a class="<?= $footerLink ?>" href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_privacy')) ?></a></li>
                </ul>
            </div>
        </div>

        <div class="mt-12 flex flex-col gap-3 border-t border-line pt-6 text-xs leading-relaxed text-muted sm:flex-row sm:items-center sm:justify-between">
            <p><?= e($t('footer.rights', ['%year%' => $year])) ?></p>
            <p class="max-w-2xl sm:text-end"><?= e($t('footer.disclaimer')) ?></p>
        </div>
    </div>
</footer>
