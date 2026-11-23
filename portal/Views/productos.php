<?php

declare(strict_types=1);
?>
<section class="dentar-hero">
    <div class="container dentar-hero-grid">
        <div class="dentar-hero-copy">
            <div class="dentar-hero-brand">
                <span class="dentar-eyebrow"><?= e($t('products.hero_eyebrow')) ?></span>
            </div>
            <h1><?= e($t('products.hero_title')) ?></h1>
            <p class="dentar-subtitle"><?= e($t('products.hero_subtitle')) ?></p>
            <p class="dentar-lead"><?= e($t('products.hero_lead')) ?></p>
            <div class="dentar-actions">
                <a class="button" href="<?= e($dentarUrl) ?>"><?= e($t('products.hero_primary')) ?></a>
                <a class="button button-ghost" href="<?= e($oftarUrl) ?>"><?= e($t('products.hero_secondary')) ?></a>
                <a class="dentar-text-link" href="<?= e($browseUrl) ?>"><?= e($t('nav.browse')) ?> →</a>
            </div>
            <p class="dentar-hero-note"><?= e($t('products.hero_note')) ?></p>
        </div>

        <aside class="dentar-identity" aria-label="<?= e($t('products.hero_card_title')) ?>">
            <div class="dentar-identity-art">
                <picture class="dentar-logo-lockup">
                    <img src="/assets/logos/dentar-logo0.png" width="1108" height="274" alt="DENTAR">
                </picture>
                <picture class="dentar-logo-lockup">
                    <img src="/assets/logos/oftar-logo1.png" width="2158" height="533" alt="OFTAR">
                </picture>
            </div>
            <div class="dentar-identity-body">
                <strong><?= e($t('products.hero_card_title')) ?></strong>
                <span><?= e($t('products.hero_card_label')) ?></span>
                <ul>
                    <li><?= e($t('products.hero_card_dentar')) ?></li>
                    <li><?= e($t('products.hero_card_oftar')) ?></li>
                </ul>
                <p><?= e($t('products.hero_card_foot')) ?></p>
            </div>
        </aside>
    </div>
</section>

<section class="section" id="familias">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('products.families_eyebrow')) ?></span>
            <h2><?= e($t('products.families_title')) ?></h2>
            <p><?= e($t('products.families_lead')) ?></p>
        </div>

        <div class="dentar-catalog-grid">
            <article class="dentar-catalog-card products-family-card">
                <div class="products-family-head">
                    <picture class="products-family-mark">
                        <img src="/assets/logos/dentar-logo1.png" width="360" height="360" alt="DENTAR">
                    </picture>
                    <span class="dentar-badge"><?= e($t('products.dentar_badge')) ?></span>
                </div>
                <h3><?= e($t('products.dentar_title')) ?></h3>
                <p><?= e($t('products.dentar_text')) ?></p>
                <p class="dentar-prefix code-pill"><?= e($t('products.dentar_prefix')) ?></p>
                <h4><?= e($t('products.hero_card_label')) ?></h4>
                <ul class="dentar-fields">
                    <li><?= e($t('products.dentar_catalog_pr')) ?></li>
                    <li><?= e($t('products.dentar_catalog_dx')) ?></li>
                </ul>
                <div class="dentar-actions">
                    <a class="button button-small" href="<?= e($dentarUrl) ?>"><?= e($t('products.dentar_page_action')) ?></a>
                    <a class="dentar-text-link" href="<?= e($browseDentarPrUrl) ?>"><?= e($t('products.dentar_browse_action')) ?> →</a>
                </div>
            </article>

            <article class="dentar-catalog-card products-family-card">
                <div class="products-family-head">
                    <picture class="products-family-mark">
                        <img src="/assets/logos/oftar-logo0.png" width="794" height="544" alt="OFTAR">
                    </picture>
                    <span class="dentar-badge"><?= e($t('products.oftar_badge')) ?></span>
                </div>
                <h3><?= e($t('products.oftar_title')) ?></h3>
                <p><?= e($t('products.oftar_text')) ?></p>
                <p class="dentar-prefix code-pill"><?= e($t('products.oftar_prefix')) ?></p>
                <h4><?= e($t('products.hero_card_label')) ?></h4>
                <ul class="dentar-fields">
                    <li><?= e($t('products.oftar_catalog_pr')) ?></li>
                    <li><?= e($t('products.oftar_catalog_dx')) ?></li>
                </ul>
                <div class="dentar-actions">
                    <a class="button button-small" href="<?= e($oftarUrl) ?>"><?= e($t('products.oftar_page_action')) ?></a>
                    <a class="dentar-text-link" href="<?= e($browseOftarPrUrl) ?>"><?= e($t('products.oftar_browse_action')) ?> →</a>
                </div>
            </article>
        </div>
    </div>
</section>

<section class="section section-alt" id="criterios">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('products.choose_eyebrow')) ?></span>
            <h2><?= e($t('products.choose_title')) ?></h2>
            <p><?= e($t('products.choose_lead')) ?></p>
        </div>
        <div class="dentar-cards-three">
            <article class="dentar-info-card">
                <h3><?= e($t('products.choose_pr_title')) ?></h3>
                <p><?= e($t('products.choose_pr_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('products.choose_dx_title')) ?></h3>
                <p><?= e($t('products.choose_dx_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('products.choose_uvr_title')) ?></h3>
                <p><?= e($t('products.choose_uvr_text')) ?></p>
            </article>
        </div>
    </div>
</section>

<section class="section" id="explorador">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('products.browser_eyebrow')) ?></span>
            <h2><?= e($t('products.browser_title')) ?></h2>
            <p><?= e($t('products.browser_lead')) ?></p>
        </div>
        <div class="dentar-cards-three">
            <article class="dentar-info-card">
                <h3><?= e($t('products.browser_1_title')) ?></h3>
                <p><?= e($t('products.browser_1_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('products.browser_2_title')) ?></h3>
                <p><?= e($t('products.browser_2_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('products.browser_3_title')) ?></h3>
                <p><?= e($t('products.browser_3_text')) ?></p>
            </article>
        </div>
        <div class="dentar-actions">
            <a class="dentar-text-link" href="<?= e($browseDentarPrUrl) ?>">DENTAR-PR →</a>
            <a class="dentar-text-link" href="<?= e($browseDentarDxUrl) ?>">DENTAR-DX →</a>
            <a class="dentar-text-link" href="<?= e($browseOftarPrUrl) ?>">OFTAR-PR →</a>
            <a class="dentar-text-link" href="<?= e($browseOftarDxUrl) ?>">OFTAR-DX →</a>
        </div>
    </div>
</section>

<section class="cta dentar-cta">
    <div class="container cta-inner">
        <div>
            <h2><?= e($t('products.cta_title')) ?></h2>
            <p><?= e($t('products.cta_text')) ?></p>
        </div>
        <div class="dentar-cta-actions">
            <a class="button button-light" href="<?= e($browseUrl) ?>"><?= e($t('products.cta_primary')) ?></a>
            <a class="dentar-text-link" href="<?= e($docsUrl) ?>"><?= e($t('products.cta_secondary')) ?> →</a>
            <a class="dentar-text-link" href="<?= e($contactUrl) ?>"><?= e($t('products.cta_contact')) ?> →</a>
        </div>
    </div>
</section>
