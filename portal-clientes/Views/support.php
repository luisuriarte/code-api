<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $contact_url */
/** @var string $docs_url */
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.support.title')) ?></h1>
        <p class="mt-1 max-w-3xl text-sm text-muted"><?= e($t('customer.support.intro')) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<div class="grid gap-6 lg:grid-cols-2">
    <a class="surface-card flex items-center justify-between gap-3 transition hover:border-teal/40 hover:bg-mint" href="<?= e($contact_url) ?>">
        <span class="flex items-center gap-3">
            <svg class="size-5 shrink-0 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>
            <span>
                <span class="block text-sm font-semibold text-ink"><?= e($t('customer.support.contact_link')) ?></span>
                <span class="block text-xs text-muted"><?= e($t('customer.support.contact_hint')) ?></span>
            </span>
        </span>
        <svg class="size-4 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
    </a>

    <a class="surface-card flex items-center justify-between gap-3 transition hover:border-teal/40 hover:bg-mint" href="<?= e($docs_url) ?>">
        <span class="flex items-center gap-3">
            <svg class="size-5 shrink-0 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5a2 2 0 0 1 2-2h12v18H6a2 2 0 0 1-2-2zM8 7h8M8 11h8M8 15h5"/></svg>
            <span class="block text-sm font-semibold text-ink"><?= e($t('customer.docs.title')) ?></span>
        </span>
        <svg class="size-4 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
    </a>
</div>
