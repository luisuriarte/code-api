<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$domainUrl = static function (string $domain) use ($locale, $browseUrl): string {
    return $browseUrl . '?domain=' . rawurlencode($domain);
};

$ecosystem = [
    ['label' => $t('oftar.ecosystem_snomed'), 'href' => $domainUrl('snomed')],
    ['label' => $t('oftar.ecosystem_cie10'), 'href' => $domainUrl('cie10')],
    ['label' => $t('oftar.ecosystem_loinc'), 'href' => $domainUrl('loinc')],
    ['label' => $t('oftar.ecosystem_anmat'), 'href' => $domainUrl('anmat')],
    ['label' => $t('oftar.ecosystem_nomencladores'), 'href' => $domainUrl('nomenclador')],
    ['label' => $t('oftar.ecosystem_prestaciones'), 'href' => $domainUrl('prestaciones')],
];
?>
<section class="dentar-hero">
    <div class="container dentar-hero-grid">
        <div class="dentar-hero-copy">
            <div class="dentar-hero-brand">
                <picture class="dentar-brand-mark">
                    <img src="/assets/logos/oftar-logo0.png" width="794" height="544" alt="OFTAR">
                </picture>
                <span class="dentar-eyebrow"><?= e($t('oftar.hero_eyebrow')) ?></span>
            </div>
            <h1><?= e($t('oftar.hero_title')) ?></h1>
            <p class="dentar-subtitle"><?= e($t('oftar.hero_subtitle')) ?></p>
            <p class="dentar-lead"><?= e($t('oftar.hero_lead')) ?></p>
            <div class="dentar-actions">
                <a class="button" href="<?= e($browsePrUrl) ?>"><?= e($t('oftar.hero_primary')) ?></a>
                <a class="button button-ghost" href="<?= e($browseDxUrl) ?>"><?= e($t('oftar.hero_secondary')) ?></a>
                <a class="dentar-text-link" href="<?= e($docsUrl) ?>"><?= e($t('oftar.hero_docs')) ?> →</a>
            </div>
            <p class="dentar-hero-note"><?= e($t('oftar.hero_note')) ?></p>
        </div>

        <aside class="dentar-identity" aria-label="<?= e($t('oftar.hero_card_title')) ?>">
            <div class="dentar-identity-art">
                <picture class="dentar-logo-lockup">
                    <img src="/assets/logos/oftar-logo1.png" width="2158" height="533" alt="OFTAR">
                </picture>
            </div>
            <div class="dentar-identity-body">
                <strong><?= e($t('oftar.hero_card_title')) ?></strong>
                <span><?= e($t('oftar.hero_card_label')) ?></span>
                <ul>
                    <li><?= e($t('oftar.hero_card_pr')) ?></li>
                    <li><?= e($t('oftar.hero_card_dx')) ?></li>
                </ul>
                <p><?= e($t('oftar.hero_card_foot')) ?></p>
            </div>
        </aside>
    </div>
</section>

<section class="section" id="proyecto">
    <div class="container dentar-two-col">
        <div>
            <span class="eyebrow"><?= e($t('oftar.problem_eyebrow')) ?></span>
            <h2><?= e($t('oftar.problem_title')) ?></h2>
            <p class="lead"><?= e($t('oftar.problem_lead')) ?></p>
        </div>
        <div>
            <ol class="dentar-problems">
                <li><strong><?= e($t('oftar.problem_1_title')) ?></strong><p><?= e($t('oftar.problem_1_text')) ?></p></li>
                <li><strong><?= e($t('oftar.problem_2_title')) ?></strong><p><?= e($t('oftar.problem_2_text')) ?></p></li>
                <li><strong><?= e($t('oftar.problem_3_title')) ?></strong><p><?= e($t('oftar.problem_3_text')) ?></p></li>
                <li><strong><?= e($t('oftar.problem_4_title')) ?></strong><p><?= e($t('oftar.problem_4_text')) ?></p></li>
                <li><strong><?= e($t('oftar.problem_5_title')) ?></strong><p><?= e($t('oftar.problem_5_text')) ?></p></li>
                <li><strong><?= e($t('oftar.problem_6_title')) ?></strong><p><?= e($t('oftar.problem_6_text')) ?></p></li>
            </ol>
        </div>
    </div>
</section>

