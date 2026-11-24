<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var array<string, mixed> $user */
/** @var list<array<string, mixed>> $organizations */
/** @var array<string, mixed>|null $organization */
/** @var int|null $organization_id */
?>
<div class="card">
    <h1><?= e($t('customer.home.title')) ?></h1>
    <p><?= e($t('customer.home.welcome', ['%name%' => (string) ($user['full_name'] ?? '')])) ?></p>
    <p><?= e($t('customer.home.context', ['%organization%' => $organization['display_name'] ?? $organization['legal_name'] ?? $t('customer.home.none')])) ?></p>
</div>

<?php if ($organizations === []) : ?>
    <div class="card"><p><?= e($t('customer.home.no_organization')) ?></p></div>
<?php else : ?>
    <div class="card">
        <h2><?= e($t('customer.home.organizations')) ?></h2>
        <?php foreach ($organizations as $org) : ?>
            <?php $id = (int) ($org['id'] ?? 0); ?>
            <form method="post" action="<?= e($baseUrl . '/' . $locale . '/organizations/switch') ?>">
                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                <input type="hidden" name="organization_id" value="<?= e($id) ?>">
                <button type="submit"<?= $id === $organization_id ? ' disabled' : '' ?>>
                    <?= e($t('customer.home.switch', ['%name%' => (string) ($org['display_name'] ?? $org['legal_name'] ?? '' )])) ?>
                </button>
            </form>
        <?php endforeach; ?>
    </div>
<?php endif; ?>

<div class="card">
    <a href="<?= e($baseUrl . '/' . $locale . '/organizations') ?>"><?= e($t('customer.nav.organizations')) ?></a>
    <a href="<?= e($baseUrl . '/' . $locale . '/members') ?>"><?= e($t('customer.nav.members')) ?></a>
    <form method="post" action="<?= e($baseUrl . '/' . $locale . '/logout') ?>">
        <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
        <button type="submit"><?= e($t('customer.nav.logout')) ?></button>
    </form>
</div>
