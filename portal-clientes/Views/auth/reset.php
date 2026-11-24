<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var string $token */
/** @var bool $valid */
?>
<div class="card">
    <h1><?= e($t('customer.reset.title')) ?></h1>

    <?php if (!$valid) : ?>
        <p class="error"><?= e($t('customer.reset.invalid')) ?></p>
    <?php else : ?>
        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/reset/' . rawurlencode($token)) ?>">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <label for="password"><?= e($t('customer.reset.password')) ?></label>
            <input id="password" name="password" type="password" minlength="12" required autocomplete="new-password">
            <button type="submit"><?= e($t('customer.reset.submit')) ?></button>
        </form>
    <?php endif; ?>
</div>
