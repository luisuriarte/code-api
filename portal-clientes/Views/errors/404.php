<?php
/** @var callable $t */
?>
<div class="card">
    <h1><?= e($t('customer.error.not_found_title')) ?></h1>
    <p><?= e($t('customer.error.not_found_body')) ?></p>
    <p><a href="/portal-clientes/<?= e((string) ($locale ?? 'es-AR')) ?>/"><?= e($t('customer.nav.home')) ?></a></p>
</div>
