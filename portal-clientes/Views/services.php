<?php
/** @var callable $t */
/** @var string $locale */
/** @var string $csrfToken */
/** @var list<array<string, mixed>> $catalog */
/** @var list<array<string, mixed>> $entitlements */
/** @var list<array<string, mixed>> $requests */
/** @var list<array<string, mixed>> $pending */
/** @var list<array<string, mixed>> $organizations */
/** @var bool $is_super_admin */
/** @var bool $can_request */
/** @var int|null $organization_id */
?>
<h1><?= e($t('customer.service.title')) ?></h1>
<p><?= e($t('customer.service.intro')) ?></p>

<div class="card">
    <h2><?= e($t('customer.service.catalog')) ?></h2>
    <?php if ($catalog === []): ?>
        <p><?= e($t('customer.service.no_services')) ?></p>
    <?php else: ?>
        <table>
            <thead>
            <tr>
                <th><?= e($t('customer.service.code')) ?></th>
                <th><?= e($t('customer.service.name')) ?></th>
                <th><?= e($t('customer.service.route')) ?></th>
                <th><?= e($t('customer.service.access')) ?></th>
            </tr>
            </thead>
            <tbody>
            <?php foreach ($catalog as $service): ?>
                <tr>
                    <td><code><?= e((string) $service['code']) ?></code></td>
                    <td><?= e((string) $service['name']) ?></td>
                    <td><code><?= e((string) $service['api_route']) ?></code></td>
                    <td><?= e($t($service['auth_required'] ? 'customer.service.auth_required' : 'customer.service.public')) ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    <?php endif; ?>
</div>

<?php if ($can_request): ?>
    <div class="card">
        <h2><?= e($t('customer.service.request')) ?></h2>
        <p><?= e($t('customer.service.request_hint')) ?></p>
        <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/request">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <?php foreach ($catalog as $service): ?>
                <label>
                    <input type="checkbox" name="service_ids[]" value="<?= e((string) $service['id']) ?>" style="width:auto">
                    <?= e((string) $service['name']) ?>
                </label>
            <?php endforeach; ?>
            <label for="request-note"><?= e($t('customer.service.note')) ?></label>
            <textarea id="request-note" name="note" rows="3" maxlength="2000"></textarea>
            <button type="submit"><?= e($t('customer.service.request_submit')) ?></button>
        </form>
    </div>
<?php endif; ?>

