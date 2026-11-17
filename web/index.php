<?php

declare(strict_types=1);

/**
 * Origen Salud - Portal institucional (med.origen.ar)
 *
 * Vista principal trilingüe (es-AR / EN / PT-BR). El idioma se resuelve en
 * includes/i18n.php y se persiste en cookie; las traducciones viven en
 * translations/*.yaml.
 */

require_once dirname(__DIR__) . '/bootstrap.php';
require_once __DIR__ . '/includes/i18n.php';

use OrigenSalud\Web\I18n;

$locale = I18n::boot();

header('Content-Type: text/html; charset=UTF-8');
header('Vary: Accept-Language');
header('Content-Language: ' . $locale);

$t = static fn (string $key, array $parameters = []): string => trans($key, $parameters, $locale);

$requestPath = parse_url((string) ($_SERVER['REQUEST_URI'] ?? '/'), PHP_URL_PATH);
$currentPath = is_string($requestPath) && $requestPath !== '' ? $requestPath : '/';
$apiLocale = I18n::metadata($locale)['api_language'];

$baseUrl = rtrim((string) env('WEB_BASE_URL', 'https://med.origen.ar'), '/');

if ($baseUrl === '') {
    $baseUrl = 'https://med.origen.ar';
}

$contactEmail = 'contacto@origen.ar';
$accessMailto = 'mailto:' . $contactEmail . '?subject=' . rawurlencode($t('nav.access_api'));
$contactMailto = 'mailto:' . $contactEmail;
$legalMailto = 'mailto:legal@origen.ar?subject=' . rawurlencode($t('footer.legal'));

$exampleLanguage = $apiLocale === 'en' ? 'en' : 'es';
$exampleFallback = $exampleLanguage !== $apiLocale;
$exampleFallbackReason = $exampleFallback ? 'rf2_dialect_undetermined' : null;

$exampleResponse = [
    'data' => [
        [
            'description_id' => '138875005',
            'concept_id' => '22298006',
            'term' => $t('api.example_term'),
            'language' => $exampleLanguage,
            'term_type' => 'synonym',
            'type_id' => '900000000000013009',
            'score' => 0.9871,
        ],
    ],
    'meta' => [
        'query' => $t('api.example_query'),
        'requested_language' => $apiLocale,
        'effective_language' => $exampleLanguage,
        'language' => $exampleLanguage,
        'limit' => 10,
        'offset' => 0,
        'returned' => 1,
        'has_more' => false,
        'took_ms' => 12.4,
        'fallback_applied' => $exampleFallback,
        'fallback_reason' => $exampleFallbackReason,
        'dialect_determined' => $exampleLanguage === 'en',
        'available_languages' => [
            ['code' => 'es-AR', 'selectable' => true],
            ['code' => 'en', 'selectable' => true],
            ['code' => 'pt-BR', 'selectable' => true],
        ],
        'field_languages' => [
            'term' => [
                'effective_language' => $exampleLanguage,
                'source_language' => $exampleLanguage,
                'provenance' => 'snomed_rf2',
                'approval_state' => 'approved',
                'fallback_applied' => $exampleFallback,
                'fallback_reason' => $exampleFallbackReason,
                'untranslated' => false,
                'dialect_determined' => $exampleLanguage === 'en',
            ],
        ],
    ],
    'request_id' => '7f3c9a1e8b2d4f60',
];

$exampleJson = json_encode(
    $exampleResponse,
    JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
) ?: '{}';

$year = date('Y');
?>
<!doctype html>
<html lang="<?= e($locale) ?>">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><?= e($t('meta.title')) ?></title>
    <meta name="description" content="<?= e($t('meta.description')) ?>">
    <link rel="canonical" href="<?= e($baseUrl . $currentPath) ?>">
    <?php foreach (I18n::alternateLinks($currentPath) as $alternate): ?>
    <link rel="alternate" hreflang="<?= e($alternate['hreflang']) ?>" href="<?= e($baseUrl . $alternate['href']) ?>">
    <?php endforeach; ?>
    <meta property="og:type" content="website">
    <meta property="og:title" content="<?= e($t('meta.title')) ?>">
    <meta property="og:description" content="<?= e($t('meta.description')) ?>">
    <meta property="og:locale" content="<?= e(I18n::metadata($locale)['og_locale']) ?>">
    <link rel="stylesheet" href="assets/css/app.css">
</head>
<body>
<a class="skip-link" href="#main"><?= e($t('a11y.skip')) ?></a>

