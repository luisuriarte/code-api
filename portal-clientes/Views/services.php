<?php
/** @var callable $t */
/** @var string $baseUrl */
/** @var string $locale */
/** @var string $csrfToken */
/** @var list<array<string, mixed>> $catalog */
/** @var list<array<string, mixed>> $entitlements */
/** @var list<array<string, mixed>> $requests */
/** @var list<array<string, mixed>> $pending */
/** @var list<array<string, mixed>> $operator_entitlements */
/** @var list<array<string, mixed>> $organizations */
/** @var bool $is_super_admin */
/** @var bool $can_request */
/** @var int|null $organization_id */
?>
<div class="mb-6 flex flex-wrap items-center justify-between gap-3">
    <div>
        <h1 class="text-2xl font-semibold tracking-tight text-ink sm:text-3xl"><?= e($t('customer.service.title')) ?></h1>
        <p class="mt-1 max-w-3xl text-sm text-muted"><?= e($t('customer.service.intro')) ?></p>
    </div>
    <a class="btn-secondary" href="<?= e($baseUrl . '/' . $locale . '/') ?>">
        <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><path d="M3 10.5 12 3l9 7.5V21h-6v-6H9v6H3z"/></svg>
        <?= e($t('customer.nav.home')) ?>
    </a>
</div>

<section class="surface-card">
    <div class="mb-4 flex items-center gap-3">
        <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                <path d="M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z"/>
            </svg>
        </span>
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.service.catalog')) ?></h2>
    </div>

    <?php if ($catalog === []): ?>
        <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.service.no_services')) ?></p>
    <?php else: ?>
        <div class="overflow-x-auto">
            <table class="w-full min-w-[40rem] text-sm">
                <thead>
                <tr class="border-b border-line">
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.code')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.name')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.route')) ?></th>
                    <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.access')) ?></th>
                </tr>
                </thead>
                <tbody class="divide-y divide-line">
                <?php foreach ($catalog as $service): ?>
                    <tr class="transition hover:bg-paper/70">
                        <td class="px-2 py-3"><code class="rounded-md bg-paper px-1.5 py-0.5 text-xs text-ink-soft"><?= e((string) $service['code']) ?></code></td>
                        <td class="px-2 py-3 font-semibold text-ink"><?= e((string) $service['name']) ?></td>
                        <td class="px-2 py-3"><code class="text-xs text-teal-dark"><?= e((string) $service['api_route']) ?></code></td>
                        <td class="px-2 py-3">
                            <span class="rounded-full bg-mint px-2.5 py-1 text-xs font-semibold text-teal-dark">
                                <?= e($t($service['auth_required'] ? 'customer.service.auth_required' : 'customer.service.public')) ?>
                            </span>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    <?php endif; ?>
</section>

<section class="surface-card mt-6">
    <div class="mb-4 flex items-center gap-3">
        <span class="flex size-9 items-center justify-center rounded-xl bg-teal/10 text-teal">
            <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <path d="M12 3v18M7 7h7a3 3 0 0 1 0 6H9a3 3 0 0 0 0 6h8"/>
            </svg>
        </span>
        <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.service.modalities_title')) ?></h2>
    </div>
    <div class="grid gap-3 md:grid-cols-3">
        <div class="rounded-2xl border border-line bg-paper p-4">
            <h3 class="text-sm font-semibold text-teal-dark"><?= e($t('customer.service.modality_public')) ?></h3>
            <p class="mt-2 text-xs text-muted"><?= e($t('customer.service.modality_public_hint')) ?></p>
        </div>
        <div class="rounded-2xl border border-line bg-paper p-4">
            <h3 class="text-sm font-semibold text-teal-dark"><?= e($t('customer.service.modality_from')) ?></h3>
            <p class="mt-2 text-xs text-muted"><?= e($t('customer.service.modality_from_hint')) ?></p>
        </div>
        <div class="rounded-2xl border border-line bg-paper p-4">
            <h3 class="text-sm font-semibold text-teal-dark"><?= e($t('customer.service.modality_quote')) ?></h3>
            <p class="mt-2 text-xs text-muted"><?= e($t('customer.service.modality_quote_hint')) ?></p>
        </div>
    </div>
    <p class="mt-4 rounded-xl border border-line bg-white px-4 py-3 text-xs text-muted"><?= e($t('customer.service.pricing_note')) ?></p>
    <p class="mt-2 rounded-xl border border-line bg-white px-4 py-3 text-xs text-muted"><?= e($t('customer.service.usage_note')) ?></p>
