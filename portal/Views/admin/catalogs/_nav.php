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
?>
<section class="admin-panel">
    <h1><?= e($t('admin.catalogs.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.catalogs.lead')) ?></p>
    <nav class="admin-tabs" aria-label="<?= e($t('admin.catalogs.nav')) ?>">
        <a href="/admin/catalogs"><?= e($t('admin.catalogs.tab_codes')) ?></a>
        <a href="/admin/catalogs/proposals"><?= e($t('admin.catalogs.tab_requests')) ?></a>
    </nav>
    <?php require dirname(__DIR__) . '/_flash.php'; ?>
