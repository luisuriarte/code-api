<?php

declare(strict_types=1);

namespace OrigenSalud\Portal\Services;

/**
 * Normalización y validación de entrada del portal.
 */
final class Validator
{
    public static function text(mixed $value, int $maxLength = 255): string
    {
        if (!is_string($value)) {
            return '';
        }

        $value = preg_replace('/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/u', '', $value) ?? '';
        $value = trim($value);

        return mb_substr($value, 0, $maxLength);
    }

    public static function email(mixed $value): string
    {
        $value = self::text($value, 254);

        return filter_var($value, FILTER_VALIDATE_EMAIL) ? $value : '';
    }

    public static function choice(mixed $value, array $allowed): string
    {
        $value = self::text($value, 64);

        return in_array($value, $allowed, true) ? $value : '';
    }
}
