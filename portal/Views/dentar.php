<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$domainUrl = static function (string $domain) use ($locale, $browseUrl): string {
    return $browseUrl . '?domain=' . rawurlencode($domain);
};

$ecosystem = [
    ['label' => $t('dentar.ecosystem_snomed'), 'href' => $domainUrl('snomed')],
    ['label' => $t('dentar.ecosystem_cie10'), 'href' => $domainUrl('cie10')],
    ['label' => $t('dentar.ecosystem_loinc'), 'href' => $domainUrl('loinc')],
    ['label' => $t('dentar.ecosystem_anmat'), 'href' => $domainUrl('anmat')],
    ['label' => $t('dentar.ecosystem_nomencladores'), 'href' => $domainUrl('nomenclador')],
    ['label' => $t('dentar.ecosystem_odontologia'), 'href' => $domainUrl('odontologia')],
];
?>
<section class="dentar-hero">
    <div class="container dentar-hero-grid">
        <div class="dentar-hero-copy">
            <span class="dentar-eyebrow"><?= e($t('dentar.hero_eyebrow')) ?></span>
            <h1><?= e($t('dentar.hero_title')) ?></h1>
            <p class="dentar-subtitle"><?= e($t('dentar.hero_subtitle')) ?></p>
            <p class="dentar-lead"><?= e($t('dentar.hero_lead')) ?></p>
            <div class="dentar-actions">
                <a class="button" href="<?= e($browsePrUrl) ?>"><?= e($t('dentar.hero_primary')) ?></a>
                <a class="button button-ghost" href="<?= e($browseDxUrl) ?>"><?= e($t('dentar.hero_secondary')) ?></a>
                <a class="dentar-text-link" href="<?= e($docsUrl) ?>"><?= e($t('dentar.hero_docs')) ?> →</a>
            </div>
            <p class="dentar-hero-note"><?= e($t('dentar.hero_note')) ?></p>
        </div>

        <aside class="dentar-identity" aria-label="<?= e($t('dentar.hero_card_title')) ?>">
            <div class="dentar-identity-art" aria-hidden="true">
                <svg viewBox="0 0 220 180" role="presentation" focusable="false">
                    <g class="dentar-grid">
                        <path d="M10 30H210M10 90H210M10 150H210M50 10V170M110 10V170M170 10V170"/>
                    </g>
                    <g class="dentar-links">
                        <path d="M110 88 L48 40M110 88 L172 40M110 88 L48 142M110 88 L172 142"/>
                    </g>
                    <path class="dentar-tooth" d="M110 34c-14-14-38-9-42 12-3 14 3 26 10 40l9 28c3 10 15 10 18 0l6-22 6 22c3 10 15 10 18 0l9-28c7-14 13-26 10-40-4-21-28-26-42-12-2 2-4 2-6 0-2-2-4-2-6 0z"/>
                    <g class="dentar-nodes">
                        <circle cx="48" cy="40" r="6"/><circle cx="172" cy="40" r="6"/>
                        <circle cx="48" cy="142" r="6"/><circle cx="172" cy="142" r="6"/>
                        <circle cx="110" cy="88" r="8"/>
                    </g>
                    <g class="dentar-chips">
                        <rect x="16" y="14" width="64" height="18" rx="9"/>
                        <rect x="140" y="14" width="64" height="18" rx="9"/>
                        <rect x="16" y="148" width="64" height="18" rx="9"/>
                        <rect x="140" y="148" width="64" height="18" rx="9"/>
                    </g>
                </svg>
            </div>
            <div class="dentar-identity-body">
                <strong><?= e($t('dentar.hero_card_title')) ?></strong>
                <span><?= e($t('dentar.hero_card_label')) ?></span>
                <ul>
                    <li><?= e($t('dentar.hero_card_pr')) ?></li>
                    <li><?= e($t('dentar.hero_card_dx')) ?></li>
                </ul>
                <p><?= e($t('dentar.hero_card_foot')) ?></p>
            </div>
        </aside>
    </div>
</section>

