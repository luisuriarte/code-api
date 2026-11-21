<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $invitations */
/** @var list<array<string, mixed>> $organizations */
/** @var list<string> $roles */
/** @var string $status */
/** @var list<array{code: string, name: string, short_name: string}> $catalogs */
?>
<section class="space-y-6">
    <div class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <h1 class="ui-title"><?= e($t('admin.invites.title')) ?></h1>
                <p class="ui-subtitle"><?= e($t('admin.invites.lead')) ?></p>
            </div>
            <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-mint text-teal-dark">
                <i data-lucide="mail" class="h-6 w-6"></i>
            </span>
        </div>
    </div>

    <?php require __DIR__ . '/_flash.php'; ?>

    <div class="ui-grid items-start">
        <article class="ui-card ui-card-pad">
            <h2 class="mb-5 text-lg font-semibold text-ink"><?= e($t('admin.invites.new')) ?></h2>
            <?php
            $values = $flash['values'] ?? [];
            $value = static fn (string $key, string $default = ''): string => e(
                is_string($values[$key] ?? null) && $values[$key] !== '' ? $values[$key] : $default
            );
            $roleCatalogOps = static fn (string $role): string => implode(
                ' ',
                \OrigenSalud\Portal\Admin\Rbac::catalogOperationsForRole($role)
            );
            $applyGrantDefaultsOnLoad = !array_key_exists('grant_allow', $values)
                && !array_key_exists('grant_deny', $values)
                && !array_key_exists('grants', $values);
            ?>
            <form method="post" action="/admin/invitations" class="ui-stack">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <div>
                    <label for="invite-org" class="ui-label"><?= e($t('admin.orgs.name')) ?></label>
                    <select id="invite-org" name="organization_id" required class="ui-input">
                        <option value=""><?= e($t('admin.select')) ?></option>
                        <?php foreach ($organizations as $organization): ?>
                            <option value="<?= (int) $organization['id'] ?>"
                                <?= (string) ($values['organization_id'] ?? '') === (string) $organization['id'] ? 'selected' : '' ?>>
                                <?= e((string) $organization['name']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div>
                    <label for="invite-email" class="ui-label"><?= e($t('admin.email')) ?></label>
                    <input id="invite-email" type="email" name="email" required maxlength="254" value="<?= $value('email') ?>" class="ui-input">
                </div>
                <div>
                    <label for="invite-role" class="ui-label"><?= e($t('admin.members.role')) ?></label>
                    <select id="invite-role" name="role_code" required class="ui-input"
                            data-grants-role
                            data-apply-on-load="<?= $applyGrantDefaultsOnLoad ? '1' : '0' ?>">
                        <?php foreach ($roles as $role): ?>
                            <option value="<?= e($role) ?>"
                                    data-catalog-ops="<?= e($roleCatalogOps($role)) ?>"
                                <?= ($values['role_code'] ?? 'reviewer') === $role ? 'selected' : '' ?>>
                                <?= e($t('admin.roles.' . $role)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div>
                    <label for="invite-ttl" class="ui-label"><?= e($t('admin.invites.ttl')) ?></label>
                    <input id="invite-ttl" type="number" name="ttl" min="60" max="2592000" step="60" value="604800" class="ui-input">
                </div>
                <p class="text-sm text-muted"><?= e($t('admin.grants.role_auto')) ?></p>
                <?php
                $allowedSelected = [];
                $deniedSelected = [];
                require __DIR__ . '/_grant_choices.php';
                ?>
                <div>
                    <label for="invite-message" class="ui-label"><?= e($t('admin.invites.message')) ?></label>
                    <textarea id="invite-message" name="message" rows="3" maxlength="1000" class="ui-input"><?= $value('message') ?></textarea>
                </div>
                <button type="submit" class="ui-btn w-full">
                    <i data-lucide="send" class="h-4 w-4"></i>
                    <?= e($t('admin.invites.send')) ?>
                </button>
            </form>
        </article>

        <article class="ui-card ui-card-pad">
            <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
                <h2 class="text-lg font-semibold text-ink"><?= e($t('admin.invites.list')) ?></h2>
                <nav class="flex flex-wrap gap-1" aria-label="<?= e($t('admin.invites.filter')) ?>">
                    <?php foreach (['pending', 'expired', 'accepted', 'revoked', 'all'] as $filter): ?>
                        <a href="/admin/invitations?status=<?= e($filter) ?>"
                           class="rounded-lg px-2.5 py-1.5 text-xs font-semibold no-underline transition <?= $status === $filter ? 'bg-mint text-teal-dark' : 'bg-paper text-muted hover:text-ink' ?>"
                           <?= $status === $filter ? 'aria-current="page"' : '' ?>>
                            <?= e($t('admin.invites.status.' . $filter)) ?>
                        </a>
                    <?php endforeach; ?>
                </nav>
            </div>

            <?php if ($invitations === []): ?>
                <p class="ui-empty"><?= e($t('admin.invites.empty')) ?></p>
            <?php else: ?>
                <div class="ui-table-wrap">
                    <table class="ui-table">
                        <thead>
                        <tr>
                            <th class="ui-th"><?= e($t('admin.email')) ?></th>
                            <th class="ui-th"><?= e($t('admin.orgs.name')) ?></th>
                            <th class="ui-th"><?= e($t('admin.members.role')) ?></th>
                            <th class="ui-th"><?= e($t('admin.invites.expires')) ?></th>
                            <th class="ui-th"><?= e($t('admin.orgs.status')) ?></th>
                            <th class="ui-th"><?= e($t('admin.members.actions')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($invitations as $invitation): ?>
                            <?php $invitationId = (int) $invitation['id']; ?>
                            <tr class="transition hover:bg-paper/60">
                                <td class="ui-td"><?= e((string) $invitation['email']) ?></td>
                                <td class="ui-td font-medium text-ink"><?= e((string) $invitation['organization_name']) ?></td>
                                <td class="ui-td"><code class="ui-code"><?= e((string) $invitation['role_code']) ?></code></td>
                                <td class="ui-td text-xs"><?= e((string) $invitation['expires_at']) ?></td>
                                <td class="ui-td">
                                    <span class="ui-badge">
                                        <?php if ($invitation['accepted_at'] !== null): ?>
                                            <?= e($t('admin.invites.accepted')) ?>
                                        <?php elseif ($invitation['revoked_at'] !== null): ?>
                                            <?= e($t('admin.invites.revoked')) ?>
                                        <?php else: ?>
                                            <?= e($t('admin.invites.pending')) ?>
                                        <?php endif; ?>
                                    </span>
                                </td>
                                <td class="ui-td">
                                    <?php if ($invitation['accepted_at'] === null && $invitation['revoked_at'] === null): ?>
                                        <div class="flex flex-wrap gap-2">
                                            <form method="post" action="/admin/invitations/<?= $invitationId ?>/resend">
                                                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                                <button type="submit" class="ui-btn ui-btn-sm ui-btn-ghost">
                                                    <?= e($t('admin.invites.resend')) ?>
                                                </button>
                                            </form>
                                            <form method="post" action="/admin/invitations/<?= $invitationId ?>/revoke">
                                                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                                <button type="submit" class="ui-btn ui-btn-sm ui-btn-ghost">
                                                    <?= e($t('admin.invites.revoke')) ?>
                                                </button>
                                            </form>
                                        </div>
                                    <?php endif; ?>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </article>
    </div>
</section>
<?php require __DIR__ . '/_grant_role_defaults.php'; ?>
