<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
?>
<div class="card">
    <h1><?= e($t('customer.forgot.title')) ?></h1>
    <p><?= e($t('customer.forgot.intro')) ?></p>

    <form method="post" action="<?= e($baseUrl . '/' . $locale . '/forgot') ?>">
        <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
        <label for="email"><?= e($t('customer.login.email')) ?></label>
        <input id="email" name="email" type="email" required autocomplete="username">
        <button type="submit"><?= e($t('customer.forgot.submit')) ?></button>
    </form>

    <p><a href="<?= e($baseUrl . '/' . $locale . '/login') ?>"><?= e($t('customer.nav.login')) ?></a></p>
</div>
