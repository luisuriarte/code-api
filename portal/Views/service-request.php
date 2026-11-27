<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Web\I18n;

/** @var callable $t */
/** @var list<array<string, mixed>> $products */
/** @var array<string, int> $selection */
/** @var bool $catalogAvailable */
/** @var bool $catalogTruncated */
/** @var array<string, string> $form */
/** @var array<string, mixed>|null $flash */
/** @var string $csrfToken */

require __DIR__ . '/partials/format.php';

$value = static fn (string $key): string => isset($form[$key]) && is_string($form[$key]) ? $form[$key] : '';
$byId = [];
foreach ($products as $product) {
    $byId[(string) $product['id']] = $product;
}
$total = 0.0;
$hasPrices = false;
foreach ($selection as $id => $quantity) {
    if (!isset($byId[(string) $id])) {
        continue;
    }
    $price = $byId[(string) $id]['price'];
    if ($price !== null) {
        $total += (float) $price * (int) $quantity;
        $hasPrices = true;
    }
}
$errorKey = is_array($flash) && is_string($flash['error'] ?? null) ? (string) $flash['error'] : '';
$notification = is_array($flash) && is_string($flash['notification'] ?? null)
    ? (string) $flash['notification']
    : '';
$currencies = array_values(array_unique(array_filter(
    array_column($products, 'currency'),
    static fn (mixed $value): bool => is_string($value) && $value !== ''
)));
$currency = count($currencies) === 1 ? (string) $currencies[0] : null;

$eyebrow = 'inline-flex items-center gap-2 rounded-full bg-mint px-3 py-1 text-xs font-semibold uppercase tracking-[0.18em] text-teal-dark';
$card = 'rounded-3xl border border-line bg-white p-5 shadow-card sm:p-6';
$step = 'flex size-9 shrink-0 items-center justify-center rounded-xl bg-teal/10 font-mono text-sm font-bold text-teal';
$labelClass = 'mb-1.5 block text-sm font-semibold text-ink-soft';
?>
<section class="relative overflow-hidden border-b border-line/70 bg-gradient-to-b from-white via-paper to-white">
    <div class="pointer-events-none absolute -end-32 -top-40 size-[32rem] rounded-full bg-mint/70 blur-3xl" aria-hidden="true"></div>
    <div class="pointer-events-none absolute -bottom-48 start-[35%] size-[26rem] rounded-full bg-teal/10 blur-3xl" aria-hidden="true"></div>

    <div class="relative mx-auto w-full max-w-6xl px-4 py-14 sm:px-6 sm:py-20">
        <span class="<?= $eyebrow ?>">
            <span class="size-1.5 rounded-full bg-teal" aria-hidden="true"></span>
            <?= e($t('service_request.eyebrow')) ?>
        </span>
        <h1 class="mt-6 text-balance text-4xl font-semibold tracking-tight text-ink sm:text-5xl"><?= e($t('service_request.title')) ?></h1>
        <p class="mt-5 max-w-3xl text-base leading-relaxed text-muted sm:text-lg"><?= e($t('service_request.lead')) ?></p>
    </div>
</section>

