<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use OrigenSalud\Portal\Config;

/**
 * Persistencia de la Solicitud de Servicios pública (Etapa 10).
 *
 * Guarda solo la solicitud y las referencias opacas de productos elegidos.
 * No guarda precios, importes, facturas, pagos ni datos de la base comercial.
 * Usa la conexión pública con privilegios limitados a estas dos tablas.
 */
final class PublicServiceRequestRepository
{
    public static function available(): bool
    {
        $config = Config::database();

        return $config['dsn'] !== '' && $config['pass'] !== '';
    }

    /**
     * @param array<string, mixed> $request
     * @return int Identificador de la solicitud.
     * @throws RepositoryException
     */
    public static function create(array $request): int
    {
        $sql = 'INSERT INTO os_customer.public_service_request
                    (reference, locale, organization_name, contact_name, contact_email,
                     country, tax_id_normalized, dedupe_key, note, terms_accepted,
                     status, ninja_client_status, duplicate_of)
                VALUES
                    (:reference, :locale, :organization_name, :contact_name, :contact_email,
                     :country, :tax_id_normalized, :dedupe_key, :note, :terms_accepted,
                     :status, :ninja_client_status, :duplicate_of)
                RETURNING id';

        try {
            $statement = PortalDatabase::connection()->prepare($sql);
            $statement->execute([
                ':reference' => (string) $request['reference'],
                ':locale' => (string) $request['locale'],
                ':organization_name' => (string) $request['organization_name'],
                ':contact_name' => (string) $request['contact_name'],
                ':contact_email' => (string) $request['contact_email'],
                ':country' => (string) $request['country'],
                ':tax_id_normalized' => (string) $request['tax_id_normalized'],
                ':dedupe_key' => (string) $request['dedupe_key'],
                ':note' => (string) $request['note'],
                ':terms_accepted' => true,
                ':status' => (string) $request['status'],
                ':ninja_client_status' => (string) $request['ninja_client_status'],
                ':duplicate_of' => ($request['duplicate_of'] ?? null) === null
                    ? null
                    : (int) $request['duplicate_of'],
            ]);

            return (int) $statement->fetchColumn();
        } catch (\PDOException) {
            throw new RepositoryException('request_not_saved');
        }
    }

    /** @throws RepositoryException */
    public static function addItem(int $requestId, string $productRef, int $quantity): void
    {
        try {
            $statement = PortalDatabase::connection()->prepare(
                'INSERT INTO os_customer.public_service_request_item
                    (request_id, product_ref, quantity)
                 VALUES (:request_id, :product_ref, :quantity)'
            );
            $statement->execute([
                ':request_id' => $requestId,
                ':product_ref' => $productRef,
                ':quantity' => $quantity,
            ]);
        } catch (\PDOException) {
            throw new RepositoryException('request_item_not_saved');
        }
    }

    /**
     * @return array{id: int, reference: string, created_at: string}|null
     * @throws RepositoryException
     */
    public static function findRecent(string $dedupeKey, int $windowDays): ?array
    {
        try {
            $statement = PortalDatabase::connection()->prepare(
                'SELECT id, reference, created_at
                   FROM os_customer.public_service_request
                  WHERE dedupe_key = :dedupe_key
                    AND created_at >= now() - (:days * interval \'1 day\')
                  ORDER BY created_at DESC
                  LIMIT 1'
            );
            $statement->execute([
                ':dedupe_key' => $dedupeKey,
                ':days' => $windowDays,
            ]);
            $row = $statement->fetch();

            return is_array($row) ? [
                'id' => (int) $row['id'],
                'reference' => (string) $row['reference'],
                'created_at' => (string) $row['created_at'],
            ] : null;
        } catch (\PDOException) {
            throw new RepositoryException('duplicate_check_unavailable');
        }
    }
}
