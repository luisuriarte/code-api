<?php

declare(strict_types=1);

/** @var array<string, mixed> $organization */
/** @var list<array<string, mixed>> $members */
/** @var list<array<string, mixed>> $invitations */
/** @var list<string> $roles */
/** @var list<array{code: string, name: string, short_name: string}> $catalogs */
?>
<?php
$roleCatalogOps = static fn (string $role): string => implode(
    ' ',
    \OrigenSalud\Portal\Admin\Rbac::catalogOperationsForRole($role)
);
?>
<section class="space-y-6">
    <div class="ui-card ui-card-pad">
        <a href="/admin/organizations" class="inline-flex items-center gap-1.5 text-sm font-medium no-underline hover:underline">
            <i data-lucide="arrow-left" class="h-4 w-4"></i>
            <?= e($t('admin.orgs.back')) ?>
        </a>
        <div class="mt-4 flex flex-wrap items-start justify-between gap-4">
            <div>
                <h1 class="ui-title"><?= e((string) $organization['name']) ?></h1>
                <p class="ui-subtitle">
                    <code class="ui-code"><?= e((string) ($organization['code'] ?? '')) ?></code> ·
                    <?= e($t('admin.roles.org_type.' . (string) $organization['type'])) ?> ·
                    <?= e((string) $organization['country_code']) ?> ·
                    <?= (bool) $organization['is_active']
                        ? e($t('admin.orgs.active')) : e($t('admin.orgs.inactive')) ?>
                </p>
            </div>
            <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-mint text-teal-dark">
                <i data-lucide="building-2" class="h-6 w-6"></i>
            </span>
        </div>
    </div>

    <?php require __DIR__ . '/_flash.php'; ?>

    <div class="ui-grid items-start">
        <article class="ui-card ui-card-pad">
            <h2 class="mb-5 text-lg font-semibold text-ink"><?= e($t('admin.orgs.edit')) ?></h2>
            <form method="post" action="/admin/organizations/<?= (int) $organization['id'] ?>" class="grid gap-4 sm:grid-cols-2">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <div>
                    <label for="org-edit-code" class="ui-label"><?= e($t('admin.orgs.code')) ?></label>
                    <input id="org-edit-code" type="text" value="<?= e((string) ($organization['code'] ?? '')) ?>" disabled class="ui-input bg-paper">
                </div>
                <div>
                    <label for="org-edit-name" class="ui-label"><?= e($t('admin.orgs.name')) ?></label>
                    <input id="org-edit-name" type="text" name="name" required maxlength="180"
                           value="<?= e((string) $organization['name']) ?>" class="ui-input">
                </div>
                <div class="sm:col-span-2">
                    <label for="org-edit-legal" class="ui-label"><?= e($t('admin.orgs.legal_name')) ?></label>
                    <input id="org-edit-legal" type="text" name="legal_name" maxlength="240"
                           value="<?= e((string) ($organization['legal_name'] ?? '')) ?>" class="ui-input">
                </div>
                <div>
                    <label for="org-edit-type" class="ui-label"><?= e($t('admin.orgs.type')) ?></label>
                    <select id="org-edit-type" name="type" class="ui-input">
                        <?php foreach (\OrigenSalud\Portal\Admin\Rbac::ORGANIZATION_TYPES as $type): ?>
                            <option value="<?= e($type) ?>" <?= $organization['type'] === $type ? 'selected' : '' ?>>
                                <?= e($t('admin.roles.org_type.' . $type)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div>
                    <label for="org-edit-country" class="ui-label"><?= e($t('admin.orgs.country')) ?></label>
                    <input id="org-edit-country" type="text" name="country_code" required maxlength="2"
                           value="<?= e((string) $organization['country_code']) ?>" class="ui-input">
                </div>
                <div>
                    <label for="org-edit-email" class="ui-label"><?= e($t('admin.email')) ?></label>
                    <input id="org-edit-email" type="email" name="contact_email" maxlength="254"
                           value="<?= e((string) ($organization['contact_email'] ?? '')) ?>" class="ui-input">
                </div>
                <div>
                    <label for="org-edit-website" class="ui-label"><?= e($t('admin.orgs.website')) ?></label>
                    <input id="org-edit-website" type="url" name="website" maxlength="254"
                           value="<?= e((string) ($organization['website'] ?? '')) ?>" class="ui-input">
                </div>
                <label class="flex items-center gap-2 text-sm text-ink-soft sm:col-span-2">
                    <input type="checkbox" name="confirm_duplicate" value="1"
                           class="h-4 w-4 rounded border-line text-teal focus:ring-teal/30">
                    <?= e($t('admin.orgs.confirm_duplicate')) ?>
                </label>
                <div class="sm:col-span-2">
                    <label for="org-edit-notes" class="ui-label"><?= e($t('admin.orgs.notes')) ?></label>
                    <textarea id="org-edit-notes" name="notes" rows="3" maxlength="1000" class="ui-input"><?= e((string) ($organization['notes'] ?? '')) ?></textarea>
                </div>
                <div class="flex flex-col gap-2 sm:col-span-2 sm:flex-row">
                    <button type="submit" class="ui-btn w-full"><?= e($t('admin.orgs.save')) ?></button>
                    <a href="/admin/organizations" class="ui-btn ui-btn-ghost w-full no-underline">
                        <?= e($t('admin.cancel')) ?>
                    </a>
                </div>
            </form>

            <form method="post"
                  action="/admin/organizations/<?= (int) $organization['id'] ?>/<?= (bool) $organization['is_active'] ? 'deactivate' : 'reactivate' ?>"
                  class="mt-4 border-t border-line pt-4">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <button type="submit" class="ui-btn ui-btn-sm ui-btn-ghost">
                    <?= e($t((bool) $organization['is_active'] ? 'admin.orgs.deactivate' : 'admin.orgs.reactivate')) ?>
                </button>
            </form>
        </article>

        <article class="ui-card ui-card-pad">
            <h2 class="mb-5 text-lg font-semibold text-ink"><?= e($t('admin.members.assign')) ?></h2>
            <form method="post" action="/admin/organizations/<?= (int) $organization['id'] ?>/members" class="ui-stack">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <div>
                    <label for="member-email" class="ui-label"><?= e($t('admin.email')) ?></label>
                    <input id="member-email" type="email" name="email" required maxlength="254" class="ui-input">
                </div>
                <div>
                    <label for="member-role" class="ui-label"><?= e($t('admin.members.role')) ?></label>
                    <select id="member-role" name="role_code" class="ui-input"
                            data-grants-role data-apply-on-load="1">
                        <?php foreach ($roles as $role): ?>
                            <option value="<?= e($role) ?>" data-catalog-ops="<?= e($roleCatalogOps($role)) ?>"
                                <?= $role === 'reviewer' ? 'selected' : '' ?>>
                                <?= e($t('admin.roles.' . $role)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <p class="text-sm text-muted"><?= e($t('admin.grants.role_auto')) ?></p>
                <?php
                $allowedSelected = [];
                $deniedSelected = [];
                require __DIR__ . '/_grant_choices.php';
                ?>
                <button type="submit" class="ui-btn w-full"><?= e($t('admin.members.assign_submit')) ?></button>
            </form>
        </article>
    </div>

    <article class="ui-card ui-card-pad">
        <h2 class="mb-5 text-lg font-semibold text-ink"><?= e($t('admin.members.title')) ?></h2>
        <?php if ($members === []): ?>
            <p class="ui-empty"><?= e($t('admin.members.empty')) ?></p>
        <?php else: ?>
            <div class="ui-table-wrap">
                <table class="ui-table">
                    <thead>
                    <tr>
                        <th class="ui-th"><?= e($t('admin.email')) ?></th>
                        <th class="ui-th"><?= e($t('admin.members.role')) ?></th>
                        <th class="ui-th"><?= e($t('admin.orgs.status')) ?></th>
                        <th class="ui-th"><?= e($t('admin.members.actions')) ?></th>
                    </tr>
                    </thead>
                    <tbody class="divide-y divide-line">
                    <?php foreach ($members as $member): ?>
                        <?php $memberId = (int) $member['id']; ?>
                        <tr class="transition hover:bg-paper/60">
                            <td class="ui-td"><?= e((string) $member['email']) ?></td>
                            <td class="ui-td"><code class="ui-code"><?= e((string) $member['role_code']) ?></code></td>
                            <td class="ui-td"><span class="ui-badge"><?= e((string) $member['status']) ?></span></td>
                            <td class="ui-td">
                                <div class="flex flex-wrap gap-2">
                                    <?php foreach (['active', 'suspended', 'revoked'] as $status): ?>
                                        <?php if ($status === $member['status']) { continue; } ?>
                                        <form method="post" action="/admin/memberships/<?= $memberId ?>/status">
                                            <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                                   value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                            <input type="hidden" name="status" value="<?= e($status) ?>">
                                            <button type="submit" class="ui-btn ui-btn-sm ui-btn-ghost">
                                                <?= e($t('admin.members.status.' . $status)) ?>
                                            </button>
                                        </form>
                                    <?php endforeach; ?>
                                </div>
                            </td>
                        </tr>
                        <tr class="bg-paper/60">
                            <td colspan="4" class="px-4 py-3">
                                <?php
                                $existingGrants = is_array($member['grants'] ?? null) ? $member['grants'] : [];
                                $allowedSelected = [];
                                $deniedSelected = [];

                                foreach ($existingGrants as $existingGrant) {
                                    $value = (string) $existingGrant['catalog_code'] . '|' . (string) $existingGrant['operation'];

                                    if ((bool) $existingGrant['allowed']) {
                                        $allowedSelected[] = $value;
                                    } else {
                                        $deniedSelected[] = $value;
                                    }
                                }
                                $grantCount = count($allowedSelected) + count($deniedSelected);
                                ?>
                                <details class="admin-member-grants rounded-xl border border-line bg-white">
                                    <summary class="cursor-pointer list-none rounded-xl px-4 py-3 text-sm font-semibold text-ink-soft transition hover:bg-paper">
                                        <span class="inline-flex items-center gap-2">
                                            <i data-lucide="key-round" class="h-4 w-4 text-teal-dark"></i>
                                            <?= e($t('admin.grants.member_title')) ?>
                                            <?php if ($grantCount > 0): ?>
                                                <span class="ui-badge"><?= $grantCount ?></span>
                                            <?php endif; ?>
                                        </span>
                                    </summary>
                                    <form method="post" action="/admin/grants/<?= $memberId ?>" class="ui-stack border-t border-line p-4">
                                        <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                               value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                        <?php require __DIR__ . '/_grant_choices.php'; ?>
                                        <button type="submit" class="ui-btn ui-btn-sm"><?= e($t('admin.grants.save')) ?></button>
                                    </form>
                                </details>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </article>

    <article class="ui-card ui-card-pad">
        <h2 class="mb-5 text-lg font-semibold text-ink"><?= e($t('admin.invites.in_organization')) ?></h2>
        <?php if ($invitations === []): ?>
            <p class="ui-empty"><?= e($t('admin.invites.empty')) ?></p>
        <?php else: ?>
            <div class="ui-table-wrap">
                <table class="ui-table">
                    <thead>
                    <tr>
                        <th class="ui-th"><?= e($t('admin.email')) ?></th>
                        <th class="ui-th"><?= e($t('admin.members.role')) ?></th>
                        <th class="ui-th"><?= e($t('admin.invites.expires')) ?></th>
                        <th class="ui-th"><?= e($t('admin.orgs.status')) ?></th>
                    </tr>
                    </thead>
                    <tbody class="divide-y divide-line">
                    <?php foreach ($invitations as $invitation): ?>
                        <tr class="transition hover:bg-paper/60">
                            <td class="ui-td"><?= e((string) $invitation['email']) ?></td>
                            <td class="ui-td"><code class="ui-code"><?= e((string) $invitation['role_code']) ?></code></td>
                            <td class="ui-td text-xs"><?= e((string) $invitation['expires_at']) ?></td>
                            <td class="ui-td">
                                <span class="ui-badge"><?= $invitation['accepted_at'] !== null
                                    ? e($t('admin.invites.accepted'))
                                    : ($invitation['revoked_at'] !== null
                                        ? e($t('admin.invites.revoked'))
                                        : e($t('admin.invites.pending'))) ?></span>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </article>
</section>
<?php require __DIR__ . '/_grant_role_defaults.php'; ?>
