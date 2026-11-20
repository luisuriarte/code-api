<?php

declare(strict_types=1);

use OrigenSalud\Portal\Admin\Rbac;
use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Web\I18n;

$adminAssetRoot = dirname(__DIR__, 3) . '/web';
$adminAsset = static function (string $path) use ($adminAssetRoot): string {
    $file = $adminAssetRoot . $path;
    $version = is_file($file) ? @filemtime($file) : false;

    return $version === false ? $path : $path . '?v=' . $version;
};

$adminPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/admin'), PHP_URL_PATH);
$adminPath = is_string($adminPath) && $adminPath !== '' ? $adminPath : '/admin';
$adminNext = $adminPath;
$adminIsActive = static function (string $href) use ($adminPath): bool {
    if ($href === '/admin') {
        return $adminPath === '/admin';
    }

    return $adminPath === $href || str_starts_with($adminPath, $href . '/');
};

$adminPermissions = is_array($current['permissions'] ?? null) ? $current['permissions'] : [];
$adminContexts = is_array($current['contexts'] ?? null) ? $current['contexts'] : [];
$adminActiveOrg = $current['active_org_id'] ?? null;

$adminNav = [
    ['/admin', 'admin.home.title', 'layout-dashboard', null],
    ['/admin/uvr', 'admin.uvr.title', 'scale', 'catalog.view'],
    ['/admin/catalogs', 'admin.catalogs.title', 'library', 'catalog.view'],
    ['/admin/organizations', 'admin.orgs.title', 'building-2', 'admin.orgs.manage'],
    ['/admin/invitations', 'admin.invites.title', 'mail', 'admin.invites.manage'],
    ['/admin/audit', 'admin.audit.title', 'scroll-text', 'audit.view'],
];
?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title><?= e($pageTitle) ?></title>
    <meta name="description" content="<?= e($pageDescription) ?>">
    <link rel="stylesheet" href="<?= e($adminAsset('/assets/css/admin.css')) ?>">
</head>
<body class="min-h-screen bg-paper text-ink antialiased" x-data="{ sidebarOpen: false }">
<a class="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[100] focus:rounded-xl focus:bg-ink focus:px-4 focus:py-2 focus:text-sm focus:font-semibold focus:text-white"
    href="#main"><?= e($t('a11y.skip')) ?></a>

<!-- Navegación lateral -->
<div x-show="sidebarOpen"
     x-cloak
     @click="sidebarOpen = false"
     class="fixed inset-0 z-40 bg-ink/50 backdrop-blur-sm lg:hidden"
     aria-hidden="true"></div>

