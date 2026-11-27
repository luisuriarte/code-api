<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

/** @var callable $t */
$error = is_array($flash) && is_string($flash['error'] ?? null) ? (string) $flash['error'] : '';
?>
<section class="mx-auto flex min-h-[72vh] max-w-md flex-col justify-center py-6">
    <div class="mb-6 text-center">
        <span class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-ink text-teal">
            <svg class="h-8 w-8" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
        </span>
        <h1 class="ui-title"><?= e($t('admin.login.title')) ?></h1>
        <p class="ui-subtitle"><?= e($t('admin.login.lead')) ?></p>
    </div>

    <div class="ui-card ui-card-pad">
        <div class="ui-stack">
            <?php if (isset($_GET['logged_out'])): ?>
            <div class="ui-alert border-line bg-paper text-ink-soft" role="status">
                <p><?= e($t('admin.login.logged_out')) ?></p>
            </div>
            <?php endif; ?>
            <?php if (isset($_GET['reset'])): ?>
            <div class="ui-alert border-line bg-paper text-ink-soft" role="status">
                <p><?= e($t('admin.reset.done')) ?></p>
            </div>
            <?php endif; ?>
            <?php if (is_array($flash) && !empty($flash['ok']) && is_string($flash['message'] ?? null)): ?>
            <div class="ui-alert border-mint bg-mint/60 text-teal-dark" role="status">
                <p class="font-medium"><?= e($t('admin.messages.' . $flash['message'])) ?></p>
            </div>
            <?php endif; ?>
            <?php if ($error !== ''): ?>
            <div class="ui-alert border-red-200 bg-red-50 text-red-800" role="alert">
                <p class="font-medium"><?= e($t('admin.login.error_' . $error)) ?></p>
            </div>
            <?php endif; ?>

            <form method="post" action="/admin/login<?= $next !== '/admin' ? '?next=' . rawurlencode($next) : '' ?>" class="space-y-4">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                <input type="hidden" name="next" value="<?= e($next) ?>">
                <div>
                    <label for="login-email" class="ui-label"><?= e($t('admin.email')) ?></label>
                    <input id="login-email" type="email" name="email" value="<?= e($email) ?>"
                           autocomplete="username" required maxlength="254" class="ui-input"
                           placeholder="<?= e($t('admin.login.email_placeholder')) ?>">
                </div>
                <div>
                    <label for="login-password" class="ui-label"><?= e($t('admin.password')) ?></label>
                    <input id="login-password" type="password" name="password"
                           autocomplete="current-password" required maxlength="200" class="ui-input">
                </div>
                <button type="submit" class="ui-btn w-full">
                    <i data-lucide="log-in" class="h-4 w-4"></i>
                    <?= e($t('admin.login.submit')) ?>
                </button>
            </form>

            <p class="border-t border-line pt-4 text-center text-sm text-muted">
                <a href="/admin/forgot" class="font-medium no-underline hover:underline"><?= e($t('admin.forgot.link')) ?></a>
            </p>
            <a href="<?= e(I18n::localizedPath($locale, '/')) ?>"
               class="ui-btn ui-btn-ghost w-full no-underline">
                <i data-lucide="arrow-left" class="h-4 w-4"></i>
                <?= e($t('admin.login.back_site')) ?>
            </a>
        </div>
    </div>
</section>
