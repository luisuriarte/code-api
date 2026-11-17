<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

?>
<section class="section">
    <div class="container narrow">
        <span class="eyebrow"><?= e($t('about.eyebrow')) ?></span>
        <h1><?= e($t('about.title')) ?></h1>
        <p class="lead"><?= e($t('about.lead')) ?></p>
    </div>
</section>

<section class="section section-alt">
    <div class="container">
        <div class="cards">
            <article class="card">
                <h2><?= e($t('about.mission_title')) ?></h2>
                <p><?= e($t('about.mission_text')) ?></p>
            </article>
            <article class="card">
                <h2><?= e($t('about.scope_title')) ?></h2>
                <p><?= e($t('about.scope_text')) ?></p>
            </article>
            <article class="card">
                <h2><?= e($t('about.interoperability_title')) ?></h2>
                <p><?= e($t('about.interoperability_text')) ?></p>
            </article>
            <article class="card">
                <h2><?= e($t('about.catalogs_title')) ?></h2>
                <p><?= e($t('about.catalogs_text')) ?></p>
            </article>
            <article class="card">
                <h2><?= e($t('about.region_title')) ?></h2>
                <p><?= e($t('about.region_text')) ?></p>
            </article>
        </div>
    </div>
</section>

<section class="section">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('about.principles_title')) ?></span>
            <h2><?= e($t('about.principles_title')) ?></h2>
        </div>
        <ol class="principles">
            <li>
                <strong><?= e($t('about.principle_1_title')) ?></strong>
                <p><?= e($t('about.principle_1_text')) ?></p>
            </li>
            <li>
                <strong><?= e($t('about.principle_2_title')) ?></strong>
                <p><?= e($t('about.principle_2_text')) ?></p>
            </li>
            <li>
                <strong><?= e($t('about.principle_3_title')) ?></strong>
                <p><?= e($t('about.principle_3_text')) ?></p>
            </li>
        </ol>
    </div>
</section>

<section class="cta">
    <div class="container cta-inner">
        <div>
            <h2><?= e($t('about.cta_title')) ?></h2>
            <p><?= e($t('about.cta_text')) ?></p>
        </div>
        <div class="hero-actions">
            <a class="button button-light" href="<?= e($browseUrl) ?>"><?= e($t('nav.browse')) ?></a>
            <a class="button button-ghost" href="<?= e($contactUrl) ?>"><?= e($t('nav.contact')) ?></a>
        </div>
    </div>
</section>