<header class="site-header">
    <div class="container header-inner">
        <a class="brand" href="/" aria-label="Origen Salud">
            <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                <rect width="40" height="40" rx="12" fill="currentColor"/>
                <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
            </svg>
            <span class="brand-name">Origen<span>Salud</span></span>
        </a>

        <nav class="site-nav" aria-label="<?= e($t('nav.label')) ?>">
            <a href="#plataforma"><?= e($t('nav.platform')) ?></a>
            <a href="#snomed"><?= e($t('nav.snomed')) ?></a>
            <a href="#anmat"><?= e($t('nav.anmat')) ?></a>
            <a href="#api"><?= e($t('nav.api')) ?></a>
            <a href="/search"><?= e($t('nav.search')) ?></a>
            <a href="/docs"><?= e($t('nav.docs')) ?></a>
            <a href="#contacto"><?= e($t('nav.contact')) ?></a>
        </nav>

        <div class="header-actions">
            <?php require __DIR__ . '/includes/language-switcher.php'; ?>
            <a class="button button-small" href="<?= e($accessMailto) ?>"><?= e($t('nav.access')) ?></a>
        </div>
    </div>
</header>

<main id="main">
    <section class="hero">
        <div class="container hero-grid">
            <div class="hero-copy">
                <span class="eyebrow"><?= e($t('hero.badge')) ?></span>
                <h1><?= e($t('hero.title')) ?></h1>
                <p class="lead"><?= e($t('hero.lead')) ?></p>
                <div class="hero-actions">
                    <a class="button" href="#api"><?= e($t('hero.primary')) ?></a>
                    <a class="button button-ghost" href="#plataforma"><?= e($t('hero.secondary')) ?></a>
                </div>
                <p class="hero-note"><?= e($t('hero.note')) ?></p>
            </div>

            <aside class="api-card" aria-label="<?= e($t('hero.card_title')) ?>">
                <div class="api-card-head">
                    <span class="status-dot" aria-hidden="true"></span>
                    <div>
                        <strong><?= e($t('hero.card_title')) ?></strong>
                        <span><?= e($t('hero.card_subtitle')) ?></span>
                    </div>
                    <span class="method">GET</span>
                </div>
                <pre><code><?= e($exampleJson) ?></code></pre>
                <div class="api-card-foot"><?= e($t('hero.card_footer')) ?></div>
            </aside>
        </div>
    </section>

    <section class="stats" aria-label="<?= e($t('stats.label')) ?>">
        <div class="container stats-grid">
            <div class="stat">
                <strong><?= e($t('stats.concepts_value')) ?></strong>
                <span><?= e($t('stats.concepts_label')) ?></span>
            </div>
            <div class="stat">
                <strong><?= e($t('stats.languages_value')) ?></strong>
                <span><?= e($t('stats.languages_label')) ?></span>
            </div>
            <div class="stat">
                <strong><?= e($t('stats.anmat_value')) ?></strong>
                <span><?= e($t('stats.anmat_label')) ?></span>
            </div>
            <div class="stat">
                <strong><?= e($t('stats.latency_value')) ?></strong>
                <span><?= e($t('stats.latency_label')) ?></span>
            </div>
        </div>
    </section>

    <section class="section search-section" id="buscador">
        <div class="container search-intro">
            <div>
                <span class="eyebrow"><?= e($t('api.eyebrow')) ?></span>
                <h2><?= e($t('search.title')) ?></h2>
                <p><?= e($t('search.lead')) ?></p>
            </div>
            <form class="search-form" action="/search" method="get">
                <label for="q"><?= e($t('search.query_label')) ?></label>
                <input id="q" name="q" type="search" required
                       placeholder="<?= e($t('search.query_placeholder')) ?>">
                <input type="hidden" name="lang" value="<?= e($apiLocale) ?>">
                <button class="button" type="submit"><?= e($t('search.button')) ?></button>
            </form>
        </div>
    </section>

    <section class="section" id="plataforma">
        <div class="container">
            <div class="section-head">
                <span class="eyebrow"><?= e($t('services.eyebrow')) ?></span>
                <h2><?= e($t('services.title')) ?></h2>
                <p><?= e($t('services.lead')) ?></p>
            </div>

            <div class="cards">
                <article class="card" id="snomed">
                    <span class="card-icon" aria-hidden="true">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M12 3 2 8l10 5 10-5-10-5Z"/>
                            <path d="m2 12 10 5 10-5"/>
                            <path d="m2 16 10 5 10-5"/>
                        </svg>
                    </span>
                    <h3><?= e($t('services.snomed_title')) ?></h3>
                    <p><?= e($t('services.snomed_text')) ?></p>
                </article>

                <article class="card">
                    <span class="card-icon" aria-hidden="true">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M3 12h4l2-6 4 12 2-6h6"/>
                        </svg>
                    </span>
                    <h3><?= e($t('services.tas_title')) ?></h3>
                    <p><?= e($t('services.tas_text')) ?></p>
                </article>

                <article class="card" id="anmat">
                    <span class="card-icon" aria-hidden="true">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M10.5 20.5 3.5 13.5a5 5 0 0 1 7-7l7 7a5 5 0 0 1-7 7Z"/>
                            <path d="m8.5 8.5 7 7"/>
                        </svg>
                    </span>
                    <h3><?= e($t('services.anmat_title')) ?></h3>
                    <p><?= e($t('services.anmat_text')) ?></p>
                </article>

                <article class="card">
                    <span class="card-icon" aria-hidden="true">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6l-7-3Z"/>
                            <path d="m9 12 2 2 4-4"/>
                        </svg>
                    </span>
                    <h3><?= e($t('services.security_title')) ?></h3>
                    <p><?= e($t('services.security_text')) ?></p>
                </article>
            </div>
        </div>
    </section>

    <section class="section api-section" id="api">
        <div class="container api-grid">
            <div class="api-copy">
                <span class="eyebrow"><?= e($t('api.eyebrow')) ?></span>
                <h2><?= e($t('api.title')) ?></h2>
                <p><?= e($t('api.lead')) ?></p>

                <dl class="api-meta">
                    <div>
                        <dt><?= e($t('api.endpoint_label')) ?></dt>
                        <dd><code>GET /v1/concepts/search</code></dd>
                    </div>
                    <div>
                        <dt><?= e($t('api.auth_label')) ?></dt>
                        <dd><?= e($t('api.auth_text')) ?></dd>
                    </div>
                </dl>

                <a class="button button-light" href="<?= e($accessMailto) ?>"><?= e($t('api.docs')) ?></a>
            </div>

            <div class="code-card">
                <div class="code-head">
                    <span>cURL</span>
                    <span class="code-dots" aria-hidden="true"><i></i><i></i><i></i></span>
                </div>
