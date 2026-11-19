<?php

declare(strict_types=1);

/** @var callable $t */
$error = is_array($flash) && is_string($flash['error'] ?? null) ? (string) $flash['error'] : '';
?>
<section class="admin-card">
    <h1><?= e($t('admin.login.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.login.lead')) ?></p>

    <?php if (isset($_GET['logged_out'])): ?>
    <p class="admin-notice" role="status"><?= e($t('admin.login.logged_out')) ?></p>
    <?php endif; ?>
    <?php if (isset($_GET['reset'])): ?>
    <p class="admin-notice" role="status"><?= e($t('admin.reset.done')) ?></p>
    <?php endif; ?>
    <?php if ($error !== ''): ?>
    <p class="admin-error" role="alert"><?= e($t('admin.login.error_' . $error)) ?></p>
    <?php endif; ?>

    <form method="post" action="/admin/login<?= $next !== '/admin' ? '?next=' . rawurlencode($next) : '' ?>" class="admin-form">
        <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
        <input type="hidden" name="next" value="<?= e($next) ?>">
        <label>
            <span><?= e($t('admin.email')) ?></span>
            <input type="email" name="email" value="<?= e($email) ?>" autocomplete="username" required maxlength="254">
        </label>
        <label>
            <span><?= e($t('admin.password')) ?></span>
            <input type="password" name="password" autocomplete="current-password" required maxlength="200">
        </label>
        <button type="submit" class="button"><?= e($t('admin.login.submit')) ?></button>
    </form>

    <p class="admin-help"><a href="/admin/forgot"><?= e($t('admin.forgot.link')) ?></a></p>
</section>
