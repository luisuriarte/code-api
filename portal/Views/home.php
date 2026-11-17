<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$browseUrl = I18n::localizedPath($locale, '/browse');
$docsUrl = I18n::localizedPath($locale, '/docs');
$cartUrl = I18n::localizedPath($locale, '/cart');
?>
<section class="hero">
    <div class="container hero-grid">
        <div class="hero-copy">
            <span class="eyebrow"><?= e($t('hero.badge')) ?></span>
            <h1><?= e($t('hero.title')) ?></h1>
            <p class="lead"><?= e($t('hero.lead')) ?></p>
            <div class="hero-actions">
                <a class="button" href="<?= e($docsUrl) ?>"><?= e($t('hero.primary')) ?></a>
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
        <form class="search-form" action="<?= e($browseUrl) ?>" method="get">
            <label for="q"><?= e($t('search.query_label')) ?></label>
            <input id="q" name="q" type="search" required
                   placeholder="<?= e($t('search.query_placeholder')) ?>">
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
                        <path d="M12 3 2 8l10 5 10-5-10-5Z"/><path d="m2 12 10 5 10-5"/><path d="m2 16 10 5 10-5"/>
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
                        <path d="M10.5 20.5 3.5 13.5a5 5 0 0 1 7-7l7 7a5 5 0 0 1-7 7Z"/><path d="m8.5 8.5 7 7"/>
                    </svg>
                </span>
                <h3><?= e($t('services.anmat_title')) ?></h3>
                <p><?= e($t('services.anmat_text')) ?></p>
            </article>

            <article class="card">
                <span class="card-icon" aria-hidden="true">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-4"/>
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
        <a class="button button-light" href="<?= e(I18n::localizedPath($locale, '/contact')) ?>"><?= e($t('cta.button')) ?></a>
    </div>
</section>
