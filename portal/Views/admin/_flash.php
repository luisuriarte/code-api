<?php

declare(strict_types=1);

/** @var array{ok: bool, error: ?string, message: ?string, values: array<string, mixed>}|null $flash */
if (!is_array($flash)) {
    return;
}

if ($flash['ok'] && $flash['message'] !== null): ?>
    <p class="admin-ok" role="status"><?= e($t('admin.messages.' . $flash['message'])) ?></p>
<?php elseif ($flash['error'] !== null): ?>
    <p class="admin-error" role="alert"><?= e($t('admin.errors.' . $flash['error'])) ?></p>
<?php endif;
