<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;

/** @var array<string, mixed>|null $invitation */
/** @var string $token */
/** @var bool $requiresLogin */
?>
<section class="mx-auto flex min-h-[72vh] max-w-lg flex-col justify-center py-6">
    <div class="mb-6 text-center">
        <span class="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-2xl bg-ink text-teal">
            <svg class="h-8 w-8" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
        </span>
        <h1 class="ui-title"><?= e($t('admin.invite.title')) ?></h1>
        <p class="ui-subtitle"><?= e($t('admin.invite.lead')) ?></p>
    </div>

    <div class="ui-card ui-card-pad">
        <div class="ui-stack">
            <?php require __DIR__ . '/_flash.php'; ?>

            <?php if ($invitation === null): ?>
                <div class="ui-alert border-red-200 bg-red-50 text-red-800" role="alert">
                    <p class="font-medium"><?= e($t('admin.invite.invalid')) ?></p>
                </div>
                <p class="text-center text-sm text-muted">
                    <a href="/admin/login" class="font-medium no-underline hover:underline"><?= e($t('admin.back_login')) ?></a>
                </p>
            <?php elseif ($requiresLogin): ?>
                <div class="ui-alert border-line bg-paper text-ink-soft" role="status">
                    <p><?= e($t('admin.invite.login_required')) ?></p>
                </div>
                <a href="/admin/login?next=<?= rawurlencode('/admin/invite?token=' . $token) ?>" class="ui-btn w-full no-underline">
                    <?= e($t('admin.invite.go_login')) ?>
                </a>
            <?php else: ?>
                <dl class="ui-dl rounded-xl border border-line bg-paper/70 p-4">
                    <dt class="ui-dt"><?= e($t('admin.invite.organization')) ?></dt>
                    <dd class="ui-dd font-semibold"><?= e((string) $invitation['organization_name']) ?></dd>
                    <dt class="ui-dt"><?= e($t('admin.invite.role')) ?></dt>
                    <dd class="ui-dd"><code class="ui-code"><?= e((string) $invitation['role_code']) ?></code></dd>
                    <dt class="ui-dt"><?= e($t('admin.invite.expires')) ?></dt>
                    <dd class="ui-dd"><?= e((string) $invitation['expires_at']) ?></dd>
                </dl>
                <p class="text-sm text-muted"><?= e($t('admin.invite.email_note')) ?>: <strong class="text-ink"><?= e((string) $invitation['email']) ?></strong></p>

                <form method="post" action="/admin/invite/accept" class="space-y-4">
                    <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
                    <input type="hidden" name="token" value="<?= e($token) ?>">
                    <?php if (!is_int(\OrigenSalud\Portal\Services\Session::get('admin.user_id'))): ?>
                    <div>
                        <label for="invite-name" class="ui-label"><?= e($t('admin.invite.full_name')) ?></label>
                        <input id="invite-name" type="text" name="full_name" required maxlength="180"
                               autocomplete="name" value="" class="ui-input">
                    </div>
                    <div>
                        <label for="invite-password" class="ui-label"><?= e($t('admin.password_new')) ?></label>
                        <input id="invite-password" type="password" name="password" required minlength="12"
                               maxlength="200" autocomplete="new-password" class="ui-input">
                    </div>
                    <?php else: ?>
                    <div class="ui-alert border-line bg-paper text-ink-soft" role="status">
                        <p><?= e($t('admin.invite.existing_note')) ?></p>
                    </div>
                    <?php endif; ?>
                    <button type="submit" class="ui-btn w-full"><?= e($t('admin.invite.accept')) ?></button>
                </form>
            <?php endif; ?>
        </div>
    </div>
</section>
