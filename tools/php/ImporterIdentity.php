<?php

declare(strict_types=1);

namespace OrigenSalud\Tools\Php;

use PDO;
use RuntimeException;

/**
 * Identidad de importador y compuerta de corte controlado (Fases 11 y 13).
 *
 * app.importer_run_id se fija con set_config(..., true) DENTRO de la
 * transacción: la auditoría de D-23 puede distinguir escrituras de proceso de
 * escrituras humanas sin usar SESSION_USER como sustituto del actor real.
 */
final class ImporterIdentity
{
    public const MODE_DUAL = 'dual';
    public const MODE_NEW_ONLY = 'new_only';

    public static function newRunId(string $importer): string
    {
        $prefix = trim(str_replace([' ', ':', '/'], '-', $importer));
        if ($prefix === '') {
            $prefix = 'importer';
        }

        return $prefix . ':' . gmdate('Ymd\THis\Z') . ':' . bin2hex(random_bytes(4));
    }

    /**
     * Modo de escritura. El default es dual: el corte a new_only nunca se
     * activa automáticamente (Fase 13).
     */
    public static function mode(): string
    {
        $value = function_exists('env')
            ? env('OS_IMPORT_MODE', self::MODE_DUAL)
            : (getenv('OS_IMPORT_MODE') ?: self::MODE_DUAL);

        $mode = strtolower(trim((string) $value));

        return in_array($mode, [self::MODE_DUAL, self::MODE_NEW_ONLY], true)
            ? $mode
            : self::MODE_DUAL;
    }

    /**
     * new_only queda como compuerta explícita: hoy no existe implementación
     * write-only verificada hacia os_*, así que falla en vez de cambiar el
     * comportamiento de escritura sin una decisión operativa.
     */
    public static function assertWritableMode(): void
    {
        if (self::mode() === self::MODE_NEW_ONLY) {
            throw new RuntimeException(
                'OS_IMPORT_MODE=new_only requiere la implementación write-only aprobada en Fase 13; '
                . 'no se activa automáticamente. Dejar OS_IMPORT_MODE=dual.'
            );
        }
    }

    public static function bind(PDO $db, string $runId, ?string $actorId = null): void
    {
        $statement = $db->prepare(
            "SELECT set_config('app.importer_run_id', :run_id, true), "
            . "set_config('app.actor_type', 'importer', true), "
            . "set_config('app.actor_id', :actor_id, true)"
        );
        $statement->execute([
            ':run_id' => $runId,
            ':actor_id' => $actorId ?? '',
        ]);
    }
}