</section>

<?php if ($can_request): ?>
    <section class="surface-card mt-6">
        <div class="mb-4 flex items-center gap-3">
            <span class="flex size-9 items-center justify-center rounded-xl bg-teal/10 text-teal">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                    <path d="M12 5v14M5 12h14"/>
                </svg>
            </span>
            <div>
                <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.service.request')) ?></h2>
                <p class="text-xs text-muted"><?= e($t('customer.service.request_hint')) ?></p>
            </div>
        </div>

        <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/request" class="grid gap-4">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <fieldset class="grid gap-2 sm:grid-cols-2">
                <legend class="sr-only"><?= e($t('customer.service.catalog')) ?></legend>
                <?php foreach ($catalog as $service): ?>
                    <label class="flex items-center gap-2 rounded-xl border border-line bg-paper px-3 py-2 text-sm font-medium text-ink-soft transition hover:border-teal/40 hover:bg-mint">
                        <input class="size-4 rounded border-line text-teal focus:ring-teal/20" type="checkbox" name="service_ids[]" value="<?= e((string) $service['id']) ?>">
                        <?= e((string) $service['name']) ?>
                    </label>
                <?php endforeach; ?>
            </fieldset>
            <div>
                <label class="mb-1.5 block text-sm font-semibold text-ink-soft" for="request-note"><?= e($t('customer.service.note')) ?></label>
                <textarea class="form-field" id="request-note" name="note" rows="3" maxlength="2000"></textarea>
            </div>
            <div>
                <button class="btn-primary" type="submit">
                    <?= e($t('customer.service.request_submit')) ?>
                    <svg class="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M5 12h14M13 6l6 6-6 6"/></svg>
                </button>
            </div>
        </form>
    </section>
<?php endif; ?>

<?php if ($organization_id !== null): ?>
    <div class="mt-6 grid gap-6 lg:grid-cols-2">
        <section class="surface-card">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                        <path d="M20 6 9 17l-5-5"/>
                    </svg>
                </span>
                <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.service.my_services')) ?></h2>
            </div>
            <?php if ($entitlements === []): ?>
                <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.service.no_entitlements')) ?></p>
            <?php else: ?>
                <div class="overflow-x-auto">
                    <table class="w-full min-w-[28rem] text-sm">
                        <thead>
                        <tr class="border-b border-line">
                            <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.name')) ?></th>
                            <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.status_label')) ?></th>
                            <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.decided_at')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($entitlements as $entitlement): ?>
                            <tr class="transition hover:bg-paper/70">
                                <td class="px-2 py-3 font-semibold text-ink"><?= e((string) $entitlement['service_name']) ?></td>
                                <td class="px-2 py-3"><span class="rounded-full bg-mint px-2.5 py-1 text-xs font-semibold text-teal-dark"><?= e($t('customer.service.status.' . (string) $entitlement['status'])) ?></span></td>
                                <td class="px-2 py-3 text-muted"><?= e((string) ($entitlement['decision_at'] ?? '')) ?></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </section>

        <section class="surface-card">
            <div class="mb-4 flex items-center gap-3">
                <span class="flex size-9 items-center justify-center rounded-xl bg-mint text-teal">
                    <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                        <path d="M4 6h16M4 12h16M4 18h10"/>
                    </svg>
                </span>
                <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.service.requests')) ?></h2>
            </div>
            <?php if ($requests === []): ?>
                <p class="rounded-xl border border-dashed border-line bg-paper p-4 text-sm text-muted"><?= e($t('customer.service.no_requests')) ?></p>
            <?php else: ?>
                <div class="overflow-x-auto">
                    <table class="w-full min-w-[24rem] text-sm">
                        <thead>
                        <tr class="border-b border-line">
                            <th class="table-head px-2 py-3 text-left">ID</th>
                            <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.status_label')) ?></th>
                            <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.created_at')) ?></th>
                        </tr>
                        </thead>
                        <tbody class="divide-y divide-line">
                        <?php foreach ($requests as $request): ?>
                            <tr class="transition hover:bg-paper/70">
                                <td class="px-2 py-3"><code class="text-xs text-ink-soft"><?= e((string) $request['id']) ?></code></td>
                                <td class="px-2 py-3"><span class="rounded-full bg-paper px-2.5 py-1 text-xs font-semibold text-ink-soft"><?= e($t('customer.service.request_status.' . (string) $request['status'])) ?></span></td>
                                <td class="px-2 py-3 text-muted"><?= e((string) $request['created_at']) ?></td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            <?php endif; ?>
        </section>
    </div>
