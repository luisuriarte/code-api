<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Repositories;

/**
 * Error estable de repositorio. Su mensaje es un código seguro para la vista;
 * nunca contiene SQL, credenciales ni detalles internos de PostgreSQL.
 */
final class RepositoryException extends \RuntimeException
{
}
