<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $invitations */
/** @var list<array<string, mixed>> $organizations */
/** @var list<string> $roles */
/** @var string $status */
/** @var list<array{code: string, name: string, short_name: string}> $catalogs */
?>
<section class="admin-panel">
    <h1><?= e($t('admin.invites.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.invites.lead')) ?></p>

    <?php require __DIR__ . '/_flash.php'; ?>

    <div class="admin-grid">
        <article class="admin-box">
            <h2><?= e($t('admin.invites.new')) ?></h2>
            <?php
            $values = $flash['values'] ?? [];
            $value = static fn (string $key, string $default = ''): string => e(
                is_string($values[$key] ?? null) && $values[$key] !== '' ? $values[$key] : $default
            );
            ?>
            <form method="post" action="/admin/invitations" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.orgs.name')) ?>
                    <select name="organization_id" required>
                        <option value=""><?= e($t('admin.select')) ?></option>
                        <?php foreach ($organizations as $organization): ?>
                            <option value="<?= (int) $organization['id'] ?>"
                                <?= (string) ($values['organization_id'] ?? '') === (string) $organization['id'] ? 'selected' : '' ?>>
                                <?= e((string) $organization['name']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label><?= e($t('admin.email')) ?>
                    <input type="email" name="email" required maxlength="254" value="<?= $value('email') ?>">
                </label>
                <label><?= e($t('admin.members.role')) ?>
                    <select name="role_code" required>
                        <?php foreach ($roles as $role): ?>
                            <option value="<?= e($role) ?>"
                                <?= ($values['role_code'] ?? 'reviewer') === $role ? 'selected' : '' ?>>
                                <?= e($t('admin.roles.' . $role)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label><?= e($t('admin.invites.ttl')) ?>
                    <input type="number" name="ttl" min="60" max="2592000" step="60" value="604800">
                </label>
                <?php
                $allowedSelected = [];
                $deniedSelected = [];
                require __DIR__ . '/_grant_choices.php';
                ?>
                <label><?= e($t('admin.invites.message')) ?>
                    <textarea name="message" rows="3" maxlength="1000"><?= $value('message') ?></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.invites.send')) ?></button>
            </form>
        </article>

        <article class="admin-box">
            <h2><?= e($t('admin.invites.list')) ?></h2>
            <nav class="admin-tabs" aria-label="<?= e($t('admin.invites.filter')) ?>">
                <?php foreach (['pending', 'expired', 'accepted', 'revoked', 'all'] as $filter): ?>
                    <a href="/admin/invitations?status=<?= e($filter) ?>"
                       class="<?= $status === $filter ? 'active' : '' ?>">
                        <?= e($t('admin.invites.status.' . $filter)) ?>
                    </a>
                <?php endforeach; ?>
            </nav>
            <?php if ($invitations === []): ?>
            <p><?= e($t('admin.invites.empty')) ?></p>
            <?php else: ?>
            <div class="admin-table-wrap">
                <table class="admin-table">
                    <thead>
                    <tr>
                        <th><?= e($t('admin.email')) ?></th>
                        <th><?= e($t('admin.orgs.name')) ?></th>
                        <th><?= e($t('admin.members.role')) ?></th>
                        <th><?= e($t('admin.invites.expires')) ?></th>
                        <th><?= e($t('admin.orgs.status')) ?></th>
                        <th><?= e($t('admin.members.actions')) ?></th>
                    </tr>
                    </thead>
                    <tbody>
                    <?php foreach ($invitations as $invitation): ?>
                        <?php $invitationId = (int) $invitation['id']; ?>
                        <tr>
                            <td><?= e((string) $invitation['email']) ?></td>
                            <td><?= e((string) $invitation['organization_name']) ?></td>
                            <td><code><?= e((string) $invitation['role_code']) ?></code></td>
                            <td><?= e((string) $invitation['expires_at']) ?></td>
                            <td>
                                <?php if ($invitation['accepted_at'] !== null): ?>
                                    <?= e($t('admin.invites.accepted')) ?>
                                <?php elseif ($invitation['revoked_at'] !== null): ?>
                                    <?= e($t('admin.invites.revoked')) ?>
                                <?php else: ?>
                                    <?= e($t('admin.invites.pending')) ?>
                                <?php endif; ?>
                            </td>
                            <td>
                                <?php if ($invitation['accepted_at'] === null && $invitation['revoked_at'] === null): ?>
                                <form method="post" action="/admin/invitations/<?= $invitationId ?>/resend"
                                      class="admin-inline">
                                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                    <button type="submit" class="button button-small">
                                        <?= e($t('admin.invites.resend')) ?>
                                    </button>
                                </form>
                                <form method="post" action="/admin/invitations/<?= $invitationId ?>/revoke"
                                      class="admin-inline">
                                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                    <button type="submit" class="button button-small">
                                        <?= e($t('admin.invites.revoke')) ?>
                                    </button>
                                </form>
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
