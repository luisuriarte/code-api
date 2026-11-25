<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var string $token */
/** @var array<string, mixed>|null $invitation */
?>
<div class="mx-auto w-full max-w-lg">
    <div class="mb-6 text-center">
        <span class="inline-flex size-12 items-center justify-center rounded-2xl bg-teal/10 text-teal">
            <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M19 8v6M22 11h-6"/>
            </svg>
        </span>
        <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ink"><?= e($t('customer.invitation.title')) ?></h1>
    </div>

    <div class="surface-card">
        <?php if ($invitation === null): ?>
            <p class="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-semibold text-red-700" role="alert"><?= e($t('customer.invitation.invalid')) ?></p>
        <?php else: ?>
            <div class="mb-5 grid gap-2 rounded-xl border border-line bg-paper p-4 text-sm">
                <p><?= e($t('customer.invitation.intro', ['%organization%' => (string) ($invitation['organization_name'] ?? '')])) ?></p>
                <p class="text-muted"><?= e($t('customer.invitation.email', ['%email%' => (string) ($invitation['email'] ?? '')])) ?></p>
            </div>

            <form method="post" action="<?= e($baseUrl . '/' . $locale . '/invitations/' . rawurlencode($token)) ?>" class="grid gap-4">
                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                <div>
                    <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="full_name"><?= e($t('customer.member.full_name')) ?></label>
                    <input class="form-field" id="full_name" name="full_name" required maxlength="200">
                </div>
                <div>
                    <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="password"><?= e($t('customer.reset.password')) ?></label>
                    <input class="form-field" id="password" name="password" type="password" minlength="12" required autocomplete="new-password">
                </div>
                <button class="btn-primary mt-2 w-full" type="submit"><?= e($t('customer.invitation.submit')) ?></button>
            </form>
        <?php endif; ?>
    </div>
</div>
