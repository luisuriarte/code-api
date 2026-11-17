<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

/**
 * Limitador de frecuencia por sesión y acción.
 *
 * Combinado con honeypot y control de tiempo mínimo de llenado en el formulario.
 * No sustituye a un límite por IP en capa de servidor web.
 */
final class RateLimiter
{
    public static function hit(string $action, int $limit, int $windowSeconds): bool
    {
        $key = 'ratelimit.' . $action;
        $now = time();
        $events = Session::get($key, []);

        if (!is_array($events)) {
            $events = [];
        }

        $events = array_values(array_filter(
            $events,
            static fn (mixed $timestamp): bool => is_int($timestamp) && $timestamp > $now - $windowSeconds
        ));

        if (count($events) >= $limit) {
            Session::set($key, $events);

            return false;
        }

        $events[] = $now;
        Session::set($key, $events);

        return true;
    }
}