<aside class="fixed inset-y-0 left-0 z-50 flex w-72 flex-col border-r border-white/10 bg-ink text-white shadow-panel transition-transform duration-200 lg:translate-x-0"
       :class="sidebarOpen ? 'translate-x-0' : '-translate-x-full'"
       aria-label="<?= e($t('admin.nav')) ?>">
    <div class="flex h-16 items-center justify-between border-b border-white/10 px-6">
        <a href="/admin" class="flex items-center gap-3 text-white no-underline" aria-label="Origen Salud">
            <svg class="h-9 w-9 shrink-0 text-teal" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
            <span class="leading-tight">
                <span class="block text-sm font-semibold tracking-wide">Origen Salud</span>
                <span class="block text-[11px] uppercase tracking-[0.18em] text-white/50"><?= e($t('admin.brand')) ?></span>
            </span>
        </a>
        <button type="button" @click="sidebarOpen = false"
                class="rounded-lg p-2 text-white/60 transition hover:bg-white/10 hover:text-white lg:hidden"
                aria-label="<?= e($t('admin.nav')) ?>">
            <i data-lucide="x" class="h-5 w-5"></i>
        </button>
    </div>

    <nav class="flex-1 space-y-1 overflow-y-auto px-4 py-6">
        <?php foreach ($adminNav as [$href, $labelKey, $icon, $permission]): ?>
            <?php if ($permission !== null && !Rbac::hasPermission($adminPermissions, $permission)) { continue; } ?>
            <?php $active = $adminIsActive($href); ?>
            <a href="<?= e($href) ?>"
               class="group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition no-underline <?= $active ? 'bg-white/10 text-white' : 'text-white/60 hover:bg-white/5 hover:text-white' ?>"
               <?= $active ? 'aria-current="page"' : '' ?>>
                <i data-lucide="<?= e($icon) ?>" class="h-5 w-5 shrink-0 <?= $active ? 'text-teal' : 'text-white/40 group-hover:text-white/70' ?>"></i>
                <span><?= e($t($labelKey)) ?></span>
                <?php if ($active): ?><span class="ml-auto h-1.5 w-1.5 rounded-full bg-teal"></span><?php endif; ?>
            </a>
        <?php endforeach; ?>
    </nav>

    <?php if (!empty($adminUser)): ?>
    <div class="border-t border-white/10 px-4 py-4">
        <div class="flex items-center gap-3 rounded-xl bg-white/5 p-3">
            <span class="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-teal/20 text-teal">
                <i data-lucide="shield-check" class="h-4 w-4"></i>
            </span>
            <span class="min-w-0">
                <span class="block truncate text-xs font-semibold text-white"><?= e((string) ($adminUser['full_name'] ?? '')) ?></span>
                <span class="block truncate text-[11px] text-white/50"><?= e((string) ($adminUser['email'] ?? '')) ?></span>
            </span>
        </div>
    </div>
    <?php endif; ?>
</aside>

