<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var string|null $error */
?>
<div class="mx-auto w-full max-w-md">
    <div class="mb-6 flex flex-col items-center text-center">
        <span class="flex size-12 items-center justify-center rounded-2xl bg-teal/10 text-teal">
            <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <rect x="4" y="10" width="16" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>
            </svg>
        </span>
        <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ink"><?= e($t('customer.login.title')) ?></h1>
    </div>

    <div class="surface-card">
        <?php if (is_string($error) && $error !== ''): ?>
            <p class="mb-5 flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2 text-sm font-semibold text-red-700" role="alert">
                <svg class="mt-0.5 size-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                    <circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>
                </svg>
                <?= e($t($error)) ?>
            </p>
        <?php endif; ?>

        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/login') ?>" class="grid gap-4">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <div>
                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="email"><?= e($t('customer.login.email')) ?></label>
                <input class="form-field" id="email" name="email" type="email" required autocomplete="username">
            </div>
            <div>
                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="password"><?= e($t('customer.login.password')) ?></label>
                <input class="form-field" id="password" name="password" type="password" required autocomplete="current-password">
            </div>
            <button class="btn-primary mt-2 w-full" type="submit">
                <?= e($t('customer.login.submit')) ?>
                <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
            </button>
        </form>

        <p class="mt-5 text-center text-sm">
            <a class="font-semibold text-teal transition hover:text-teal-dark" href="<?= e($baseUrl . '/' . $locale . '/forgot') ?>"><?= e($t('customer.login.forgot')) ?></a>
        </p>
    </div>

    <p class="mt-5 text-center">
        <a class="btn-secondary" href="https://med.origen.ar/"><?= e($t('customer.login.back_site')) ?></a>
    </p>
</div>
