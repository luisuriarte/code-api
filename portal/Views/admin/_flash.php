<?php

declare(strict_types=1);

/** @var array{ok: bool, error: ?string, message: ?string, values: array<string, mixed>}|null $flash */
if (!is_array($flash)) {
    return;
}

if ($flash['ok'] && $flash['message'] !== null): ?>
    <div class="ui-alert border-mint bg-mint/60 text-teal-dark" role="status">
        <div class="flex items-start gap-3">
            <i data-lucide="circle-check" class="mt-0.5 h-4 w-4 shrink-0"></i>
            <p class="font-medium"><?= e($t('admin.messages.' . $flash['message'])) ?></p>
        </div>
    </div>
<?php elseif ($flash['error'] !== null): ?>
    <div class="ui-alert border-red-200 bg-red-50 text-red-800" role="alert">
        <div class="flex items-start gap-3">
            <i data-lucide="circle-alert" class="mt-0.5 h-4 w-4 shrink-0"></i>
            <p class="font-medium"><?= e($t('admin.errors.' . $flash['error'])) ?></p>
        </div>
    </div>
<?php endif;
