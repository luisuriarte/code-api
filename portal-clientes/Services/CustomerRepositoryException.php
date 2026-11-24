<?php

declare(strict_types=1);

namespace OrigenSalud\CustomerPortal\Services;

use RuntimeException;

/** Error estable de repositorio: nunca expone mensajes de PDO al navegador. */
final class CustomerRepositoryException extends RuntimeException
{
}
