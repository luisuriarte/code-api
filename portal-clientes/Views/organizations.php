<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var list<array<string, mixed>> $organizations */
/** @var array<string, mixed> $organization */
/** @var bool $can_update */
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.org.title')) ?></h1>
        <p class="mt-1 text-sm text-muted"><?= e($t('customer.home.context', ['%organization%' => $organization['display_name'] ?? $organization['legal_name'] ?? $t('customer.home.none')])) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<section class="surface-card">
    <div class="mb-5 flex items-center gap-3">
        <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <path d="M4 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16M8 7h2M8 11h2M8 15h2M16 9h2a2 2 0 0 1 2 2v10"/>
            </svg>
        </span>
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.home.organizations')) ?></h2>
    </div>

    <dl class="grid gap-x-8 gap-y-4 sm:grid-cols-2">
        <?php foreach ([
            'customer.org.legal_name' => $organization['legal_name'] ?? '',
            'customer.org.display_name' => $organization['display_name'] ?? '',
            'customer.org.tax_id' => $organization['tax_id_normalized'] ?? '',
            'customer.org.country' => $organization['country'] ?? '',
        ] as $key => $value): ?>
            <div class="rounded-xl border border-line bg-paper p-4">
                <dt class="table-head"><?= e($t((string) $key)) ?></dt>
                <dd class="mt-1 text-sm font-semibold text-ink"><?= e((string) $value) ?></dd>
            </div>
        <?php endforeach; ?>
    </dl>
</section>

<?php if ($can_update): ?>
    <section class="surface-card mt-6">
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.org.update')) ?></h2>
        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/organizations/update') ?>" class="mt-4 grid gap-4 sm:grid-cols-2">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <?php foreach ([
                'legal_name' => ['customer.org.legal_name', 200, true],
                'display_name' => ['customer.org.display_name', 200, false],
                'tax_id' => ['customer.org.tax_id', 32, false],
            ] as $name => $field): ?>
                <div>
                    <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="<?= e((string) $name) ?>"><?= e($t($field[0])) ?></label>
                    <input class="form-field" id="<?= e((string) $name) ?>" name="<?= e((string) $name) ?>" <?= $field[2] ? 'required' : '' ?> maxlength="<?= (int) $field[1] ?>" value="<?= e((string) ($organization[$name === 'tax_id' ? 'tax_id_normalized' : $name] ?? '')) ?>">
                </div>
            <?php endforeach; ?>
            <div class="sm:col-span-2">
                <button class="btn-primary" type="submit"><?= e($t('customer.org.save')) ?></button>
            </div>
        </form>
    </section>
<?php endif; ?>

<section class="surface-card mt-6">
    <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.home.organizations')) ?></h2>
    <div class="mt-4 grid gap-3 sm:grid-cols-2">
        <?php foreach ($organizations as $org): ?>
            <form method="post" action="<?= e($baseUrl . '/' . $locale . '/organizations/switch') ?>" class="flex items-center justify-between gap-3 rounded-xl border border-line bg-paper p-3">
                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                <input type="hidden" name="organization_id" value="<?= e((string) (int) ($org['id'] ?? 0)) ?>">
                <span class="text-sm font-semibold text-ink"><?= e((string) ($org['display_name'] ?? $org['legal_name'] ?? '')) ?></span>
                <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('customer.home.switch', ['%name%' => (string) ($org['display_name'] ?? $org['legal_name'] ?? '')])) ?></button>
            </form>
        <?php endforeach; ?>
    </div>
</section>
