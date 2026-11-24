<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

require __DIR__ . '/customer-portal-href.php';
?>
<header class="sticky top-0 z-40 border-b border-line/80 bg-white/85 backdrop-blur-xl">
    <div class="mx-auto flex h-16 w-full max-w-[1500px] items-center gap-3 px-4 sm:px-6 lg:gap-6">
        <a class="group flex shrink-0 items-center gap-2.5 focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
           href="<?= e(I18n::localizedPath($locale, '/')) ?>" aria-label="Origen Salud">
            <span class="flex size-9 items-center justify-center rounded-xl bg-teal text-white shadow-card transition group-hover:bg-teal-dark">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" aria-hidden="true" focusable="false">
                    <path d="M12 5v14M5 12h14"/>
                </svg>
            </span>
            <span class="text-[15px] font-semibold tracking-tight text-ink">Origen<span class="text-teal">Salud</span></span>
        </a>

        <nav class="hidden flex-1 lg:flex lg:items-center lg:justify-center" aria-label="<?= e($t('nav.label')) ?>">
            <div class="flex items-center gap-0.5 rounded-full border border-line bg-paper/70 p-1">
                <?php require __DIR__ . '/nav-links.php'; ?>
            </div>
        </nav>

        <div class="ms-auto flex items-center gap-2 sm:gap-3">
            <?php require __DIR__ . '/language-switcher.php'; ?>
            <a class="hidden items-center rounded-full border border-line bg-white px-4 py-2 text-xs font-semibold text-ink-soft transition hover:border-teal/40 hover:bg-mint hover:text-teal-dark focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 sm:inline-flex"
               href="/admin/login"><?= e($t('nav.management')) ?></a>
            <a class="hidden items-center rounded-full bg-ink px-4 py-2 text-xs font-semibold text-white shadow-card transition hover:bg-teal-dark focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 sm:inline-flex"
               href="<?= e($customerPortalHref) ?>"><?= e($t('nav.customer_portal')) ?></a>

            <details class="relative lg:hidden">
                <summary class="flex size-10 cursor-pointer list-none items-center justify-center rounded-xl border border-line bg-white text-ink shadow-card transition hover:border-teal/40 hover:text-teal focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 [&::-webkit-details-marker]:hidden">
                    <span class="sr-only"><?= e($t('nav.label')) ?></span>
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                        <path d="M4 7h16M4 12h16M4 17h16"/>
                    </svg>
                </summary>
                <div class="absolute end-0 top-12 w-[min(20rem,calc(100vw-2rem))] rounded-2xl border border-line bg-white p-2 shadow-panel">
                    <nav class="flex flex-col" aria-label="<?= e($t('nav.label')) ?>">
                        <?php require __DIR__ . '/nav-links.php'; ?>
                    </nav>
                    <div class="mt-2 grid grid-cols-2 gap-2 border-t border-line pt-2">
                        <a class="inline-flex items-center justify-center rounded-xl border border-line px-3 py-2 text-xs font-semibold text-ink-soft transition hover:bg-mint hover:text-teal-dark"
                           href="/admin/login"><?= e($t('nav.management')) ?></a>
                        <a class="inline-flex items-center justify-center rounded-xl bg-ink px-3 py-2 text-xs font-semibold text-white transition hover:bg-teal-dark"
                           href="<?= e($customerPortalHref) ?>"><?= e($t('nav.customer_portal')) ?></a>
                    </div>
                </div>
            </details>
        </div>
    </div>
</header>
