<?php

declare(strict_types=1);

$error = is_array($flash) && is_string($flash['error'] ?? null) ? (string) $flash['error'] : '';
$tokenValue = is_array($flash) && is_string($flash['token'] ?? null) ? (string) $flash['token'] : (string) $token;
?>
<section class="admin-card">
    <h1><?= e($t('admin.reset.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.reset.lead')) ?></p>

    <?php if ($invalidToken): ?>
    <p class="admin-error" role="alert"><?= e($t('admin.reset.invalid')) ?></p>
    <?php endif; ?>
    <?php if ($error !== ''): ?>
    <p class="admin-error" role="alert"><?= e($t('admin.reset.error_' . $error)) ?></p>
    <?php endif; ?>

    <?php if ($tokenValue !== ''): ?>
    <form method="post" action="/admin/reset" class="admin-form">
        <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
        <input type="hidden" name="token" value="<?= e($tokenValue) ?>">
        <label>
            <span><?= e($t('admin.password_new')) ?></span>
            <input type="password" name="password" autocomplete="new-password" required minlength="12" maxlength="200">
        </label>
        <button type="submit" class="button"><?= e($t('admin.reset.submit')) ?></button>
    </form>
    <?php endif; ?>

    <p class="admin-help"><a href="/admin/login"><?= e($t('admin.back_login')) ?></a></p>
</section>
