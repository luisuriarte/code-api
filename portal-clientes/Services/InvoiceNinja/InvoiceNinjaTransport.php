<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services\InvoiceNinja;

/**
 * Transporte de solo lectura hacia Invoice Ninja.
 *
 * @return array{ok: bool, status: int, data: ?array<string, mixed>, error: ?string}
 */
interface InvoiceNinjaTransport
{
    /**
     * @param array<string, string|int|null> $query
     */
    public function get(string $path, array $query = []): array;
}
