<?php

declare(strict_types=1);

use OrigenSalud\CustomerPortal\I18n\CustomerI18n;
use OrigenSalud\CustomerPortal\Services\AccessControl;
use OrigenSalud\CustomerPortal\Services\CustomerSession;

/**
 * @var string $title
 * @var string $locale
 * @var string $baseUrl
 * @var string $content
 * @var callable $t
 * @var array<string, mixed>|null $flash
 */

$assetRoot = dirname(__DIR__, 3) . '/web';
$assetSrc = $assetRoot . '/assets/css/public.css';
$assetHref = '/assets/css/public.css';
if (is_file($assetSrc)) {
    $assetHref .= '?v=' . @filemtime($assetSrc);
}

$rawPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
$rawPath = is_string($rawPath) && $rawPath !== '' ? $rawPath : '/portal-clientes/';
$basePath = preg_replace('#^/portal-clientes/(?:es-AR|en|pt-BR)(?:/|$)#', '/portal-clientes/', $rawPath);
$basePath = is_string($basePath) && $basePath !== '' ? $basePath : '/portal-clientes/';
$suffix = str_starts_with($basePath, '/portal-clientes')
    ? substr($basePath, strlen('/portal-clientes'))
    : $basePath;

$isAuthenticated = CustomerSession::get('customer_user_id') !== null;
$canCredentials = $isAuthenticated && AccessControl::can('credential.read');
$home = $baseUrl . '/' . $locale . '/';

$flags = [
    'es-AR' => '<svg viewBox="0 0 24 24" aria-hidden="true"><rect width="24" height="24" fill="#74acdf"/><rect y="8" width="24" height="8" fill="#fff"/><circle cx="12" cy="12" r="2" fill="#f6b40e"/></svg>',
    'en' => '<svg viewBox="0 0 24 24" aria-hidden="true"><rect width="24" height="24" fill="#012169"/><path d="M0 0 24 24M24 0 0 24" stroke="#fff" stroke-width="4"/><path d="M0 0 24 24M24 0 0 24" stroke="#c8102e" stroke-width="2"/><path d="M12 0v24M0 12h24" stroke="#fff" stroke-width="6"/><path d="M12 0v24M0 12h24" stroke="#c8102e" stroke-width="3.5"/></svg>',
    'pt-BR' => '<svg viewBox="0 0 24 24" aria-hidden="true"><rect width="24" height="24" fill="#009c3b"/><path d="M12 3 21 12 12 21 3 12Z" fill="#ffdf00"/><circle cx="12" cy="12" r="4.2" fill="#002776"/></svg>',
];

$navItems = [
    ['href' => $home, 'key' => 'customer.nav.home', 'icon' => '<path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/>'],
    ['href' => $baseUrl . '/' . $locale . '/servicios', 'key' => 'customer.nav.services', 'icon' => '<path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z"/>'],
    ['href' => $baseUrl . '/' . $locale . '/organizations', 'key' => 'customer.nav.organizations', 'icon' => '<path d="M4 21V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v16M8 7h2M8 11h2M8 15h2M16 9h2a2 2 0 0 1 2 2v10"/>'],
    ['href' => $baseUrl . '/' . $locale . '/members', 'key' => 'customer.nav.members', 'icon' => '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>'],
    ['href' => $baseUrl . '/' . $locale . '/credentials', 'key' => 'customer.nav.credentials', 'icon' => '<circle cx="8" cy="15" r="4"/><path d="M11 12V5a3 3 0 0 1 6 0v3M17 8h3v3h-3"/>'],
];
if (!$canCredentials) {
    $navItems = array_values(array_filter(
        $navItems,
        static fn (array $item): bool => $item['key'] !== 'customer.nav.credentials'
    ));
}
?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title><?= e($title) ?></title>
    <link rel="stylesheet" href="<?= e($assetHref) ?>">
</head>
<body class="min-h-screen bg-paper text-ink antialiased">
<a class="skip-link" href="#main"><?= e($t('customer.a11y.skip')) ?></a>