<div class="min-h-screen lg:pl-72">
    <header class="sticky top-0 z-30 border-b border-line bg-white/90 backdrop-blur">
        <div class="mx-auto flex h-16 max-w-[1400px] items-center gap-3 px-4 sm:px-6 lg:px-8">
            <button type="button" @click="sidebarOpen = true"
                    class="rounded-xl border border-line p-2 text-ink-soft transition hover:border-teal hover:text-teal-dark lg:hidden"
                    aria-label="<?= e($t('admin.nav')) ?>">
                <i data-lucide="menu" class="h-5 w-5"></i>
            </button>

            <div class="min-w-0 flex-1">
                <p class="truncate text-[11px] font-semibold uppercase tracking-[0.18em] text-muted"><?= e($t('admin.brand')) ?></p>
                <h1 class="truncate text-base font-semibold text-ink sm:text-lg"><?= e($pageTitle) ?></h1>
            </div>

            <?php if (!empty($adminUser)): ?>
                <?php if (count($adminContexts) > 1): ?>
                <form method="post" action="/admin/context" class="hidden items-center gap-2 sm:flex">
                    <label for="admin-context-select" class="sr-only"><?= e($t('admin.context.label')) ?></label>
                    <select id="admin-context-select" name="organization_id"
                            onchange="this.form.submit()"
                            class="ui-input max-w-[13rem] py-1.5 text-xs">
                        <?php foreach ($adminContexts as $context): ?>
                            <option value="<?= $context['id'] === null ? '' : (int) $context['id'] ?>"
                                <?= $context['id'] === $adminActiveOrg ? 'selected' : '' ?>>
                                <?= e((string) $context['name']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                    <input type="hidden" name="next" value="<?= e($adminNext) ?>">
                    <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
                    <button type="submit" class="ui-btn ui-btn-sm ui-btn-ghost"><?= e($t('admin.context.switch')) ?></button>
                </form>
                <?php endif; ?>

                <form method="post" action="/admin/logout" class="hidden sm:block">
                    <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
                    <button type="submit" class="ui-btn ui-btn-sm ui-btn-ghost">
                        <i data-lucide="log-out" class="h-4 w-4"></i>
                        <span><?= e($t('admin.logout')) ?></span>
                    </button>
                </form>
            <?php endif; ?>

            <div class="relative">
                <button type="button" id="admin-language-button"
                        data-dropdown-toggle="admin-language-menu"
                        data-dropdown-placement="bottom-end"
                        class="flex items-center gap-1.5 rounded-xl border border-line bg-white px-3 py-2 text-xs font-semibold uppercase tracking-wide text-ink-soft transition hover:border-teal hover:text-teal-dark">
                    <i data-lucide="languages" class="h-4 w-4"></i>
                    <?= e(strtoupper($locale)) ?>
                    <i data-lucide="chevron-down" class="h-3.5 w-3.5"></i>
                </button>
                <div id="admin-language-menu"
                     class="z-50 hidden w-36 rounded-xl border border-line bg-white p-1 shadow-panel">
                    <ul class="space-y-0.5">
                        <?php
                        $adminQuery = $_GET;
                        foreach (I18n::SUPPORTED as $adminLocale):
                            $adminQuery['lang'] = $adminLocale;
                            $adminHref = $adminPath . '?' . http_build_query($adminQuery, '', '&', PHP_QUERY_RFC3986);
                        ?>
                        <li>
                            <a href="<?= e($adminHref) ?>" hreflang="<?= e($adminLocale) ?>"
                               class="flex items-center justify-between rounded-lg px-3 py-2 text-xs font-semibold uppercase tracking-wide no-underline <?= $adminLocale === $locale ? 'bg-mint text-teal-dark' : 'text-ink-soft hover:bg-paper' ?>"
                               <?= $adminLocale === $locale ? 'aria-current="true"' : '' ?>>
                                <?= e(strtoupper($adminLocale)) ?>
                                <?php if ($adminLocale === $locale): ?><i data-lucide="check" class="h-3.5 w-3.5"></i><?php endif; ?>
                            </a>
                        </li>
                        <?php endforeach; ?>
                    </ul>
                </div>
            </div>
        </div>

        <?php if (!empty($adminUser) && count($adminContexts) > 1): ?>
        <div class="border-t border-line px-4 py-2 sm:hidden">
            <form method="post" action="/admin/context" class="flex items-center gap-2">
                <label for="admin-context-mobile" class="sr-only"><?= e($t('admin.context.label')) ?></label>
                <select id="admin-context-mobile" name="organization_id" onchange="this.form.submit()" class="ui-input py-1.5 text-xs">
                    <?php foreach ($adminContexts as $context): ?>
                        <option value="<?= $context['id'] === null ? '' : (int) $context['id'] ?>"
                            <?= $context['id'] === $adminActiveOrg ? 'selected' : '' ?>>
                            <?= e((string) $context['name']) ?>
                        </option>
                    <?php endforeach; ?>
                </select>
                <input type="hidden" name="next" value="<?= e($adminNext) ?>">
                <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e(Csrf::token()) ?>">
                <button type="submit" class="ui-btn ui-btn-sm ui-btn-ghost"><?= e($t('admin.context.switch')) ?></button>
            </form>
        </div>
        <?php endif; ?>
    </header>

    <main id="main" class="mx-auto max-w-[1400px] px-4 py-8 sm:px-6 lg:px-8">
        <?= $content ?>
    </main>

    <footer class="border-t border-line px-4 py-6 text-center text-xs text-muted sm:px-6">
        Origen Salud — <?= e($t('admin.footer')) ?>
    </footer>
</div>

<script defer src="<?= e($adminAsset('/assets/js/flowbite.min.js')) ?>"></script>
<script defer src="<?= e($adminAsset('/assets/js/alpine.min.js')) ?>"></script>
<script defer src="<?= e($adminAsset('/assets/js/lucide.min.js')) ?>"></script>
<script>
    document.addEventListener('DOMContentLoaded', function () {
        if (window.lucide && typeof window.lucide.createIcons === 'function') {
            window.lucide.createIcons();
        }
    });
</script>
</body>
</html>
