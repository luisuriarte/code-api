<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Web\I18n;

$value = static fn (string $key) => isset($form[$key]) && is_string($form[$key]) ? $form[$key] : '';
$contactEmail = is_string($contactEmail ?? null) ? $contactEmail : '';
?>
<section class="border-b border-line/70 bg-paper">
    <div class="mx-auto w-full max-w-3xl px-4 py-14 text-center sm:px-6 sm:py-20">
        <span class="text-xs font-semibold uppercase tracking-[0.18em] text-teal"><?= e($t('contact.eyebrow')) ?></span>
        <h1 class="mt-3 text-3xl font-semibold tracking-tight text-ink sm:text-4xl"><?= e($t('contact.title')) ?></h1>
        <p class="mx-auto mt-4 max-w-2xl text-base leading-relaxed text-ink-soft sm:text-lg"><?= e($t('contact.lead')) ?></p>
    </div>
</section>

<section class="bg-white py-12 sm:py-16">
    <div class="mx-auto w-full max-w-5xl px-4 sm:px-6">
        <div class="grid gap-6 lg:grid-cols-[minmax(0,1.6fr)_minmax(260px,1fr)] lg:items-start">
            <div class="surface-card">
                <?php if (is_array($flash) && !empty($flash['ok'])): ?>
                    <div class="mb-6 flex items-start gap-3 rounded-2xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-emerald-800" role="status">
                        <svg class="mt-0.5 size-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                            <circle cx="12" cy="12" r="9"/><path d="m8 12 2.5 2.5L16 9"/>
                        </svg>
                        <div>
                            <p class="font-semibold"><?= e($t('contact.success_title')) ?></p>
                            <p class="text-sm opacity-80"><?= e($t('contact.success_text')) ?></p>
                        </div>
                    </div>
                <?php elseif (is_array($flash) && !empty($flash['error'])): ?>
                    <?php
                    $errorKey = is_string($flash['error']) ? $flash['error'] : '';
                    $reason = is_string($flash['reason'] ?? null) ? $flash['reason'] : '';
                    $reasonKey = 'contact.error_reason_' . $reason;
                    $reasonMessage = $reason !== '' && $t($reasonKey) !== $reasonKey ? $t($reasonKey) : $t('contact.error_text');
                    ?>
                    <div class="mb-6 flex items-start gap-3 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-red-800" role="alert">
                        <svg class="mt-0.5 size-5 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true">
                            <circle cx="12" cy="12" r="9"/><path d="M12 8v4M12 16h.01"/>
                        </svg>
                        <div>
                            <p class="font-semibold"><?= e($t('contact.error_title')) ?></p>
                            <p class="text-sm"><?= e($t('contact.' . $errorKey)) ?></p>
                            <p class="mt-1 text-sm opacity-80"><?= e($reasonMessage) ?></p>
                        </div>
                    </div>
                <?php endif; ?>

                <form method="post" action="<?= e(I18n::localizedPath($locale, '/contact/send')) ?>" class="grid gap-5">
                    <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
                    <input type="hidden" name="created_at" value="<?= e((string) time()) ?>">
                    <div class="absolute -left-[9999px] size-px overflow-hidden" aria-hidden="true">
                        <label for="website">Website</label>
                        <input id="website" name="website" type="text" tabindex="-1" autocomplete="off">
                    </div>

                    <div class="grid gap-5 sm:grid-cols-2">
                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="name"><?= e($t('contact.form_name')) ?> *</label>
                            <input class="form-field" id="name" name="name" type="text" required maxlength="120" value="<?= e($value('name')) ?>" autocomplete="name">
                        </div>
                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="company"><?= e($t('contact.form_company')) ?></label>
                            <input class="form-field" id="company" name="company" type="text" maxlength="160" value="<?= e($value('company')) ?>" autocomplete="organization">
                        </div>
                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="email"><?= e($t('contact.form_email')) ?> *</label>
                            <input class="form-field" id="email" name="email" type="email" required maxlength="254" value="<?= e($value('email')) ?>" autocomplete="email">
                        </div>
                        <div>
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="country"><?= e($t('contact.form_country')) ?></label>
                            <input class="form-field" id="country" name="country" type="text" maxlength="100" value="<?= e($value('country')) ?>" autocomplete="country-name">
                        </div>
                        <div class="sm:col-span-2">
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="type"><?= e($t('contact.form_type')) ?> *</label>
                            <select class="form-field" id="type" name="type" required>
                                <?php foreach ($types as $type): ?>
                                    <option value="<?= e($type) ?>" <?= $value('type') === $type ? 'selected' : '' ?>><?= e($t('contact.type_' . $type)) ?></option>
                                <?php endforeach; ?>
                            </select>
                        </div>
                        <div class="sm:col-span-2">
                            <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="message"><?= e($t('contact.form_message')) ?> *</label>
                            <textarea class="form-field min-h-40 resize-y" id="message" name="message" rows="7" required minlength="10" maxlength="5000" placeholder="<?= e($t('contact.message_placeholder')) ?>"><?= e($value('message')) ?></textarea>
                        </div>
                    </div>

                    <p class="text-xs text-muted"><?= e($t('contact.privacy_note')) ?></p>
                    <button class="btn-primary justify-self-start" type="submit">
                        <?= e($t('contact.form_submit')) ?>
                        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
                    </button>
                </form>
            </div>

            <aside class="surface-card bg-paper">
                <span class="flex size-10 items-center justify-center rounded-xl bg-teal/10 text-teal">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                        <rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>
                    </svg>
                </span>
                <h2 class="mt-4 text-lg font-semibold tracking-tight text-ink"><?= e($t('contact.direct_title')) ?></h2>
                <p class="mt-2 text-sm leading-relaxed text-ink-soft"><?= e($t('contact.direct_text')) ?></p>
                <?php if ($contactEmail !== ''): ?>
                    <a class="mt-4 inline-flex break-all font-semibold text-teal transition hover:text-teal-dark" href="mailto:<?= e($contactEmail) ?>"><?= e($contactEmail) ?></a>
                <?php endif; ?>
            </aside>
        </div>
    </div>
</section>
