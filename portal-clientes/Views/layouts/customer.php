<?php
/** @var string $title */
/** @var string $locale */
/** @var string $baseUrl */
/** @var string $content */
/** @var callable $t */
/** @var array<string, mixed>|null $flash */
?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex,nofollow">
    <title><?= e($title) ?></title>
    <style>
        :root { color-scheme: light; font-family: system-ui, -apple-system, Segoe UI, sans-serif; }
        body { margin: 0; color: #16202b; background: #f4f6f8; line-height: 1.5; }
        header, footer { background: #12263a; color: #fff; padding: 1rem 1.5rem; }
        header a, footer a { color: #fff; margin-right: 1rem; }
        main { max-width: 980px; margin: 1.5rem auto; padding: 0 1rem; }
        .card { background: #fff; border: 1px solid #d8dee5; border-radius: 8px; padding: 1.25rem; margin-bottom: 1rem; }
        label { display: block; font-weight: 600; margin-top: .75rem; }
        input, select { width: 100%; max-width: 32rem; padding: .5rem; border: 1px solid #b8c2cc; border-radius: 4px; }
        button { margin-top: 1rem; padding: .55rem 1rem; background: #17629a; color: #fff; border: 0; border-radius: 4px; cursor: pointer; }
        .flash { border-left: 4px solid #17629a; background: #e8f2fa; padding: .75rem 1rem; margin-bottom: 1rem; word-break: break-all; }
        .error { color: #9b1c1c; font-weight: 600; }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: .5rem; border-bottom: 1px solid #e1e6eb; vertical-align: top; }
        code { word-break: break-all; }
        .langs { float: right; }
        .langs a { font-size: .85rem; opacity: .9; }
        @media (max-width: 640px) { header, footer { padding: 1rem; } }
    </style>
</head>
<body>
<header>
    <strong><?= e($t('customer.app.name')) ?></strong>
    <nav class="langs">
        <?php
        $rawPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
        $rawPath = is_string($rawPath) && $rawPath !== '' ? $rawPath : '/portal-clientes/';
        $basePath = preg_replace('#^/portal-clientes/(?:es-AR|en|pt-BR)(?:/|$)#', '/portal-clientes/', $rawPath);
        $basePath = is_string($basePath) && $basePath !== '' ? $basePath : '/portal-clientes/';
        $suffix = str_starts_with($basePath, '/portal-clientes')
            ? substr($basePath, strlen('/portal-clientes'))
            : $basePath;
        foreach (\OrigenSalud\CustomerPortal\I18n\CustomerI18n::supported() as $supported) :
            $href = '/portal-clientes/' . $supported . $suffix;
        ?>
            <a href="<?= e($href) ?>"<?= $supported === $locale ? ' aria-current="page"' : '' ?>><?= e(strtoupper($supported)) ?></a>
        <?php endforeach; ?>
    </nav>
</header>
<main>
    <?php if (is_array($flash) && isset($flash['key']) && is_string($flash['key'])) : ?>
        <div class="flash"><?= e($t($flash['key'], is_array($flash['params'] ?? null) ? $flash['params'] : [])) ?></div>
    <?php endif; ?>

    <?= $content ?>
</main>
<footer>
    <a href="<?= e($baseUrl . '/' . $locale . '/') ?>"><?= e($t('customer.nav.home')) ?></a>
    <span><?= e($t('customer.footer.note')) ?></span>
</footer>
</body>
</html>
