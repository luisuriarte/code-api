<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services\InvoiceNinja;

/**
 * Adaptador de prueba determinista. Nunca abre una conexión de red.
 *
 * Los datos son identificadores ficticios. No contienen precios, facturas,
 * pagos ni datos personales reales.
 */
final class MockInvoiceNinjaTransport implements InvoiceNinjaTransport
{
    /**
     * @param list<array<string, mixed>> $clients
     */
    public function __construct(private readonly array $clients = [])
    {
    }

    public function get(string $path, array $query = []): array
    {
        if ($path !== '/clients') {
            return ['ok' => false, 'status' => 404, 'data' => null, 'error' => 'mock_unsupported_path'];
        }

        $taxId = isset($query['tax_id']) ? (string) $query['tax_id'] : '';
        $name = isset($query['legal_name']) ? (string) $query['legal_name'] : '';
        $email = isset($query['email']) ? (string) $query['email'] : '';

        $matches = [];
        foreach ($this->clients as $client) {
            $clientTax = (string) ($client['tax_id_normalized'] ?? '');
            $clientName = (string) ($client['legal_name'] ?? '');
            $clientEmail = (string) ($client['contact_email'] ?? '');

            $byTax = $taxId !== '' && $clientTax === $taxId;
            $byName = $name !== '' && $clientName === $name;
            $byEmail = $email !== '' && $clientEmail === $email;

            if ($byTax || $byName || $byEmail) {
                $matches[] = [
                    'id' => (string) ($client['id'] ?? ''),
                    'tax_id_normalized' => $clientTax,
                    'legal_name' => $clientName,
                    'matched_by' => $byTax ? 'tax_id' : ($byName ? 'legal_name' : 'contact'),
                ];
            }
        }

        return [
            'ok' => true,
            'status' => 200,
            'data' => ['data' => $matches],
            'error' => null,
        ];
    }
}
