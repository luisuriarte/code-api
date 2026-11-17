<?php

declare(strict_types=1);

use OrigenSalud\Portal\Services\Csrf;
use OrigenSalud\Web\I18n;

$value = static fn (string $key) => isset($form[$key]) && is_string($form[$key]) ? $form[$key] : '';
?>
<section class="section">
    <div class="container narrow">
        <span class="eyebrow"><?= e($t('contact.eyebrow')) ?></span>
        <h1><?= e($t('contact.title')) ?></h1>
        <p class="lead"><?= e($t('contact.lead')) ?></p>
    </div>
</section>

<section class="section section-alt">
    <div class="container narrow">
        <?php if (is_array($flash) && !empty($flash['ok'])): ?>
            <div class="alert alert-success" role="status">
                <strong><?= e($t('contact.success_title')) ?></strong>
                <p><?= e($t('contact.success_text')) ?></p>
            </div>
        <?php elseif (is_array($flash) && !empty($flash['error'])): ?>
            <div class="alert alert-error" role="alert">
                <strong><?= e($t('contact.error_title')) ?></strong>
                <p><?= e($t('contact.' . $flash['error'])) ?></p>
            </div>
        <?php endif; ?>

        <form class="contact-form" method="post" action="<?= e(I18n::localizedPath($locale, '/contact/send')) ?>">
            <input type="hidden" name="<?= e(Csrf::FIELD) ?>" value="<?= e($csrfToken) ?>">
            <input type="hidden" name="created_at" value="<?= e((string) time()) ?>">
            <div class="honeypot" aria-hidden="true">
                <label for="website">Website</label>
                <input id="website" name="website" type="text" tabindex="-1" autocomplete="off">
            </div>

            <div class="form-grid">
                <div class="field">
                    <label for="name"><?= e($t('contact.form_name')) ?> *</label>
                    <input id="name" name="name" type="text" required maxlength="120"
                           value="<?= e($value('name')) ?>" autocomplete="name">
                </div>
                <div class="field">
                    <label for="company"><?= e($t('contact.form_company')) ?></label>
                    <input id="company" name="company" type="text" maxlength="160"
                           value="<?= e($value('company')) ?>" autocomplete="organization">
                </div>
                <div class="field">
                    <label for="email"><?= e($t('contact.form_email')) ?> *</label>
                    <input id="email" name="email" type="email" required maxlength="254"
                           value="<?= e($value('email')) ?>" autocomplete="email">
                </div>
                <div class="field">
                    <label for="country"><?= e($t('contact.form_country')) ?></label>
                    <input id="country" name="country" type="text" maxlength="100"
                           value="<?= e($value('country')) ?>" autocomplete="country-name">
                </div>
                <div class="field field-full">
                    <label for="type"><?= e($t('contact.form_type')) ?> *</label>
                    <select id="type" name="type" required>
                        <?php foreach ($types as $type): ?>
                            <option value="<?= e($type) ?>" <?= $value('type') === $type ? 'selected' : '' ?>>
                                <?= e($t('contact.type_' . $type)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="field field-full">
                    <label for="message"><?= e($t('contact.form_message')) ?> *</label>
                    <textarea id="message" name="message" rows="7" required minlength="10" maxlength="5000"
                              placeholder="<?= e($t('contact.message_placeholder')) ?>"><?= e($value('message')) ?></textarea>
                </div>
            </div>

            <p class="form-note"><?= e($t('contact.privacy_note')) ?></p>
            <button class="button" type="submit"><?= e($t('contact.form_submit')) ?></button>
        </form>
    </div>
</section>
