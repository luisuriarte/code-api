<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var list<array<string, mixed>> $entitlements */
/** @var bool $can_credentials */
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.api.title')) ?></h1>
        <p class="mt-1 max-w-3xl text-sm text-muted"><?= e($t('customer.api.intro')) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<section class="surface-card">
    <div class="mb-4 flex items-center gap-3">
        <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M8 9 3 12l5 3M16 9l5 3-5 3M14 4l-4 16"/>
            </svg>
        </span>
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.api.title')) ?></h2>
    </div>

    <?php if ($entitlements === []): ?>
        <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.api.empty')) ?></p>
    <?php else: ?>
        <div class="overflow-x-auto">
            <table class="w-full min-w-[38rem] text-sm">
                <thead>
                <tr class="border-b border-line">
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.name')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.api.route')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.api.method')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.api.status')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($entitlements as $entitlement): ?>
                    <tr class="transition hover:bg-paper/70">
                        <td class="px-2 py-3 font-semibold text-ink"><?= e((string) ($entitlement['service_name'] ?? '')) ?></td>
                        <td class="px-2 py-3"><code class="text-xs text-teal-dark"><?= e((string) ($entitlement['api_route'] ?? '')) ?></code></td>
                        <td class="px-2 py-3 text-ink-soft"><?= e((string) ($entitlement['api_method'] ?? 'GET')) ?></td>
                        <td class="px-2 py-3"><span class="rounded-full bg-mint px-2.5 py-1 text-xs font-semibold text-teal-dark"><?= e($t('customer.service.status.' . (string) ($entitlement['status'] ?? ''))) ?></span></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</section>

<div class="mt-6 grid gap-6 lg:grid-cols-2">
    <?php if ($can_credentials): ?>
        <a class="surface-card flex items-center justify-between gap-3 transition hover:border-teal/40 hover:bg-mint" href="<?= e($baseUrl . '/' . $locale . '/credentials') ?>">
            <span class="flex items-center gap-3">
                <svg class="size-5 shrink-0 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="8" cy="15" r="4"/><path d="M11 12V5a3 3 0 0 1 6 0v3M17 8h3v3h-3"/></svg>
                <span class="text-sm font-semibold text-ink"><?= e($t('customer.api.credentials_link')) ?></span>
            </span>
            <svg class="size-4 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
        </a>
    <?php endif; ?>
    <a class="surface-card flex items-center justify-between gap-3 transition hover:border-teal/40 hover:bg-mint" href="<?= e($baseUrl . '/' . $locale . '/documentation') ?>">
        <span class="flex items-center gap-3">
            <svg class="size-5 shrink-0 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 5a2 2 0 0 1 2-2h12v18H6a2 2 0 0 1-2-2zM8 7h8M8 11h8M8 15h5"/></svg>
            <span class="text-sm font-semibold text-ink"><?= e($t('customer.api.docs_link')) ?></span>
        </span>
        <svg class="size-4 text-teal" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
    </a>
</div>

<p class="mt-6 rounded-xl border border-line bg-paper px-4 py-3 text-sm text-muted"><?= e($t('customer.api.consumption_unavailable')) ?></p>