<header class="sticky top-0 z-40 border-b border-line/80 bg-white/85 backdrop-blur-xl">
    <div class="mx-auto flex h-16 w-full max-w-[1500px] items-center gap-3 px-4 sm:px-6 lg:gap-6">
        <a class="group flex shrink-0 items-center gap-2.5 focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
           href="<?= e($home) ?>" aria-label="Origen Salud">
            <span class="flex size-9 items-center justify-center rounded-xl bg-teal text-white shadow-card transition group-hover:bg-teal-dark">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" aria-hidden="true" focusable="false">
                    <path d="M12 5v14M5 12h14"/>
                </svg>
            </span>
            <span class="text-[15px] font-semibold tracking-tight text-ink">Origen<span class="text-teal">Salud</span></span>
        </a>

        <?php if ($isAuthenticated): ?>
            <nav class="hidden flex-1 lg:flex lg:items-center lg:justify-center"
                 aria-label="<?= e($t('customer.nav.label')) ?>">
                <div class="flex items-center gap-0.5 rounded-full border border-line bg-paper/70 p-1">
                    <?php foreach ($navItems as $item): ?>
                        <a class="inline-flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-semibold text-ink-soft transition hover:bg-white hover:text-teal-dark focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
                           href="<?= e($item['href']) ?>">
                            <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><?= $item['icon'] ?></svg>
                            <?= e($t($item['key'])) ?>
                        </a>
                    <?php endforeach; ?>
                </div>
            </nav>
        <?php endif; ?>

        <div class="ms-auto flex items-center gap-2 sm:gap-3">
            <div class="inline-flex shrink-0 items-center gap-0.5 rounded-full border border-line bg-paper/80 p-0.5"
                 role="group" aria-label="<?= e($t('customer.lang.label')) ?>">
                <?php foreach (CustomerI18n::supported() as $supported): ?>
                    <?php $flag = $flags[$supported] ?? ''; ?>
                    <a class="inline-flex items-center gap-1.5 rounded-full px-2 py-1 text-[10px] font-bold tracking-wide transition focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 <?= $supported === $locale ? 'bg-ink text-white' : 'text-muted hover:bg-white hover:text-teal-dark' ?>"
                       href="/portal-clientes/<?= e((string) $supported) . e($suffix) ?>"
                       hreflang="<?= e((string) $supported) ?>" lang="<?= e((string) $supported) ?>"
                       title="<?= e(strtoupper((string) $supported)) ?>"
                       <?= $supported === $locale ? 'aria-current="true"' : '' ?>>
                        <?php if ($flag !== ''): ?>
                            <span class="size-4 shrink-0 overflow-hidden rounded-full ring-1 ring-black/10 [&>svg]:size-4 [&>svg]:block"><?= $flag ?></span>
                        <?php endif; ?>
                        <?= e(strtoupper((string) $supported)) ?>
                    </a>
                <?php endforeach; ?>
            </div>

            <?php if ($isAuthenticated): ?>
                <form method="post" action="<?= e($baseUrl . '/' . $locale . '/logout') ?>" class="hidden sm:block">
                    <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                    <button class="btn-secondary !mt-0 !py-1.5" type="submit">
                        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                            <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>
                        </svg>
                        <?= e($t('customer.nav.logout')) ?>
                    </button>
                </form>
            <?php else: ?>
                <a class="btn-primary !mt-0 !py-1.5 hidden sm:inline-flex"
                   href="<?= e($baseUrl . '/' . $locale . '/login') ?>"><?= e($t('customer.nav.login')) ?></a>
            <?php endif; ?>

            <?php if ($isAuthenticated): ?>
                <details class="relative lg:hidden">
                    <summary class="flex size-10 cursor-pointer list-none items-center justify-center rounded-xl border border-line bg-white text-ink shadow-card transition hover:border-teal/40 hover:text-teal focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 [&::-webkit-details-marker]:hidden">
                        <span class="sr-only"><?= e($t('customer.nav.label')) ?></span>
                        <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                            <path d="M4 7h16M4 12h16M4 17h16"/>
                        </svg>
                    </summary>
                    <div class="absolute end-0 top-12 w-[min(20rem,calc(100vw-2rem))] rounded-2xl border border-line bg-white p-2 shadow-panel">
                        <nav class="flex flex-col" aria-label="<?= e($t('customer.nav.label')) ?>">
                            <?php foreach ($navItems as $item): ?>
                                <a class="inline-flex items-center gap-2 rounded-xl px-3 py-2 text-sm font-semibold text-ink-soft transition hover:bg-mint hover:text-teal-dark"
                                   href="<?= e($item['href']) ?>">
                                    <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><?= $item['icon'] ?></svg>
                                    <?= e($t($item['key'])) ?>
                                </a>
                            <?php endforeach; ?>
                        </nav>
                        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/logout') ?>" class="mt-2 border-t border-line pt-2">
                            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                            <button class="btn-secondary w-full !mt-0" type="submit"><?= e($t('customer.nav.logout')) ?></button>
                        </form>
                    </div>
                </details>
            <?php endif; ?>
        </div>
    </div>
</header>

<main id="main" class="mx-auto w-full max-w-[1500px] px-4 py-8 sm:px-6 lg:px-8">
    <?php if (is_array($flash) && isset($flash['key']) && is_string($flash['key'])): ?>
        <div class="mb-6 flex items-start gap-3 rounded-xl border border-teal/20 bg-mint px-4 py-3 text-sm text-teal-dark shadow-card" role="status">
            <svg class="mt-0.5 size-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                <circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>
            </svg>
            <span><?= e($t($flash['key'], is_array($flash['params'] ?? null) ? $flash['params'] : [])) ?></span>
        </div>
    <?php endif; ?>

    <?= $content ?>
</main>

<footer class="border-t border-line bg-ink text-white/80">
    <div class="mx-auto flex w-full max-w-[1500px] flex-col gap-3 px-4 py-6 text-xs sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div class="flex flex-wrap items-center gap-4">
            <a class="transition hover:text-white" href="<?= e($home) ?>"><?= e($t('customer.nav.home')) ?></a>
            <a class="transition hover:text-white" href="<?= e($baseUrl . '/' . $locale . '/servicios') ?>"><?= e($t('customer.nav.services')) ?></a>
            <?php if ($canCredentials): ?>
                <a class="transition hover:text-white" href="<?= e($baseUrl . '/' . $locale . '/credentials') ?>"><?= e($t('customer.nav.credentials')) ?></a>
            <?php endif; ?>
            <a class="transition hover:text-white" href="/<?= e($locale) ?>/"><?= e($t('customer.footer.public_site')) ?></a>
        </div>
        <span><?= e($t('customer.footer.note')) ?></span>
    </div>
</footer>
</body>
</html>
