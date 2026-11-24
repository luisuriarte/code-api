<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var list<array<string, mixed>> $organizations */
/** @var array<string, mixed> $organization */
/** @var bool $can_update */
?>
<div class="card">
    <h1><?= e($t('customer.org.title')) ?></h1>
    <dl>
        <dt><?= e($t('customer.org.legal_name')) ?></dt>
        <dd><?= e((string) ($organization['legal_name'] ?? '')) ?></dd>
        <dt><?= e($t('customer.org.display_name')) ?></dt>
        <dd><?= e((string) ($organization['display_name'] ?? '')) ?></dd>
        <dt><?= e($t('customer.org.tax_id')) ?></dt>
        <dd><?= e((string) ($organization['tax_id_normalized'] ?? '')) ?></dd>
        <dt><?= e($t('customer.org.country')) ?></dt>
        <dd><?= e((string) ($organization['country'] ?? '')) ?></dd>
    </dl>
</div>

<?php if ($can_update) : ?>
    <div class="card">
        <h2><?= e($t('customer.org.update')) ?></h2>
        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/organizations/update') ?>">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <label for="legal_name"><?= e($t('customer.org.legal_name')) ?></label>
            <input id="legal_name" name="legal_name" required maxlength="200" value="<?= e((string) ($organization['legal_name'] ?? '')) ?>">
            <label for="display_name"><?= e($t('customer.org.display_name')) ?></label>
            <input id="display_name" name="display_name" maxlength="200" value="<?= e((string) ($organization['display_name'] ?? '')) ?>">
            <label for="tax_id"><?= e($t('customer.org.tax_id')) ?></label>
            <input id="tax_id" name="tax_id" maxlength="32" value="<?= e((string) ($organization['tax_id_normalized'] ?? '')) ?>">
            <button type="submit"><?= e($t('customer.org.save')) ?></button>
        </form>
    </div>
<?php endif; ?>

<div class="card">
    <h2><?= e($t('customer.home.organizations')) ?></h2>
    <?php foreach ($organizations as $org) : ?>
        <form method="post" action="<?= e($baseUrl . '/' . $locale . '/organizations/switch') ?>" style="margin-bottom:.5rem">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <input type="hidden" name="organization_id" value="<?= e((int) ($org['id'] ?? 0)) ?>">
            <button type="submit"><?= e($t('customer.home.switch', ['%name%' => (string) ($org['display_name'] ?? $org['legal_name'] ?? '')])) ?></button>
        </form>
    <?php endforeach; ?>
</div>
