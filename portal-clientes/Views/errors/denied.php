<?php
/** @var callable $t */
?>
<div class="card">
    <h1><?= e($t('customer.error.denied_title')) ?></h1>
    <p><?= e($t('customer.error.denied_body')) ?></p>
    <p><a href="/portal-clientes/<?= e((string) ($locale ?? 'es-AR')) ?>/"><?= e($t('customer.nav.home')) ?></a></p>
</div>
