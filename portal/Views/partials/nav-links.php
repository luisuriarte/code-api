<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

/**
 * Navegación principal compartida por el portal y el menú móvil.
 * `$activeNav` es opcional y marca el enlace con aria-current.
 */
$navItems = [
    ['key' => 'home', 'label' => $t('nav.home'), 'href' => I18n::localizedPath($locale, '/')],
    ['key' => 'dentar', 'label' => $t('nav.dentar'), 'href' => I18n::localizedPath($locale, '/dentar'), 'class' => 'nav-dentar'],
    ['key' => 'browse', 'label' => $t('nav.browse'), 'href' => I18n::localizedPath($locale, '/browse')],
    ['key' => 'docs', 'label' => $t('nav.docs'), 'href' => I18n::localizedPath($locale, '/docs')],
    ['key' => 'uvr', 'label' => $t('nav.uvr'), 'href' => '/uvr?lang=' . rawurlencode($locale)],
    ['key' => 'about', 'label' => $t('nav.about'), 'href' => I18n::localizedPath($locale, '/about')],
    ['key' => 'contact', 'label' => $t('nav.contact'), 'href' => I18n::localizedPath($locale, '/contact')],
];

$navBase = 'inline-flex w-full items-center justify-start rounded-xl px-3 py-2 text-sm font-medium text-ink-soft transition '
    . 'hover:bg-mint hover:text-teal-dark focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15 '
    . 'lg:w-auto lg:justify-center lg:rounded-full lg:px-3 lg:py-1.5 lg:text-xs';
$navActive = 'bg-mint text-teal-dark';

foreach ($navItems as $item):
    $isActive = isset($activeNav) && $activeNav === $item['key'];
    $class = trim($navBase . ' ' . ($item['class'] ?? '') . ($isActive ? ' ' . $navActive . ' is-active' : ''));
    ?>
    <a class="<?= e($class) ?>" href="<?= e($item['href']) ?>" <?= $isActive ? 'aria-current="page"' : '' ?>><?= e($item['label']) ?></a>
<?php endforeach; ?>
