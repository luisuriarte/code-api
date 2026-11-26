<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Web\I18n;

/** @var callable $t */
/** @var list<array{id: string, key: string, label: string, price: ?float, modality: string}> $products */
/** @var array<string, int> $selection */
/** @var bool $catalogAvailable */
/** @var array<string, string> $form */
/** @var array<string, mixed>|null $flash */
/** @var string $csrfToken */

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
?>
<section class="border-b border-line/70 bg-paper">
    <div class="mx-auto w-full max-w-6xl px-4 py-14 sm:px-6 sm:py-20">
        <span class="text-xs font-semibold uppercase tracking-[0.18em] text-teal"><?= e($t('service_request.eyebrow')) ?></span>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight text-ink sm:text-4xl"><?= e($t('service_request.title')) ?></h1>
        <p class="mx-auto mt-4 max-w-3xl text-base leading-relaxed text-ink-soft sm:text-lg"><?= e($t('service_request.lead')) ?></p>
    </div>
</section>

<section class="bg-white py-12 sm:py-16">
    <div class="mx-auto w-full max-w-6xl px-4 sm:px-6">
        <?php if (is_array($flash) && !empty($flash['ok'])): ?>
            <div class="mb-8 flex items-start gap-3 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-4 text-emerald-800" role="status">
                <svg class="mt-0.5 size-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                    <circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>
                </svg>
                <div>
                    <p class="font-semibold"><?= e($t('service_request.success_title')) ?></p>
                    <p class="text-sm"><?= e($t('service_request.success_text')) ?></p>
                    <?php if (is_string($flash['reference'] ?? null) && $flash['reference'] !== ''): ?>
                        <p class="mt-1 text-sm font-mono"><?= e($t('service_request.success_reference')) ?>: <?= e((string) $flash['reference']) ?></p>
                    <?php endif; ?>
                </div>
            </div>
        <?php elseif ($errorKey !== ''): ?>
            <?php $message = $t('service_request.error_' . $errorKey); ?>
            <div class="mb-8 flex items-start gap-3 rounded-2xl border border-red-200 bg-red-50 px-4 py-4 text-red-800" role="alert">
                <svg class="mt-0.5 size-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                    <circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>
                </svg>
                <div>
                    <p class="font-semibold"><?= e($t('service_request.error_title')) ?></p>
                    <p class="text-sm"><?= e($message === 'service_request.error_' . $errorKey ? $t('service_request.error_text') : $message) ?></p>
                </div>
            </div>
        <?php endif; ?>

        <div class="grid gap-6 lg:grid-cols-[minmax(0,1.45fr)_minmax(300px,1fr)] lg:items-start">
            <div class="grid gap-6">
                <section class="surface-card">
                    <div class="mb-5 flex flex-wrap items-start justify-between gap-3">
                        <div>
                            <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('service_request.catalog_title')) ?></h2>
                            <p class="mt-1 text-sm text-muted"><?= e($t('service_request.catalog_hint')) ?></p>
                        </div>
                        <span class="rounded-full bg-mint px-3 py-1 text-xs font-semibold text-teal-dark"><?= e($t('service_request.catalog_source')) ?></span>
                    </div>

                    <?php if (!$catalogAvailable): ?>
                        <div class="rounded-2xl border border-dashed border-line bg-paper p-5">
                            <p class="font-semibold text-ink"><?= e($t('service_request.catalog_unavailable_title')) ?></p>
                            <p class="mt-1 text-sm text-muted"><?= e($t('service_request.catalog_unavailable_text')) ?></p>
                        </div>
                    <?php else: ?>
                        <div class="grid gap-3 sm:grid-cols-2">
                            <?php foreach ($products as $product): ?>
                                <?php $id = (string) $product['id']; ?>
                                <article class="flex flex-col justify-between gap-3 rounded-2xl border border-line bg-paper p-4 transition hover:border-teal/40">
                                    <div>
                                        <h3 class="text-sm font-semibold text-ink"><?= e((string) $product['label']) ?></h3>
                                        <?php if ((string) $product['key'] !== ''): ?>
                                            <p class="mt-1 font-mono text-xs text-ink-soft"><?= e((string) $product['key']) ?></p>
                                        <?php endif; ?>
                                        <p class="mt-2 text-sm font-semibold text-teal-dark">
                                            <?= $product['price'] === null
                                                ? e($t('service_request.quote_only'))
                                                : e(number_format((float) $product['price'], 2, ',', '.')) ?>
                                        </p>
                                        <p class="mt-1 text-xs text-muted"><?= e($t('service_request.modality_' . (string) $product['modality'])) ?></p>
                                    </div>
                                    <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/agregar')) ?>" class="flex items-center gap-2">
                                        <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                                        <input type="hidden" name="product_id" value="<?= e($id) ?>">
                                        <label class="sr-only" for="qty-<?= e($id) ?>"><?= e($t('service_request.quantity')) ?></label>
                                        <input class="form-field !w-16" id="qty-<?= e($id) ?>" name="quantity" type="number" min="1" max="20" value="1">
                                        <button class="btn-secondary !mt-0" type="submit"><?= e($t('service_request.add')) ?></button>
                                    </form>
                                </article>
                            <?php endforeach; ?>
                        </div>
                    <?php endif; ?>
                </section>
            </div>

            <div class="grid gap-6">
                <section class="surface-card">
                    <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('service_request.selection_title')) ?></h2>
                    <?php if ($selection === []): ?>
                        <p class="mt-4 rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('service_request.selection_empty')) ?></p>
                    <?php else: ?>
                        <ul class="mt-4 divide-y divide-line">
                            <?php foreach ($selection as $id => $quantity): ?>
                                <?php $product = $byId[(string) $id] ?? null; ?>
                                <li class="flex items-center justify-between gap-3 py-3 text-sm">
                                    <span class="font-semibold text-ink"><?= e($product['label'] ?? (string) $id) ?></span>
                                    <span class="flex items-center gap-2">
                                        <span class="text-muted"><?= e((string) $quantity) ?></span>
                                        <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/restar')) ?>">
                                            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                                            <input type="hidden" name="product_id" value="<?= e((string) $id) ?>">
                                            <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('service_request.remove_one')) ?></button>
                                        </form>
                                        <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/quitar')) ?>">
                                            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                                            <input type="hidden" name="product_id" value="<?= e((string) $id) ?>">
                                            <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('service_request.remove')) ?></button>
                                        </form>
                                    </span>
                                </li>
                            <?php endforeach; ?>
                        </ul>
                        <?php if ($hasPrices): ?>
                            <p class="mt-4 rounded-xl bg-paper px-4 py-3 text-sm">
                                <span class="font-semibold text-ink"><?= e($t('service_request.total_label')) ?>:</span>
                                <span class="text-teal-dark"><?= e(number_format($total, 2, ',', '.')) ?></span>
                            </p>
                        <?php endif; ?>
                        <p class="mt-2 text-xs text-muted"><?= e($t('service_request.total_hint')) ?></p>
                    <?php endif; ?>
                </section>

                <section class="surface-card">
                    <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('service_request.form_title')) ?></h2>
                    <p class="mt-1 text-xs text-muted"><?= e($t('service_request.form_hint')) ?></p>

                    <form method="post" action="<?= e(I18n::localizedPath($locale, '/solicitud/enviar')) ?>" class="mt-5 grid gap-4">
                        <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                        <input type="hidden" name="created_at" value="<?= e((string) time()) ?>">
                        <div class="absolute -left-[9999px] size-px overflow-hidden" aria-hidden="true">
                            <label for="request-website"><?= e($t('service_request.website')) ?></label>
                            <input id="request-website" name="website" type="text" tabindex="-1" autocomplete="off">
                        </div>

                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="request-organization"><?= e($t('service_request.form_organization')) ?> *</label>
                            <input class="form-field" id="request-organization" name="organization" type="text" required maxlength="160" value="<?= e($value('organization')) ?>" autocomplete="organization">
                        </div>
                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="request-contact"><?= e($t('service_request.form_contact')) ?> *</label>
                            <input class="form-field" id="request-contact" name="contact_name" type="text" required maxlength="120" value="<?= e($value('contact_name')) ?>" autocomplete="name">
                        </div>
                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="request-email"><?= e($t('service_request.form_email')) ?> *</label>
                            <input class="form-field" id="request-email" name="email" type="email" required maxlength="254" value="<?= e($value('email')) ?>" autocomplete="email">
                        </div>
                        <div class="grid gap-4 sm:grid-cols-2">
                            <div>
                                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="request-country"><?= e($t('service_request.form_country')) ?></label>
                                <input class="form-field" id="request-country" name="country" type="text" maxlength="100" value="<?= e($value('country')) ?>" autocomplete="country-name">
                            </div>
                            <div>
                                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="request-tax"><?= e($t('service_request.form_tax_id')) ?></label>
                                <input class="form-field" id="request-tax" name="tax_id" type="text" maxlength="64" value="<?= e($value('tax_id')) ?>">
                            </div>
                        </div>
                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="request-note"><?= e($t('service_request.form_notes')) ?></label>
                            <textarea class="form-field min-h-32 resize-y" id="request-note" name="note" rows="5" maxlength="2000" placeholder="<?= e($t('service_request.form_notes_placeholder')) ?>"><?= e($value('note')) ?></textarea>
                        </div>
                        <label class="flex items-start gap-2 text-sm text-ink-soft">
                            <input class="mt-1 size-4 rounded border-line text-teal focus:ring-teal/20" type="checkbox" name="terms" value="1" required>
                            <span><?= e($t('service_request.form_terms')) ?></span>
                        </label>
                        <p class="text-xs text-muted"><?= e($t('service_request.privacy_note')) ?></p>
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