<section class="section" id="proyecto">
    <div class="container dentar-two-col">
        <div>
            <span class="eyebrow"><?= e($t('dentar.problem_eyebrow')) ?></span>
            <h2><?= e($t('dentar.problem_title')) ?></h2>
            <p class="lead"><?= e($t('dentar.problem_lead')) ?></p>
        </div>
        <div>
            <ol class="dentar-problems">
                <li><strong><?= e($t('dentar.problem_1_title')) ?></strong><p><?= e($t('dentar.problem_1_text')) ?></p></li>
                <li><strong><?= e($t('dentar.problem_2_title')) ?></strong><p><?= e($t('dentar.problem_2_text')) ?></p></li>
                <li><strong><?= e($t('dentar.problem_3_title')) ?></strong><p><?= e($t('dentar.problem_3_text')) ?></p></li>
                <li><strong><?= e($t('dentar.problem_4_title')) ?></strong><p><?= e($t('dentar.problem_4_text')) ?></p></li>
                <li><strong><?= e($t('dentar.problem_5_title')) ?></strong><p><?= e($t('dentar.problem_5_text')) ?></p></li>
                <li><strong><?= e($t('dentar.problem_6_title')) ?></strong><p><?= e($t('dentar.problem_6_text')) ?></p></li>
            </ol>
        </div>
    </div>
</section>

<section class="section section-alt" id="catalogos">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('dentar.catalogs_eyebrow')) ?></span>
            <h2><?= e($t('dentar.catalogs_title')) ?></h2>
            <p><?= e($t('dentar.catalogs_lead')) ?></p>
        </div>

        <div class="dentar-catalog-grid">
            <article class="dentar-catalog-card dentar-catalog-pr">
                <span class="dentar-badge"><?= e($t('dentar.pr_badge')) ?></span>
                <h3><?= e($t('dentar.pr_title')) ?></h3>
                <p><?= e($t('dentar.pr_text')) ?></p>
                <p class="dentar-prefix code-pill"><?= e($t('dentar.pr_prefix')) ?></p>
                <h4><?= e($t('dentar.fields_label')) ?></h4>
                <ul class="dentar-fields">
                    <li><?= e($t('dentar.field_code')) ?></li>
                    <li><?= e($t('dentar.field_status')) ?></li>
                    <li><?= e($t('dentar.field_short')) ?></li>
                    <li><?= e($t('dentar.field_medium')) ?></li>
                    <li><?= e($t('dentar.field_long')) ?></li>
                    <li><?= e($t('dentar.field_classification')) ?></li>
                    <li><?= e($t('dentar.field_specialty')) ?></li>
                    <li><?= e($t('dentar.field_synonyms')) ?></li>
                    <li><?= e($t('dentar.field_criteria')) ?></li>
                    <li><?= e($t('dentar.field_modifiers')) ?></li>
                    <li><?= e($t('dentar.field_rvu')) ?></li>
                    <li><?= e($t('dentar.field_period')) ?></li>
                    <li><?= e($t('dentar.field_validity')) ?></li>
                    <li><?= e($t('dentar.field_source')) ?></li>
                </ul>
                <a class="button button-small" href="<?= e($browsePrUrl) ?>"><?= e($t('dentar.pr_action')) ?></a>
            </article>

            <article class="dentar-catalog-card dentar-catalog-dx">
                <span class="dentar-badge"><?= e($t('dentar.dx_badge')) ?></span>
                <h3><?= e($t('dentar.dx_title')) ?></h3>
                <p><?= e($t('dentar.dx_text')) ?></p>
                <p class="dentar-prefix code-pill"><?= e($t('dentar.dx_prefix')) ?></p>
                <h4><?= e($t('dentar.fields_label')) ?></h4>
                <ul class="dentar-fields">
                    <li><?= e($t('dentar.field_code')) ?></li>
                    <li><?= e($t('dentar.field_status')) ?></li>
                    <li><?= e($t('dentar.field_description')) ?></li>
                    <li><?= e($t('dentar.field_classification')) ?></li>
                    <li><?= e($t('dentar.field_specialty')) ?></li>
                    <li><?= e($t('dentar.field_synonyms')) ?></li>
                    <li><?= e($t('dentar.field_criteria')) ?></li>
                    <li><?= e($t('dentar.field_cie10')) ?></li>
                    <li><?= e($t('dentar.field_snomed')) ?></li>
                    <li><?= e($t('dentar.field_validity')) ?></li>
                    <li><?= e($t('dentar.field_source')) ?></li>
                    <li><?= e($t('dentar.field_relations')) ?></li>
                </ul>
                <a class="button button-small" href="<?= e($browseDxUrl) ?>"><?= e($t('dentar.dx_action')) ?></a>
            </article>
        </div>

        <p class="form-note"><?= e($t('dentar.catalogs_note')) ?></p>
    </div>
