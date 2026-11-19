<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;

/** @var array<string, mixed>|null $invitation */
/** @var string $token */
/** @var bool $requiresLogin */
?>
<section class="admin-card">
    <h1><?= e($t('admin.invite.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.invite.lead')) ?></p>

    <?php require __DIR__ . '/_flash.php'; ?>

    <?php if ($invitation === null): ?>
        <p class="admin-error" role="alert"><?= e($t('admin.invite.invalid')) ?></p>
        <p class="admin-help"><a href="/admin/login"><?= e($t('admin.back_login')) ?></a></p>
    <?php elseif ($requiresLogin): ?>
        <p class="admin-notice" role="status"><?= e($t('admin.invite.login_required')) ?></p>
        <p class="admin-help">
            <a href="/admin/login?next=<?= rawurlencode('/admin/invite?token=' . $token) ?>">
                <?= e($t('admin.invite.go_login')) ?>
            </a>
        </p>
    <?php else: ?>
        <p class="admin-notice" role="status">
            <?= e($t('admin.invite.organization')) ?>: <strong><?= e((string) $invitation['organization_name']) ?></strong>
        </p>
        <p><?= e($t('admin.invite.role')) ?>: <code><?= e((string) $invitation['role_code']) ?></code></p>
        <p><?= e($t('admin.invite.expires')) ?>: <?= e((string) $invitation['expires_at']) ?></p>
        <p class="admin-help"><?= e($t('admin.invite.email_note')) ?>: <strong><?= e((string) $invitation['email']) ?></strong></p>

        <form method="post" action="/admin/invite/accept" class="admin-form">
            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
            <input type="hidden" name="token" value="<?= e($token) ?>">
            <?php if (!is_int(\OrigenSalud\Portal\Services\Session::get('admin.user_id'))): ?>
            <label><?= e($t('admin.invite.full_name')) ?>
                <input type="text" name="full_name" required maxlength="180"
                       autocomplete="name" value="">
            </label>
            <label><?= e($t('admin.password_new')) ?>
                <input type="password" name="password" required minlength="12" maxlength="200"
                       autocomplete="new-password">
            </label>
            <?php else: ?>
            <p class="admin-notice"><?= e($t('admin.invite.existing_note')) ?></p>
            <?php endif; ?>
            <button type="submit" class="button"><?= e($t('admin.invite.accept')) ?></button>
        </form>
    <?php endif; ?>
</section>
