<?php

declare(strict_types=1);

use OrigenSalud\Web\I18n;

$browseUrl = I18n::localizedPath($locale, '/browse');
$docsUrl = I18n::localizedPath($locale, '/docs');
$contactUrl = I18n::localizedPath($locale, '/contact');

$eyebrow = 'inline-flex items-center gap-2 rounded-full bg-mint px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-teal-dark';
$button = 'inline-flex items-center justify-center rounded-full bg-teal px-5 py-3 text-sm font-semibold text-white shadow-card transition hover:bg-teal-dark focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15';
$buttonGhost = 'inline-flex items-center justify-center rounded-full border border-line bg-white px-5 py-3 text-sm font-semibold text-ink transition hover:border-teal/40 hover:bg-mint hover:text-teal-dark focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15';
?>
<section class="relative overflow-hidden border-b border-line bg-gradient-to-b from-white via-paper to-white">
    <div class="pointer-events-none absolute -end-32 -top-40 size-[32rem] rounded-full bg-mint/70 blur-3xl" aria-hidden="true"></div>
    <div class="pointer-events-none absolute -bottom-48 start-[35%] size-[26rem] rounded-full bg-teal/10 blur-3xl" aria-hidden="true"></div>

    <div class="relative mx-auto grid w-full max-w-[1500px] items-center gap-12 px-4 py-16 sm:px-6 sm:py-20 lg:grid-cols-[minmax(0,1.05fr)_minmax(0,0.95fr)] lg:gap-16 lg:py-28">
        <div class="max-w-2xl">
            <span class="<?= $eyebrow ?>">
                <span class="size-1.5 rounded-full bg-teal" aria-hidden="true"></span>
                <?= e($t('hero.badge')) ?>
            </span>
            <h1 class="mt-6 text-balance text-4xl font-semibold tracking-tight text-ink sm:text-5xl lg:text-[3.6rem] lg:leading-[1.08]">
                <?= e($t('hero.title')) ?>
            </h1>
            <p class="mt-6 max-w-xl text-base leading-relaxed text-muted sm:text-lg">
                <?= e($t('hero.lead')) ?>
            </p>
            <div class="mt-8 flex flex-wrap items-center gap-3">
                <a class="<?= $button ?>" href="<?= e($docsUrl) ?>"><?= e($t('hero.primary')) ?></a>
                <a class="<?= $buttonGhost ?>" href="#plataforma"><?= e($t('hero.secondary')) ?></a>
            </div>
            <p class="mt-5 text-xs leading-relaxed text-muted"><?= e($t('hero.note')) ?></p>
        </div>

        <aside class="overflow-hidden rounded-3xl border border-white/10 bg-[#08182a] shadow-panel"
               aria-label="<?= e($t('hero.card_title')) ?>">
            <div class="flex items-center gap-3 border-b border-white/10 px-5 py-4">
                <span class="relative flex size-2.5" aria-hidden="true">
                    <span class="absolute inline-flex size-full animate-ping rounded-full bg-mint/40"></span>
                    <span class="relative inline-flex size-2.5 rounded-full bg-mint"></span>
                </span>
                <div class="min-w-0">
                    <strong class="block truncate text-sm font-semibold text-white"><?= e($t('hero.card_title')) ?></strong>
                    <span class="block truncate text-xs text-white/60"><?= e($t('hero.card_subtitle')) ?></span>
                </div>
                <span class="ms-auto rounded-full bg-white/10 px-2.5 py-1 font-mono text-[10px] font-bold tracking-wide text-mint">GET</span>
            </div>
            <pre class="overflow-x-auto px-5 py-6 font-mono text-xs leading-relaxed text-white/80 sm:text-sm"><code><?= e($exampleJson) ?></code></pre>
            <div class="border-t border-white/10 bg-white/5 px-5 py-3 text-xs text-white/60">
                <?= e($t('hero.card_footer')) ?>
            </div>
        </aside>
    </div>
