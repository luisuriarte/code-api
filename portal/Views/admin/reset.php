<?php

declare(strict_types=1);

$error = is_array($flash) && is_string($flash['error'] ?? null) ? (string) $flash['error'] : '';
$tokenValue = is_array($flash) && is_string($flash['token'] ?? null) ? (string) $flash['token'] : (string) $token;
?>
<section class="mx-auto flex min-h-[72vh] max-w-md flex-col justify-center py-6">
    <div class="mb-6 text-center">
        <span class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-mint text-teal-dark">
            <i data-lucide="shield-check" class="h-6 w-6"></i>
        </span>
        <h1 class="ui-title"><?= e($t('admin.reset.title')) ?></h1>
        <p class="ui-subtitle"><?= e($t('admin.reset.lead')) ?></p>
    </div>

    <div class="ui-card ui-card-pad">
        <div class="ui-stack">
            <?php if ($invalidToken): ?>
            <div class="ui-alert border-red-200 bg-red-50 text-red-800" role="alert">
                <p class="font-medium"><?= e($t('admin.reset.invalid')) ?></p>
            </div>
            <?php endif; ?>
            <?php if ($error !== ''): ?>
            <div class="ui-alert border-red-200 bg-red-50 text-red-800" role="alert">
                <p class="font-medium"><?= e($t('admin.reset.error_' . $error)) ?></p>
            </div>
            <?php endif; ?>

            <?php if ($tokenValue !== ''): ?>
            <form method="post" action="/admin/reset" class="space-y-4">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                <input type="hidden" name="token" value="<?= e($tokenValue) ?>">
                <div>
                    <label for="reset-password" class="ui-label"><?= e($t('admin.password_new')) ?></label>
                    <input id="reset-password" type="password" name="password" autocomplete="new-password"
                           required minlength="12" maxlength="200" class="ui-input">
                </div>
                <button type="submit" class="ui-btn w-full"><?= e($t('admin.reset.submit')) ?></button>
            </form>
            <?php endif; ?>

            <p class="border-t border-line pt-4 text-center text-sm text-muted">
                <a href="/admin/login" class="font-medium no-underline hover:underline"><?= e($t('admin.back_login')) ?></a>
            </p>
        </div>
    </div>
</section>