<pre><code>curl --request GET \
  'https://api.origen.ar/v1/concepts/search?q=<?= e(rawurlencode($t('api.example_query'))) ?>&amp;lang=<?= e($apiLocale) ?>&amp;limit=10' \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Accept-Language: <?= e($apiLocale) ?>'</code></pre>
            </div>
        </div>
    </section>

    <section class="cta" id="contacto">
        <div class="container cta-inner">
            <div>
                <h2><?= e($t('cta.title')) ?></h2>
                <p><?= e($t('cta.text')) ?></p>
            </div>
            <a class="button button-light" href="<?= e($contactMailto) ?>"><?= e($t('cta.button')) ?></a>
        </div>
    </section>
</main>

<footer class="site-footer">
    <div class="container footer-grid">
        <div class="footer-brand">
            <a class="brand" href="/" aria-label="Origen Salud">
                <svg class="brand-mark" viewBox="0 0 40 40" aria-hidden="true" focusable="false">
                    <rect width="40" height="40" rx="12" fill="currentColor"/>
                    <path d="M20 11v18M11 20h18" stroke="#fff" stroke-width="3.2" stroke-linecap="round"/>
                </svg>
                <span class="brand-name">Origen<span>Salud</span></span>
            </a>
            <p><?= e($t('footer.tagline')) ?></p>
        </div>

        <div>
            <h3><?= e($t('footer.product')) ?></h3>
            <ul>
                <li><a href="#api"><?= e($t('footer.product_api')) ?></a></li>
                <li><a href="/docs"><?= e($t('nav.docs')) ?></a></li>
                <li><a href="#snomed"><?= e($t('footer.product_snomed')) ?></a></li>
                <li><a href="#anmat"><?= e($t('footer.product_anmat')) ?></a></li>
            </ul>
        </div>

        <div>
            <h3><?= e($t('footer.company')) ?></h3>
            <ul>
                <li><a href="#plataforma"><?= e($t('footer.company_about')) ?></a></li>
                <li><a href="<?= e($contactMailto) ?>"><?= e($t('footer.company_contact')) ?></a></li>
            </ul>
        </div>

        <div>
            <h3><?= e($t('footer.legal')) ?></h3>
            <ul>
                <li><a href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_terms')) ?></a></li>
                <li><a href="<?= e($legalMailto) ?>"><?= e($t('footer.legal_privacy')) ?></a></li>
            </ul>
        </div>
    </div>

    <div class="container footer-bottom">
        <p><?= e($t('footer.rights', ['%year%' => $year])) ?></p>
        <p class="disclaimer"><?= e($t('footer.disclaimer')) ?></p>
    </div>
</footer>
</body>
</html>
