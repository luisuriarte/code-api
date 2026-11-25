<?php
/** @var callable $t */
?>
<div class="mx-auto w-full max-w-lg text-center">
    <div class="surface-card">
        <span class="inline-flex size-12 items-center justify-center rounded-2xl bg-mint text-teal">
            <svg class="size-6" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/>
            </svg>
        </span>
        <h1 class="mt-4 text-2xl font-semibold tracking-tight text-ink"><?= e($t('customer.error.denied_title')) ?></h1>
        <p class="mt-2 text-sm text-muted"><?= e($t('customer.error.denied_body')) ?></p>
        <a class="btn-secondary mt-6" href="/portal-clientes/<?= e((string) ($locale ?? 'es-AR')) ?>/"><?= e($t('customer.nav.home')) ?></a>
    </div>
</div>
