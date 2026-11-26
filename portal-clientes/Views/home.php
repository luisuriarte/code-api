<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var array<string, mixed> $user */
/** @var list<array<string, mixed>> $organizations */
/** @var array<string, mixed>|null $organization */
/** @var int|null $organization_id */
/** @var bool $can_credentials */
?>
<div class="mb-8 overflow-hidden rounded-3xl border border-line bg-gradient-to-br from-white via-mint to-paper shadow-card">
    <div class="grid gap-6 p-6 sm:p-10 lg:grid-cols-[1fr_auto] lg:items-end">
        <div>
            <span class="inline-flex items-center gap-2 rounded-full bg-white/80 px-3 py-1 text-xs font-semibold text-teal-dark ring-1 ring-teal/15">
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                    <path d="M12 5v14M5 12h14"/>
                </svg>
                Origen Salud
            </span>
            <h1 class="mt-4 text-3xl font-semibold tracking-tight text-ink sm:text-4xl"><?= e($t('customer.home.title')) ?></h1>
            <p class="mt-2 text-base text-ink-soft"><?= e($t('customer.home.welcome', ['%name%' => (string) ($user['full_name'] ?? '')])) ?></p>
            <p class="mt-1 text-sm text-muted"><?= e($t('customer.home.context', ['%organization%' => $organization['display_name'] ?? $organization['legal_name'] ?? $t('customer.home.none')])) ?></p>
        </div>
        <div class="flex flex-wrap gap-2">
            <a class="btn-primary" href="<?= e($baseUrl . '/' . $locale . '/servicios') ?>">
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z"/></svg>
                <?= e($t('customer.nav.services')) ?>
            </a>
            <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/members') ?>">
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8"/></svg>
                <?= e($t('customer.nav.members')) ?>
            </a>
        </div>
    </div>
</div>

<div class="grid gap-6 lg:grid-cols-2">
    <section class="surface-card">
        <div class="mb-4 flex items-center gap-3">
            <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                    <path d="M4 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16M8 7h2M8 11h2M8 15h2M16 9h2a2 2 0 0 1 2 2v10"/>
                </svg>
            </span>
            <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.home.organizations')) ?></h2>
        </div>

        <?php if ($organizations === []): ?>
            <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.home.no_organization')) ?></p>
        <?php else: ?>
            <div class="grid gap-3">
                <?php foreach ($organizations as $org): ?>
                    <?php $id = (int) ($org['id'] ?? 0); ?>
                    <form method="post" action="<?= e($baseUrl . '/' . $locale . '/organizations/switch') ?>" class="flex items-center justify-between gap-3 rounded-xl border border-line bg-paper p-3">
                        <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                        <input type="hidden" name="organization_id" value="<?= e((string) $id) ?>">
                        <span class="text-sm font-semibold text-ink"><?= e((string) ($org['display_name'] ?? $org['legal_name'] ?? '')) ?></span>
                        <button class="btn-secondary !mt-0 !py-1" type="submit"<?= $id === $organization_id ? ' disabled' : '' ?>>
                            <?= e($t('customer.home.switch', ['%name%' => (string) ($org['display_name'] ?? $org['legal_name'] ?? '')])) ?>
                        </button>
                    </form>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>

    <section class="surface-card">
        <div class="mb-4 flex items-center gap-3">
            <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                    <path d="M4 6h16M4 12h16M4 18h10"/>
                </svg>
            </span>
            <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.nav.organizations')) ?></h2>
        </div>
        <div class="grid gap-3 sm:grid-cols-2">
            <a class="flex items-center justify-between rounded-xl border border-line bg-paper p-4 text-sm font-semibold text-ink-soft transition hover:border-teal/40 hover:bg-mint hover:text-teal-dark" href="<?= e($baseUrl . '/' . $locale . '/organizations') ?>">
                <?= e($t('customer.nav.organizations')) ?>
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </a>
            <a class="flex items-center justify-between rounded-xl border border-line bg-paper p-4 text-sm font-semibold text-ink-soft transition hover:border-teal/40 hover:bg-mint hover:text-teal-dark" href="<?= e($baseUrl . '/' . $locale . '/members') ?>">
                <?= e($t('customer.nav.members')) ?>
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </a>
        </div>
    </section>
</div>

<section class="surface-card mt-6">
    <div class="mb-4 flex items-center gap-3">
        <span class="flex size-9 items-center justify-center rounded-xl bg-teal/10 text-teal">
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M5 12h.01M12 12h.01M19 12h.01"/>
            </svg>
        </span>
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.home.quick_links')) ?></h2>
    </div>
    <div class="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        <?php
        $quickLinks = [
            ['servicios', 'customer.nav.services'],
            ['api', 'customer.nav.api'],
            ['documentation', 'customer.nav.documentation'],
            ['support', 'customer.nav.support'],
            ['billing', 'customer.nav.billing'],
        ];
        if ($can_credentials) {
            $quickLinks[] = ['credentials', 'customer.nav.credentials'];
        }
        ?>
        <?php foreach ($quickLinks as [$path, $key]): ?>
            <a class="flex items-center justify-between rounded-xl border border-line bg-paper p-4 text-sm font-semibold text-ink-soft transition hover:border-teal/40 hover:bg-mint hover:text-teal-dark" href="<?= e($baseUrl . '/' . $locale . '/' . $path) ?>">
                <?= e($t($key)) ?>
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </a>
        <?php endforeach; ?>
    </div>
</section>