<section class="section section-alt" id="catalogos">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('oftar.catalogs_eyebrow')) ?></span>
            <h2><?= e($t('oftar.catalogs_title')) ?></h2>
            <p><?= e($t('oftar.catalogs_lead')) ?></p>
        </div>

        <div class="dentar-catalog-grid">
            <article class="dentar-catalog-card dentar-catalog-pr">
                <span class="dentar-badge"><?= e($t('oftar.pr_badge')) ?></span>
                <h3><?= e($t('oftar.pr_title')) ?></h3>
                <p><?= e($t('oftar.pr_text')) ?></p>
                <p class="dentar-prefix code-pill"><?= e($t('oftar.pr_prefix')) ?></p>
                <h4><?= e($t('oftar.fields_label')) ?></h4>
                <ul class="dentar-fields">
                    <li><?= e($t('oftar.field_code')) ?></li>
                    <li><?= e($t('oftar.field_status')) ?></li>
                    <li><?= e($t('oftar.field_term')) ?></li>
                    <li><?= e($t('oftar.field_category')) ?></li>
                    <li><?= e($t('oftar.field_laterality')) ?></li>
                    <li><?= e($t('oftar.field_language')) ?></li>
                    <li><?= e($t('oftar.field_criteria')) ?></li>
                    <li><?= e($t('oftar.field_uvr')) ?></li>
                    <li><?= e($t('oftar.field_source')) ?></li>
                    <li><?= e($t('oftar.field_validity')) ?></li>
                </ul>
                <a class="button button-small" href="<?= e($browsePrUrl) ?>"><?= e($t('oftar.pr_action')) ?></a>
            </article>

            <article class="dentar-catalog-card dentar-catalog-dx">
                <span class="dentar-badge"><?= e($t('oftar.dx_badge')) ?></span>
                <h3><?= e($t('oftar.dx_title')) ?></h3>
                <p><?= e($t('oftar.dx_text')) ?></p>
                <p class="dentar-prefix code-pill"><?= e($t('oftar.dx_prefix')) ?></p>
                <h4><?= e($t('oftar.fields_label')) ?></h4>
                <ul class="dentar-fields">
                    <li><?= e($t('oftar.field_code')) ?></li>
                    <li><?= e($t('oftar.field_status')) ?></li>
                    <li><?= e($t('oftar.field_term')) ?></li>
                    <li><?= e($t('oftar.field_category')) ?></li>
                    <li><?= e($t('oftar.field_language')) ?></li>
                    <li><?= e($t('oftar.field_criteria')) ?></li>
                    <li><?= e($t('oftar.field_source')) ?></li>
                    <li><?= e($t('oftar.field_validity')) ?></li>
                    <li><?= e($t('oftar.no_uvr')) ?></li>
                </ul>
                <a class="button button-small" href="<?= e($browseDxUrl) ?>"><?= e($t('oftar.dx_action')) ?></a>
            </article>
        </div>

        <p class="form-note"><?= e($t('oftar.catalogs_note')) ?></p>
    </div>
</section>

<section class="section" id="consulta">
    <div class="container dentar-two-col dentar-search-layout">
        <div>
            <span class="eyebrow"><?= e($t('oftar.search_eyebrow')) ?></span>
            <h2><?= e($t('oftar.search_title')) ?></h2>
            <p><?= e($t('oftar.search_lead')) ?></p>
            <a class="dentar-text-link" href="<?= e($browseUrl) ?>"><?= e($t('oftar.search_all_link')) ?> →</a>
        </div>
        <form class="dentar-search-form" method="get" action="<?= e($browseUrl) ?>">
            <input type="hidden" name="domain" value="oftar">
            <div class="field">
                <label for="oftar-q"><?= e($t('oftar.search_label')) ?></label>
                <input id="oftar-q" name="q" type="search" maxlength="200"
                       placeholder="<?= e($t('oftar.search_placeholder')) ?>">
            </div>
            <div class="field">
                <label for="oftar-catalog"><?= e($t('oftar.search_catalog_label')) ?></label>
                <select id="oftar-catalog" name="catalog">
                    <option value="oftar-pr"><?= e($t('oftar.search_option_pr')) ?></option>
                    <option value="oftar-dx"><?= e($t('oftar.search_option_dx')) ?></option>
                </select>
            </div>
            <button class="button" type="submit"><?= e($t('oftar.search_button')) ?></button>
        </form>
    </div>
</section>

<section class="section section-alt" id="fichas">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('oftar.detail_eyebrow')) ?></span>
            <h2><?= e($t('oftar.detail_title')) ?></h2>
            <p><?= e($t('oftar.detail_lead')) ?></p>
        </div>
        <div class="dentar-detail-grid">
            <article class="dentar-detail-card">
                <h3><?= e($t('oftar.detail_pr_title')) ?></h3>
                <p><?= e($t('oftar.detail_pr_text')) ?></p>
            </article>
            <article class="dentar-detail-card">
                <h3><?= e($t('oftar.detail_dx_title')) ?></h3>
                <p><?= e($t('oftar.detail_dx_text')) ?></p>
            </article>
        </div>
        <p class="form-note"><?= e($t('oftar.detail_note')) ?></p>
    </div>
</section>

