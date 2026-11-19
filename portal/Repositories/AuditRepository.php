<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

use PDO;
use PDOException;

/**
 * Escritura append-only en os_admin.audit_log.
 *
 * No expone UPDATE ni DELETE: además del trigger de base, este repositorio
 * solo construye INSERT.
 */
final class AuditRepository
{
    /** @param array<string, mixed> $entry */
    public static function append(array $entry): void
    {
        $sql = 'INSERT INTO os_admin.audit_log (
                    actor_user_id, actor_email, action, entity_type, entity_id,
                    catalog_code, before_state, after_state, reason,
                    ip_hash, user_agent_hash, request_id
                ) VALUES (
                    :actor_user_id, :actor_email, :action, :entity_type, :entity_id,
                    :catalog_code, :before_state, :after_state, :reason,
                    :ip_hash, :user_agent_hash, :request_id
                )';

        try {
            $statement = AdminDatabase::connection()->prepare($sql);
            $statement->execute([
                ':actor_user_id' => $entry['actor_user_id'] ?? null,
                ':actor_email' => $entry['actor_email'] ?? null,
                ':action' => (string) ($entry['action'] ?? 'unknown'),
                ':entity_type' => $entry['entity_type'] ?? null,
                ':entity_id' => $entry['entity_id'] ?? null,
                ':catalog_code' => $entry['catalog_code'] ?? null,
                ':before_state' => self::json($entry['before_state'] ?? null),
                ':after_state' => self::json($entry['after_state'] ?? null),
                ':reason' => $entry['reason'] ?? null,
                ':ip_hash' => $entry['ip_hash'] ?? null,
                ':user_agent_hash' => $entry['user_agent_hash'] ?? null,
                ':request_id' => $entry['request_id'] ?? null,
            ]);
        } catch (PDOException) {
            throw new RepositoryException('audit_unavailable');
        }
    }

    /** @return list<array<string, mixed>> */
    public static function recent(int $limit = 20): array
    {
        $limit = max(1, min(100, $limit));

        try {
            $statement = AdminDatabase::connection()->prepare(
                'SELECT actor_user_id, actor_email, action, entity_type, entity_id,
                        catalog_code, reason, occurred_at
                   FROM os_admin.audit_log
                  ORDER BY occurred_at DESC, id DESC
                  LIMIT ' . $limit
            );
            $statement->execute();

            return $statement->fetchAll();
        } catch (PDOException) {
            throw new RepositoryException('admin_database_unavailable');
        }
    }

    private static function json(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $encoded = json_encode($value, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);

        return $encoded === false ? null : $encoded;
    }
}
