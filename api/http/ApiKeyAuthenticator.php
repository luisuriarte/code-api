<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Http;

use PDO;

/**
 * Autenticación de clientes B2B mediante API Key.
 *
 * La clave se acepta en el header X-API-Key o como Bearer token:
 *   X-API-Key: <clave>
 *   Authorization: Bearer <clave>
 *
 * Las claves nuevas se verifican contra SHA-256(clave + NUL + pepper) en
 * `key_hash` (migración V11.001). Las antiguas se leen por compatibilidad desde
 * `api_key` en texto plano, sin exponer cuál de los dos caminos autenticó.
 */
final class ApiKeyAuthenticator
{
    public function __construct(private readonly PDO $db)
    {
    }

    /**
     * @return array{id: int, institution_name: string, rate_limit_per_second: int}
     *
     * @throws ApiException
     */
    public function authenticate(Request $request): array
    {
        $apiKey = $request->header('x-api-key') ?? $request->bearerToken();

        if ($apiKey === null || trim($apiKey) === '') {
            throw ApiException::unauthorized(
                'Falta la API Key. Enviá el header X-API-Key o Authorization: Bearer <clave>.'
            );
        }

        $apiKey = trim($apiKey);

        if (strlen($apiKey) > 128 || preg_match('/^[\x21-\x7E]+$/', $apiKey) !== 1) {
            throw ApiException::unauthorized('La API Key tiene un formato inválido.');
        }

        $client = false;

        // Lectura primaria: clave hasheada. Solo si hay pepper y la migración
        // V11.001 ya está aplicada; en producción sin migrar se omite.
        if (ApiKeyHash::enabled() && ApiKeyHash::columnsAvailable($this->db)) {
            $statement = $this->db->prepare(
                'SELECT id, institution_name, rate_limit_per_second
                   FROM api_clients
                  WHERE key_prefix = :prefix
                    AND key_hash = :hash
                    AND is_active = TRUE
                  LIMIT 1'
            );
            $statement->execute([
                ':prefix' => ApiKeyHash::prefix($apiKey),
                ':hash' => ApiKeyHash::of($apiKey),
            ]);
            $client = $statement->fetch();
        }

        // Lectura de compatibilidad: claves legacy en texto plano.
        if ($client === false) {
            $statement = $this->db->prepare(
                'SELECT id, institution_name, rate_limit_per_second
                   FROM api_clients
                  WHERE api_key = :api_key
                    AND is_active = TRUE
                  LIMIT 1'
            );
            $statement->execute([':api_key' => $apiKey]);
            $client = $statement->fetch();
        }

        if ($client === false) {
            // Mismo mensaje para clave inexistente o inactiva: no se filtra
            // información sobre clientes registrados.
            throw ApiException::unauthorized('La API Key es inválida o está inactiva.');
        }

        return [
            'id' => (int) $client['id'],
            'institution_name' => (string) $client['institution_name'],
            'rate_limit_per_second' => (int) $client['rate_limit_per_second'],
        ];
    }
}
