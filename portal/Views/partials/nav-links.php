<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

/**
 * Navegación principal compartida por el portal y las páginas standalone
 * (Docs y UVR). `$activeNav` es opcional y marca el enlace con aria-current.
 */
$navItems = [
    ['key' => 'home', 'label' => $t('nav.home'), 'href' => I18n::localizedPath($locale, '/')],
    ['key' => 'dentar', 'label' => $t('nav.dentar'), 'href' => I18n::localizedPath($locale, '/dentar'), 'class' => 'nav-dentar'],
    ['key' => 'browse', 'label' => $t('nav.browse'), 'href' => I18n::localizedPath($locale, '/browse')],
    ['key' => 'docs', 'label' => $t('nav.docs'), 'href' => I18n::localizedPath($locale, '/docs')],
    ['key' => 'uvr', 'label' => $t('nav.uvr'), 'href' => '/uvr?lang=' . rawurlencode($locale)],
    ['key' => 'services', 'label' => $t('nav.services'), 'href' => I18n::localizedPath($locale, '/') . '#plataforma'],
    ['key' => 'about', 'label' => $t('nav.about'), 'href' => I18n::localizedPath($locale, '/about')],
    ['key' => 'contact', 'label' => $t('nav.contact'), 'href' => I18n::localizedPath($locale, '/contact')],
];

foreach ($navItems as $item):
    $isActive = isset($activeNav) && $activeNav === $item['key'];
    $class = trim(($item['class'] ?? '') . ($isActive ? ' is-active' : ''));
    ?>
    <a class="<?= e($class) ?>" href="<?= e($item['href']) ?>" <?= $isActive ? 'aria-current="page"' : '' ?>><?= e($item['label']) ?></a>
<?php endforeach; ?>
