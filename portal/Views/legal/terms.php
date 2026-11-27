<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$sections = [
    ['scope_title', 'scope_text'],
    ['sources_title', 'sources_text'],
    ['use_title', 'use_text'],
    ['availability_title', 'availability_text'],
    ['ip_title', 'ip_text'],
    ['contact_title', 'contact_text'],
];
?>
<section class="section">
    <div class="container narrow">
        <nav class="breadcrumb" aria-label="<?= e($t('legal.breadcrumb_label')) ?>">
            <ol>
                <li><a href="<?= e(I18n::localizedPath($locale, '/')) ?>"><?= e($t('nav.home')) ?></a></li>
                <li aria-current="page"><?= e($t('legal.terms.title')) ?></li>
            </ol>
        </nav>

        <header class="mt-6">
            <span class="eyebrow"><?= e($t('footer.legal')) ?></span>
            <h1 class="mt-2 text-3xl font-semibold tracking-tight text-ink sm:text-4xl"><?= e($t('legal.terms.title')) ?></h1>
            <p class="lead mt-3"><?= e($t('legal.terms.lead')) ?></p>
            <dl class="mt-5 flex flex-wrap gap-x-8 gap-y-2 text-sm text-muted">
                <div class="flex gap-2">
                    <dt class="font-semibold text-ink-soft"><?= e($t('legal.version_label')) ?>:</dt>
                    <dd><?= e($t('legal.version')) ?></dd>
                </div>
                <div class="flex gap-2">
                    <dt class="font-semibold text-ink-soft"><?= e($t('legal.effective_label')) ?>:</dt>
                    <dd><?= e($t('legal.effective_date')) ?></dd>
                </div>
            </dl>
        </header>

        <div class="mt-8 flex flex-col gap-8">
            <?php foreach ($sections as [$titleKey, $textKey]): ?>
                <section class="border-t border-line pt-6">
                    <h2 class="text-xl font-semibold tracking-tight text-ink"><?= e($t('legal.terms.sections.' . $titleKey)) ?></h2>
                    <p class="mt-3 leading-7 text-ink-soft"><?= e($t('legal.terms.sections.' . $textKey)) ?></p>
                </section>
            <?php endforeach; ?>
        </div>

        <footer class="mt-10 rounded-2xl border border-line bg-paper p-5 text-sm leading-relaxed text-muted">
            <p>
                <?= e($t('legal.contact_label')) ?>:
                <a class="font-semibold text-teal-dark underline underline-offset-4"
                   href="mailto:<?= e($t('legal.contact_email')) ?>"><?= e($t('legal.contact_email')) ?></a>
            </p>
            <p class="mt-3">
                <a class="underline underline-offset-4" href="<?= e(I18n::localizedPath($locale, '/privacidad')) ?>"><?= e($t('footer.legal_privacy')) ?></a>
            </p>
        </footer>
    </div>
</section>
