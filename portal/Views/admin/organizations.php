<?php

declare(strict_types=1);

/** @var list<array<string, mixed>> $organizations */
/** @var list<string> $types */
?>
<section class="space-y-6">
    <div class="ui-card ui-card-pad">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div>
                <h1 class="ui-title"><?= e($t('admin.orgs.title')) ?></h1>
                <p class="ui-subtitle"><?= e($t('admin.orgs.lead')) ?></p>
            </div>
            <span class="flex h-12 w-12 items-center justify-center rounded-2xl bg-mint text-teal-dark">
                <i data-lucide="building-2" class="h-6 w-6"></i>
            </span>
        </div>
    </div>

    <?php require __DIR__ . '/_flash.php'; ?>

    <div class="ui-grid items-start">
        <article class="ui-card ui-card-pad">
            <h2 class="mb-5 text-lg font-semibold text-ink"><?= e($t('admin.orgs.new')) ?></h2>
            <?php
            $values = $flash['values'] ?? [];
            $value = static fn (string $key, string $default = ''): string => e(
                is_string($values[$key] ?? null) && $values[$key] !== '' ? $values[$key] : $default
            );
            ?>
            <form method="post" action="/admin/organizations" class="grid gap-4 sm:grid-cols-2">
                <input type="hidden" name="<?= e(\OrigenSalud\Portal\Services\Csrf::FIELD) ?>"
                       value="<?= e(\OrigenSalud\Portal\Services\Csrf::token()) ?>">
                <div>
                    <label for="org-code" class="ui-label"><?= e($t('admin.orgs.code')) ?></label>
                    <input id="org-code" type="text" name="code" required maxlength="40"
                           pattern="[a-z0-9][a-z0-9-]{1,39}" value="<?= $value('code') ?>" class="ui-input">
                </div>
                <div>
                    <label for="org-name" class="ui-label"><?= e($t('admin.orgs.name')) ?></label>
                    <input id="org-name" type="text" name="name" required maxlength="180" value="<?= $value('name') ?>" class="ui-input">
                </div>
                <div class="sm:col-span-2">
                    <label for="org-legal" class="ui-label"><?= e($t('admin.orgs.legal_name')) ?></label>
                    <input id="org-legal" type="text" name="legal_name" maxlength="240" value="<?= $value('legal_name') ?>" class="ui-input">
                </div>
                <div>
                    <label for="org-type" class="ui-label"><?= e($t('admin.orgs.type')) ?></label>
                    <select id="org-type" name="type" class="ui-input">
                        <?php foreach ($types as $type): ?>
                            <option value="<?= e($type) ?>" <?= ($values['type'] ?? 'external') === $type ? 'selected' : '' ?>>
                                <?= e($t('admin.roles.org_type.' . $type)) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div>
                    <label for="org-country" class="ui-label"><?= e($t('admin.orgs.country')) ?></label>
                    <input id="org-country" type="text" name="country_code" required maxlength="2"
                           pattern="[A-Za-z]{2}" value="<?= $value('country_code', 'AR') ?>" class="ui-input">
                </div>
                <div>
                    <label for="org-email" class="ui-label"><?= e($t('admin.email')) ?></label>
                    <input id="org-email" type="email" name="contact_email" maxlength="254" value="<?= $value('contact_email') ?>" class="ui-input">
                </div>
                <div>
                    <label for="org-website" class="ui-label"><?= e($t('admin.orgs.website')) ?></label>
                    <input id="org-website" type="url" name="website" maxlength="254" value="<?= $value('website') ?>" class="ui-input">
                </div>
                <label class="flex items-center gap-2 text-sm text-ink-soft sm:col-span-2">
                    <input type="checkbox" name="confirm_duplicate" value="1"
                           class="h-4 w-4 rounded border-line text-teal focus:ring-teal/30">
                    <?= e($t('admin.orgs.confirm_duplicate')) ?>
                </label>
                <div class="sm:col-span-2">
                    <label for="org-notes" class="ui-label"><?= e($t('admin.orgs.notes')) ?></label>
                    <textarea id="org-notes" name="notes" rows="3" maxlength="1000" class="ui-input"><?= $value('notes') ?></textarea>
                </div>
                <div class="flex flex-col gap-2 sm:col-span-2 sm:flex-row">
                    <button type="submit" class="ui-btn w-full">
                        <i data-lucide="plus" class="h-4 w-4"></i>
                        <?= e($t('admin.orgs.create')) ?>
                    </button>
                    <a href="/admin/organizations" class="ui-btn ui-btn-ghost w-full no-underline">
                        <?= e($t('admin.cancel')) ?>
                    </a>
                </div>
            </form>
        </article>

        <article class="ui-card ui-card-pad">
            <h2 class="mb-5 text-lg font-semibold text-ink"><?= e($t('admin.orgs.list')) ?></h2>
            <?php if ($organizations === []): ?>
                <p class="ui-empty"><?= e($t('admin.orgs.empty')) ?></p>
            <?php else: ?>
                <div class="ui-table-wrap">
                    <table class="ui-table">
                        <thead>
                        <tr>
                            <th class="ui-th"><?= e($t('admin.orgs.code')) ?></th>
                            <th class="ui-th"><?= e($t('admin.orgs.name')) ?></th>
                            <th class="ui-th"><?= e($t('admin.orgs.country')) ?></th>
                            <th class="ui-th"><?= e($t('admin.orgs.members')) ?></th>
                            <th class="ui-th"><?= e($t('admin.orgs.status')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($organizations as $organization): ?>
                            <tr class="transition hover:bg-paper/60">
                                <td class="ui-td"><code class="ui-code"><?= e((string) ($organization['code'] ?? '')) ?></code></td>
                                <td class="ui-td font-medium text-ink">
                                    <a href="/admin/organizations/<?= (int) $organization['id'] ?>" class="no-underline hover:underline">
                                        <?= e((string) $organization['name']) ?>
                                    </a>
                                </td>
                                <td class="ui-td"><?= e((string) $organization['country_code']) ?></td>
                                <td class="ui-td"><span class="ui-badge"><?= (int) $organization['members'] ?></span></td>
                                <td class="ui-td">
                                    <span class="<?= (bool) $organization['is_active'] ? 'text-teal-dark' : 'text-muted' ?>">
                                        <?= (bool) $organization['is_active']
                                            ? e($t('admin.orgs.active')) : e($t('admin.orgs.inactive')) ?>
                                    </span>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </article>
    </div>
</section>