<?php if ($organization_id !== null): ?>
    <div class="card">
        <h2><?= e($t('customer.service.my_services')) ?></h2>
        <?php if ($entitlements === []): ?>
            <p><?= e($t('customer.service.no_entitlements')) ?></p>
        <?php else: ?>
            <table>
                <thead>
                <tr>
                    <th><?= e($t('customer.service.name')) ?></th>
                    <th><?= e($t('customer.service.status_label')) ?></th>
                    <th><?= e($t('customer.service.decided_at')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($entitlements as $entitlement): ?>
                    <tr>
                        <td><?= e((string) $entitlement['service_name']) ?></td>
                        <td><?= e($t('customer.service.status.' . (string) $entitlement['status'])) ?></td>
                        <td><?= e((string) ($entitlement['decision_at'] ?? '')) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>

    <div class="card">
        <h2><?= e($t('customer.service.requests')) ?></h2>
        <?php if ($requests === []): ?>
            <p><?= e($t('customer.service.no_requests')) ?></p>
        <?php else: ?>
            <table>
                <thead>
                <tr>
                    <th>ID</th>
                    <th><?= e($t('customer.service.status_label')) ?></th>
                    <th><?= e($t('customer.service.created_at')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($requests as $request): ?>
                    <tr>
                        <td><?= e((string) $request['id']) ?></td>
                        <td><?= e($t('customer.service.request_status.' . (string) $request['status'])) ?></td>
                        <td><?= e((string) $request['created_at']) ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
<?php endif; ?>

<?php if ($is_super_admin): ?>
    <div class="card">
        <h2><?= e($t('customer.service.operator_panel')) ?></h2>
        <p><?= e($t('customer.service.operator_note')) ?></p>

        <h3><?= e($t('customer.service.new_contract')) ?></h3>
        <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/contrato">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <label for="contract-org"><?= e($t('customer.service.organization')) ?></label>
            <select id="contract-org" name="organization_id">
                <?php foreach ($organizations as $organization): ?>
                    <option value="<?= e((string) $organization['id']) ?>">
                        <?= e((string) ($organization['display_name'] ?: $organization['legal_name'])) ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <label for="contract-client"><?= e($t('customer.service.external_client_ref')) ?></label>
            <input id="contract-client" name="client_ref" maxlength="64">
            <label for="contract-item"><?= e($t('customer.service.external_item_ref')) ?></label>
            <input id="contract-item" name="item_ref" maxlength="64">
            <button type="submit"><?= e($t('customer.service.create_contract')) ?></button>
        </form>

        <h3><?= e($t('customer.service.verify_payment')) ?></h3>
        <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/payment">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <label for="payment-contract"><?= e($t('customer.service.contract_id')) ?></label>
            <input id="payment-contract" name="contract_id" inputmode="numeric" required>
            <button type="submit"><?= e($t('customer.service.verify_payment_submit')) ?></button>
        </form>

        <h3><?= e($t('customer.service.new_entitlement')) ?></h3>
        <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/entitlement">
            <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
            <label for="entitlement-org"><?= e($t('customer.service.organization')) ?></label>
            <select id="entitlement-org" name="organization_id">
                <?php foreach ($organizations as $organization): ?>
                    <option value="<?= e((string) $organization['id']) ?>">
                        <?= e((string) ($organization['display_name'] ?: $organization['legal_name'])) ?>
                    </option>
                <?php endforeach; ?>
            </select>
            <label for="entitlement-service"><?= e($t('customer.service.name')) ?></label>
            <select id="entitlement-service" name="service_id">
                <?php foreach ($catalog as $service): ?>
                    <option value="<?= e((string) $service['id']) ?>"><?= e((string) $service['name']) ?></option>
                <?php endforeach; ?>
            </select>
            <label for="entitlement-contract"><?= e($t('customer.service.contract_id')) ?></label>
            <input id="entitlement-contract" name="contract_id" inputmode="numeric" required>
            <label for="entitlement-request"><?= e($t('customer.service.request_id')) ?></label>
            <input id="entitlement-request" name="request_id" inputmode="numeric">
            <button type="submit"><?= e($t('customer.service.create_entitlement')) ?></button>
        </form>

        <h3><?= e($t('customer.service.pending_review')) ?></h3>
        <?php if ($pending === []): ?>
            <p><?= e($t('customer.service.no_pending')) ?></p>
        <?php else: ?>
            <table>
                <thead>
                <tr>
                    <th>ID</th>
                    <th><?= e($t('customer.service.organization')) ?></th>
                    <th><?= e($t('customer.service.name')) ?></th>
                    <th><?= e($t('customer.service.contract_id')) ?></th>
                    <th><?= e($t('customer.service.actions')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($pending as $item): ?>
                    <tr>
                        <td><?= e((string) $item['id']) ?></td>
                        <td><?= e((string) ($item['organization_name'] ?: $item['organization_code'])) ?></td>
                        <td><?= e((string) $item['service_name']) ?></td>
                        <td><?= e((string) ($item['contract_id'] ?? '')) ?></td>
                        <td>
                            <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/activate">
                                <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                <input type="hidden" name="entitlement_id" value="<?= e((string) $item['id']) ?>">
                                <button type="submit"><?= e($t('customer.service.activate')) ?></button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>

        <h3><?= e($t('customer.service.operator_entitlements')) ?></h3>
        <?php if ($operator_entitlements === []): ?>
            <p><?= e($t('customer.service.no_operator_entitlements')) ?></p>
        <?php else: ?>
            <table>
                <thead>
                <tr>
                    <th>ID</th>
                    <th><?= e($t('customer.service.organization')) ?></th>
                    <th><?= e($t('customer.service.name')) ?></th>
                    <th><?= e($t('customer.service.status_label')) ?></th>
                    <th><?= e($t('customer.service.actions')) ?></th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($operator_entitlements as $item): ?>
                    <?php $itemStatus = (string) ($item['status'] ?? ''); ?>
                    <tr>
                        <td><?= e((string) $item['id']) ?></td>
                        <td><?= e((string) ($item['organization_name'] ?: $item['organization_code'])) ?></td>
                        <td><?= e((string) $item['service_name']) ?></td>
                        <td><?= e($t('customer.service.status.' . $itemStatus)) ?></td>
                        <td>
                            <?php if (in_array($itemStatus, ['active', 'suspended'], true)): ?>
                                <?php if ($itemStatus === 'active'): ?>
                                    <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/status">
                                        <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                        <input type="hidden" name="entitlement_id" value="<?= e((string) $item['id']) ?>">
                                        <input type="hidden" name="action" value="suspended">
                                        <button type="submit"><?= e($t('customer.service.suspend')) ?></button>
                                    </form>
                                <?php endif; ?>
                                <form method="post" action="/portal-clientes/<?= e($locale) ?>/servicios/status">
                                    <input type="hidden" name="_csrf" value="<?= e($csrfToken) ?>">
                                    <input type="hidden" name="entitlement_id" value="<?= e((string) $item['id']) ?>">
                                    <input type="hidden" name="action" value="revoked">
                                    <button type="submit"><?= e($t('customer.service.revoke')) ?></button>
                                </form>
                            <?php endif; ?>
                        </td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
<?php endif; ?>
