<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
?>
<div class="mx-auto w-full max-w-md">
    <div class="mb-6 flex flex-col items-center text-center">
        <span class="flex size-12 items-center justify-center rounded-2xl bg-teal/10 text-teal">
            <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>
            </svg>
        </span>
        <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ink"><?= e($t('customer.forgot.title')) ?></h1>
        <p class="mt-2 text-sm text-muted"><?= e($t('customer.forgot.intro')) ?></p>
    </div>

    <div class="surface-card">
        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/forgot') ?>" class="grid gap-4">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <div>
                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="email"><?= e($t('customer.login.email')) ?></label>
                <input class="form-field" id="email" name="email" type="email" required autocomplete="username">
            </div>
            <button class="btn-primary mt-2 w-full" type="submit"><?= e($t('customer.forgot.submit')) ?></button>
        </form>

        <p class="mt-5 text-center text-sm">
            <a class="font-semibold text-teal transition hover:text-teal-dark" href="<?= e($baseUrl . '/' . $locale . '/login') ?>"><?= e($t('customer.nav.login')) ?></a>
        </p>
    </div>
</div>
