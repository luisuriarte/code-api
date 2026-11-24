<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var string $token */
/** @var array<string, mixed>|null $invitation */
?>
<div class="card">
    <h1><?= e($t('customer.invitation.title')) ?></h1>

    <?php if ($invitation === null) : ?>
        <p class="error"><?= e($t('customer.invitation.invalid')) ?></p>
    <?php else : ?>
        <p><?= e($t('customer.invitation.intro', ['%organization%' => (string) ($invitation['organization_name'] ?? '')])) ?></p>
        <p><?= e($t('customer.invitation.email', ['%email%' => (string) ($invitation['email'] ?? '')])) ?></p>

        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/invitations/' . rawurlencode($token)) ?>">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <label for="full_name"><?= e($t('customer.member.full_name')) ?></label>
            <input id="full_name" name="full_name" required maxlength="200">
            <label for="password"><?= e($t('customer.reset.password')) ?></label>
            <input id="password" name="password" type="password" minlength="12" required autocomplete="new-password">
            <button type="submit"><?= e($t('customer.invitation.submit')) ?></button>
        </form>
    <?php endif; ?>
</div>
