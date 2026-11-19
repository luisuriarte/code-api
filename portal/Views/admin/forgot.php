<?php

declare(strict_types=1);

$sent = isset($_GET['sent']);
$error = is_array($flash) && is_string($flash['error'] ?? null) ? (string) $flash['error'] : '';
?>
<section class="admin-card">
    <h1><?= e($t('admin.forgot.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.forgot.lead')) ?></p>

    <?php if ($sent): ?>
    <p class="admin-notice" role="status"><?= e($t('admin.forgot.sent')) ?></p>
    <?php endif; ?>
    <?php if ($error !== ''): ?>
    <p class="admin-error" role="alert"><?= e($t('admin.error.' . $error)) ?></p>
    <?php endif; ?>

    <form method="post" action="/admin/forgot" class="admin-form">
        <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
        <label>
            <span><?= e($t('admin.email')) ?></span>
            <input type="email" name="email" autocomplete="email" required maxlength="254">
        </label>
        <button type="submit" class="button"><?= e($t('admin.forgot.submit')) ?></button>
    </form>

    <p class="admin-help"><a href="/admin/login"><?= e($t('admin.back_login')) ?></a></p>
</section>
