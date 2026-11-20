<?php

declare(strict_types=1);

$sent = isset($_GET['sent']);
$error = is_array($flash) && is_string($flash['error'] ?? null) ? (string) $flash['error'] : '';
?>
<section class="mx-auto flex min-h-[72vh] max-w-md flex-col justify-center py-6">
    <div class="mb-6 text-center">
        <span class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-mint text-teal-dark">
            <i data-lucide="key-round" class="h-6 w-6"></i>
        </span>
        <h1 class="ui-title"><?= e($t('admin.forgot.title')) ?></h1>
        <p class="ui-subtitle"><?= e($t('admin.forgot.lead')) ?></p>
    </div>

    <div class="ui-card ui-card-pad">
        <div class="ui-stack">
            <?php if ($sent): ?>
            <div class="ui-alert border-mint bg-mint/60 text-teal-dark" role="status">
                <p class="font-medium"><?= e($t('admin.forgot.sent')) ?></p>
            </div>
            <?php endif; ?>
            <?php if ($error !== ''): ?>
            <div class="ui-alert border-red-200 bg-red-50 text-red-800" role="alert">
                <p class="font-medium"><?= e($t('admin.error.' . $error)) ?></p>
            </div>
            <?php endif; ?>

            <form method="post" action="/admin/forgot" class="space-y-4">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                <div>
                    <label for="forgot-email" class="ui-label"><?= e($t('admin.email')) ?></label>
                    <input id="forgot-email" type="email" name="email" autocomplete="email"
                           required maxlength="254" class="ui-input">
                </div>
                <button type="submit" class="ui-btn w-full"><?= e($t('admin.forgot.submit')) ?></button>
            </form>

            <p class="border-t border-line pt-4 text-center text-sm text-muted">
                <a href="/admin/login" class="font-medium no-underline hover:underline"><?= e($t('admin.back_login')) ?></a>
            </p>
        </div>
    </div>
</section>