<section class="section" id="interoperabilidad">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('oftar.interop_eyebrow')) ?></span>
            <h2><?= e($t('oftar.interop_title')) ?></h2>
            <p><?= e($t('oftar.interop_lead')) ?></p>
        </div>

        <div class="dentar-interop-grid">
            <article class="dentar-interop-card">
                <h3><?= e($t('oftar.interop_pr_title')) ?></h3>
                <ul class="dentar-map">
                    <li><span><?= e($t('oftar.system_nomenclature')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('oftar.system_oftar_pr')) ?></strong></li>
                    <li><span><?= e($t('oftar.system_snomed')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('oftar.system_oftar_pr')) ?></strong></li>
                </ul>
            </article>
            <article class="dentar-interop-card">
                <h3><?= e($t('oftar.interop_dx_title')) ?></h3>
                <ul class="dentar-map">
                    <li><span><?= e($t('oftar.system_cie10')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('oftar.system_oftar_dx')) ?></strong></li>
                    <li><span><?= e($t('oftar.system_snomed')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('oftar.system_oftar_dx')) ?></strong></li>
                </ul>
            </article>
        </div>

        <div class="dentar-legend" aria-label="<?= e($t('oftar.interop_legend_title')) ?>">
            <h3><?= e($t('oftar.interop_legend_title')) ?></h3>
            <ul>
                <li><span class="dentar-chip dentar-chip-internal"><?= e($t('oftar.interop_internal')) ?></span></li>
                <li><span class="dentar-chip dentar-chip-external"><?= e($t('oftar.interop_external')) ?></span></li>
                <li><span class="dentar-chip dentar-chip-pending"><?= e($t('oftar.interop_pending')) ?></span></li>
            </ul>
            <p><?= e($t('oftar.interop_note')) ?></p>
        </div>
    </div>
</section>

<section class="section section-alt" id="valoracion">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('oftar.value_eyebrow')) ?></span>
            <h2><?= e($t('oftar.value_title')) ?></h2>
            <p><?= e($t('oftar.value_lead')) ?></p>
        </div>
        <div class="dentar-cards-three">
            <article class="dentar-info-card">
                <h3><?= e($t('oftar.value_work_title')) ?></h3>
                <p><?= e($t('oftar.value_work_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('oftar.value_total_title')) ?></h3>
                <p><?= e($t('oftar.value_total_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('oftar.value_amount_title')) ?></h3>
                <p><?= e($t('oftar.value_amount_text')) ?></p>
            </article>
        </div>
        <p class="form-note"><?= e($t('oftar.value_note')) ?></p>
    </div>
</section>

<section class="section" id="ecosistema">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('oftar.ecosystem_eyebrow')) ?></span>
            <h2><?= e($t('oftar.ecosystem_title')) ?></h2>
            <p><?= e($t('oftar.ecosystem_lead')) ?></p>
        </div>
        <ul class="dentar-ecosystem">
            <?php foreach ($ecosystem as $entry): ?>
                <li><a href="<?= e($entry['href']) ?>"><?= e($entry['label']) ?></a></li>
            <?php endforeach; ?>
        </ul>
    </div>
</section>

<section class="section section-alt" id="evolucion">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('oftar.roadmap_eyebrow')) ?></span>
            <h2><?= e($t('oftar.roadmap_title')) ?></h2>
            <p><?= e($t('oftar.roadmap_lead')) ?></p>
        </div>
        <ol class="principles dentar-roadmap">
            <li><strong><?= e($t('oftar.roadmap_1_title')) ?></strong><p><?= e($t('oftar.roadmap_1_text')) ?></p></li>
            <li><strong><?= e($t('oftar.roadmap_2_title')) ?></strong><p><?= e($t('oftar.roadmap_2_text')) ?></p></li>
            <li><strong><?= e($t('oftar.roadmap_3_title')) ?></strong><p><?= e($t('oftar.roadmap_3_text')) ?></p></li>
        </ol>
        <p class="form-note"><?= e($t('oftar.roadmap_note')) ?></p>
    </div>
</section>

<section class="cta dentar-cta">
    <div class="container cta-inner">
        <div>
            <h2><?= e($t('oftar.cta_title')) ?></h2>
            <p><?= e($t('oftar.cta_text')) ?></p>
        </div>
        <div class="dentar-cta-actions">
            <a class="button button-light" href="<?= e($browsePrUrl) ?>"><?= e($t('oftar.cta_primary')) ?></a>
            <a class="dentar-text-link" href="<?= e($docsUrl) ?>"><?= e($t('oftar.cta_secondary')) ?> →</a>
            <a class="dentar-text-link" href="<?= e($contactUrl) ?>"><?= e($t('oftar.cta_contact')) ?> →</a>
        </div>
    </div>
</section>
