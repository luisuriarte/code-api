<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $organizations */
/** @var list<string> $types */
?>
<section class="admin-panel">
    <h1><?= e($t('admin.orgs.title')) ?></h1>
    <p class="admin-lead"><?= e($t('admin.orgs.lead')) ?></p>

    <?php require __DIR__ . '/_flash.php'; ?>

    <div class="admin-grid">
        <article class="admin-box">
            <h2><?= e($t('admin.orgs.new')) ?></h2>
            <?php
            $values = $flash['values'] ?? [];
            $value = static fn (string $key, string $default = ''): string => e(
                is_string($values[$key] ?? null) && $values[$key] !== '' ? $values[$key] : $default
            );
            ?>
            <form method="post" action="/admin/organizations" class="admin-form">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <label><?= e($t('admin.orgs.code')) ?>
                    <input type="text" name="code" required maxlength="40"
                           pattern="[a-z0-9][a-z0-9-]{1,39}" value="<?= $value('code') ?>">
                </label>
                <label><?= e($t('admin.orgs.name')) ?>
                    <input type="text" name="name" required maxlength="180" value="<?= $value('name') ?>">
                </label>
                <label><?= e($t('admin.orgs.legal_name')) ?>
                    <input type="text" name="legal_name" maxlength="240" value="<?= $value('legal_name') ?>">
                </label>
                <label><?= e($t('admin.orgs.type')) ?>
                    <select name="type">
                        <?php foreach ($types as $type): ?>
                            <option value="<?= e($type) ?>" <?= ($values['type'] ?? 'external') === $type ? 'selected' : '' ?>>
                                <?= e($t('admin.roles.org_type.' . $type)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </label>
                <label><?= e($t('admin.orgs.country')) ?>
                    <input type="text" name="country_code" required maxlength="2"
                           pattern="[A-Za-z]{2}" value="<?= $value('country_code', 'AR') ?>">
                </label>
                <label><?= e($t('admin.email')) ?>
                    <input type="email" name="contact_email" maxlength="254" value="<?= $value('contact_email') ?>">
                </label>
                <label><?= e($t('admin.orgs.website')) ?>
                    <input type="url" name="website" maxlength="254" value="<?= $value('website') ?>">
                </label>
                <label><?= e($t('admin.orgs.confirm_duplicate')) ?>
                    <input type="checkbox" name="confirm_duplicate" value="1">
                </label>
                <label><?= e($t('admin.orgs.notes')) ?>
                    <textarea name="notes" rows="3" maxlength="1000"><?= $value('notes') ?></textarea>
                </label>
                <button type="submit" class="button"><?= e($t('admin.orgs.create')) ?></button>
            </form>
        </article>

        <article class="admin-box">
            <h2><?= e($t('admin.orgs.list')) ?></h2>
            <?php if ($organizations === []): ?>
            <p><?= e($t('admin.orgs.empty')) ?></p>
            <?php else: ?>
            <div class="admin-table-wrap">
                <table class="admin-table">
                    <thead>
                    <tr>
                        <th><?= e($t('admin.orgs.code')) ?></th>
                        <th><?= e($t('admin.orgs.name')) ?></th>
                        <th><?= e($t('admin.orgs.country')) ?></th>
                        <th><?= e($t('admin.orgs.members')) ?></th>
                        <th><?= e($t('admin.orgs.status')) ?></th>
                    </tr>
                    </thead>
                    <tbody>
                    <?php foreach ($organizations as $organization): ?>
                        <tr>
                            <td><code><?= e((string) ($organization['code'] ?? '')) ?></code></td>
                            <td><a href="/admin/organizations/<?= (int) $organization['id'] ?>"><?= e((string) $organization['name']) ?></a></td>
                            <td><?= e((string) $organization['country_code']) ?></td>
                            <td><?= (int) $organization['members'] ?></td>
                            <td><?= (bool) $organization['is_active']
                                ? e($t('admin.orgs.active')) : e($t('admin.orgs.inactive')) ?></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <?php endif; ?>
        </article>
    </div>
</section>