</section>

<section class="section" id="consulta">
    <div class="container dentar-two-col dentar-search-layout">
        <div>
            <span class="eyebrow"><?= e($t('dentar.search_eyebrow')) ?></span>
            <h2><?= e($t('dentar.search_title')) ?></h2>
            <p><?= e($t('dentar.search_lead')) ?></p>
            <a class="dentar-text-link" href="<?= e($browseUrl) ?>"><?= e($t('dentar.search_all_link')) ?> →</a>
        </div>
        <form class="dentar-search-form" method="get" action="<?= e($browseUrl) ?>">
            <input type="hidden" name="domain" value="odontologia">
            <div class="field">
                <label for="dentar-q"><?= e($t('dentar.search_label')) ?></label>
                <input id="dentar-q" name="q" type="search" maxlength="200"
                       placeholder="<?= e($t('dentar.search_placeholder')) ?>">
            </div>
            <div class="field">
                <label for="dentar-catalog"><?= e($t('dentar.search_catalog_label')) ?></label>
                <select id="dentar-catalog" name="catalog">
                    <option value="dentar-pr"><?= e($t('dentar.search_option_pr')) ?></option>
                    <option value="dentar-dx"><?= e($t('dentar.search_option_dx')) ?></option>
                </select>
            </div>
            <button class="button" type="submit"><?= e($t('dentar.search_button')) ?></button>
        </form>
    </div>
</section>

<section class="section section-alt" id="fichas">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('dentar.detail_eyebrow')) ?></span>
            <h2><?= e($t('dentar.detail_title')) ?></h2>
            <p><?= e($t('dentar.detail_lead')) ?></p>
        </div>
        <div class="dentar-detail-grid">
            <article class="dentar-detail-card">
                <h3><?= e($t('dentar.detail_pr_title')) ?></h3>
                <p><?= e($t('dentar.detail_pr_text')) ?></p>
            </article>
            <article class="dentar-detail-card">
                <h3><?= e($t('dentar.detail_dx_title')) ?></h3>
                <p><?= e($t('dentar.detail_dx_text')) ?></p>
            </article>
        </div>
        <p class="form-note"><?= e($t('dentar.detail_note')) ?></p>
    </div>
</section>

<section class="section" id="interoperabilidad">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('dentar.interop_eyebrow')) ?></span>
            <h2><?= e($t('dentar.interop_title')) ?></h2>
            <p><?= e($t('dentar.interop_lead')) ?></p>
        </div>

        <div class="dentar-interop-grid">
            <article class="dentar-interop-card">
                <h3><?= e($t('dentar.interop_pr_title')) ?></h3>
                <ul class="dentar-map">
                    <li><span><?= e($t('dentar.system_nomenclature')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('dentar.system_dentar_pr')) ?></strong></li>
                    <li><span><?= e($t('dentar.system_cdt')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('dentar.system_dentar_pr')) ?></strong></li>
                    <li><span><?= e($t('dentar.system_snomed')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('dentar.system_dentar_pr')) ?></strong></li>
                </ul>
            </article>
            <article class="dentar-interop-card">
                <h3><?= e($t('dentar.interop_dx_title')) ?></h3>
                <ul class="dentar-map">
                    <li><span><?= e($t('dentar.system_cie10')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('dentar.system_dentar_dx')) ?></strong></li>
                    <li><span><?= e($t('dentar.system_snomed')) ?></span><span aria-hidden="true">→</span><strong><?= e($t('dentar.system_dentar_dx')) ?></strong></li>
                </ul>
            </article>
        </div>

        <div class="dentar-legend" aria-label="<?= e($t('dentar.interop_legend_title')) ?>">
            <h3><?= e($t('dentar.interop_legend_title')) ?></h3>
            <ul>
                <li><span class="dentar-chip dentar-chip-internal"><?= e($t('dentar.interop_internal')) ?></span></li>
                <li><span class="dentar-chip dentar-chip-external"><?= e($t('dentar.interop_external')) ?></span></li>
                <li><span class="dentar-chip dentar-chip-exact"><?= e($t('dentar.interop_exact')) ?></span></li>
                <li><span class="dentar-chip dentar-chip-approx"><?= e($t('dentar.interop_approx')) ?></span></li>
                <li><span class="dentar-chip dentar-chip-pending"><?= e($t('dentar.interop_pending')) ?></span></li>
            </ul>
            <p><?= e($t('dentar.interop_note')) ?></p>
        </div>
    </div>