</section>

<section aria-label="<?= e($t('stats.label')) ?>" class="border-b border-line bg-white">
    <div class="mx-auto w-full max-w-[1500px] px-4 py-10 sm:px-6 sm:py-12">
        <div class="grid gap-px overflow-hidden rounded-3xl border border-line bg-line shadow-card sm:grid-cols-2 lg:grid-cols-4">
            <div class="bg-white px-6 py-6">
                <strong class="block text-3xl font-semibold tracking-tight text-ink"><?= e($t('stats.concepts_value')) ?></strong>
                <span class="mt-2 block text-xs font-medium uppercase tracking-[0.14em] text-muted"><?= e($t('stats.concepts_label')) ?></span>
            </div>
            <div class="bg-white px-6 py-6">
                <strong class="block text-3xl font-semibold tracking-tight text-ink"><?= e($t('stats.languages_value')) ?></strong>
                <span class="mt-2 block text-xs font-medium uppercase tracking-[0.14em] text-muted"><?= e($t('stats.languages_label')) ?></span>
            </div>
            <div class="bg-white px-6 py-6">
                <strong class="block text-3xl font-semibold tracking-tight text-ink"><?= e($t('stats.anmat_value')) ?></strong>
                <span class="mt-2 block text-xs font-medium uppercase tracking-[0.14em] text-muted"><?= e($t('stats.anmat_label')) ?></span>
            </div>
            <div class="bg-white px-6 py-6">
                <strong class="block text-3xl font-semibold tracking-tight text-ink"><?= e($t('stats.latency_value')) ?></strong>
                <span class="mt-2 block text-xs font-medium uppercase tracking-[0.14em] text-muted"><?= e($t('stats.latency_label')) ?></span>
            </div>
        </div>
    </div>
</section>

<section id="buscador" class="bg-paper py-16 sm:py-20">
    <div class="mx-auto grid w-full max-w-[1500px] items-center gap-10 px-4 sm:px-6 lg:grid-cols-[minmax(0,0.8fr)_minmax(0,1.2fr)] lg:gap-16">
        <div>
            <span class="<?= $eyebrow ?>">
                <span class="size-1.5 rounded-full bg-teal" aria-hidden="true"></span>
                <?= e($t('api.eyebrow')) ?>
            </span>
            <h2 class="mt-5 text-3xl font-semibold tracking-tight text-ink sm:text-4xl"><?= e($t('search.title')) ?></h2>
            <p class="mt-4 text-base leading-relaxed text-muted"><?= e($t('search.lead')) ?></p>
        </div>

        <form class="rounded-3xl border border-line bg-white p-4 shadow-card" action="<?= e($browseUrl) ?>" method="get">
            <label class="text-xs font-semibold uppercase tracking-[0.14em] text-muted" for="q"><?= e($t('search.query_label')) ?></label>
            <div class="mt-3 flex flex-col gap-3 sm:flex-row">
                <input class="h-13 min-w-0 flex-1 rounded-2xl border border-line bg-paper/70 px-4 text-sm text-ink placeholder:text-muted/70 focus:border-teal focus:outline-none focus:ring-4 focus:ring-teal/15"
                       id="q" name="q" type="search" required
                       placeholder="<?= e($t('search.query_placeholder')) ?>">
                <button class="shrink-0 rounded-2xl bg-ink px-6 py-3 text-sm font-semibold text-white transition hover:bg-teal-dark focus:outline-none focus-visible:ring-4 focus-visible:ring-teal/15"
                        type="submit"><?= e($t('search.button')) ?></button>
            </div>
        </form>
    </div>
</section>

