<?php

declare(strict_types=1);

/** @var array<string, mixed> $current */
$catalogPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$catalogCanPropose = \OrigenSalud\Portal\Admin\Rbac::hasPermission($catalogPermissions, 'catalog.propose');
$catalogFlash = is_array($flash ?? null) ? $flash : null;
$catalogValues = is_array($catalogFlash['values'] ?? null) ? $catalogFlash['values'] : [];
$catalogValue = static fn (string $key, string $default = ''): string => e(
    is_string($catalogValues[$key] ?? null) && $catalogValues[$key] !== '' ? $catalogValues[$key] : $default
);

$catalogRequestPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/admin/catalogs'), PHP_URL_PATH);
$catalogRequestPath = is_string($catalogRequestPath) && $catalogRequestPath !== '' ? $catalogRequestPath : '/admin/catalogs';
$catalogTabs = [
    ['/admin/catalogs', 'admin.catalogs.tab_codes', 'library'],
    ['/admin/catalogs/proposals', 'admin.catalogs.tab_requests', 'inbox'],
];
$catalogIsActive = static function (string $href) use ($catalogRequestPath): bool {
    if ($href === '/admin/catalogs/proposals') {
        return str_starts_with($catalogRequestPath, $href);
    }

    return $catalogRequestPath === $href
        || (str_starts_with($catalogRequestPath, '/admin/catalogs/')
            && !str_starts_with($catalogRequestPath, '/admin/catalogs/proposals'));
};
?>
<section class="space-y-6">
    <div class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <p class="text-[11px] font-semibold uppercase tracking-[0.18em] text-teal-dark"><?= e($t('nav.management')) ?></p>
                <h1 class="ui-title"><?= e($t('admin.catalogs.title')) ?></h1>
                <p class="ui-subtitle"><?= e($t('admin.catalogs.lead')) ?></p>
            </div>
            <a href="/admin/catalogs/proposals" class="ui-btn ui-btn-sm no-underline">
                <i data-lucide="inbox" class="h-4 w-4"></i>
                <?= e($t('admin.catalogs.tab_requests')) ?>
            </a>
        </div>

        <nav class="mt-6 flex gap-1 overflow-x-auto border-b border-line"
             aria-label="<?= e($t('admin.catalogs.nav')) ?>">
            <?php foreach ($catalogTabs as [$href, $labelKey, $icon]): ?>
                <?php $active = $catalogIsActive($href); ?>
                <a href="<?= e($href) ?>"
                   class="flex shrink-0 items-center gap-2 border-b-2 px-3 py-2.5 text-sm font-medium no-underline transition <?= $active ? 'border-teal text-teal-dark' : 'border-transparent text-muted hover:border-line hover:text-ink' ?>"
                   <?= $active ? 'aria-current="page"' : '' ?>>
                    <i data-lucide="<?= e($icon) ?>" class="h-4 w-4"></i>
                    <?= e($t($labelKey)) ?>
                </a>
            <?php endforeach; ?>
        </nav>
    </div>

    <?php require dirname(__DIR__) . '/_flash.php'; ?>
