<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var list<array<string, mixed>> $credentials */
/** @var array<string, mixed> $organization */
/** @var bool $can_create */
/** @var bool $can_rotate */
/** @var bool $can_revoke */
/** @var bool $available */
/** @var string|null $secret */
/** @var string $submit_nonce */

$orgLabel = trim((string) ($organization['display_name'] ?? ''));
if ($orgLabel === '') {
    $orgLabel = (string) ($organization['legal_name'] ?? '');
}
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.credential.title')) ?></h1>
        <p class="mt-1 max-w-3xl text-sm text-muted"><?= e($t('customer.credential.intro')) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<?php if (!$available): ?>
    <section class="mb-6 flex items-start gap-3 rounded-xl border border-amber-300/70 bg-amber-50 px-4 py-3 text-sm text-amber-900" role="status">
        <svg class="mt-0.5 size-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
            <path d="M12 9v4M12 17h.01M10.3 3.9 2 18a2 2 0 0 0 1.7 3h16.6a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/>
        </svg>
        <span><?= e($t('customer.credential.unavailable')) ?></span>
    </section>
<?php endif; ?>

<?php if ($secret !== null && $secret !== ''): ?>
    <section class="mb-6 overflow-hidden rounded-2xl border border-teal/30 bg-white shadow-panel">
        <div class="flex items-center gap-3 border-b border-line bg-mint px-5 py-4">
            <span class="flex size-9 items-center justify-center rounded-xl bg-teal text-white">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                    <circle cx="8" cy="15" r="4"/><path d="M11 12V5a3 3 0 0 1 6 0v3M17 8h3v3h-3"/>
                </svg>
            </span>
            <h2 class="text-base font-semibold tracking-tight text-teal-dark"><?= e($t('customer.credential.secret_title')) ?></h2>
        </div>
        <div class="grid gap-4 px-5 py-5">
            <p class="text-sm text-muted"><?= e($t('customer.credential.secret_once')) ?></p>
            <div>
                <span class="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-muted"><?= e($t('customer.credential.secret_label')) ?></span>
                <code class="block break-all rounded-xl border border-line bg-paper px-4 py-3 font-mono text-sm text-ink"><?= e($secret) ?></code>
            </div>
        </div>
    </section>
<?php endif; ?>

<section class="surface-card">
    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
        <div class="flex items-center gap-3">
            <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                    <circle cx="8" cy="15" r="4"/><path d="M11 12V5a3 3 0 0 1 6 0v3M17 8h3v3h-3"/>
                </svg>
            </span>
            <div>
                <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.credential.list_title')) ?></h2>
                <p class="text-xs text-muted"><?= e($orgLabel) ?></p>
            </div>
        </div>
        <?php if ($can_create): ?>
            <div class="sm:text-end">
                <form method="post" action="/portal-clientes/<?= e($locale) ?>/credentials/create">
                    <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                    <input type="hidden" name="submit_nonce" value="<?= e($submit_nonce) ?>">
                    <button class="btn-primary !mt-0" type="submit">
                        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>
                        <?= e($t('customer.credential.create')) ?>
                    </button>
                </form>
                <p class="mt-1 text-xs text-muted"><?= e($t('customer.credential.create_hint')) ?></p>
            </div>
        <?php endif; ?>
    </div>

    <?php if ($credentials === []): ?>
        <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.credential.empty')) ?></p>
    <?php else: ?>
        <div class="overflow-x-auto">
            <table class="w-full min-w-[52rem] text-sm">
                <thead>
                <tr class="border-b border-line">
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.credential.id')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.credential.institution')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.credential.status')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.credential.created_at')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.credential.rotated_at')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.credential.revoked_at')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.credential.actions')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($credentials as $credential): ?>
                    <?php $isActive = ($credential['status'] ?? '') === 'active'; ?>
                    <tr class="transition hover:bg-paper/70">
                        <td class="px-2 py-3"><code class="rounded-md bg-paper px-1.5 py-0.5 text-xs text-ink-soft">#<?= e((string) $credential['api_client_id']) ?></code></td>
                        <td class="px-2 py-3 font-semibold text-ink"><?= e((string) $credential['institution_name']) ?></td>
                        <td class="px-2 py-3">
                            <span class="rounded-full px-2.5 py-1 text-xs font-semibold <?= $isActive ? 'bg-mint text-teal-dark' : 'bg-paper text-muted' ?>">
                                <?= e($t($isActive ? 'customer.credential.status.active' : 'customer.credential.status.revoked')) ?>
                            </span>
                        </td>
                        <td class="px-2 py-3 text-xs text-muted"><?= e((string) ($credential['created_at'] ?? '')) ?></td>
                        <td class="px-2 py-3 text-xs text-muted"><?= e((string) ($credential['rotated_at'] ?? '')) ?></td>
                        <td class="px-2 py-3 text-xs text-muted"><?= e((string) ($credential['revoked_at'] ?? '')) ?></td>
                        <td class="px-2 py-3">
                            <?php if ($isActive && ($can_rotate || $can_revoke)): ?>
                                <div class="flex flex-wrap gap-2">
                                    <?php if ($can_rotate): ?>
                                        <form method="post" action="/portal-clientes/<?= e($locale) ?>/credentials/rotate">
                                            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                            <input type="hidden" name="submit_nonce" value="<?= e($submit_nonce) ?>">
                                            <input type="hidden" name="credential_id" value="<?= e((string) $credential['id']) ?>">
                                            <button class="btn-secondary !mt-0 !py-1.5" type="submit"><?= e($t('customer.credential.rotate')) ?></button>
                                        </form>
                                    <?php endif; ?>
                                    <?php if ($can_revoke): ?>
                                        <form method="post" action="/portal-clientes/<?= e($locale) ?>/credentials/revoke">
                                            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                            <input type="hidden" name="submit_nonce" value="<?= e($submit_nonce) ?>">
                                            <input type="hidden" name="credential_id" value="<?= e((string) $credential['id']) ?>">
                                            <button class="btn-secondary !mt-0 !py-1.5" type="submit"><?= e($t('customer.credential.revoke')) ?></button>
                                        </form>
                                    <?php endif; ?>
                                </div>
                            <?php else: ?>
                                <span class="text-xs text-muted"><?= e($t('customer.credential.no_actions')) ?></span>
                            <?php endif; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</section>

<section class="surface-card mt-6">
    <div class="flex items-start gap-3">
        <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-paper text-muted">
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 8h.01"/>
            </svg>
        </span>
        <p class="text-sm text-muted"><?= e($t('customer.credential.limits')) ?></p>
    </div>
</section>