<section id="plataforma" class="bg-white py-16 sm:py-24">
    <div class="mx-auto w-full max-w-[1500px] px-4 sm:px-6">
        <div class="max-w-2xl">
            <span class="<?= $eyebrow ?>">
                <span class="size-1.5 rounded-full bg-teal" aria-hidden="true"></span>
                <?= e($t('services.eyebrow')) ?>
            </span>
            <h2 class="mt-5 text-3xl font-semibold tracking-tight text-ink sm:text-4xl"><?= e($t('services.title')) ?></h2>
            <p class="mt-4 text-base leading-relaxed text-muted"><?= e($t('services.lead')) ?></p>
        </div>

        <div class="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <article class="group rounded-3xl border border-line bg-white p-6 shadow-card transition hover:-translate-y-1 hover:border-teal/40 hover:shadow-panel" id="snomed">
                <span class="flex size-11 items-center justify-center rounded-2xl bg-mint text-teal-dark" aria-hidden="true">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 3 2 8l10 5 10-5-10-5Z"/><path d="m2 12 10 5 10-5"/><path d="m2 16 10 5 10-5"/>
                    </svg>
                </span>
                <h3 class="mt-5 text-base font-semibold text-ink"><?= e($t('services.snomed_title')) ?></h3>
                <p class="mt-2 text-sm leading-relaxed text-muted"><?= e($t('services.snomed_text')) ?></p>
            </article>

            <article class="group rounded-3xl border border-line bg-white p-6 shadow-card transition hover:-translate-y-1 hover:border-teal/40 hover:shadow-panel">
                <span class="flex size-11 items-center justify-center rounded-2xl bg-mint text-teal-dark" aria-hidden="true">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M3 12h4l2-6 4 12 2-6h6"/>
                    </svg>
                </span>
                <h3 class="mt-5 text-base font-semibold text-ink"><?= e($t('services.tas_title')) ?></h3>
                <p class="mt-2 text-sm leading-relaxed text-muted"><?= e($t('services.tas_text')) ?></p>
            </article>

            <article class="group rounded-3xl border border-line bg-white p-6 shadow-card transition hover:-translate-y-1 hover:border-teal/40 hover:shadow-panel" id="anmat">
                <span class="flex size-11 items-center justify-center rounded-2xl bg-mint text-teal-dark" aria-hidden="true">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M10.5 20.5 3.5 13.5a5 5 0 0 1 7-7l7 7a5 5 0 0 1-7 7Z"/><path d="m8.5 8.5 7 7"/>
                    </svg>
                </span>
                <h3 class="mt-5 text-base font-semibold text-ink"><?= e($t('services.anmat_title')) ?></h3>
                <p class="mt-2 text-sm leading-relaxed text-muted"><?= e($t('services.anmat_text')) ?></p>
            </article>

            <article class="group rounded-3xl border border-line bg-white p-6 shadow-card transition hover:-translate-y-1 hover:border-teal/40 hover:shadow-panel">
                <span class="flex size-11 items-center justify-center rounded-2xl bg-mint text-teal-dark" aria-hidden="true">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 3 5 6v5c0 4.5 3 8 7 10 4-2 7-5.5 7-10V6l-7-3Z"/><path d="m9 12 2 2 4-4"/>
                    </svg>
                </span>
                <h3 class="mt-5 text-base font-semibold text-ink"><?= e($t('services.security_title')) ?></h3>
                <p class="mt-2 text-sm leading-relaxed text-muted"><?= e($t('services.security_text')) ?></p>
            </article>
        </div>
    </div>
</section>

