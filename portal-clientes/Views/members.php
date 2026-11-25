<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var list<array<string, mixed>> $members */
/** @var list<array<string, mixed>> $invitations */
/** @var list<array<string, mixed>> $roles */
/** @var bool $can_invite */
/** @var bool $can_update */
/** @var bool $can_revoke */
/** @var int $current_user_id */
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.member.title')) ?></h1>
        <p class="mt-1 text-sm text-muted"><?= e($t('customer.member.invitations')) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<section class="surface-card">
    <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.member.title')) ?></h2>
    <div class="mt-4 overflow-x-auto">
        <table class="w-full min-w-[42rem] text-sm">
            <thead>
            <tr class="border-b border-line">
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.email')) ?></th>
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.full_name')) ?></th>
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.role')) ?></th>
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.status')) ?></th>
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.actions')) ?></th>
            </tr>
            </thead>
            <tbody class="divide-y divide-line">
            <?php foreach ($members as $member): ?>
                <?php $userId = (int) ($member['user_id'] ?? 0); ?>
                <tr class="transition hover:bg-paper/70">
                    <td class="px-2 py-3 text-ink-soft"><?= e((string) ($member['email'] ?? '')) ?></td>
                    <td class="px-2 py-3 font-semibold text-ink"><?= e((string) ($member['full_name'] ?? '')) ?></td>
                    <td class="px-2 py-3"><span class="rounded-full bg-mint px-2.5 py-1 text-xs font-semibold text-teal-dark"><?= e((string) ($member['role_code'] ?? '')) ?></span></td>
                    <td class="px-2 py-3 text-ink-soft"><?= e((string) ($member['status'] ?? '')) ?></td>
                    <td class="px-2 py-3">
                        <div class="flex flex-wrap items-center gap-2">
                            <?php if ($can_update && $userId !== $current_user_id): ?>
                                <form method="post" action="<?= e($baseUrl . '/' . $locale . '/members/role') ?>" class="flex items-center gap-2">
                                    <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                    <input type="hidden" name="user_id" value="<?= e((string) $userId) ?>">
                                    <select class="form-field !w-auto !py-1" name="role_code">
                                        <?php foreach ($roles as $role): ?>
                                            <option value="<?= e((string) $role['code']) ?>"<?= $role['code'] === ($member['role_code'] ?? null) ? ' selected' : '' ?>>
                                                <?= e((string) $role['label']) ?>
                                            </option>
                                        <?php endforeach; ?>
                                    </select>
                                    <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('customer.member.save_role')) ?></button>
                                </form>
                            <?php endif; ?>
                            <?php if ($can_revoke && $userId !== $current_user_id && ($member['role_code'] ?? '') !== 'organization_owner'): ?>
                                <form method="post" action="<?= e($baseUrl . '/' . $locale . '/members/revoke') ?>">
                                    <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                    <input type="hidden" name="user_id" value="<?= e((string) $userId) ?>">
                                    <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('customer.member.revoke')) ?></button>
                                </form>
                            <?php endif; ?>
                        </div>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</section>

<?php if ($can_invite): ?>
    <section class="surface-card mt-6">
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.member.invite')) ?></h2>
        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/members/invite') ?>" class="mt-4 grid gap-4 sm:grid-cols-2">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <div>
                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="email"><?= e($t('customer.login.email')) ?></label>
                <input class="form-field" id="email" name="email" type="email" required>
            </div>
            <div>
                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="role_code"><?= e($t('customer.member.role')) ?></label>
                <select class="form-field" id="role_code" name="role_code">
                    <?php foreach ($roles as $role): ?>
                        <option value="<?= e((string) $role['code']) ?>"><?= e((string) $role['label']) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>
            <div class="sm:col-span-2">
                <button class="btn-primary" type="submit"><?= e($t('customer.member.invite')) ?></button>
            </div>
        </form>
    </section>
<?php endif; ?>

<section class="surface-card mt-6">
    <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.member.invitations')) ?></h2>
    <div class="mt-4 overflow-x-auto">
        <table class="w-full min-w-[36rem] text-sm">
            <thead>
            <tr class="border-b border-line">
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.email')) ?></th>
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.role')) ?></th>
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.status')) ?></th>
                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.member.expires')) ?></th>
            </tr>
            </thead>
            <tbody class="divide-y divide-line">
            <?php foreach ($invitations as $invitation): ?>
                <tr class="transition hover:bg-paper/70">
                    <td class="px-2 py-3 text-ink-soft"><?= e((string) ($invitation['email'] ?? '')) ?></td>
                    <td class="px-2 py-3 text-ink-soft"><?= e((string) ($invitation['role_code'] ?? '')) ?></td>
                    <td class="px-2 py-3"><span class="rounded-full bg-mint px-2.5 py-1 text-xs font-semibold text-teal-dark"><?= e((string) ($invitation['status'] ?? '')) ?></span></td>
                    <td class="px-2 py-3 text-muted"><?= e((string) ($invitation['expires_at'] ?? '')) ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</section>