<?php endif; ?>

<?php if ($is_super_admin): ?>
    <section class="surface-card mt-6">
        <div class="mb-5 flex items-center gap-3">
            <span class="flex size-9 items-center justify-center rounded-xl bg-ink text-white">
                <svg class="size-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true">
                    <path d="M12 3 4 6v6c0 5 3.5 8.5 8 9 4.5-.5 8-4 8-9V6z"/>
                </svg>
            </span>
            <div>
                <h2 class="text-lg font-semibold tracking-tight text-ink"><?= e($t('customer.service.operator_panel')) ?></h2>
                <p class="text-xs text-muted"><?= e($t('customer.service.operator_note')) ?></p>
            </div>
        </div>

        <div class="grid gap-6 lg:grid-cols-3">
            <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/contrato" class="grid gap-3 rounded-2xl border border-line bg-paper p-4">
                <h3 class="text-sm font-semibold text-ink"><?= e($t('customer.service.new_contract')) ?></h3>
                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="contract-org"><?= e($t('customer.service.organization')) ?></label>
                    <select class="form-field" id="contract-org" name="organization_id">
                        <?php foreach ($organizations as $organization): ?>
                            <option value="<?= e((string) $organization['id']) ?>"><?= e((string) ($organization['display_name'] ?: $organization['legal_name'])) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="contract-client"><?= e($t('customer.service.external_client_ref')) ?></label>
                    <input class="form-field" id="contract-client" name="client_ref" maxlength="64">
                </div>
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="contract-item"><?= e($t('customer.service.external_item_ref')) ?></label>
                    <input class="form-field" id="contract-item" name="item_ref" maxlength="64">
                </div>
                <button class="btn-primary justify-self-start !mt-1" type="submit"><?= e($t('customer.service.create_contract')) ?></button>
            </form>

            <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/payment" class="grid content-start gap-3 rounded-2xl border border-line bg-paper p-4">
                <h3 class="text-sm font-semibold text-ink"><?= e($t('customer.service.verify_payment')) ?></h3>
                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="payment-contract"><?= e($t('customer.service.contract_id')) ?></label>
                    <input class="form-field" id="payment-contract" name="contract_id" inputmode="numeric" required>
                </div>
                <button class="btn-primary justify-self-start !mt-1" type="submit"><?= e($t('customer.service.verify_payment_submit')) ?></button>
            </form>

            <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/entitlement" class="grid gap-3 rounded-2xl border border-line bg-paper p-4">
                <h3 class="text-sm font-semibold text-ink"><?= e($t('customer.service.new_entitlement')) ?></h3>
                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="entitlement-org"><?= e($t('customer.service.organization')) ?></label>
                    <select class="form-field" id="entitlement-org" name="organization_id">
                        <?php foreach ($organizations as $organization): ?>
                            <option value="<?= e((string) $organization['id']) ?>"><?= e((string) ($organization['display_name'] ?: $organization['legal_name'])) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="entitlement-service"><?= e($t('customer.service.name')) ?></label>
                    <select class="form-field" id="entitlement-service" name="service_id">
                        <?php foreach ($catalog as $service): ?>
                            <option value="<?= e((string) $service['id']) ?>"><?= e((string) $service['name']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="entitlement-contract"><?= e($t('customer.service.contract_id')) ?></label>
                    <input class="form-field" id="entitlement-contract" name="contract_id" inputmode="numeric" required>
                </div>
                <div>
                    <label class="mb-1 block text-xs font-semibold text-ink-soft" for="entitlement-request"><?= e($t('customer.service.request_id')) ?></label>
                    <input class="form-field" id="entitlement-request" name="request_id" inputmode="numeric">
                </div>
                <button class="btn-primary justify-self-start !mt-1" type="submit"><?= e($t('customer.service.create_entitlement')) ?></button>
            </form>
        </div>

        <div class="mt-6 grid gap-6 lg:grid-cols-2">
            <div class="rounded-2xl border border-line bg-paper p-4">
                <h3 class="text-sm font-semibold text-ink"><?= e($t('customer.service.pending_review')) ?></h3>
                <?php if ($pending === []): ?>
                    <p class="mt-3 rounded-xl border border-dashed border-line bg-white p-4 text-sm text-muted"><?= e($t('customer.service.no_pending')) ?></p>
                <?php else: ?>
                    <div class="mt-3 overflow-x-auto">
                        <table class="w-full min-w-[32rem] text-sm">
                            <thead>
                            <tr class="border-b border-line">
                                <th class="table-head px-2 py-3 text-left">ID</th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.organization')) ?></th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.name')) ?></th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.contract_id')) ?></th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.actions')) ?></th>
                            </tr>
                            </thead>
                            <tbody class="divide-y divide-line">
                            <?php foreach ($pending as $item): ?>
                                <tr class="transition hover:bg-white">
                                    <td class="px-2 py-3"><code class="text-xs text-ink-soft"><?= e((string) $item['id']) ?></code></td>
                                    <td class="px-2 py-3 font-semibold text-ink"><?= e((string) ($item['organization_name'] ?: $item['organization_code'])) ?></td>
                                    <td class="px-2 py-3 text-ink-soft"><?= e((string) $item['service_name']) ?></td>
                                    <td class="px-2 py-3 text-muted"><?= e((string) ($item['contract_id'] ?? '')) ?></td>
                                    <td class="px-2 py-3">
                                        <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/activate">
                                            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                            <input type="hidden" name="entitlement_id" value="<?= e((string) $item['id']) ?>">
                                            <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('customer.service.activate')) ?></button>
                                        </form>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>

            <div class="rounded-2xl border border-line bg-paper p-4">
                <h3 class="text-sm font-semibold text-ink"><?= e($t('customer.service.operator_entitlements')) ?></h3>
                <?php if ($operator_entitlements === []): ?>
                    <p class="mt-3 rounded-xl border border-dashed border-line bg-white p-4 text-sm text-muted"><?= e($t('customer.service.no_operator_entitlements')) ?></p>
                <?php else: ?>
                    <div class="mt-3 overflow-x-auto">
                        <table class="w-full min-w-[34rem] text-sm">
                            <thead>
                            <tr class="border-b border-line">
                                <th class="table-head px-2 py-3 text-left">ID</th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.organization')) ?></th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.name')) ?></th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.status_label')) ?></th>
                                <th class="table-head px-2 py-3 text-left"><?= e($t('customer.service.actions')) ?></th>
                            </tr>
                            </thead>
                            <tbody class="divide-y divide-line">
                            <?php foreach ($operator_entitlements as $item): ?>
                                <?php $itemStatus = (string) ($item['status'] ?? ''); ?>
                                <tr class="transition hover:bg-white">
                                    <td class="px-2 py-3"><code class="text-xs text-ink-soft"><?= e((string) $item['id']) ?></code></td>
                                    <td class="px-2 py-3 font-semibold text-ink"><?= e((string) ($item['organization_name'] ?: $item['organization_code'])) ?></td>
                                    <td class="px-2 py-3 text-ink-soft"><?= e((string) $item['service_name']) ?></td>
                                    <td class="px-2 py-3"><span class="rounded-full bg-mint px-2.5 py-1 text-xs font-semibold text-teal-dark"><?= e($t('customer.service.status.' . $itemStatus)) ?></span></td>
                                    <td class="px-2 py-3">
                                        <div class="flex flex-wrap gap-2">
                                            <?php if (in_array($itemStatus, ['active', 'suspended'], true)): ?>
                                                <?php if ($itemStatus === 'active'): ?>
                                                    <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/status">
                                                        <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                                        <input type="hidden" name="entitlement_id" value="<?= e((string) $item['id']) ?>">
                                                        <input type="hidden" name="action" value="suspend">
                                                        <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('customer.service.suspend')) ?></button>
                                                    </form>
                                                <?php endif; ?>
                                                <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/status">
                                                    <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                                    <input type="hidden" name="entitlement_id" value="<?= e((string) $item['id']) ?>">
                                                    <input type="hidden" name="action" value="revoke">
                                                    <button class="btn-secondary !mt-0 !py-1" type="submit"><?= e($t('customer.service.revoke')) ?></button>
                                                </form>
                                            <?php endif; ?>
                                        </div>
                                    </td>
                                </tr>
                            <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                <?php endif; ?>
            </div>
        </div>
    </section>
<?php endif; ?>
