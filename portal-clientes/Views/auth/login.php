<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var string|null $error */
?>
<div class="card">
    <h1><?= e($t('customer.login.title')) ?></h1>

    <?php if (is_string($error) && $error !== '') : ?>
        <p class="error"><?= e($t($error)) ?></p>
    <?php endif; ?>

    <form method="post" action="<?= e($baseUrl . '/' . $locale . '/login') ?>">
        <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
        <label for="email"><?= e($t('customer.login.email')) ?></label>
        <input id="email" name="email" type="email" required autocomplete="username">

        <label for="password"><?= e($t('customer.login.password')) ?></label>
        <input id="password" name="password" type="password" required autocomplete="current-password">

        <button type="submit"><?= e($t('customer.login.submit')) ?></button>
    </form>

    <p><a href="<?= e($baseUrl . '/' . $locale . '/forgot') ?>"><?= e($t('customer.login.forgot')) ?></a></p>
</div>