<section id="api" class="relative overflow-hidden bg-ink py-16 text-white sm:py-24">
    <div class="pointer-events-none absolute -end-40 top-0 size-[30rem] rounded-full bg-teal/25 blur-3xl" aria-hidden="true"></div>
    <div class="pointer-events-none absolute -bottom-52 start-[20%] size-[24rem] rounded-full bg-teal/10 blur-3xl" aria-hidden="true"></div>

    <div class="relative mx-auto grid w-full max-w-[1500px] items-center gap-12 px-4 sm:px-6 lg:grid-cols-[minmax(0,0.9fr)_minmax(0,1.1fr)] lg:gap-16">
        <div>
            <span class="inline-flex items-center gap-2 rounded-full bg-white/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-mint">
                <span class="size-1.5 rounded-full bg-mint" aria-hidden="true"></span>
                <?= e($t('api.eyebrow')) ?>
            </span>
            <h2 class="mt-6 text-balance text-3xl font-semibold tracking-tight sm:text-4xl"><?= e($t('api.title')) ?></h2>
            <p class="mt-5 max-w-xl text-base leading-relaxed text-white/70"><?= e($t('api.lead')) ?></p>

            <dl class="mt-8 grid gap-4">
                <div class="rounded-2xl border border-white/10 bg-white/5 px-5 py-4">
                    <dt class="text-[10px] font-semibold uppercase tracking-[0.16em] text-mint"><?= e($t('api.endpoint_label')) ?></dt>
                    <dd class="mt-2 font-mono text-sm text-white"><code>GET /v1/concepts/search</code></dd>
                </div>
                <div class="rounded-2xl border border-white/10 bg-white/5 px-5 py-4">
                    <dt class="text-[10px] font-semibold uppercase tracking-[0.16em] text-mint"><?= e($t('api.auth_label')) ?></dt>
                    <dd class="mt-2 text-sm text-white/80"><?= e($t('api.auth_text')) ?></dd>
                </div>
            </dl>

            <a class="mt-8 inline-flex items-center justify-center rounded-full bg-mint px-5 py-3 text-sm font-semibold text-teal-dark transition hover:bg-white focus:outline-none focus-visible:ring-4 focus-visible:ring-white/30"
               href="<?= e($accessMailto) ?>"><?= e($t('api.docs')) ?></a>
        </div>

        <div class="overflow-hidden rounded-3xl border border-white/10 bg-[#08182a] shadow-panel">
            <div class="flex items-center justify-between border-b border-white/10 px-5 py-4">
                <span class="font-mono text-xs font-semibold uppercase tracking-[0.16em] text-mint">cURL</span>
                <span class="flex gap-1.5" aria-hidden="true"><i class="size-2.5 rounded-full bg-white/20"></i><i class="size-2.5 rounded-full bg-white/20"></i><i class="size-2.5 rounded-full bg-white/20"></i></span>
            </div>
<pre class="overflow-x-auto px-5 py-6 font-mono text-xs leading-relaxed text-white/80 sm:text-sm"><code>curl --request GET \
  'https://api.origen.ar/v1/concepts/search?q=<?= e(rawurlencode($t('api.example_query'))) ?>&amp;lang=<?= e($apiLocale) ?>&amp;limit=10' \
  --header 'X-API-Key: YOUR_API_KEY' \
  --header 'Accept-Language: <?= e($apiLocale) ?>'</code></pre>
        </div>
    </div>
</section>

<section id="contacto" class="bg-paper py-16 sm:py-20">
    <div class="mx-auto w-full max-w-[1500px] px-4 sm:px-6">
        <div class="flex flex-col items-start gap-8 rounded-3xl bg-teal px-6 py-10 text-white shadow-panel sm:px-10 sm:py-12 lg:flex-row lg:items-center lg:justify-between">
            <div class="max-w-2xl">
                <h2 class="text-3xl font-semibold tracking-tight sm:text-4xl"><?= e($t('cta.title')) ?></h2>
                <p class="mt-4 text-base leading-relaxed text-white/80"><?= e($t('cta.text')) ?></p>
            </div>
            <a class="inline-flex shrink-0 items-center justify-center rounded-full bg-white px-6 py-3 text-sm font-semibold text-teal-dark transition hover:bg-mint focus:outline-none focus-visible:ring-4 focus-visible:ring-white/40"
               href="<?= e($contactUrl) ?>"><?= e($t('cta.button')) ?></a>
        </div>
    </div>
</section>
