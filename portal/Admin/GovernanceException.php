<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Admin;

/** Error de gestión con código estable para mostrar un mensaje i18n. */
final class GovernanceException extends \RuntimeException
{
    public function __construct(public readonly string $errorCode)
    {
        parent::__construct($errorCode);
    }
}
