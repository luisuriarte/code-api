<?php

declare(strict_types=1);

/** @var array<string, mixed> $organization */
/** @var list<array<string, mixed>> $members */
/** @var list<array<string, mixed>> $invitations */
/** @var list<string> $roles */
?>
<section class="admin-panel">
    <p><a href="/admin/organizations">← <?= e($t('admin.orgs.back')) ?></a></p>
    <h1><?= e((string) $organization['name']) ?></h1>
    <p class="admin-lead">
        <code><?= e((string) ($organization['code'] ?? '')) ?></code> ·
        <?= e($t('admin.roles.org_type.' . (string) $organization['type'])) ?> ·
        <?= e((string) $organization['country_code']) ?> ·
        <?= (bool) $organization['is_active']
            ? e($t('admin.orgs.active')) : e($t('admin.orgs.inactive')) ?>
    </p>

    <?php require __DIR__ . '/_flash.php'; ?>

    <div class="admin-grid">
        <article class="admin-box">
            <h2><?= e($t('admin.orgs.edit')) ?></h2>
            <form method="post" action="/admin/organizations/<?= (int) $organization['id'] ?>" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.orgs.code')) ?>
                    <input type="text" value="<?= e((string) ($organization['code'] ?? '')) ?>" disabled>
                </label>
                <label><?= e($t('admin.orgs.name')) ?>
                    <input type="text" name="name" required maxlength="180"
                           value="<?= e((string) $organization['name']) ?>">
                </label>
                <label><?= e($t('admin.orgs.legal_name')) ?>
                    <input type="text" name="legal_name" maxlength="240"
                           value="<?= e((string) ($organization['legal_name'] ?? '')) ?>">
                </label>
                <label><?= e($t('admin.orgs.type')) ?>
                    <select name="type">
                        <?php foreach (\OrigenSalud\Portal\Admin\Rbac::ORGANIZATION_TYPES as $type): ?>
                            <option value="<?= e($type) ?>" <?= $organization['type'] === $type ? 'selected' : '' ?>>
                                <?= e($t('admin.roles.org_type.' . $type)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label><?= e($t('admin.orgs.country')) ?>
                    <input type="text" name="country_code" required maxlength="2"
                           value="<?= e((string) $organization['country_code']) ?>">
                </label>
                <label><?= e($t('admin.email')) ?>
                    <input type="email" name="contact_email" maxlength="254"
                           value="<?= e((string) ($organization['contact_email'] ?? '')) ?>">
                </label>
                <label><?= e($t('admin.orgs.website')) ?>
                    <input type="url" name="website" maxlength="254"
                           value="<?= e((string) ($organization['website'] ?? '')) ?>">
                </label>
                <label><?= e($t('admin.orgs.confirm_duplicate')) ?>
                    <input type="checkbox" name="confirm_duplicate" value="1">
                </label>
                <label><?= e($t('admin.orgs.notes')) ?>
                    <textarea name="notes" rows="3" maxlength="1000"><?= e((string) ($organization['notes'] ?? '')) ?></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.orgs.save')) ?></button>
            </form>

            <form method="post"
                  action="/admin/organizations/<?= (int) $organization['id'] ?>/<?= (bool) $organization['is_active'] ? 'deactivate' : 'reactivate' ?>"
                  class="admin-form admin-inline">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <button type="submit" class="button button-small">
                    <?= e($t((bool) $organization['is_active'] ? 'admin.orgs.deactivate' : 'admin.orgs.reactivate')) ?>
                </button>
            </form>
        </article>

        <article class="admin-box">
            <h2><?= e($t('admin.members.assign')) ?></h2>
            <form method="post" action="/admin/organizations/<?= (int) $organization['id'] ?>/members" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.email')) ?>
                    <input type="email" name="email" required maxlength="254">
                </label>
                <label><?= e($t('admin.members.role')) ?>
                    <select name="role_code">
                        <?php foreach ($roles as $role): ?>
                            <option value="<?= e($role) ?>"><?= e($t('admin.roles.' . $role)) ?></option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label><?= e($t('admin.grants.hint')) ?>
                    <textarea name="grants" rows="3" placeholder="snomed:propose:dentar-pr:review:deny"></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.members.assign_submit')) ?></button>
            </form>
        </article>
    </div>

    <article class="admin-box">
        <h2><?= e($t('admin.members.title')) ?></h2>
        <?php if ($members === []): ?>
        <p><?= e($t('admin.members.empty')) ?></p>
        <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.email')) ?></th>
                    <th><?= e($t('admin.members.role')) ?></th>
                    <th><?= e($t('admin.orgs.status')) ?></th>
                    <th><?= e($t('admin.members.actions')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($members as $member): ?>
                    <?php $memberId = (int) $member['id']; ?>
                    <tr>
                        <td><?= e((string) $member['email']) ?></td>
                        <td><code><?= e((string) $member['role_code']) ?></code></td>
                        <td><?= e((string) $member['status']) ?></td>
                        <td>
                            <?php foreach (['active', 'suspended', 'revoked'] as $status): ?>
                                <?php if ($status === $member['status']) { continue; } ?>
                                <form method="post" action="/admin/memberships/<?= $memberId ?>/status" class="admin-inline">
                                    <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                           value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                    <input type="hidden" name="status" value="<?= e($status) ?>">
                                    <button type="submit" class="button button-small">
                                        <?= e($t('admin.members.status.' . $status)) ?>
                                    </button>
                                </form>
                            <?php endforeach; ?>
                        </td>
                    </tr>
                    <tr class="admin-subrow">
                        <td colspan="4">
                            <form method="post" action="/admin/grants/<?= $memberId ?>" class="admin-form admin-inline">
                                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                                <label><?= e($t('admin.grants.catalog')) ?>
                                    <input type="text" name="catalog_code" maxlength="50" required>
                                </label>
                                <label><?= e($t('admin.grants.operation')) ?>
                                    <select name="operation">
                                        <?php foreach (\OrigenSalud\Portal\Admin\Rbac::CATALOG_OPERATIONS as $operation): ?>
                                            <option value="<?= e($operation) ?>"><?= e($operation) ?></option>
                                        <?php endforeach; ?>
                                    </select>
                                </label>
                                <label><?= e($t('admin.grants.decision')) ?>
                                    <select name="allowed">
                                        <option value="allow"><?= e($t('admin.home.allowed')) ?></option>
                                        <option value="deny"><?= e($t('admin.home.denied')) ?></option>
                                    </select>
                                </label>
                                <button type="submit" class="button button-small"><?= e($t('admin.grants.save')) ?></button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
        <?php endif; ?>
    </article>

    <article class="admin-box">
        <h2><?= e($t('admin.invites.in_organization')) ?></h2>
        <?php if ($invitations === []): ?>
        <p><?= e($t('admin.invites.empty')) ?></p>
        <?php else: ?>
        <div class="admin-table-wrap">
            <table class="admin-table">
                <thead>
                <tr>
                    <th><?= e($t('admin.email')) ?></th>
                    <th><?= e($t('admin.members.role')) ?></th>
                    <th><?= e($t('admin.invites.expires')) ?></th>
                    <th><?= e($t('admin.orgs.status')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($invitations as $invitation): ?>
                    <tr>
                        <td><?= e((string) $invitation['email']) ?></td>
                        <td><code><?= e((string) $invitation['role_code']) ?></code></td>
                        <td><?= e((string) $invitation['expires_at']) ?></td>
                        <td><?= $invitation['accepted_at'] !== null
                            ? e($t('admin.invites.accepted'))
                            : ($invitation['revoked_at'] !== null
                                ? e($t('admin.invites.revoked'))
                                : e($t('admin.invites.pending'))) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
        <?php endif; ?>
    </article>
</section>
