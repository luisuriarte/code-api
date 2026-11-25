<?php
/** @var callable $t */
?>
<div class="mx-auto w-full max-w-lg text-center">
    <div class="surface-card">
        <span class="inline-flex size-12 items-center justify-center rounded-2xl bg-mint text-teal">
            <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <path d="M12 9v4M12 17h.01M10.3 3.9 2.6 17a2 2 0 0 0 1.7 3h15.4a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0Z"/>
            </svg>
        </span>
        <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ink"><?= e($t('customer.error.unavailable_title')) ?></h1>
        <p class="mt-2 text-sm text-muted"><?= e($t('customer.error.unavailable_body')) ?></p>
    </div>
</div>
