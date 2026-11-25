<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var string $token */
/** @var bool $valid */
?>
<div class="mx-auto w-full max-w-md">
    <div class="mb-6 text-center">
        <span class="inline-flex size-12 items-center justify-center rounded-2xl bg-teal/10 text-teal">
            <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <path d="M15 7a5 5 0 1 1-6 0M12 3v4M9 21h6"/>
            </svg>
        </span>
        <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ink"><?= e($t('customer.reset.title')) ?></h1>
    </div>

    <div class="surface-card">
        <?php if (!$valid): ?>
            <p class="rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-semibold text-red-700" role="alert"><?= e($t('customer.reset.invalid')) ?></p>
        <?php else: ?>
            <form method="post" action="<?= e($baseUrl . '/' . $locale . '/reset/' . rawurlencode($token)) ?>" class="grid gap-4">
                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                <div>
                    <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="password"><?= e($t('customer.reset.password')) ?></label>
                    <input class="form-field" id="password" name="password" type="password" minlength="12" required autocomplete="new-password">
                </div>
                <button class="btn-primary mt-2 w-full" type="submit"><?= e($t('customer.reset.submit')) ?></button>
            </form>
        <?php endif; ?>
    </div>
</div>