</section>

<section class="section section-alt" id="valoracion">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('dentar.value_eyebrow')) ?></span>
            <h2><?= e($t('dentar.value_title')) ?></h2>
            <p><?= e($t('dentar.value_lead')) ?></p>
        </div>
        <div class="dentar-cards-three">
            <article class="dentar-info-card">
                <h3><?= e($t('dentar.value_rvu_title')) ?></h3>
                <p><?= e($t('dentar.value_rvu_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('dentar.value_fee_title')) ?></h3>
                <p><?= e($t('dentar.value_fee_text')) ?></p>
            </article>
            <article class="dentar-info-card">
                <h3><?= e($t('dentar.value_history_title')) ?></h3>
                <p><?= e($t('dentar.value_history_text')) ?></p>
            </article>
        </div>
        <p class="form-note"><?= e($t('dentar.value_note')) ?></p>
    </div>
</section>

<section class="section" id="ecosistema">
    <div class="container">
        <div class="section-head">
            <span class="eyebrow"><?= e($t('dentar.ecosystem_eyebrow')) ?></span>
            <h2><?= e($t('dentar.ecosystem_title')) ?></h2>
            <p><?= e($t('dentar.ecosystem_lead')) ?></p>
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
            <span class="eyebrow"><?= e($t('dentar.roadmap_eyebrow')) ?></span>
            <h2><?= e($t('dentar.roadmap_title')) ?></h2>
            <p><?= e($t('dentar.roadmap_lead')) ?></p>
        </div>
        <ol class="principles dentar-roadmap">
            <li><strong><?= e($t('dentar.roadmap_1_title')) ?></strong><p><?= e($t('dentar.roadmap_1_text')) ?></p></li>
            <li><strong><?= e($t('dentar.roadmap_2_title')) ?></strong><p><?= e($t('dentar.roadmap_2_text')) ?></p></li>
            <li><strong><?= e($t('dentar.roadmap_3_title')) ?></strong><p><?= e($t('dentar.roadmap_3_text')) ?></p></li>
            <li><strong><?= e($t('dentar.roadmap_4_title')) ?></strong><p><?= e($t('dentar.roadmap_4_text')) ?></p></li>
        </ol>
        <p class="form-note"><?= e($t('dentar.roadmap_note')) ?></p>
    </div>
</section>

<section class="cta dentar-cta">
    <div class="container cta-inner">
        <div>
            <h2><?= e($t('dentar.cta_title')) ?></h2>
            <p><?= e($t('dentar.cta_text')) ?></p>
        </div>
        <div class="dentar-cta-actions">
            <a class="button button-light" href="<?= e($browsePrUrl) ?>"><?= e($t('dentar.cta_primary')) ?></a>
            <a class="dentar-text-link" href="<?= e($docsUrl) ?>"><?= e($t('dentar.cta_secondary')) ?> →</a>
            <a class="dentar-text-link" href="<?= e($contactUrl) ?>"><?= e($t('dentar.cta_contact')) ?> →</a>
        </div>
    </div>
</section>
