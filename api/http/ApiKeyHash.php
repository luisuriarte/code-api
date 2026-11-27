<?php

declare(strict_types=1);

namespace OrigenSalud\Api\Http;

use PDO;
use Throwable;

/**
 * Formato común de las claves de la API propia.
 *
 * Las claves nuevas se guardan como SHA-256(clave + NUL + pepper) en
 * `key_hash`, con un `key_prefix` para búsquedas indexadas. El pepper vive solo
 * en el entorno del servidor; nunca se versiona ni se envía al cliente.
 *
 * Mientras la migración V11.001 no se ejecute (o el pepper no esté configurado),
 * el sistema sigue leyendo `api_key` en texto plano por compatibilidad. Para no
 * romper producción, la disponibilidad de columnas se detecta una sola vez por
 * conexión y la lectura es dual: hash primero, legacy después.
 */
final class ApiKeyHash
{
    public static function enabled(): bool
    {
        return trim((string) env('API_KEY_PEPPER', '')) !== '';
    }

    public static function of(string $rawKey): string
    {
        return hash('sha256', $rawKey . "\0" . trim((string) env('API_KEY_PEPPER', '')));
    }

    public static function prefix(string $rawKey): string
    {
        return substr($rawKey, 0, 12);
    }

    /** Indica si `public.api_clients` ya expone las columnas de V11.001. */
    public static function columnsAvailable(PDO $db): bool
    {
        /** @var array<int, bool> $cache */
        static $cache = [];

        $id = spl_object_id($db);

        if (array_key_exists($id, $cache)) {
            return $cache[$id];
        }

        try {
            $statement = $db->prepare(
                "SELECT 1 FROM information_schema.columns
                  WHERE table_schema = 'public'
                    AND table_name = 'api_clients'
                    AND column_name = 'key_hash'
                  LIMIT 1"
            );
            $statement->execute();
            $cache[$id] = $statement->fetchColumn() !== false;
        } catch (Throwable) {
            // Sin columnas nuevas: se mantiene el esquema legacy intacto.
            $cache[$id] = false;
        }

        return $cache[$id];
    }
}
