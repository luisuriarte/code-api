<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var array<string, mixed> $organization */
/** @var string|null $billing_url */
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.billing.title')) ?></h1>
        <p class="mt-1 max-w-3xl text-sm text-muted"><?= e($t('customer.billing.intro')) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<section class="surface-card">
    <div class="mb-4 flex items-center gap-3">
        <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h4"/></svg>
        </span>
        <div>
            <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.billing.title')) ?></h2>
            <p class="text-xs text-muted"><?= e((string) ($organization['display_name'] ?? $organization['legal_name'] ?? '')) ?></p>
        </div>
    </div>

    <?php if ($billing_url === null): ?>
        <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.billing.unavailable')) ?></p>
    <?php else: ?>
        <a class="btn-primary" href="<?= e($billing_url) ?>" target="_blank" rel="noopener noreferrer">
            <?= e($t('customer.billing.open_portal')) ?>
            <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M14 4h6v6M20 4l-8 8M18 14v4a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4"/></svg>
        </a>
        <p class="mt-3 text-xs text-muted"><?= e($t('customer.billing.open_portal_hint')) ?></p>
    <?php endif; ?>

    <p class="mt-6 rounded-xl border border-line bg-paper px-4 py-3 text-sm text-muted"><?= e($t('customer.billing.no_prices')) ?></p>
</section>
