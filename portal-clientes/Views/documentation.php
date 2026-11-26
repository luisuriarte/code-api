<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $docs_url */
/** @var string $credentials_url */
/** @var bool $can_credentials */
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.docs.title')) ?></h1>
        <p class="mt-1 max-w-3xl text-sm text-muted"><?= e($t('customer.docs.intro')) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<div class="grid gap-6 lg:grid-cols-2">
    <section class="surface-card">
        <div class="mb-4 flex items-center gap-3">
            <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5a2 2 0 0 1 2-2h12v18H6a2 2 0 0 1-2-2zM8 7h8M8 11h8M8 15h5"/></svg>
            </span>
            <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.docs.api_reference')) ?></h2>
        </div>
        <p class="mb-4 text-sm text-ink-soft"><?= e($t('customer.docs.api_reference_hint')) ?></p>
        <a class="btn-primary" href="<?= e($docs_url) ?>">
            <?= e($t('customer.docs.api_reference')) ?>
            <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </a>
    </section>

    <section class="surface-card">
        <div class="mb-4 flex items-center gap-3">
            <span class="flex size-9 items-center justify-center rounded-xl bg-teal/10 text-teal">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="8" cy="15" r="4"/><path d="M11 12V5a3 3 0 0 1 6 0v3M17 8h3v3h-3"/></svg>
            </span>
            <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.docs.credentials')) ?></h2>
        </div>
        <p class="mb-4 text-sm text-ink-soft"><?= e($t('customer.docs.credentials_hint')) ?></p>
        <?php if ($can_credentials): ?>
            <a class="btn-secondary" href="<?= e($credentials_url) ?>">
                <?= e($t('customer.api.credentials_link')) ?>
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </a>
        <?php else: ?>
            <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.error.denied_body')) ?></p>
        <?php endif; ?>
    </section>
</div>