<section class="bg-white py-12 sm:py-16">
    <div class="mx-auto w-full max-w-6xl px-4 sm:px-6">
        <?php if (is_array($flash) && !empty($flash['ok'])): ?>
            <div class="mb-8 flex items-start gap-3 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-4 text-emerald-800 shadow-card" role="status">
                <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-emerald-100" aria-hidden="true">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                        <circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>
                    </svg>
                </span>
                <div>
                    <p class="font-semibold"><?= e($t('service_request.success_title')) ?></p>
                    <p class="text-sm opacity-80"><?= e($t('service_request.success_text')) ?></p>
                    <?php if (is_string($flash['reference'] ?? null) && $flash['reference'] !== ''): ?>
                        <p class="mt-1 text-sm font-mono"><?= e($t('service_request.success_reference')) ?>: <?= e((string) $flash['reference']) ?></p>
                    <?php endif; ?>
                    <?php if ($notification === 'partial' || $notification === 'failed'): ?>
                        <p class="mt-2 text-sm font-medium text-amber-700" role="status">
                            <?= e($t('service_request.notification_' . $notification, [
                                '%reference%' => is_string($flash['reference'] ?? null) ? (string) $flash['reference'] : '',
                            ])) ?>
                        </p>
                    <?php endif; ?>
                </div>
            </div>
        <?php elseif ($errorKey !== ''): ?>
            <?php $message = $t('service_request.error_' . $errorKey); ?>
            <div class="mb-8 flex items-start gap-3 rounded-2xl border border-red-200 bg-red-50 px-4 py-4 text-red-800 shadow-card" role="alert">
                <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-red-100" aria-hidden="true">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                        <circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>
                    </svg>
                </span>
                <div>
                    <p class="font-semibold"><?= e($t('service_request.error_title')) ?></p>
                    <p class="text-sm"><?= e($message === 'service_request.error_' . $errorKey ? $t('service_request.error_text') : $message) ?></p>
                </div>
            </div>
        <?php endif; ?>

        <div class="grid gap-6 lg:grid-cols-[minmax(0,1.45fr)_minmax(320px,1fr)] lg:items-start">
            <section class="<?= $card ?>" aria-labelledby="service-catalog-title">
                <div class="flex flex-wrap items-start justify-between gap-4 border-b border-line pb-5">
                    <div class="flex items-start gap-3">
                        <span class="<?= $step ?>" aria-hidden="true">01</span>
                        <div>
                            <h2 id="service-catalog-title" class="text-lg font-semibold tracking-tight text-ink"><?= e($t('service_request.catalog_title')) ?></h2>
                            <p class="mt-1 text-sm text-muted"><?= e($t('service_request.catalog_hint')) ?></p>
                        </div>
                    </div>
                    <span class="rounded-full bg-mint px-3 py-1 text-xs font-semibold text-teal-dark"><?= e($t('service_request.catalog_source')) ?></span>
                </div>

                <?php if ($catalogTruncated): ?>
                    <p class="mt-4 rounded-2xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800" role="status">
                        <?= e($t('service_request.catalog_limited')) ?>
                    </p>
                <?php endif; ?>

                <?php if (!$catalogAvailable): ?>
                    <div class="mt-5 flex items-start gap-3 rounded-2xl border border-dashed border-line bg-paper p-5">
                        <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-white text-muted shadow-card" aria-hidden="true">
                            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                                <path d="M12 8v5M12 16h.01"/><circle cx="12" cy="12" r="9"/>
                            </svg>
                        </span>
                        <div>
                            <p class="font-semibold text-ink"><?= e($t('service_request.catalog_unavailable_title')) ?></p>
                            <p class="mt-1 text-sm text-muted"><?= e($t('service_request.catalog_unavailable_text')) ?></p>
                        </div>
                    </div>
                <?php else: ?>
                    <div class="mt-5 grid gap-4 sm:grid-cols-2">
                        <?php foreach ($products as $product): ?>
                            <?php $id = (string) $product['id']; ?>
                            <article class="group flex flex-col justify-between gap-5 rounded-2xl border border-line bg-paper p-5 transition duration-200 hover:-translate-y-0.5 hover:border-teal/40 hover:bg-white hover:shadow-card">
                                <div>
                                    <div class="flex items-start justify-between gap-3">
                                        <span class="flex size-10 shrink-0 items-center justify-center rounded-xl bg-teal/10 text-teal transition group-hover:bg-teal group-hover:text-white" aria-hidden="true">
                                            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                                                <rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>
                                            </svg>
                                        </span>
                                        <?php if ($product['price'] === null): ?>
                                            <span class="rounded-full bg-white px-3 py-1 text-xs font-semibold text-ink-soft"><?= e($t('service_request.quote_only')) ?></span>
                                        <?php else: ?>
                                            <span class="rounded-full bg-mint px-3 py-1 text-sm font-semibold text-teal-dark"><?= e($formatNumber($product['price']) . ($currency !== null ? ' ' . $currency : '')) ?></span>
                                        <?php endif; ?>
                                    </div>
                                    <h3 class="mt-4 text-sm font-semibold text-ink"><?= e((string) $product['label']) ?></h3>
                                    <?php if ((string) $product['key'] !== ''): ?>
                                        <p class="mt-1 font-mono text-xs text-muted"><?= e((string) $product['key']) ?></p>
                                    <?php endif; ?>
                                    <p class="mt-3 text-xs font-medium uppercase tracking-[0.12em] text-teal"><?= e($t('service_request.modality_' . (string) $product['modality'])) ?></p>
                                    <?php
                                    $details = [];
                                    $billing = $product['billing'] ?? null;
                                    if ($billing === 'one_time' || $billing === 'recurring') {
                                        $details[] = $t('service_request.billing_' . $billing);
                                    }
                                    foreach (['periodicity', 'tax'] as $field) {
                                        $detailValue = $product[$field] ?? null;
                                        if (is_string($detailValue) && $detailValue !== '') {
                                            $details[] = $detailValue;
                                        }
                                    }
                                    ?>
                                    <?php if ($details !== []): ?>
                                        <p class="mt-2 text-xs leading-relaxed text-muted"><?= e(implode(' · ', $details)) ?></p>
                                    <?php endif; ?>
                                </div>
                                <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/agregar')) ?>" class="flex items-center gap-2 border-t border-line pt-4">
                                    <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                                    <input type="hidden" name="product_id" value="<?= e($id) ?>">
                                    <label class="sr-only" for="qty-<?= e($id) ?>"><?= e($t('service_request.quantity')) ?></label>
                                    <input class="form-field !w-16" id="qty-<?= e($id) ?>" name="quantity" type="number" min="1" max="20" value="1">
                                    <button class="btn-secondary !mt-0" type="submit">
                                        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M12 5v14M5 12h14"/></svg>
                                        <?= e($t('service_request.add')) ?>
                                    </button>
                                </form>
                            </article>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>
            </section>

            <div class="grid gap-6">
                <section class="<?= $card ?>" aria-labelledby="service-selection-title">
                    <div class="flex items-start gap-3 border-b border-line pb-5">
                        <span class="<?= $step ?>" aria-hidden="true">02</span>
                        <h2 id="service-selection-title" class="text-lg font-semibold tracking-tight text-ink"><?= e($t('service_request.selection_title')) ?></h2>
                    </div>

                    <?php if ($selection === []): ?>
                        <div class="mt-5 flex items-start gap-3 rounded-2xl border border-dashed border-line bg-paper p-4">
                            <span class="flex size-9 shrink-0 items-center justify-center rounded-xl bg-white text-muted shadow-card" aria-hidden="true">
                                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                                    <path d="M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01"/>
                                </svg>
                            </span>
                            <p class="text-sm text-muted"><?= e($t('service_request.selection_empty')) ?></p>
                        </div>
                    <?php else: ?>
                        <ul class="mt-5 grid gap-2">
                            <?php foreach ($selection as $id => $quantity): ?>
                                <?php $product = $byId[(string) $id] ?? null; ?>
                                <li class="flex items-center justify-between gap-3 rounded-2xl bg-paper px-3 py-3">
                                    <div class="min-w-0">
                                        <span class="block truncate text-sm font-semibold text-ink"><?= e($product['label'] ?? (string) $id) ?></span>
                                        <span class="mt-0.5 block font-mono text-xs text-muted"><?= e((string) $quantity) ?></span>
                                    </div>
                                    <div class="flex shrink-0 items-center gap-1.5">
                                        <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/restar')) ?>">
                                            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                                            <input type="hidden" name="product_id" value="<?= e((string) $id) ?>">
                                            <button class="btn-secondary !mt-0 !px-3 !py-1.5" type="submit">
                                                <svg class="size-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14"/></svg>
                                                <?= e($t('service_request.remove_one')) ?>
                                            </button>
                                        </form>
                                        <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/quitar')) ?>">
                                            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                                            <input type="hidden" name="product_id" value="<?= e((string) $id) ?>">
                                            <button class="btn-secondary !mt-0 !px-3 !py-1.5" type="submit">
                                                <svg class="size-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M6 6l12 12M18 6 6 18"/></svg>
                                                <?= e($t('service_request.remove')) ?>
                                            </button>
                                        </form>
                                    </div>
                                </li>
                            <?php endforeach; ?>
                        </ul>
                        <?php if ($hasPrices): ?>
                            <div class="mt-5 flex items-center justify-between gap-3 rounded-2xl bg-ink px-4 py-4 shadow-card">
                                <span class="text-sm font-semibold text-white/80"><?= e($t('service_request.total_label')) ?></span>
                                <span class="font-mono text-lg font-semibold text-mint"><?= e($formatNumber($total) . ($currency !== null ? ' ' . $currency : '')) ?></span>
                            </div>
                        <?php endif; ?>
                        <p class="mt-3 text-xs leading-relaxed text-muted"><?= e($t('service_request.total_hint')) ?></p>
                    <?php endif; ?>
                </section>

                <section class="<?= $card ?>" aria-labelledby="service-form-title">
                    <div class="flex items-start gap-3 border-b border-line pb-5">
                        <span class="<?= $step ?>" aria-hidden="true">03</span>
                        <div>
                            <h2 id="service-form-title" class="text-lg font-semibold tracking-tight text-ink"><?= e($t('service_request.form_title')) ?></h2>
                            <p class="mt-1 text-xs text-muted"><?= e($t('service_request.form_hint')) ?></p>
                        </div>
                    </div>

                    <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/enviar')) ?>" class="mt-5 grid gap-4">
                        <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                        <input type="hidden" name="created_at" value="<?= e((string) time()) ?>">
                        <div class="absolute -left-[9999px] size-px overflow-hidden" aria-hidden="true">
                            <label for="request-website"><?= e($t('service_request.website')) ?></label>
                            <input id="request-website" name="website" type="text" tabindex="-1" autocomplete="off">
                        </div>

                        <div>
                            <label class="<?= $labelClass ?>" for="request-organization"><?= e($t('service_request.form_organization')) ?> *</label>
                            <input class="form-field" id="request-organization" name="organization" type="text" required maxlength="160" value="<?= e($value('organization')) ?>" autocomplete="organization">
                        </div>
                        <div>
                            <label class="<?= $labelClass ?>" for="request-contact"><?= e($t('service_request.form_contact')) ?> *</label>
                            <input class="form-field" id="request-contact" name="contact_name" type="text" required maxlength="120" value="<?= e($value('contact_name')) ?>" autocomplete="name">
                        </div>
                        <div>
                            <label class="<?= $labelClass ?>" for="request-email"><?= e($t('service_request.form_email')) ?> *</label>
                            <input class="form-field" id="request-email" name="email" type="email" required maxlength="254" value="<?= e($value('email')) ?>" autocomplete="email">
                        </div>
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div>
                                <label class="<?= $labelClass ?>" for="request-country"><?= e($t('service_request.form_country')) ?></label>
                                <input class="form-field" id="request-country" name="country" type="text" maxlength="100" value="<?= e($value('country')) ?>" autocomplete="country-name">
                            </div>
                            <div>
                                <label class="<?= $labelClass ?>" for="request-tax"><?= e($t('service_request.form_tax_id')) ?></label>
                                <input class="form-field" id="request-tax" name="tax_id" type="text" maxlength="64" value="<?= e($value('tax_id')) ?>">
                            </div>
                        </div>
                        <div>
                            <label class="<?= $labelClass ?>" for="request-note"><?= e($t('service_request.form_notes')) ?></label>
                            <textarea class="form-field min-h-32 resize-y" id="request-note" name="note" rows="5" maxlength="2000" placeholder="<?= e($t('service_request.form_notes_placeholder')) ?>"><?= e($value('note')) ?></textarea>
                        </div>
                        <label class="flex items-start gap-3 rounded-2xl bg-paper p-4 text-sm leading-relaxed text-ink-soft">
                            <input class="mt-0.5 size-4 shrink-0 rounded border-line text-teal focus:ring-teal/20" type="checkbox" name="terms" value="1" required>
                            <span><?= e($t('service_request.form_terms')) ?></span>
                        </label>
                        <p class="text-xs leading-relaxed text-muted">
                            <?= e($t('service_request.privacy_note')) ?>
                            <a class="underline decoration-teal/40 underline-offset-2 hover:text-teal" href="<?= e(I18n::localizedPath($locale, '/terminos')) ?>"><?= e($t('service_request.terms_link_label')) ?></a>
                            ·
                            <a class="underline decoration-teal/40 underline-offset-2 hover:text-teal" href="<?= e(I18n::localizedPath($locale, '/privacidad')) ?>"><?= e($t('service_request.privacy_link_label')) ?></a>
                        </p>
                        <button class="btn-primary justify-self-start" type="submit">
                            <?= e($t('service_request.submit')) ?>
                            <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
                        </button>
                    </form>
                </section>
            </div>
        </div>
    </div>
</section>
