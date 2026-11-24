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
<div class="card">
    <h1><?= e($t('customer.member.title')) ?></h1>
    <table>
        <thead>
        <tr>
            <th><?= e($t('customer.member.email')) ?></th>
            <th><?= e($t('customer.member.full_name')) ?></th>
            <th><?= e($t('customer.member.role')) ?></th>
            <th><?= e($t('customer.member.status')) ?></th>
            <th><?= e($t('customer.member.actions')) ?></th>
        </tr>
        </thead>
        <tbody>
        <?php foreach ($members as $member) : ?>
            <?php $userId = (int) ($member['user_id'] ?? 0); ?>
            <tr>
                <td><?= e((string) ($member['email'] ?? '')) ?></td>
                <td><?= e((string) ($member['full_name'] ?? '')) ?></td>
                <td><?= e((string) ($member['role_code'] ?? '')) ?></td>
                <td><?= e((string) ($member['status'] ?? '')) ?></td>
                <td>
                    <?php if ($can_update && $userId !== $current_user_id) : ?>
                        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/members/role') ?>">
                            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                            <input type="hidden" name="user_id" value="<?= e($userId) ?>">
                            <select name="role_code">
                                <?php foreach ($roles as $role) : ?>
                                    <option value="<?= e((string) $role['code']) ?>"<?= $role['code'] === ($member['role_code'] ?? null) ? ' selected' : '' ?>>
                                        <?= e((string) $role['label']) ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                            <button type="submit"><?= e($t('customer.member.save_role')) ?></button>
                        </form>
                    <?php endif; ?>

                    <?php if ($can_revoke && $userId !== $current_user_id && ($member['role_code'] ?? '') !== 'organization_owner') : ?>
                        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/members/revoke') ?>">
                            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                            <input type="hidden" name="user_id" value="<?= e($userId) ?>">
                            <button type="submit"><?= e($t('customer.member.revoke')) ?></button>
                        </form>
                    <?php endif; ?>
                </td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>

<?php if ($can_invite) : ?>
    <div class="card">
        <h2><?= e($t('customer.member.invite')) ?></h2>
        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/members/invite') ?>">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <label for="email"><?= e($t('customer.login.email')) ?></label>
            <input id="email" name="email" type="email" required>
            <label for="role_code"><?= e($t('customer.member.role')) ?></label>
            <select id="role_code" name="role_code">
                <?php foreach ($roles as $role) : ?>
                    <option value="<?= e((string) $role['code']) ?>"><?= e((string) $role['label']) ?></option>
                <?php endforeach; ?>
            </select>
            <button type="submit"><?= e($t('customer.member.invite')) ?></button>
        </form>
    </div>
<?php endif; ?>

<div class="card">
    <h2><?= e($t('customer.member.invitations')) ?></h2>
    <table>
        <thead>
        <tr>
            <th><?= e($t('customer.member.email')) ?></th>
            <th><?= e($t('customer.member.role')) ?></th>
            <th><?= e($t('customer.member.status')) ?></th>
            <th><?= e($t('customer.member.expires')) ?></th>
        </tr>
        </thead>
        <tbody>
        <?php foreach ($invitations as $invitation) : ?>
            <tr>
                <td><?= e((string) ($invitation['email'] ?? '')) ?></td>
                <td><?= e((string) ($invitation['role_code'] ?? '')) ?></td>
                <td><?= e((string) ($invitation['status'] ?? '')) ?></td>
                <td><?= e((string) ($invitation['expires_at'] ?? '')) ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
