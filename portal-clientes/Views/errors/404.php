<?php
/** @var callable $t */
?>
<div class="mx-auto w-full max-w-lg text-center">
    <div class="surface-card">
        <span class="inline-flex size-12 items-center justify-center rounded-2xl bg-mint text-teal">
            <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>
            </svg>
        </span>
        <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ink"><?= e($t('customer.error.not_found_title')) ?></h1>
        <p class="mt-2 text-sm text-muted"><?= e($t('customer.error.not_found_body')) ?></p>
        <a class="btn-secondary mt-6" href="/portal-clientes/<?= e((string) ($locale ?? 'es-AR')) ?>/"><?= e($t('customer.nav.home')) ?></a>
    </div>
</div>
